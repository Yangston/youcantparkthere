import Foundation
import ParkCore
#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif

@main
struct FeedCheck {
    static func main() async {
        do {
            let snapshot = try await GBFSClient().fetch()
            let fresh = snapshot.stations.filter { snapshot.isFresh($0, at: Date()) }.count
            print("Parsed \(snapshot.stations.count) stations; \(fresh) currently fresh.")
            print("Feed publication: \(snapshot.updatedAt); refresh interval: \(snapshot.refreshAfter)s")
            guard fresh > 0 else { throw FeedError.invalid("Feed parsed but no stations have fresh status.") }
        } catch {
            fputs("Live feed check failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
}
