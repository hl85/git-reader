import Foundation
import Yams
import Combine

struct PropertyField: Codable, Identifiable, Hashable {
    var id: String { name }
    var name: String
    var type: FieldType
    var options: [String]?
    
    enum FieldType: String, Codable, CaseIterable {
        case date
        case `enum`
        case tags
        case text
    }
}

@MainActor
class PropertyTemplateManager: ObservableObject {
    @MainActor static let shared = PropertyTemplateManager()
    
    @Published var templateYAML: String {
        didSet {
            UserDefaults.standard.set(templateYAML, forKey: "PropertyTemplateYAML")
            reloadTemplate()
        }
    }
    
    @Published private(set) var fields: [PropertyField] = []
    
    private var cancellables = Set<AnyCancellable>()
    
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
        
        // 订阅仓库切换通知
        NotificationCenter.default.publisher(for: .activeRepositoryDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadTemplate()
            }
            .store(in: &cancellables)
            
        // 订阅同步完成通知（配置文件可能被更新）
        NotificationCenter.default.publisher(for: .gitSyncDidComplete)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadTemplate()
            }
            .store(in: &cancellables)
            
        reloadTemplate()
    }
    
    func reloadTemplate() {
        guard let activeRepo = GitSyncService.shared.activeRepository else {
            parseGlobalTemplate()
            return
        }
        
        let repoRoot = GitSyncService.shared.repoRootURL
        let configFileURL = repoRoot
            .appendingPathComponent(".obsidian")
            .appendingPathComponent("gr-workflow.yaml")
            
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
