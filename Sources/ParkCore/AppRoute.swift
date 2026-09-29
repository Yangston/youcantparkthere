import Foundation

/// Routes supplied by our widgets. Unknown input must not silently start navigation.
public enum AppRoute: String, CaseIterable, Sendable {
    case docks, bikes, ride

    public init?(url: URL) {
        guard url.scheme?.lowercased() == "youcantparkthere",
              url.user == nil, url.password == nil, url.port == nil,
              url.path.isEmpty || url.path == "/",
              url.query == nil, url.fragment == nil,
              let host = url.host?.lowercased(), let route = Self(rawValue: host) else { return nil }
        self = route
    }
}
