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

    /// Permanently deletes a conversation and all of its messages/runs.
    /// Backend: `DELETE /conversations/{id}` — expected to return 204 or
    /// 200 with no body.
    func deleteConversation(id: UUID) async throws {
        try await deleteConversation(id: id.uuidString)
    }

    func deleteConversation(id: String) async throws {
        let path = "/conversations/\(id)"
        let (_, _) = try await requestRaw(path: path, method: "DELETE", body: Optional<Int>.none)
    }

    /// Updates the conversation's title. Backend: `PATCH
    /// /conversations/{id}` with body `{"title": "..."}`.
    func updateConversation(id: UUID, title: String) async throws -> Conversation {
        try await updateConversation(id: id.uuidString, title: title)
    }

    func updateConversation(id: String, title: String) async throws -> Conversation {
        struct Body: Encodable { let title: String }
        return try await request(
            path: "/conversations/\(id)",
            method: "PATCH",
            body: Body(title: title)
        )
    }

    func postMessage(
        conversationId: UUID,
        content: String,
        promptType: String,
        summaryFormat: String? = nil,
        enabledAdvocates: [String]? = nil,
        arbiterStyle: String? = nil
    ) async throws -> PostMessageResponse {
        try await postMessage(
            conversationId: conversationId.uuidString,
            content: content,
            promptType: promptType,
            summaryFormat: summaryFormat,
            enabledAdvocates: enabledAdvocates,
            arbiterStyle: arbiterStyle
        )
    }

    func postMessage(
        conversationId: String,
        content: String,
        promptType: String,
        summaryFormat: String? = nil,
        enabledAdvocates: [String]? = nil,
        arbiterStyle: String? = nil
    ) async throws -> PostMessageResponse {
        struct Body: Encodable {
            let content: String
            let promptType: String
            let summaryFormat: String?
            let enabledAdvocates: [String]?
            let arbiterStyle: String?
        }

        return try await request(
            path: "/conversations/\(conversationId)/messages",
            method: "POST",
            body: Body(
                content: content,
                promptType: promptType,
                summaryFormat: summaryFormat,
                enabledAdvocates: enabledAdvocates,
                arbiterStyle: arbiterStyle
            )
        )
    }

    func resolve(
        conversationId: UUID,
        messageId: UUID,
        promptType: String? = nil,
        summaryFormat: String? = nil,
        enabledAdvocates: [String]? = nil,
        arbiterStyle: String? = nil
    ) async throws -> PostMessageResponse {
        try await resolve(
            conversationId: conversationId.uuidString,
            messageId: messageId.uuidString,
            promptType: promptType,
            summaryFormat: summaryFormat,
            enabledAdvocates: enabledAdvocates,
            arbiterStyle: arbiterStyle
        )
    }

    func resolve(
        conversationId: String,
        messageId: String,
        promptType: String? = nil,
        summaryFormat: String? = nil,
        enabledAdvocates: [String]? = nil,
        arbiterStyle: String? = nil
    ) async throws -> PostMessageResponse {
        struct Body: Encodable {
            let promptType: String?
            let summaryFormat: String?
            let enabledAdvocates: [String]?
            let arbiterStyle: String?
        }

        return try await request(
            path: "/conversations/\(conversationId)/messages/\(messageId)/resolve",
            method: "POST",
            body: Body(
                promptType: promptType,
                summaryFormat: summaryFormat,
                enabledAdvocates: enabledAdvocates,
                arbiterStyle: arbiterStyle
            )
        )
    }

    func getRun(conversationId: UUID, runId: UUID) async throws -> RunResult {
        try await getRun(conversationId: conversationId.uuidString, runId: runId.uuidString)
    }

    func getRun(conversationId: String, runId: String) async throws -> RunResult {
        let path = "/conversations/\(conversationId)/runs/\(runId)"
        let (data, _) = try await requestRaw(path: path, method: "GET", body: Optional<Int>.none)

        if let raw = String(data: data, encoding: .utf8) {
            print("DEBUG getRun RAW RESPONSE:")
            print(raw)
        } else {
            print("DEBUG getRun RAW RESPONSE: <non-utf8>")
        }

        do {
            return try Self.decoder.decode(RunResult.self, from: data)
        } catch {
            logDecodingError(error, context: "getRun")
            throw BackendAPIError.decoding(error)
        }
    }

    func listRuns(conversationId: UUID, messageId: UUID) async throws -> [RunResult] {
        try await listRuns(conversationId: conversationId.uuidString, messageId: messageId.uuidString)
    }

    func listRuns(conversationId: String, messageId: String) async throws -> [RunResult] {
        let path = "/conversations/\(conversationId)/messages/\(messageId)/runs"
        let (data, _) = try await requestRaw(path: path, method: "GET", body: Optional<Int>.none)

        do {
            let response = try Self.decoder.decode(RunsListResponse.self, from: data)
            return response.runs
        } catch {
            logDecodingError(error, context: "listRuns")
            throw BackendAPIError.decoding(error)
        }
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

    private func requestRaw<Body: Encodable>(path: String, method: String, body: Body?) async throws -> (Data, HTTPURLResponse) {
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

            return (data, http)
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

    private func logDecodingError(_ error: Error, context: String) {
        guard let decodingError = error as? DecodingError else {
            print("DEBUG decoding error (\(context)): \(error)")
            return
        }

        switch decodingError {
        case .keyNotFound(let key, let contextInfo):
            print("DEBUG decoding error (\(context)) keyNotFound: \(key.stringValue) path=\(codingPathString(contextInfo.codingPath)) \(contextInfo.debugDescription)")
        case .typeMismatch(let type, let contextInfo):
            print("DEBUG decoding error (\(context)) typeMismatch: \(type) path=\(codingPathString(contextInfo.codingPath)) \(contextInfo.debugDescription)")
        case .valueNotFound(let type, let contextInfo):
            print("DEBUG decoding error (\(context)) valueNotFound: \(type) path=\(codingPathString(contextInfo.codingPath)) \(contextInfo.debugDescription)")
        case .dataCorrupted(let contextInfo):
            print("DEBUG decoding error (\(context)) dataCorrupted: path=\(codingPathString(contextInfo.codingPath)) \(contextInfo.debugDescription)")
        @unknown default:
            print("DEBUG decoding error (\(context)) unknown: \(decodingError)")
        }
    }

    private func codingPathString(_ path: [CodingKey]) -> String {
        guard !path.isEmpty else { return "<root>" }
        return path.map { $0.stringValue }.joined(separator: ".")
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
