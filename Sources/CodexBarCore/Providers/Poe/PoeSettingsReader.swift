import Foundation

public struct PoeSettingsReader: Sendable {
    public static let apiKeyKey = "POE_API_KEY"
    public static let apiHostKey = "POE_API_HOST"

    public static func apiKey(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String? {
        if let token = self.cleaned(environment[apiKeyKey]) { return token }
        return nil
    }

    public static func apiHost(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String? {
        self.cleaned(environment[apiHostKey])
    }

    static func cleaned(_ raw: String?) -> String? {
        guard var value = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }

        // 移除引号包裹
        if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
           (value.hasPrefix("'") && value.hasSuffix("'")) {
            value.removeFirst()
            value.removeLast()
        }

        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

public enum PoeSettingsError: LocalizedError, Sendable {
    case missingToken

    public var errorDescription: String? {
        switch self {
        case .missingToken:
            "Poe API key not found. Set POE_API_KEY environment variable."
        }
    }
}
