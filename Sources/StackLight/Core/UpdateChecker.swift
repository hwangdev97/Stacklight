import Foundation

#if os(macOS)
import AppKit
#endif

enum DistributionChannel: String {
    case github
    case macAppStore = "mac-app-store"
    case development

    var displayName: String {
        switch self {
        case .github:
            return "GitHub"
        case .macAppStore:
            return "Mac App Store"
        case .development:
            return "Development"
        }
    }
}

enum UpdateCheckResult {
    case unsupported(channel: DistributionChannel)
    case upToDate(version: String)
    case updateAvailable(version: String, pageURL: URL)
}

enum UpdateChecker {
    static var channel: DistributionChannel {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "StackLightDistributionChannel") as? String,
            let channel = DistributionChannel(rawValue: value)
        else {
            return .development
        }
        return channel
    }

    static var currentVersion: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return [shortVersion, build].compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }.joined(separator: " (") + (build == nil ? "" : ")")
    }

    static var currentMarketingVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    static var releasesURL: URL {
        if let value = Bundle.main.object(forInfoDictionaryKey: "StackLightGitHubReleasesURL") as? String,
           let url = URL(string: value) {
            return url
        }
        return URL(string: "https://github.com/hwangdev97/Stacklight/releases/latest")!
    }

    static func checkForUpdates() async throws -> UpdateCheckResult {
        guard channel == .github else {
            return .unsupported(channel: channel)
        }

        let release = try await latestGitHubRelease()
        let latestVersion = normalizedVersion(release.tagName)
        let currentVersion = normalizedVersion(currentMarketingVersion)

        if isVersion(latestVersion, newerThan: currentVersion) {
            return .updateAvailable(version: release.tagName, pageURL: release.htmlURL)
        }

        return .upToDate(version: currentMarketingVersion)
    }

    @MainActor
    static func presentUpdateCheckResult(_ result: Result<UpdateCheckResult, Error>) {
#if os(macOS)
        let alert = NSAlert()
        alert.alertStyle = .informational

        switch result {
        case .success(.unsupported(let channel)):
            alert.messageText = "Updates are handled by \(channel.displayName)"
            alert.informativeText = channel == .macAppStore
                ? "Install updates from the Mac App Store."
                : "This build is not configured for GitHub release updates."
            alert.addButton(withTitle: "OK")
        case .success(.upToDate(let version)):
            alert.messageText = "StackLight is up to date"
            alert.informativeText = "You are running version \(version)."
            alert.addButton(withTitle: "OK")
        case .success(.updateAvailable(let version, let pageURL)):
            alert.messageText = "A StackLight update is available"
            alert.informativeText = "Version \(version) is available on GitHub Releases."
            alert.addButton(withTitle: "Open Release")
            alert.addButton(withTitle: "Later")

            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(pageURL)
            }
            return
        case .failure(let error):
            alert.alertStyle = .warning
            alert.messageText = "Could not check for updates"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "OK")
        }

        alert.runModal()
#endif
    }

    private static func latestGitHubRelease() async throws -> GitHubRelease {
        let repository = Bundle.main.object(forInfoDictionaryKey: "StackLightGitHubRepository") as? String
        let repo = repository?.isEmpty == false ? repository! : "hwangdev97/Stacklight"
        let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("StackLight", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }

    private static func normalizedVersion(_ value: String) -> [Int] {
        let trimmed = value.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        return trimmed
            .split { !$0.isNumber }
            .prefix(3)
            .map { Int($0) ?? 0 }
    }

    private static func isVersion(_ lhs: [Int], newerThan rhs: [Int]) -> Bool {
        let count = max(lhs.count, rhs.count)
        for index in 0..<count {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right {
                return left > right
            }
        }
        return false
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: URL

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}
