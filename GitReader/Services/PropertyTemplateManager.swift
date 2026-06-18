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
            parseTemplate()
        }
    }
    
    @Published var fields: [PropertyField] = []
    
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
        parseTemplate()
    }
    
    private func parseTemplate() {
        do {
            let decoder = YAMLDecoder()
            self.fields = try decoder.decode([PropertyField].self, from: templateYAML)
        } catch {
            print("Failed to parse property template YAML: \(error)")
        }
    }
}
