import Foundation

struct RemoteSyncService: Syncing {
    private let session: URLSession
    private let configuration: ServerConfiguration

    init(session: URLSession = .shared, configuration: ServerConfiguration = .shared) {
        self.session = session
        self.configuration = configuration
    }

    func pull(since revision: Int64) async throws -> SyncPullResponse {
        let url = configuration.baseURL.appendingPathComponent("sync")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "since", value: String(revision))]
        let request = try makeRequest(url: components?.url ?? url, method: "GET")
        return try await execute(request)
    }

    func push(_ request: SyncPushRequest) async throws -> SyncPullResponse {
        let url = configuration.baseURL.appendingPathComponent("sync")
        var urlRequest = try makeRequest(url: url, method: "POST")
        urlRequest.httpBody = try JSONEncoder.backend.encode(request)
        return try await execute(urlRequest)
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw SyncError.server(httpResponse.statusCode, data: data)
        }

        return try JSONDecoder.backend.decode(T.self, from: data)
    }

    private func makeRequest(url: URL, method: String) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(configuration.apiToken)", forHTTPHeaderField: "Authorization")
        return request
    }
}

enum SyncError: Error {
    case invalidResponse
    case server(Int, data: Data)
}
