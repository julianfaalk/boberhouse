import Foundation

enum JSONCoders {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

extension JSONEncoder {
    static var backend: JSONEncoder { JSONCoders.encoder }
}

extension JSONDecoder {
    static var backend: JSONDecoder { JSONCoders.decoder }
}
