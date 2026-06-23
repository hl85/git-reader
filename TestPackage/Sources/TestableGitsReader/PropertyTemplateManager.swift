import Foundation
import Yams
import Combine

public struct PropertyField: Codable, Identifiable, Hashable {
    public var id: String { name }
    public var name: String
    public var type: FieldType
    public var options: [String]?
    
    public enum FieldType: String, Codable, CaseIterable {
        case date
        case `enum`
        case tags
        case text
    }
    
    public init(name: String, type: FieldType, options: [String]? = nil) {
        self.name = name
        self.type = type
        self.options = options
    }
}

@MainActor
public class PropertyTemplateManager: ObservableObject {
    @MainActor public static let shared = PropertyTemplateManager()
    
    @Published public var templateYAML: String {
        didSet {
            UserDefaults.standard.set(templateYAML, forKey: "PropertyTemplateYAML")
            reloadTemplate()
        }
    }
    
    @Published public private(set) var fields: [PropertyField] = []
    
    private init() {
        let defaultYAML = """
        - name: date
          type: date
        - name: status
          type: enum
          options: [idea, draft, review, reading, archived]
        - name: tags
          type: tags
        """
        self.templateYAML = UserDefaults.standard.string(forKey: "PropertyTemplateYAML") ?? defaultYAML
        reloadTemplate()
    }
    
    public func reloadTemplate() {
        guard let activeRepo = GitSyncService.shared.activeRepository else {
            parseGlobalTemplate()
            return
        }
        
        let repoRoot = GitSyncService.shared.repoRootURL
        let configFileURL = repoRoot
            .appendingPathComponent(".obsidian")
            .appendingPathComponent("gitsreader.yaml")
            
        guard FileManager.default.fileExists(atPath: configFileURL.path) else {
            parseGlobalTemplate()
            return
        }
        
        do {
            let yamlData = try String(contentsOf: configFileURL, encoding: .utf8)
            let decoder = YAMLDecoder()
            let repoFields = try decoder.decode([PropertyField].self, from: yamlData)
            self.fields = repoFields
            print("[PropertyTemplateManager] Successfully loaded repository-level template for: \(activeRepo.name)")
        } catch {
            print("[PropertyTemplateManager] Failed to parse repository-level template, falling back to global: \(error)")
            parseGlobalTemplate()
        }
    }
    
    private func parseGlobalTemplate() {
        do {
            let decoder = YAMLDecoder()
            self.fields = try decoder.decode([PropertyField].self, from: templateYAML)
        } catch {
            print("[PropertyTemplateManager] Failed to parse global template: \(error)")
            self.fields = []
        }
    }
}
