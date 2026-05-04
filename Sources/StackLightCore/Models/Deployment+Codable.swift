import Foundation

extension Deployment: Codable {
    enum CodingKeys: String, CodingKey {
        case id, providerID, projectName, status, url, createdAt, commitMessage, branch
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try c.decode(String.self, forKey: .status)
        self.init(
            id:             try c.decode(String.self, forKey: .id),
            providerID:     try c.decode(String.self, forKey: .providerID),
            projectName:    try c.decode(String.self, forKey: .projectName),
            status:         Status(rawValue: raw) ?? .unknown,
            url:            try c.decodeIfPresent(URL.self, forKey: .url),
            createdAt:      try c.decode(Date.self, forKey: .createdAt),
            commitMessage:  try c.decodeIfPresent(String.self, forKey: .commitMessage),
            branch:         try c.decodeIfPresent(String.self, forKey: .branch)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,                     forKey: .id)
        try c.encode(providerID,             forKey: .providerID)
        try c.encode(projectName,            forKey: .projectName)
        try c.encode(status.rawValue,        forKey: .status)
        try c.encodeIfPresent(url,           forKey: .url)
        try c.encode(createdAt,              forKey: .createdAt)
        try c.encodeIfPresent(commitMessage, forKey: .commitMessage)
        try c.encodeIfPresent(branch,        forKey: .branch)
    }
}
