import Foundation

/// Keep the existing preference key and opaque station IDs across app updates.
public struct FavoriteStore {
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    public func load() -> Set<String> {
        Set(defaults.stringArray(forKey: "favorites") ?? [])
    }
    public func save(_ ids: Set<String>) {
        defaults.set(Array(ids).sorted(), forKey: "favorites")
    }
}
