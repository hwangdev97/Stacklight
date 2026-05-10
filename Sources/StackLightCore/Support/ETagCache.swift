import Foundation

/// In-memory LRU layer over `HTTPResponseCache`. Holds the hottest 512 ETag
/// entries so the menu first-paint reads from RAM, with the SQLite store as a
/// fallback after process restart.
///
/// Implementation: classic doubly-linked list + dictionary. Earlier versions
/// stored ordering in a `[String]` and called `removeAll { $0 == key }` on
/// every touch — O(n) per cache hit, which becomes painful when a single poll
/// resolves dozens of ETag-keyed URLs.
public actor ETagCache {
    public static let defaultMaxEntries = 512

    private final class Node {
        let key: String
        var etag: String
        var data: Data
        var prev: Node?
        var next: Node?

        init(key: String, etag: String, data: Data) {
            self.key = key
            self.etag = etag
            self.data = data
        }
    }

    private let maxEntries: Int
    private let persistentStore: HTTPResponseCache?
    private var nodes: [String: Node] = [:]
    private var head: Node?  // least-recently used
    private var tail: Node?  // most-recently used
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
        if let node = nodes[key] {
            moveToTail(node)
            return (node.etag, node.data)
        }
        guard let cached = persistentStore?.cached(url: url) else { return nil }
        if maxEntries > 0 {
            insertNew(key: key, etag: cached.etag, data: cached.data)
        }
        return (cached.etag, cached.data)
    }

    public func save(url: URL, etag: String?, data: Data, response: HTTPURLResponse? = nil) {
        guard let etag else { return }
        let key = url.absoluteString
        if maxEntries > 0 {
            if let existing = nodes[key] {
                existing.etag = etag
                existing.data = data
                moveToTail(existing)
            } else {
                insertNew(key: key, etag: etag, data: data)
            }
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
        nodes.removeAll()
        head = nil
        tail = nil
        rateLimitedUntil = nil
        persistentStore?.clear()
    }

    public func count() -> Int {
        persistentStore?.count() ?? nodes.count
    }

    // MARK: - LRU plumbing

    private func insertNew(key: String, etag: String, data: Data) {
        let node = Node(key: key, etag: etag, data: data)
        nodes[key] = node
        attachAtTail(node)
        evictIfNeeded()
    }

    private func moveToTail(_ node: Node) {
        guard tail !== node else { return }
        detach(node)
        attachAtTail(node)
    }

    private func attachAtTail(_ node: Node) {
        node.prev = tail
        node.next = nil
        tail?.next = node
        tail = node
        if head == nil { head = node }
    }

    private func detach(_ node: Node) {
        let p = node.prev
        let n = node.next
        p?.next = n
        n?.prev = p
        if head === node { head = n }
        if tail === node { tail = p }
        node.prev = nil
        node.next = nil
    }

    private func evictIfNeeded() {
        while nodes.count > maxEntries, let oldest = head {
            detach(oldest)
            nodes.removeValue(forKey: oldest.key)
        }
    }
}
