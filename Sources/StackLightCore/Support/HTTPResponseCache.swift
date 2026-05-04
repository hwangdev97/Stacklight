import Foundation
@preconcurrency import GRDB

/// On-disk cache for HTTP responses keyed by URL. Stores the body, ETag,
/// status, headers JSON, and rate-limit metadata. Designed so the menu can
/// open from cached data first and only spend a network request when the
/// background refresh has something fresh to deliver.
///
/// Mirrors RepoBar's `HTTPResponseDiskCache` — pared down (no GraphQL table)
/// because StackLight is REST-only.

public struct PersistentHTTPResponse: Equatable, Sendable {
    public let etag: String
    public let data: Data
    public let fetchedAt: Date

    public init(etag: String, data: Data, fetchedAt: Date) {
        self.etag = etag
        self.data = data
        self.fetchedAt = fetchedAt
    }
}

public struct CachedResponseSummary: Codable, Equatable, Sendable {
    public let method: String
    public let url: String
    public let hasETag: Bool
    public let statusCode: Int?
    public let fetchedAt: Date
    public let rateLimitRemaining: Int?
    public let rateLimitReset: Date?
}

public struct StackLightCacheSummary: Codable, Equatable, Sendable {
    public let databasePath: String
    public let exists: Bool
    public let apiResponseCount: Int
    public let rateLimitCount: Int
    public let latestResponses: [CachedResponseSummary]
}

public enum CacheError: Error, LocalizedError {
    case missingApplicationSupportDirectory

    public var errorDescription: String? {
        switch self {
        case .missingApplicationSupportDirectory: "Unable to resolve Application Support directory."
        }
    }
}

public enum PersistentCache {
    public static func standardDatabaseURL(fileManager: FileManager = .default) -> URL? {
        HTTPResponseCache.standardDatabaseURL(fileManager: fileManager)
    }

    public static func summary(limit: Int = 10, fileManager: FileManager = .default) throws -> StackLightCacheSummary {
        guard let url = HTTPResponseCache.standardDatabaseURL(fileManager: fileManager) else {
            throw CacheError.missingApplicationSupportDirectory
        }
        let exists = fileManager.fileExists(atPath: url.path)
        guard exists else {
            return StackLightCacheSummary(
                databasePath: url.path,
                exists: false,
                apiResponseCount: 0,
                rateLimitCount: 0,
                latestResponses: []
            )
        }
        return try HTTPResponseCache(path: url.path).summary(limit: limit)
    }

    public static func clear(fileManager: FileManager = .default) throws -> StackLightCacheSummary {
        guard let url = HTTPResponseCache.standardDatabaseURL(fileManager: fileManager) else {
            throw CacheError.missingApplicationSupportDirectory
        }
        let cache = try HTTPResponseCache(path: url.path)
        cache.clear()
        return try cache.summary(limit: 0)
    }
}

public final class HTTPResponseCache: @unchecked Sendable {
    private let queue: DatabaseQueue
    private let path: String
    private let clock: @Sendable () -> Date

    public init(path: String, clock: @escaping @Sendable () -> Date = Date.init) throws {
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: path).deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var configuration = Configuration()
        configuration.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
            try db.execute(sql: "PRAGMA journal_mode = WAL")
        }
        self.queue = try DatabaseQueue(path: path, configuration: configuration)
        self.path = path
        self.clock = clock
        try Self.migrate(self.queue)
    }

    public static func standard() -> HTTPResponseCache? {
        guard let path = standardDatabaseURL()?.path else { return nil }
        return try? HTTPResponseCache(path: path)
    }

    public static func standardDatabaseURL(fileManager: FileManager = .default) -> URL? {
        guard let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return base
            .appendingPathComponent("StackLight", isDirectory: true)
            .appendingPathComponent("Cache.sqlite", isDirectory: false)
    }

    public func cached(url: URL) -> PersistentHTTPResponse? {
        let key = Self.key(url: url)
        return try? queue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "select etag, body, fetched_at from api_responses where key = ? and etag is not null",
                arguments: [key]
            ) else { return nil }
            let etag: String = row["etag"]
            let body: Data = row["body"]
            let fetchedAt: Double = row["fetched_at"]
            return PersistentHTTPResponse(
                etag: etag,
                data: body,
                fetchedAt: Date(timeIntervalSinceReferenceDate: fetchedAt)
            )
        } as? PersistentHTTPResponse
    }

    /// Cache a 200 response with its ETag so the next request can send
    /// `If-None-Match` and (hopefully) get a 304 for free.
    public func save(url: URL, etag: String, data: Data, response: HTTPURLResponse? = nil) {
        let now = clock()
        let reset = response.flatMap(Self.rateLimitReset)
        let remaining = response.flatMap(Self.rateLimitRemaining)
        let statusCode = response?.statusCode
        let headersJSON = response.flatMap(Self.headersJSON)
        let key = Self.key(url: url)

        try? queue.write { db in
            try db.execute(
                sql: """
                insert into api_responses(
                    key, method, url, etag, status_code, headers_json, body, fetched_at,
                    rate_limit_remaining, rate_limit_reset, updated_at
                )
                values (?, 'GET', ?, ?, ?, ?, ?, ?, ?, ?, ?)
                on conflict(key) do update set
                    etag = excluded.etag,
                    status_code = excluded.status_code,
                    headers_json = excluded.headers_json,
                    body = excluded.body,
                    fetched_at = excluded.fetched_at,
                    rate_limit_remaining = excluded.rate_limit_remaining,
                    rate_limit_reset = excluded.rate_limit_reset,
                    updated_at = excluded.updated_at
                """,
                arguments: [
                    key,
                    url.absoluteString,
                    etag,
                    statusCode,
                    headersJSON,
                    data,
                    now.timeIntervalSinceReferenceDate,
                    remaining,
                    reset?.timeIntervalSinceReferenceDate,
                    now.timeIntervalSinceReferenceDate
                ]
            )
        }
    }

    public func setRateLimitReset(resource: String = "core", date: Date, message: String? = nil) {
        let now = clock()
        try? queue.write { db in
            try db.execute(
                sql: """
                insert into rate_limits(resource, remaining, reset_at, last_error, updated_at)
                values (?, 0, ?, ?, ?)
                on conflict(resource) do update set
                    remaining = excluded.remaining,
                    reset_at = excluded.reset_at,
                    last_error = excluded.last_error,
                    updated_at = excluded.updated_at
                """,
                arguments: [
                    resource,
                    date.timeIntervalSinceReferenceDate,
                    message,
                    now.timeIntervalSinceReferenceDate
                ]
            )
        }
    }

    public func rateLimitUntil(resource: String = "core", now: Date = Date()) -> Date? {
        let reset = try? queue.read { db -> Double? in
            try Double.fetchOne(
                db,
                sql: "select reset_at from rate_limits where resource = ?",
                arguments: [resource]
            )
        }
        guard let value = reset, let reset = value else { return nil }
        let date = Date(timeIntervalSinceReferenceDate: reset)
        if date <= now {
            try? queue.write { db in
                try db.execute(
                    sql: "delete from rate_limits where resource = ? and reset_at = ?",
                    arguments: [resource, reset]
                )
            }
            return nil
        }
        return date
    }

    public func count() -> Int {
        (try? queue.read { db in
            try Int.fetchOne(db, sql: "select count(*) from api_responses") ?? 0
        }) ?? 0
    }

    public func summary(limit: Int = 10) throws -> StackLightCacheSummary {
        try queue.read { db in
            let apiResponseCount = try Int.fetchOne(db, sql: "select count(*) from api_responses") ?? 0
            let rateLimitCount = try Int.fetchOne(db, sql: "select count(*) from rate_limits") ?? 0
            let responses = try Row.fetchAll(
                db,
                sql: """
                select method, url, etag, status_code, fetched_at,
                    rate_limit_remaining, rate_limit_reset
                from api_responses
                order by fetched_at desc
                limit ?
                """,
                arguments: [max(0, limit)]
            ).map { row -> CachedResponseSummary in
                let fetchedAt: Double = row["fetched_at"]
                let rateLimitReset: Double? = row["rate_limit_reset"]
                let etag: String? = row["etag"]
                return CachedResponseSummary(
                    method: row["method"],
                    url: row["url"],
                    hasETag: etag?.isEmpty == false,
                    statusCode: row["status_code"],
                    fetchedAt: Date(timeIntervalSinceReferenceDate: fetchedAt),
                    rateLimitRemaining: row["rate_limit_remaining"],
                    rateLimitReset: rateLimitReset.map { Date(timeIntervalSinceReferenceDate: $0) }
                )
            }
            return StackLightCacheSummary(
                databasePath: self.path,
                exists: true,
                apiResponseCount: apiResponseCount,
                rateLimitCount: rateLimitCount,
                latestResponses: responses
            )
        }
    }

    public func clear() {
        try? queue.write { db in
            try db.execute(sql: "delete from api_responses")
            try db.execute(sql: "delete from rate_limits")
        }
    }

    static func migrate(_ queue: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "api_responses", ifNotExists: true) { table in
                table.column("key", .text).primaryKey()
                table.column("method", .text).notNull()
                table.column("url", .text).notNull()
                table.column("etag", .text)
                table.column("status_code", .integer)
                table.column("headers_json", .text)
                table.column("body", .blob).notNull()
                table.column("fetched_at", .double).notNull()
                table.column("rate_limit_remaining", .integer)
                table.column("rate_limit_reset", .double)
                table.column("updated_at", .double).notNull()
            }
            try db.create(index: "idx_api_responses_url", on: "api_responses", columns: ["url"], ifNotExists: true)
            try db.create(table: "rate_limits", ifNotExists: true) { table in
                table.column("resource", .text).primaryKey()
                table.column("remaining", .integer)
                table.column("reset_at", .double).notNull()
                table.column("last_error", .text)
                table.column("updated_at", .double).notNull()
            }
        }
        try migrator.migrate(queue)
    }

    private static func key(url: URL) -> String {
        "GET\t\(url.absoluteString)"
    }

    private static func rateLimitReset(from response: HTTPURLResponse) -> Date? {
        guard let value = response.value(forHTTPHeaderField: "X-RateLimit-Reset"),
              let epoch = TimeInterval(value) else { return nil }
        return Date(timeIntervalSince1970: epoch)
    }

    private static func rateLimitRemaining(from response: HTTPURLResponse) -> Int? {
        guard let value = response.value(forHTTPHeaderField: "X-RateLimit-Remaining") else { return nil }
        return Int(value)
    }

    private static func headersJSON(from response: HTTPURLResponse) -> String? {
        let headers = response.allHeaderFields.reduce(into: [String: String]()) { result, pair in
            guard let key = pair.key as? String else { return }
            result[key] = "\(pair.value)"
        }
        guard let data = try? JSONEncoder().encode(headers) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
