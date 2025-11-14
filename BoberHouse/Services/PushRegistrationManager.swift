import Foundation

@MainActor
final class PushRegistrationManager {
    static let shared = PushRegistrationManager()

    private let configuration: ServerConfiguration
    private let session: URLSession
    private let stateStore: UserDefaults
    private weak var store: HouseholdStore?
    private var deviceToken: String?

    private var registeredToken: String? {
        get { stateStore.string(forKey: "registeredDeviceToken") }
        set { stateStore.set(newValue, forKey: "registeredDeviceToken") }
    }

    init(
        configuration: ServerConfiguration = .shared,
        session: URLSession = .shared,
        stateStore: UserDefaults = .standard
    ) {
        self.configuration = configuration
        self.session = session
        self.stateStore = stateStore
    }

    func attach(store: HouseholdStore) {
        self.store = store
        Task { await registerIfPossible() }
    }

    func updateDeviceToken(_ data: Data) async {
        let token = data.map { String(format: "%02x", $0) }.joined()
        deviceToken = token
        await registerIfPossible()
    }

    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) async {
        await store?.performManualSync()
    }

    func unregister() async {
        guard let token = deviceToken ?? registeredToken else { return }
        do {
            var request = try makeRequest(path: "devices", method: "DELETE")
            let payload = DeviceDeletionRequest(token: token)
            request.httpBody = try JSONEncoder.backend.encode(payload)
            let (_, response) = try await session.data(for: request)
            try validate(response: response)
            registeredToken = nil
        } catch {
            NSLog("Failed to unregister device token: \(error.localizedDescription)")
        }
    }

    private func registerIfPossible() async {
        guard let token = deviceToken, let member = store?.members.first(where: { $0.isSelf }) else {
            return
        }

        guard token != registeredToken else { return }

        do {
            var request = try makeRequest(path: "devices", method: "POST")
            let payload = DeviceRegistrationRequest(memberID: member.id, token: token)
            request.httpBody = try JSONEncoder.backend.encode(payload)
            let (_, response) = try await session.data(for: request)
            try validate(response: response)
            registeredToken = token
        } catch {
            NSLog("Device token registration failed: \(error.localizedDescription)")
        }
    }

    private func makeRequest(path: String, method: String) throws -> URLRequest {
        let url = configuration.baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(configuration.apiToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw SyncError.invalidResponse
        }
    }
}

private struct DeviceRegistrationRequest: Codable {
    var memberID: UUID
    var token: String
}

private struct DeviceDeletionRequest: Codable {
    var token: String
}
