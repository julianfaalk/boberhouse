import APNSwift
import Vapor

private struct APNSConfigurationStorage: @unchecked Sendable {
    let value: APNSwiftConfiguration
}

private struct APNSConfigurationKey: StorageKey {
    typealias Value = APNSConfigurationStorage
}

extension Application {
    var apnsConfiguration: APNSwiftConfiguration? {
        get { storage[APNSConfigurationKey.self]?.value }
        set {
            storage[APNSConfigurationKey.self] = newValue.map(APNSConfigurationStorage.init)
        }
    }
}
