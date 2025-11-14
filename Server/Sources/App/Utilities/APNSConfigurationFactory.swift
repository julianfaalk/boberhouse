import APNSwift
import JWTKit
import Vapor

enum APNSConfigurationFactory {
    static func makeFromEnvironment() -> APNSwiftConfiguration? {
        guard
            let keyIdentifier = Environment.get("APNS_KEY_ID"),
            let teamIdentifier = Environment.get("APNS_TEAM_ID"),
            let signerPath = Environment.get("APNS_AUTH_KEY_PATH"),
            let bundleIdentifier = Environment.get("APNS_BUNDLE_ID")
        else {
            return nil
        }

        do {
            let signer = try ECDSAKey.private(filePath: signerPath)
            let environmentName = Environment.get("APNS_ENV") ?? "production"
            let environment: APNSwiftConfiguration.Environment = environmentName == "sandbox" ? .sandbox : .production
            return APNSwiftConfiguration(
                authenticationMethod: .jwt(
                    key: signer,
                    keyIdentifier: JWKIdentifier(string: keyIdentifier),
                    teamIdentifier: teamIdentifier
                ),
                topic: bundleIdentifier,
                environment: environment
            )
        } catch {
            Logger(label: "APNS").error("Unable to create APNS configuration: \(error.localizedDescription)")
            return nil
        }
    }
}
