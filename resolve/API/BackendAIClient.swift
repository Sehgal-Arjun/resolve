import Foundation
import Security

struct AIResponse: Decodable {
    let provider: String
    let model: String
    let text: String
    let latencyMs: Int
    let requestId: String

    enum CodingKeys: String, CodingKey {
        case provider
        case model
        case text
        case latencyMs = "latency_ms"
        case requestId = "request_id"
    }
}

enum BackendAIError: Error {
    case missingToken
    case badURL
    case http(status: Int, body: String)
    case decoding(Error)
    case network(Error)
}

extension BackendAIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "Missing access token. Sign in again to refresh your session."
        case .badURL:
            return "Invalid backend URL."
        case .http(let status, let body):
            return "Backend HTTP \(status): \(body)"
        case .decoding(let error):
            return "Failed to decode backend response: \(error.localizedDescription)"
        case .network(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

final class BackendAIClient {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = URL(string: "http://localhost:3000")!) {
        self.baseURL = baseURL

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    func call(model: String, prompt: String) async throws -> AIResponse {
        guard let token = loadAccessToken() else {
            print("BackendAI token missing (length=0)")
            throw BackendAIError.missingToken
        }
        print("BackendAI token found (length=\(token.count))")

        let endpoint = baseURL
            .appendingPathComponent("ai")
            .appendingPathComponent(model)

        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false),
              let url = components.url else {
            throw BackendAIError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["prompt": prompt]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        print("BackendAI headers:", request.allHTTPHeaderFields ?? [:])

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw BackendAIError.network(URLError(.badServerResponse))
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let bodyString = String(data: data, encoding: .utf8) ?? ""
                print("BackendAI HTTP \(httpResponse.statusCode): \(bodyString)")
                throw BackendAIError.http(status: httpResponse.statusCode, body: bodyString)
            }

            do {
                let decoded = try JSONDecoder().decode(AIResponse.self, from: data)
                print("BackendAI response: request_id=\(decoded.requestId) provider=\(decoded.provider) model=\(decoded.model) latency_ms=\(decoded.latencyMs)")
                return decoded
            } catch {
                throw BackendAIError.decoding(error)
            }
        } catch let error as BackendAIError {
            throw error
        } catch {
            throw BackendAIError.network(error)
        }
    }

    private func loadAccessToken() -> String? {
        KeychainHelper.load(service: "resolve.auth", account: "access_token")
    }
}

private enum KeychainHelper {
    static func save(service: String, account: String, value: String) {
        let data = Data(value.utf8)
        delete(service: service, account: account)

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(service: String, account: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(service: String, account: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]

        SecItemDelete(query as CFDictionary)
    }
}
