import Foundation

/// Process-wide singletons for objects whose construction is non-trivial and
/// are otherwise instantiated on every poll, every menu redraw, or every JSON
/// decode. `RelativeDateTimeFormatter` and `JSONDecoder` initialization both
/// show up in profiles when called per row / per response.
public enum SharedFormatters {
    public static let relativeAbbreviated: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    public static let iso8601Internet: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    public static let iso8601InternetWithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

/// Shared `JSONEncoder` / `JSONDecoder` instances. Decoders are immutable after
/// the closure runs, so they're safe to share across actors.
public enum SharedJSON {
    /// Default decoder — no custom date strategy. Use for responses that ship
    /// epoch seconds / millis or have no date fields at all.
    public static let decoder = JSONDecoder()

    /// Default encoder. Used by the response cache for header serialization.
    public static let encoder = JSONEncoder()

    /// Decoder configured to parse `withInternetDateTime` ISO8601 strings into
    /// `Date`. Used by GitHub APIs.
    public static let iso8601Decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { d in
            let container = try d.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = SharedFormatters.iso8601Internet.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date: \(raw)"
            )
        }
        return decoder
    }()

    /// Encoder/decoder pair using `Date`'s built-in `.iso8601` strategy. Used
    /// by `SharedStore` for the cross-process deployment snapshot — kept apart
    /// from the strict provider decoders because the strategy is symmetric and
    /// SDK-defined rather than a custom regex.
    public static let snapshotEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    public static let snapshotDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// Decoder that prefers fractional-second ISO8601, then falls back to the
    /// integer-second form. Used by Netlify, Fly.io, Railway, Cloudflare.
    public static let iso8601FractionalDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { d in
            let container = try d.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = SharedFormatters.iso8601InternetWithFractional.date(from: raw) {
                return date
            }
            if let date = SharedFormatters.iso8601Internet.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date: \(raw)"
            )
        }
        return decoder
    }()
}
