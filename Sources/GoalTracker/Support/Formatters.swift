import Foundation

enum Formatters {
    static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    static func minutes(_ value: Int) -> String {
        value == 1 ? "1 min" : "\(value) min"
    }

    static func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\n") || escaped.contains("\"") {
            return "\"\(escaped)\""
        }
        return escaped
    }
}
