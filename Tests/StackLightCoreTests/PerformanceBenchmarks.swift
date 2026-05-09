import XCTest
@testable import StackLightCore

/// Targeted micro-benchmarks for the hot paths that landed during the
/// menu-redraw / JSON / Keychain optimization pass.
///
/// These are not strict perf gates — `XCTMemoryMetric` and friends are too
/// flaky under CI — but they're useful for eyeballing regressions locally
/// (Run > Show Results > Performance).
final class PerformanceBenchmarks: XCTestCase {

    // MARK: - Fixtures

    private static func makeDeployments(count: Int) -> [Deployment] {
        (0..<count).map { i in
            Deployment(
                id: "id-\(i)",
                providerID: providerID(for: i),
                projectName: "project-\(i)",
                status: .success,
                url: URL(string: "https://example.com/\(i)"),
                createdAt: Date().addingTimeInterval(TimeInterval(-i * 60)),
                commitMessage: "commit \(i)",
                branch: "branch-\(i % 5)"
            )
        }
    }

    private static func providerID(for index: Int) -> String {
        switch index % 9 {
        case 0: return "vercel"
        case 1: return "cloudflare"
        case 2: return "githubActions"
        case 3: return "githubPRs"
        case 4: return "netlify"
        case 5: return "railway"
        case 6: return "flyio"
        case 7: return "xcodeCloud"
        default: return "testFlight"
        }
    }

    // MARK: - Grouping (covers the menu redraw hot path)

    /// Establishes a baseline for the work the menu used to do on every body
    /// call. After the optimization the grouping happens once per state
    /// change in `AppState`, but the raw cost shouldn't regress either.
    func testDictionaryGroupingThroughput() {
        let deployments = Self.makeDeployments(count: 90)
        measure {
            for _ in 0..<1000 {
                _ = Dictionary(grouping: deployments, by: \.providerID)
            }
        }
    }

    // MARK: - Equality diff (covers the publish-skip path)

    /// `AppState` skips `@Published` assignments when the new batch matches
    /// the old one. The dictionary-equality cost here is what we trade
    /// against the SwiftUI re-render cost we used to pay unconditionally —
    /// it should be cheap relative to a body-rebuild.
    func testDeploymentBatchEquality() {
        let a = Self.makeDeployments(count: 90)
        let b = a // identical
        measure {
            for _ in 0..<10_000 {
                _ = (a == b)
            }
        }
    }

    func testDeploymentByProviderEquality() {
        let a = Dictionary(grouping: Self.makeDeployments(count: 90), by: \.providerID)
        let b = a
        measure {
            for _ in 0..<10_000 {
                _ = (a == b)
            }
        }
    }

    // MARK: - JSON decoder reuse

    /// Demonstrates the saving from sharing one configured `JSONDecoder`
    /// across calls. The provider hot path used to instantiate a fresh
    /// decoder per response (and per error response).
    func testSharedJSONDecoderReuse() {
        let payload = #"{"id":"abc","value":42}"#.data(using: .utf8)!
        struct Sample: Decodable { let id: String; let value: Int }
        measure {
            for _ in 0..<5_000 {
                _ = try? SharedJSON.decoder.decode(Sample.self, from: payload)
            }
        }
    }

    func testFreshJSONDecoderPerCall() {
        let payload = #"{"id":"abc","value":42}"#.data(using: .utf8)!
        struct Sample: Decodable { let id: String; let value: Int }
        measure {
            for _ in 0..<5_000 {
                let decoder = JSONDecoder()
                _ = try? decoder.decode(Sample.self, from: payload)
            }
        }
    }

    // MARK: - RelativeDateTimeFormatter reuse

    /// `Deployment.relativeTime` is rendered per row. Reusing one shared
    /// formatter is meaningfully faster than allocating per call.
    func testSharedRelativeFormatterReuse() {
        let dates = (0..<200).map { Date().addingTimeInterval(TimeInterval(-$0 * 60)) }
        let now = Date()
        measure {
            for date in dates {
                _ = SharedFormatters.relativeAbbreviated.localizedString(for: date, relativeTo: now)
            }
        }
    }

    func testFreshRelativeFormatterPerCall() {
        let dates = (0..<200).map { Date().addingTimeInterval(TimeInterval(-$0 * 60)) }
        let now = Date()
        measure {
            for date in dates {
                let f = RelativeDateTimeFormatter()
                f.unitsStyle = .abbreviated
                _ = f.localizedString(for: date, relativeTo: now)
            }
        }
    }
}
