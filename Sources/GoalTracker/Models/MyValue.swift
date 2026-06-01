import Foundation

struct MyValue: Identifiable, Codable, Equatable {
    var id: UUID
    var text: String

    init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }
}

enum MyValueStore {
    static let storageKey = "GoalTracker.myValues"

    static func currentValues() -> [MyValue] {
        decode(UserDefaults.standard.string(forKey: storageKey) ?? "")
    }

    static func save(_ values: [MyValue]) {
        UserDefaults.standard.set(encode(values), forKey: storageKey)
    }

    static func decode(_ rawValue: String) -> [MyValue] {
        guard let data = rawValue.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([MyValue].self, from: data)) ?? []
    }

    static func encode(_ values: [MyValue]) -> String {
        guard let data = try? JSONEncoder().encode(values) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}
