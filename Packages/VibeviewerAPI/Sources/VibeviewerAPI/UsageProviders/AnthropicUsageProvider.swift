import Foundation
import VibeviewerModel

struct AnthropicUsageProvider: UsageProvider {
    let settings: AppSettings.ProviderSettings
    let session: URLSession

    init(settings: AppSettings.ProviderSettings, session: URLSession = .shared) {
        self.settings = settings
        self.session = session
    }

    var kind: UsageProviderKind { .anthropic }

    func fetchTotals(dateRange: DateInterval) async throws -> ProviderUsageTotal? {
        guard settings.anthropicAPIKey.isEmpty == false else { return nil }

        var components = URLComponents(string: "https://api.anthropic.com/v1/usage")!
        components.queryItems = [
            .init(name: "start_time", value: ISO8601DateFormatter.usage.string(from: dateRange.start)),
            .init(name: "end_time", value: ISO8601DateFormatter.usage.string(from: dateRange.end))
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue(settings.anthropicAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        let usage = try decoder.decode(AnthropicUsageResponse.self, from: data)

        let cents = Int((usage.totalSpendUSD * 100).rounded())
        let requests = usage.data.reduce(0) { $0 + ($1.numRequests ?? 0) }

        return ProviderUsageTotal(
            provider: .anthropic,
            spendCents: cents,
            requestCount: requests,
            currencyCode: "USD"
        )
    }
}

private struct AnthropicUsageResponse: Decodable {
    struct Entry: Decodable {
        let numRequests: Int?
        let totalCost: Cost?
    }

    struct Cost: Decodable {
        let amount: Double
        let currency: String
    }

    let data: [Entry]
    let totalUsage: UsageTotals?

    var totalSpendUSD: Double {
        if let totalUsage, let spend = totalUsage.totalUsd { return spend }
        return data.reduce(0) { partial, entry in
            guard let cost = entry.totalCost else { return partial }
            let multiplier = cost.currency.lowercased() == "usd" ? 1.0 : 1.0
            return partial + (cost.amount * multiplier)
        }
    }
}

private struct UsageTotals: Decodable {
    let totalUsd: Double?
}

private extension ISO8601DateFormatter {
    static let usage: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
