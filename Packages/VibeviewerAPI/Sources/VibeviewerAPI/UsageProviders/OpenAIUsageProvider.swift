import Foundation
import VibeviewerModel

struct OpenAIUsageProvider: UsageProvider {
    let settings: AppSettings.ProviderSettings
    let session: URLSession

    init(settings: AppSettings.ProviderSettings, session: URLSession = .shared) {
        self.settings = settings
        self.session = session
    }

    var kind: UsageProviderKind { .openAI }

    func fetchTotals(dateRange: DateInterval) async throws -> ProviderUsageTotal? {
        guard settings.openAIAPIKey.isEmpty == false else { return nil }

        let startDate = dateRange.start
        let endDate = dateRange.end

        let startComponents = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: startDate)
        let endComponents = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: endDate)
        guard let startString = startComponents.dateString, let endString = endComponents.dateString else { return nil }

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/billing/usage?start_date=\(startString)&end_date=\(endString)")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(settings.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        if let organization = settings.openAIOrganization, organization.isEmpty == false {
            request.setValue(organization, forHTTPHeaderField: "OpenAI-Organization")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let usage = try decoder.decode(OpenAIBillingUsageResponse.self, from: data)
        let cents = Int((usage.totalUsage ?? 0).rounded())

        // Request counts come from the usage endpoint which aggregates per-request metrics
        let requestCount = try await fetchRequestCount(start: startDate, end: endDate)

        return ProviderUsageTotal(
            provider: .openAI,
            spendCents: cents,
            requestCount: requestCount,
            currencyCode: (usage.currency?.uppercased() ?? "USD")
        )
    }

    private func fetchRequestCount(start: Date, end: Date) async throws -> Int {
        var components = URLComponents(string: "https://api.openai.com/v1/usage")!
        components.queryItems = [
            .init(name: "start_time", value: String(Int(start.timeIntervalSince1970))),
            .init(name: "end_time", value: String(Int(end.timeIntervalSince1970)))
        ]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(settings.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        if let organization = settings.openAIOrganization, organization.isEmpty == false {
            request.setValue(organization, forHTTPHeaderField: "OpenAI-Organization")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            return 0
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let usage = try decoder.decode(OpenAIUsageResponse.self, from: data)
        return usage.data.reduce(0) { $0 + ($1.nRequests ?? 0) }
    }
}

private struct OpenAIBillingUsageResponse: Decodable {
    let totalUsage: Double?
    let currency: String?
}

private struct OpenAIUsageResponse: Decodable {
    struct Entry: Decodable {
        let nRequests: Int?
    }

    let data: [Entry]
}

private extension DateComponents {
    var dateString: String? {
        guard let year = self.year, let month = self.month, let day = self.day else { return nil }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
