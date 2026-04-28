import Foundation

/// Generic UserDefaults-backed cache for AI feature responses.
///
/// Each instance is namespaced by `prefix` (e.g. `"ai_journal_v1_"`) so features
/// don't collide and can evict independently. Bumping the prefix version is the
/// migration path when the cached payload's shape changes.
struct AICache<Value: Codable> {

    let prefix: String
    let maxEntries: Int

    init(prefix: String, maxEntries: Int = 50) {
        self.prefix = prefix
        self.maxEntries = maxEntries
    }

    /// Loads a value previously stored under `key` (without the prefix).
    func load(key: String) -> Value? {
        guard let data = UserDefaults.standard.data(forKey: prefix + key) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    /// Stores `value` under `key` (without the prefix). Evicts oldest entries past `maxEntries`.
    func save(_ value: Value, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        let defaults = UserDefaults.standard
        defaults.set(data, forKey: prefix + key)
        evictOldestIfNeeded(defaults: defaults)
    }

    /// Removes every entry with this cache's prefix. Useful for tests and feature reset.
    func clearAll() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            defaults.removeObject(forKey: key)
        }
    }

    /// Keeps the cache bounded. Removes the oldest entries past `maxEntries`. UserDefaults
    /// has no per-key timestamp, so we fall back to the lexicographic ordering of keys, which
    /// is stable enough for content-hashed keys.
    private func evictOldestIfNeeded(defaults: UserDefaults) {
        let keys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(prefix) }
        guard keys.count > maxEntries else { return }
        let toEvict = keys.sorted().prefix(keys.count - maxEntries)
        for key in toEvict { defaults.removeObject(forKey: key) }
    }
}
