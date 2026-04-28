import Foundation

struct BackendMeResponse: Decodable {
    let id: String
    let firstName: String?
    let lastName: String?
    let primaryEmail: String?
}

enum BackendAuthError: Error {
    case unauthorized
    case invalidResponse
    case requestFailed
}

struct BackendAuthClient {
    let baseURL: URL

    func fetchMe(token: String) async throws -> BackendMeResponse {
        let url = baseURL.appendingPathComponent("me")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendAuthError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw BackendAuthError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw BackendAuthError.requestFailed
        }

        return try JSONDecoder().decode(BackendMeResponse.self, from: data)
    }
}
