import Foundation
import Security

enum BackendAPIError: Error {
    case missingToken
    case badURL
    case http(status: Int, body: String)
    case decoding(Error)
    case network(Error)
}

extension BackendAPIError: LocalizedError {
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

final class BackendAPIClient {
    struct Config {
        let baseURL: URL

        init(baseURL: URL = URL(string: "http://localhost:3000")!) {
            self.baseURL = baseURL
        }
    }

    private let config: Config
    private let session: URLSession

    init(config: Config = Config()) {
        self.config = config

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - Public API

    func createConversation(title: String?) async throws -> Conversation {
        struct Body: Encodable { let title: String? }
        return try await request(path: "/conversations", method: "POST", body: Body(title: title))
    }

    func listConversations() async throws -> [Conversation] {
        try await request(path: "/conversations", method: "GET", body: Optional<Int>.none)
    }

    func getConversation(id: UUID) async throws -> ConversationDetail {
        try await getConversation(id: id.uuidString)
    }

    func getConversation(id: String) async throws -> ConversationDetail {
        try await request(path: "/conversations/\(id)", method: "GET", body: Optional<Int>.none)
    }

    func postMessage(
        conversationId: UUID,
        content: String,
        promptType: String,
        summaryFormat: String? = nil
    ) async throws -> PostMessageResponse {
        try await postMessage(conversationId: conversationId.uuidString, content: content, promptType: promptType, summaryFormat: summaryFormat)
    }

    func postMessage(
        conversationId: String,
        content: String,
        promptType: String,
        summaryFormat: String? = nil
    ) async throws -> PostMessageResponse {
        struct Body: Encodable {
            let content: String
            let promptType: String
            let summaryFormat: String?
        }

        return try await request(
            path: "/conversations/\(conversationId)/messages",
            method: "POST",
            body: Body(content: content, promptType: promptType, summaryFormat: summaryFormat)
        )
    }

    func resolve(
        conversationId: UUID,
        messageId: UUID,
        promptType: String? = nil,
        summaryFormat: String? = nil
    ) async throws -> PostMessageResponse {
        try await resolve(conversationId: conversationId.uuidString, messageId: messageId.uuidString, promptType: promptType, summaryFormat: summaryFormat)
    }

    func resolve(
        conversationId: String,
        messageId: String,
        promptType: String? = nil,
        summaryFormat: String? = nil
    ) async throws -> PostMessageResponse {
        struct Body: Encodable {
            let promptType: String?
            let summaryFormat: String?
        }

        return try await request(
            path: "/conversations/\(conversationId)/messages/\(messageId)/resolve",
            method: "POST",
            body: Body(promptType: promptType, summaryFormat: summaryFormat)
        )
    }

    func getRun(conversationId: UUID, runId: UUID) async throws -> RunDebugResponse {
        try await getRun(conversationId: conversationId.uuidString, runId: runId.uuidString)
    }

    func getRun(conversationId: String, runId: String) async throws -> RunDebugResponse {
        try await request(path: "/conversations/\(conversationId)/runs/\(runId)", method: "GET", body: Optional<Int>.none)
    }

    // MARK: - Core Request

    private func request<T: Decodable, Body: Encodable>(path: String, method: String, body: Body?) async throws -> T {
        guard let token = loadAccessToken(), !token.isEmpty else {
            throw BackendAPIError.missingToken
        }

        let url = config.baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            request.httpBody = try Self.encoder.encode(body)
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw BackendAPIError.network(URLError(.badServerResponse))
            }

            // Debug logging (no tokens)
            let printedPath = url.path.isEmpty ? "/" : url.path
            print("BackendAPI \(method) \(printedPath) -> \(http.statusCode)")

            guard (200...299).contains(http.statusCode) else {
                let bodyString = String(data: data, encoding: .utf8) ?? ""
                let truncated = Self.truncate(bodyString, limit: 2000)
                if !truncated.isEmpty {
                    print("BackendAPI error body: \(truncated)")
                }
                throw BackendAPIError.http(status: http.statusCode, body: truncated)
            }

            do {
                return try Self.decoder.decode(T.self, from: data)
            } catch {
                throw BackendAPIError.decoding(error)
            }
        } catch let error as BackendAPIError {
            throw error
        } catch {
            throw BackendAPIError.network(error)
        }
    }

    // MARK: - Token

    private func loadAccessToken() -> String? {
        KeychainHelper.load(service: "resolve.auth", account: "access_token")
    }

    // MARK: - JSON

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = ISO8601DateFormatter.withFractional.date(from: value) {
                return date
            }
            if let date = ISO8601DateFormatter.basic.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(value)")
        }
        return decoder
    }()

    private static func truncate(_ value: String, limit: Int) -> String {
        guard value.count > limit else { return value }
        let index = value.index(value.startIndex, offsetBy: limit)
        return String(value[..<index]) + "…"
    }
}

private enum KeychainHelper {
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
}

private extension ISO8601DateFormatter {
    static let withFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let basic: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
