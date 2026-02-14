import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Poe API 响应模型

/// Poe API 配额响应
private struct PoeBalanceResponse: Decodable {
    let currentPointBalance: Int?

    enum CodingKeys: String, CodingKey {
        case currentPointBalance = "current_point_balance"
    }
}

/// Poe 使用历史响应 (可选)
private struct PoeUsageHistoryResponse: Decodable {
    let history: [PoeUsageEntry]?

    struct PoeUsageEntry: Decodable {
        let date: Int?
        let pointsUsed: Int?

        enum CodingKeys: String, CodingKey {
            case date
            case pointsUsed = "points_used"
        }
    }
}

// MARK: - Poe 使用快照

/// Poe 配额使用快照
public struct PoeUsageSnapshot: Sendable {
    public let balance: Int
    public let used: Int
    public let monthlyQuota: Int?
    public let nextResetTime: Date?
    public let updatedAt: Date

    public init(
        balance: Int,
        used: Int,
        monthlyQuota: Int?,
        nextResetTime: Date?,
        updatedAt: Date
    ) {
        self.balance = balance
        self.used = used
        self.monthlyQuota = monthlyQuota
        self.nextResetTime = nextResetTime
        self.updatedAt = updatedAt
    }

    /// 转换为通用的 UsageSnapshot
    public func toUsageSnapshot() -> UsageSnapshot {
        // Poe API 只返回当前余额，不返回总配额
        // 使用配置的配额或默认配额来计算使用百分比
        let totalPoints = self.monthlyQuota ?? 1_000_000
        let usedPoints = max(0, totalPoints - self.balance)
        let usedPercent = totalPoints > 0 ? Double(usedPoints) / Double(totalPoints) * 100 : 0

        let primary = RateWindow(
            usedPercent: usedPercent,
            windowMinutes: nil,
            resetsAt: self.nextResetTime,
            resetDescription: "Points")

        let identity = ProviderIdentitySnapshot(
            providerID: .poe,
            accountEmail: nil,
            accountOrganization: nil,
            loginMethod: "API Key")

        return UsageSnapshot(
            primary: primary,
            secondary: nil,
            tertiary: nil,
            providerCost: nil,
            poeUsage: self,
            updatedAt: self.updatedAt,
            identity: identity)
    }
}

// MARK: - Poe 使用情况获取器

/// 从 Poe API 获取使用统计数据
public struct PoeUsageFetcher: Sendable {
    private static let log = CodexBarLog.logger(LogCategories.poe)

    /// Poe API 默认主机
    private static let defaultAPIHost = "https://api.poe.com"

    /// Poe API 配额端点路径
    private static let balanceAPIPath = "/usage/current_balance"

    /// 解析配额 URL
    public static func resolveBalanceURL(
        apiHost: String?,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        let host = apiHost ?? PoeSettingsReader.apiHost(environment: environment) ?? Self.defaultAPIHost

        guard let baseURL = URL(string: host) else {
            // 如果无法解析,使用默认值
            return URL(string: "\(Self.defaultAPIHost)\(Self.balanceAPIPath)")!
        }

        if baseURL.path.isEmpty || baseURL.path == "/" {
            return baseURL.appendingPathComponent(Self.balanceAPIPath)
        }

        return baseURL
    }

    /// 使用提供的 API Key 从 Poe 获取使用统计
    public static func fetchUsage(
        apiKey: String,
        apiHost: String? = nil,
        monthlyQuota: Int? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) async throws -> PoeUsageSnapshot {
        guard !apiKey.isEmpty else {
            throw PoeUsageError.invalidCredentials
        }

        let balanceURL = Self.resolveBalanceURL(apiHost: apiHost, environment: environment)

        var request = URLRequest(url: balanceURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PoeUsageError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            Self.log.error("Poe API returned \(httpResponse.statusCode): \(errorMessage)")
            throw PoeUsageError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }

        // 检查空响应
        guard !data.isEmpty else {
            Self.log.error("Poe API returned empty body (HTTP 200) for \(Self.safeURLForLogging(balanceURL))")
            throw PoeUsageError.parseFailed("Empty response body (HTTP 200)")
        }

        // 记录原始响应用于调试
        if let jsonString = String(data: data, encoding: .utf8) {
            Self.log.debug("Poe API response: \(jsonString)")
        }

        do {
            return try Self.parseUsageSnapshot(from: data, monthlyQuota: monthlyQuota)
        } catch let error as DecodingError {
            Self.log.error("Poe JSON decoding error: \(error.localizedDescription)")
            throw PoeUsageError.parseFailed(error.localizedDescription)
        } catch let error as PoeUsageError {
            throw error
        } catch {
            Self.log.error("Poe parsing error: \(error.localizedDescription)")
            throw PoeUsageError.parseFailed(error.localizedDescription)
        }
    }

    private static func safeURLForLogging(_ url: URL) -> String {
        let host = url.host ?? "<unknown-host>"
        let port = url.port.map { ":\($0)" } ?? ""
        let path = url.path.isEmpty ? "/" : url.path
        return "\(host)\(port)\(path)"
    }

    /// 从数据解析使用快照
    static func parseUsageSnapshot(from data: Data, monthlyQuota: Int? = nil) throws -> PoeUsageSnapshot {
        guard !data.isEmpty else {
            throw PoeUsageError.parseFailed("Empty response body")
        }

        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(PoeBalanceResponse.self, from: data)

        // 提取数据,使用默认值处理缺失字段
        let balance = apiResponse.currentPointBalance ?? 0

        // Poe API 只返回当前余额，不返回已使用数量和重置时间
        let used = 0
        let nextResetTime: Date? = nil

        return PoeUsageSnapshot(
            balance: balance,
            used: used,
            monthlyQuota: monthlyQuota,
            nextResetTime: nextResetTime,
            updatedAt: Date())
    }
}

// MARK: - Poe 使用错误

/// Poe 使用情况获取期间可能发生的错误
public enum PoeUsageError: LocalizedError, Sendable {
    case invalidCredentials
    case networkError(String)
    case apiError(String)
    case parseFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            "Invalid Poe API credentials"
        case let .networkError(message):
            "Poe network error: \(message)"
        case let .apiError(message):
            "Poe API error: \(message)"
        case let .parseFailed(message):
            "Failed to parse Poe response: \(message)"
        }
    }
}
