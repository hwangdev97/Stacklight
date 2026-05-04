import Foundation

/// Single entry point for every provider's HTTP traffic. Centralizes:
/// - Per-URL backoff so a 429 from one endpoint doesn't keep hammering it.
/// - 429 / 503 / Retry-After interpretation.
/// - Structured request log line per call (when DiagnosticsLogger is enabled).
/// - (P4) ETag / persistent cache wiring.
///
/// Providers either call the high-level `get(url:token:headers:allowedStatuses:)`
/// — which throws `ProviderError` for non-success status codes — or the lower
/// level `execute(request:)`, which returns the raw `(Data, HTTPURLResponse)`
/// after backoff/rate-limit handling so the provider can decode service-specific
/// error bodies before deciding what to throw.
public actor RequestRunner {
    public static let shared = RequestRunner()

    private let backoff: BackoffTracker
    private var lastRateLimitReset: Date?
    private var rateLimitedHostsUntil: [String: Date] = [:]

    public init(backoff: BackoffTracker = BackoffTracker()) {
        self.backoff = backoff
    }

    // MARK: - High-level helpers

    /// Convenience GET. Throws `ProviderError.http` for non-success status,
    /// `ProviderError.rateLimited` / `serviceUnavailable` for 429 / 503,
    /// `ProviderError.unauthorized` for 401.
    public func get(
        url: URL,
        token: String? = nil,
        headers: [String: String] = [:],
        allowedStatuses: Set<Int> = [200]
    ) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }

        let (data, response) = try await execute(request: request)
        let status = response.statusCode

        if !allowedStatuses.contains(status) {
            throw mapStatus(status, response: response, body: data)
        }
        return (data, response)
    }

    /// Lower-level entry point. Honors backoff state, parses 429/503/Retry-After
    /// to set a cooldown, but does **not** translate other status codes — the
    /// caller is responsible for inspecting `response.statusCode` and decoding
    /// service-specific error bodies (e.g. Vercel's `{ error: { message } }`).
    public func execute(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard let url = request.url else { throw ProviderError.invalidResponse }
        let startedAt = Date()

        if let cooldownUntil = await backoff.cooldown(for: url) {
            await DiagnosticsLogger.shared.message(
                "BACKOFF \(request.httpMethod ?? "GET") \(url.path) until=\(cooldownUntil)"
            )
            throw ProviderError.serviceUnavailable(
                retryAfter: cooldownUntil,
                message: "Cooldown active until \(cooldownUntil)"
            )
        }

        let (data, urlResponse): (Data, URLResponse)
        do {
            (data, urlResponse) = try await URLSession.shared.data(for: request)
        } catch {
            await DiagnosticsLogger.shared.message(
                "HTTP \(request.httpMethod ?? "GET") \(url.path) network-error=\(error.localizedDescription)"
            )
            throw error
        }

        guard let response = urlResponse as? HTTPURLResponse else {
            throw ProviderError.invalidResponse
        }
        let status = response.statusCode
        let durationMs = Int((Date().timeIntervalSince(startedAt) * 1000).rounded())
        await DiagnosticsLogger.shared.message(
            "HTTP \(request.httpMethod ?? "GET") \(url.host ?? "?")\(url.path) status=\(status) dur=\(durationMs)ms bytes=\(data.count)"
        )

        // Rate-limit handling — set per-URL cooldown so other endpoints under
        // the same provider keep flowing.
        if status == 429 {
            let retry = retryAfterDate(from: response) ?? Date().addingTimeInterval(60)
            await backoff.setCooldown(url: url, until: retry)
            self.lastRateLimitReset = retry
            if let host = url.host {
                rateLimitedHostsUntil[host] = retry
            }
        } else if status == 503 {
            let retry = retryAfterDate(from: response) ?? Date().addingTimeInterval(30)
            await backoff.setCooldown(url: url, until: retry)
        } else if status == 403, response.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0" {
            // GitHub-style: 403 with quota exhausted is functionally a 429.
            let retry = rateLimitResetDate(from: response) ?? Date().addingTimeInterval(60)
            await backoff.setCooldown(url: url, until: retry)
            self.lastRateLimitReset = retry
        }

        return (data, response)
    }

    // MARK: - Diagnostics

    public func rateLimitReset(now: Date = Date()) -> Date? {
        guard let reset = lastRateLimitReset, reset > now else {
            lastRateLimitReset = nil
            return nil
        }
        return reset
    }

    public func backoffSnapshot() async -> [(url: String, until: Date)] {
        await backoff.snapshot()
    }

    public func clear() async {
        await backoff.clear()
        lastRateLimitReset = nil
        rateLimitedHostsUntil.removeAll()
    }

    // MARK: - Status mapping

    private func mapStatus(_ status: Int, response: HTTPURLResponse, body: Data) -> ProviderError {
        let statusMessage = HTTPURLResponse.localizedString(forStatusCode: status)
        switch status {
        case 401:
            return .unauthorized(message: statusMessage)
        case 403:
            if response.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0",
               let reset = rateLimitResetDate(from: response) {
                return .rateLimited(until: reset, message: "Rate limit hit; resets \(reset)")
            }
            return .unauthorized(message: statusMessage)
        case 429:
            let retry = retryAfterDate(from: response) ?? Date().addingTimeInterval(60)
            return .rateLimited(until: retry, message: "Rate limited; resets \(retry)")
        case 503:
            let retry = retryAfterDate(from: response) ?? Date().addingTimeInterval(30)
            return .serviceUnavailable(retryAfter: retry, message: "Service unavailable")
        default:
            return .http(code: status, message: statusMessage, body: body)
        }
    }

    private func retryAfterDate(from response: HTTPURLResponse) -> Date? {
        if let retryAfter = response.value(forHTTPHeaderField: "Retry-After") {
            if let seconds = TimeInterval(retryAfter) {
                return Date().addingTimeInterval(seconds)
            }
            // Could be HTTP-date format; we don't bother parsing that — fall through.
        }
        return nil
    }

    private func rateLimitResetDate(from response: HTTPURLResponse) -> Date? {
        if let reset = response.value(forHTTPHeaderField: "X-RateLimit-Reset"),
           let epoch = TimeInterval(reset) {
            return Date(timeIntervalSince1970: epoch)
        }
        return nil
    }
}
