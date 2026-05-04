import AppIntents
import StackLightCore

/// One choice in the provider picker. The special "any" entity means
/// "show deployments from every configured provider".
struct ProviderEntity: AppEntity {
    static let anyID = "__any__"

    let id: String
    let displayName: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Provider")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)")
    }

    static var defaultQuery = ProviderEntityQuery()

    static let any = ProviderEntity(id: anyID, displayName: "All Providers")

    static func allEntities() -> [ProviderEntity] {
        var list: [ProviderEntity] = [.any]
        list.append(contentsOf: ServiceRegistry.shared.providers.map {
            ProviderEntity(id: $0.id, displayName: $0.displayName)
        })
        return list
    }
}

struct ProviderEntityQuery: EntityQuery {
    func entities(for identifiers: [ProviderEntity.ID]) async throws -> [ProviderEntity] {
        ProviderEntity.allEntities().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ProviderEntity] {
        ProviderEntity.allEntities()
    }

    func defaultResult() async -> ProviderEntity? {
        .any
    }
}
