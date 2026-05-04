import Foundation

/// In-memory LRU layer over `HTTPResponseCache`. Holds the hottest 512 ETag
/// entries so the menu first-paint reads from RAM, with the SQLite store as a
/// fallback after process restart.
public actor ETagCache {
    public static let defaultMaxEntries = 512

    private let maxEntries: Int
    private let persistentStore: HTTPResponseCache?
    private var store: [String: (etag: String, data: Data)] = [:]
    private var entryOrder: [String] = []
    private var rateLimitedUntil: Date?

    public init(maxEntries: Int = ETagCache.defaultMaxEntries, persistentStore: HTTPResponseCache? = nil) {
        self.maxEntries = max(0, maxEntries)
        self.persistentStore = persistentStore
    }

    public static func persistent(maxEntries: Int = ETagCache.defaultMaxEntries) -> ETagCache {
        ETagCache(maxEntries: maxEntries, persistentStore: HTTPResponseCache.standard())
    }

    public func cached(for url: URL) -> (etag: String, data: Data)? {
        let key = url.absoluteString
        if let cached = store[key] {
            touch(key)
            return cached
        }
        guard let cached = persistentStore?.cached(url: url) else { return nil }
        let value = (cached.etag, cached.data)
        store[key] = value
        touch(key)
        evictIfNeeded()
        return value
    }

    public func save(url: URL, etag: String?, data: Data, response: HTTPURLResponse? = nil) {
        guard let etag else { return }
        let key = url.absoluteString
        if maxEntries > 0 {
            store[key] = (etag, data)
            touch(key)
            evictIfNeeded()
        }
        persistentStore?.save(url: url, etag: etag, data: data, response: response)
    }

    public func setRateLimitReset(date: Date) {
        rateLimitedUntil = date
        persistentStore?.setRateLimitReset(date: date)
    }

    public func rateLimitUntil(now: Date = Date()) -> Date? {
        let until = rateLimitedUntil ?? persistentStore?.rateLimitUntil(now: now)
        guard let until else { return nil }
        if until <= now {
            rateLimitedUntil = nil
            return nil
        }
        return until
    }

    public func isRateLimited(now: Date = Date()) -> Bool {
        guard let until = rateLimitUntil(now: now) else { return false }
        return until > now
    }

    public func clear() {
        store.removeAll()
        entryOrder.removeAll()
        rateLimitedUntil = nil
        persistentStore?.clear()
    }

    public func count() -> Int {
        persistentStore?.count() ?? store.count
    }

    private func touch(_ key: String) {
        entryOrder.removeAll { $0 == key }
        entryOrder.append(key)
    }

    private func evictIfNeeded() {
        while store.count > maxEntries, let oldest = entryOrder.first {
            entryOrder.removeFirst()
            store[oldest] = nil
        }
    }
}
