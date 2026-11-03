import Foundation
import XCTest

/// Helpers that inspect the JSON shape of a value instead of its Swift property names.
///
/// The generated OpenAPI types and the hand-written models agree on the wire
/// format but not necessarily on Swift member names, so the API assertions are
/// written against the encoded payload.
enum JSONProbe {
    /// Encodes a value and returns the resulting JSON object.
    static func object(_ value: some Encodable) throws -> [String: Any] {
        let parsed = try JSONSerialization.jsonObject(with: try JSONEncoder().encode(value))
        return try XCTUnwrap(parsed as? [String: Any])
    }

    /// Parses raw JSON data into an object.
    static func object(data: Data) throws -> [String: Any] {
        let parsed = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(parsed as? [String: Any])
    }

    /// Encodes a value and returns the resulting JSON array of objects.
    static func array(_ value: some Encodable) throws -> [[String: Any]] {
        let parsed = try JSONSerialization.jsonObject(with: try JSONEncoder().encode(value))
        return try XCTUnwrap(parsed as? [[String: Any]])
    }

    /// Reads a string, tolerating the wire name or a camel-cased Swift name.
    static func string(_ json: [String: Any], _ keys: [String]) -> String? {
        for key in keys {
            if let value = json[key] as? String {
                return value
            }
        }
        return nil
    }

    /// Reads a nested object, tolerating the wire name or a camel-cased Swift name.
    static func object(_ json: [String: Any], _ keys: [String]) -> [String: Any]? {
        for key in keys {
            if let value = json[key] as? [String: Any] {
                return value
            }
        }
        return nil
    }

    /// Reads a number, tolerating the wire name or a camel-cased Swift name.
    static func number(_ json: [String: Any], _ keys: [String]) -> Double? {
        for key in keys {
            if let value = json[key] as? NSNumber {
                return value.doubleValue
            }
        }
        return nil
    }
}

/// Decodes a JSON payload into the type the API expects at the call site.
///
/// The type is inferred from the parameter it is passed to, so the assertions
/// keep working when a hand-written model is replaced by its generated twin.
func decodeValue<T: Decodable>(from json: String) throws -> T {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(T.self, from: Data(json.utf8))
}

/// Decodes a JSON array into the element type the API expects at the call site.
func decodeAll<T: Decodable>(from json: String) throws -> [T] {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode([T].self, from: Data(json.utf8))
}
