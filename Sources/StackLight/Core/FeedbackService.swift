import Foundation

// MARK: - Public Types

enum FeedbackCategory: String, CaseIterable, Identifiable {
    case bug
    case feature
    case question

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bug:      return "Bug"
        case .feature:  return "Feature Request"
        case .question: return "Question"
        }
    }

    /// GitHub label slug applied to the created issue.
    var label: String { rawValue }
}

struct FeedbackPayload {
    let title: String
    let category: FeedbackCategory
    let description: String
}

enum FeedbackError: LocalizedError {
    case missingToken
    case httpError(status: Int, message: String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "No GitHub token found. Set your GitHub Personal Access Token in Settings → GitHub Pull Requests."
        case .httpError(let status, let message):
            return "GitHub API error (\(status)): \(message)"
        case .invalidResponse:
            return "Unexpected response from GitHub."
        }
    }
}

// MARK: - Service

enum FeedbackService {
    /// Hardcoded destination for user feedback issues.
    static let repository = "hwangdev97/stacklight"

    /// Submits feedback as a GitHub issue. Returns the html_url of the new issue.
    static func submit(_ payload: FeedbackPayload) async throws -> URL {
        guard let token = KeychainManager.read(key: "github.token"),
              !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FeedbackError.missingToken
        }

        let url = URL(string: "https://api.github.com/repos/\(repository)/issues")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let body: [String: Any] = [
            "title": payload.title.trimmingCharacters(in: .whitespacesAndNewlines),
            "body": composeBody(description: payload.description, category: payload.category),
            "labels": ["feedback", payload.category.label]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw FeedbackError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let message = parseErrorMessage(from: data) ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw FeedbackError.httpError(status: http.statusCode, message: message)
        }

        let decoded = try JSONDecoder().decode(IssueResponse.self, from: data)
        guard let issueURL = URL(string: decoded.html_url) else {
            throw FeedbackError.invalidResponse
        }
        return issueURL
    }

    // MARK: - Helpers

    private static func composeBody(description: String, category: FeedbackCategory) -> String {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)

        let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
        let buildNumber = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "?"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString

        let diagnostics = """
        ---
        _Submitted via StackLight in-app feedback_
        - Category: **\(category.displayName)**
        - App: StackLight \(appVersion) (\(buildNumber))
        - macOS: \(osVersion)
        """

        return "\(trimmed)\n\n\(diagnostics)"
    }

    private static func parseErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json["message"] as? String
    }
}

// MARK: - Decoding

private struct IssueResponse: Decodable {
    let html_url: String
}
