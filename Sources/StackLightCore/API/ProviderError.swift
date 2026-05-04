import Foundation

/// Unified error type thrown by `RequestRunner`. Providers translate these into
/// either a top-level throw (whole-provider failure) or a per-item entry in
/// `DeploymentFetchResult.itemErrors` so a single bad endpoint doesn't poison
/// the rest of the batch.
public enum ProviderError: LocalizedError, Sendable {
    /// 429, or a 403 with `X-RateLimit-Remaining: 0`. `until` is the
    /// reset/Retry-After deadline; the runner has already set a cooldown so
    /// retrying before then will fail-fast.
    case rateLimited(until: Date, message: String)
    /// 503 / 202-style "we're working on it" responses. Distinct from
    /// `rateLimited` because the cause is server-side, not quota exhaustion.
    case serviceUnavailable(retryAfter: Date, message: String)
    /// 401, or 403 without a rate-limit signature. Surfaces as "check your
    /// token" guidance in the UI.
    case unauthorized(message: String)
    /// Any other non-success status code.
    case http(code: Int, message: String, body: Data?)
    /// JSON decode failed. Wraps the underlying error for diagnostics.
    case decode(Error)
    /// Response wasn't `HTTPURLResponse` or had no status line.
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .rateLimited(_, let message): return message
        case .serviceUnavailable(_, let message): return message
        case .unauthorized(let message): return message
        case .http(let code, let message, _): return "HTTP \(code): \(message)"
        case .decode(let underlying): return "Decode error: \(underlying.localizedDescription)"
        case .invalidResponse: return "Invalid response"
        }
    }

    /// Compact phrase suitable for menu rows / status bar. Avoids leaking
    /// upstream HTTP jargon when a friendlier framing exists.
    public var userFacingMessage: String {
        switch self {
        case .rateLimited(let until, _):
            let remaining = max(0, Int(until.timeIntervalSince(Date()) / 60))
            if remaining < 1 { return "Rate limited; resets shortly" }
            return "Rate limited; resets in ~\(remaining) min"
        case .serviceUnavailable: return "Service temporarily unavailable"
        case .unauthorized: return "Authorization failed — check token"
        case .http(let code, _, _) where code == 404: return "Not found"
        case .http(let code, _, _): return "HTTP \(code)"
        case .decode: return "Unexpected response shape"
        case .invalidResponse: return "Invalid response"
        }
    }
}
