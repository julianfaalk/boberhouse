import Foundation

struct ServerConfiguration {
    static let shared = ServerConfiguration()

    private let info = Bundle.main.infoDictionary ?? [:]

    var baseURL: URL {
        guard
            let string = info["SERVER_BASE_URL"] as? String,
            let url = URL(string: string)
        else {
            fatalError("SERVER_BASE_URL missing or invalid in Info.plist")
        }
        return url
    }

    var apiToken: String {
        guard let token = info["SERVER_API_TOKEN"] as? String, !token.isEmpty else {
            fatalError("SERVER_API_TOKEN missing in Info.plist")
        }
        return token
    }
}
