import AppIntents
import StackLightCore

/// A `(providerID, projectName)` tuple the user can pin. The available list is
/// derived dynamically from the most recent shared snapshot so the user only
/// sees real projects they've seen deployments for.
struct ProjectEntity: AppEntity {
    let id: String
    let providerID: String
    let projectName: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Project")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(projectName)", subtitle: "\(providerID)")
    }

    static var defaultQuery = ProjectEntityQuery()

    static func id(providerID: String, projectName: String) -> String {
        "\(providerID)::\(projectName)"
    }

    static func allEntities() -> [ProjectEntity] {
        let deployments = SharedStore.read()?.deployments ?? []
        var seen = Set<String>()
        var result: [ProjectEntity] = []
        for d in deployments {
            let key = id(providerID: d.providerID, projectName: d.projectName)
            if seen.insert(key).inserted {
                result.append(ProjectEntity(
                    id: key,
                    providerID: d.providerID,
                    projectName: d.projectName
                ))
            }
        }
        return result.sorted { $0.projectName.lowercased() < $1.projectName.lowercased() }
    }
}

struct ProjectEntityQuery: EntityQuery {
    func entities(for identifiers: [ProjectEntity.ID]) async throws -> [ProjectEntity] {
        ProjectEntity.allEntities().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ProjectEntity] {
        ProjectEntity.allEntities()
    }
}
