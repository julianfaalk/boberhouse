import Foundation

final class SyncStateStore {
    static let shared = SyncStateStore()

    private let defaults: UserDefaults
    private let revisionKey = "syncRevision"

    init(userDefaults: UserDefaults = .standard) {
        defaults = userDefaults
    }

    var revision: Int64 {
        get {
            Int64(defaults.integer(forKey: revisionKey))
        }
        set {
            defaults.set(newValue, forKey: revisionKey)
        }
    }

    func reset() {
        defaults.removeObject(forKey: revisionKey)
    }
}
