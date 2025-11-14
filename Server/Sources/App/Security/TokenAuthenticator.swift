import Vapor

struct TokenValidator {
    private let expectedToken = Environment.get("SERVER_API_TOKEN") ?? ""

    func validate(token: String) -> Bool {
        !expectedToken.isEmpty && token == expectedToken
    }

    func requireToken(on request: Request) throws {
        guard
            let bearer = request.headers.bearerAuthorization,
            validate(token: bearer.token)
        else {
            throw Abort(.unauthorized, reason: "Invalid or missing API token")
        }
    }
}
