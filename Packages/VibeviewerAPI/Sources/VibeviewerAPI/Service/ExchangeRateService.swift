import Foundation

public struct ExchangeRateService: Sendable {
    private actor Cache {
        static let shared = Cache()
        var lastFetch: Date?
        var rates: [String: Double] = [:]
    }

    public init() {}

    public func rate(for currencyCode: String) async -> Double? {
        if currencyCode.uppercased() == "USD" { return 1.0 }
        if let cached = await Cache.shared.cachedRate(for: currencyCode) {
            return cached
        }
        guard let url = URL(string: "https://open.er-api.com/v6/latest/USD") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            await Cache.shared.store(rates: decoded.rates)
            return await Cache.shared.cachedRate(for: currencyCode)
        } catch {
            return nil
        }
    }

    private struct Response: Decodable {
        let rates: [String: Double]
    }
}

extension ExchangeRateService.Cache {
    func cachedRate(for code: String) -> Double? {
        let code = code.uppercased()
        if let lastFetch, Date().timeIntervalSince(lastFetch) < 43_200, let rate = rates[code] {
            return rate
        }
        return nil
    }

    func store(rates: [String: Double]) {
        self.rates = rates
        self.lastFetch = Date()
    }
}
