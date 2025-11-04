import Foundation
import Security
import VibeviewerModel

struct GoogleGeminiUsageProvider: UsageProvider {
    let settings: AppSettings.ProviderSettings
    let session: URLSession

    init(settings: AppSettings.ProviderSettings, session: URLSession = .shared) {
        self.settings = settings
        self.session = session
    }

    var kind: UsageProviderKind { .googleGemini }

    func fetchTotals(dateRange: DateInterval) async throws -> ProviderUsageTotal? {
        guard settings.googleServiceAccountJSON.isEmpty == false,
              let data = settings.googleServiceAccountJSON.data(using: .utf8)
        else {
            return nil
        }

        let credentialsDecoder = JSONDecoder()
        credentialsDecoder.keyDecodingStrategy = .convertFromSnakeCase
        let credentials = try credentialsDecoder.decode(GoogleServiceAccount.self, from: data)
        let accessToken = try await requestAccessToken(credentials: credentials)
        let requestBody = GoogleBillingReportRequest(
            filter: "project=\"projects/\(settings.googleProjectID)\"",
            dateRange: .init(startDate: dateRange.start, endDate: dateRange.end)
        )
        let bodyData = try JSONEncoder().encode(requestBody)
        let url = URL(string: "https://cloudbilling.googleapis.com/v1beta/billingAccounts/\(settings.googleBillingAccountID):reports:query")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (responseData, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            return nil
        }

        let reportDecoder = JSONDecoder()
        reportDecoder.keyDecodingStrategy = .convertFromSnakeCase
        let report = try reportDecoder.decode(GoogleBillingReportResponse.self, from: responseData)
        let totalMicros = report.totalMicros
        let cents = Int(totalMicros / 10_000)
        return ProviderUsageTotal(
            provider: .googleGemini,
            spendCents: cents,
            requestCount: report.usageCount,
            currencyCode: report.currencyCode ?? "USD"
        )
    }

    private func requestAccessToken(credentials: GoogleServiceAccount) async throws -> String {
        let tokenURL = URL(string: credentials.tokenURI ?? "https://oauth2.googleapis.com/token")!
        let jwt = try self.makeJWT(credentials: credentials, audience: tokenURL.absoluteString)
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let formBody = "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=\(jwt)"
        request.httpBody = formBody.data(using: .utf8)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw UsageProviderError.oauthFailure
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let token = try decoder.decode(GoogleOAuthResponse.self, from: data)
        return token.accessToken
    }

    private func makeJWT(credentials: GoogleServiceAccount, audience: String) throws -> String {
        let header: [String: Any] = ["alg": "RS256", "typ": "JWT"]
        let now = Date()
        let payload: [String: Any] = [
            "iss": credentials.clientEmail,
            "scope": "https://www.googleapis.com/auth/cloud-platform",
            "aud": audience,
            "exp": Int(now.addingTimeInterval(3600).timeIntervalSince1970),
            "iat": Int(now.timeIntervalSince1970)
        ]
        let headerData = try JSONSerialization.data(withJSONObject: header, options: [])
        let payloadData = try JSONSerialization.data(withJSONObject: payload, options: [])
        let signingInput = [headerData.base64URLEncodedString(), payloadData.base64URLEncodedString()].joined(separator: ".")
        let signature = try sign(message: signingInput.data(using: .utf8)!, privateKeyPEM: credentials.privateKey)
        return signingInput + "." + signature.base64URLEncodedString()
    }

    private func sign(message: Data, privateKeyPEM: String) throws -> Data {
        guard let keyData = privateKeyPEM.pemKeyData else {
            throw UsageProviderError.invalidCredentials
        }
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits as String: keyData.count * 8
        ]
        var error: Unmanaged<CFError>?
        guard let secKey = SecKeyCreateWithData(keyData as CFData, attributes as CFDictionary, &error) else {
            throw error?.takeRetainedValue() as Error? ?? UsageProviderError.invalidCredentials
        }
        guard let signature = SecKeyCreateSignature(secKey, .rsaSignatureMessagePKCS1v15SHA256, message as CFData, &error) else {
            throw error?.takeRetainedValue() as Error? ?? UsageProviderError.invalidCredentials
        }
        return signature as Data
    }
}

private struct GoogleServiceAccount: Decodable {
    let clientEmail: String
    let privateKey: String
    let tokenURI: String?
}

private struct GoogleOAuthResponse: Decodable {
    let accessToken: String
    let expiresIn: Int
    let tokenType: String
}

private struct GoogleBillingReportRequest: Encodable {
    struct DateRange: Encodable {
        let startDate: DateComponents
        let endDate: DateComponents

        init(startDate: Date, endDate: Date) {
            let calendar = Calendar(identifier: .gregorian)
            self.startDate = calendar.dateComponents([.year, .month, .day], from: startDate)
            self.endDate = calendar.dateComponents([.year, .month, .day], from: endDate)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            let start = DateComponentsWrapper(components: startDate)
            let end = DateComponentsWrapper(components: endDate)
            try container.encode(start, forKey: .startDate)
            try container.encode(end, forKey: .endDate)
        }

        enum CodingKeys: String, CodingKey {
            case startDate
            case endDate
        }
    }

    struct DateComponentsWrapper: Encodable {
        let components: DateComponents

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(components.year ?? 0, forKey: .year)
            try container.encode(components.month ?? 0, forKey: .month)
            try container.encode(components.day ?? 0, forKey: .day)
        }

        enum CodingKeys: String, CodingKey {
            case year, month, day
        }
    }

    let filter: String
    let dateRange: DateRange
    let metrics: [String] = ["COST", "USAGE"]
}

private struct GoogleBillingReportResponse: Decodable {
    struct Row: Decodable {
        let cost: MoneyValue?
        let usage: UsageValue?
    }

    struct MoneyValue: Decodable {
        let currencyCode: String?
        let units: String?
        let nanos: Int?
        let valueMicros: String?
    }

    struct UsageValue: Decodable {
        let usageAmount: Double?
    }

    let rows: [Row]?
    let totalCost: MoneyValue?

    var totalMicros: Int64 {
        if let totalCost { return totalCost.micros }
        return rows?.reduce(0) { $0 + ($1.cost?.micros ?? 0) } ?? 0
    }

    var usageCount: Int {
        Int(rows?.reduce(0.0) { $0 + ($1.usage?.usageAmount ?? 0.0) } ?? 0.0)
    }

    var currencyCode: String? {
        totalCost?.currencyCode ?? rows?.first?.cost?.currencyCode
    }
}

private extension GoogleBillingReportResponse.MoneyValue {
    var micros: Int64 {
        var total: Int64 = 0
        if let units = units.flatMap(Int64.init) {
            total += units * 1_000_000
        }
        if let valueMicros = valueMicros.flatMap(Int64.init) {
            total += valueMicros
        }
        if let nanos = nanos {
            total += Int64(nanos / 1000)
        }
        return total
    }
}

