import AppKit

enum MenuBuilder {
    static func buildMenu(
        deployments: [Deployment],
        errors: [String: String],
        lastRefresh: Date?,
        target: AppDelegate
    ) -> NSMenu {
        let menu = NSMenu()

        // Group deployments by provider
        let providers = ServiceRegistry.shared.providers
        let grouped = Dictionary(grouping: deployments, by: \.providerID)

        let configuredProviders = providers.filter { $0.isConfigured }

        if configuredProviders.isEmpty {
            let item = NSMenuItem(title: "No services configured", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            let hint = NSMenuItem(title: "Open Settings to add API tokens", action: nil, keyEquivalent: "")
            hint.isEnabled = false
            menu.addItem(hint)
        } else {
            for provider in configuredProviders {
                let providerDeployments = grouped[provider.id] ?? []

                // Section header
                if menu.items.count > 0 {
                    menu.addItem(NSMenuItem.separator())
                }
                let header = NSMenuItem(title: provider.displayName, action: nil, keyEquivalent: "")
                header.isEnabled = false
                header.attributedTitle = sectionHeaderTitle(provider.displayName)
                menu.addItem(header)

                // Error for this provider
                if let error = errors[provider.id] {
                    let msg = error.count > 60 ? String(error.prefix(58)) + "…" : error
                    let errorItem = NSMenuItem(title: "  ⚠ \(msg)", action: nil, keyEquivalent: "")
                    errorItem.isEnabled = false
                    errorItem.toolTip = error // full message on hover
                    menu.addItem(errorItem)
                }

                // Deployment items
                if providerDeployments.isEmpty && errors[provider.id] == nil {
                    let empty = NSMenuItem(title: "  No recent deployments", action: nil, keyEquivalent: "")
                    empty.isEnabled = false
                    menu.addItem(empty)
                } else {
                    for deployment in providerDeployments.prefix(5) {
                        let item = makeDeploymentItem(deployment, target: target)
                        menu.addItem(item)
                    }
                }
            }
        }

        // Footer
        menu.addItem(NSMenuItem.separator())

        if let lastRefresh {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            let timeStr = formatter.localizedString(for: lastRefresh, relativeTo: Date())
            let refreshedItem = NSMenuItem(title: "Updated \(timeStr)", action: nil, keyEquivalent: "")
            refreshedItem.isEnabled = false
            menu.addItem(refreshedItem)
        }

        let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(AppDelegate.refreshNow(_:)), keyEquivalent: "r")
        refreshItem.target = target
        menu.addItem(refreshItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(AppDelegate.openSettings(_:)), keyEquivalent: ",")
        settingsItem.target = target
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(title: "Quit ShapeBar", action: #selector(AppDelegate.quitApp(_:)), keyEquivalent: "q")
        quitItem.target = target
        menu.addItem(quitItem)

        return menu
    }

    private static func makeDeploymentItem(_ deployment: Deployment, target: AppDelegate) -> NSMenuItem {
        let title = formatDeploymentTitle(deployment)
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        item.attributedTitle = title

        if let url = deployment.url {
            item.action = #selector(AppDelegate.openDeploymentURL(_:))
            item.target = target
            item.representedObject = url
        } else {
            item.isEnabled = false
        }

        if let commit = deployment.commitMessage {
            item.toolTip = commit
        }

        return item
    }

    private static func formatDeploymentTitle(_ deployment: Deployment) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // Status emoji
        let statusColor: NSColor = {
            switch deployment.status {
            case .success:   return .systemGreen
            case .failed:    return .systemRed
            case .building:  return .systemOrange
            case .queued:    return .systemGray
            case .cancelled: return .systemGray
            case .reviewing: return .systemBlue
            case .unknown:   return .systemGray
            }
        }()

        let emoji = NSAttributedString(
            string: "  \(deployment.status.emoji) ",
            attributes: [.foregroundColor: statusColor, .font: NSFont.systemFont(ofSize: 13)]
        )
        result.append(emoji)

        // Project name (bold, max 24 chars)
        let projectName = String(deployment.projectName.prefix(24))
        let name = NSAttributedString(
            string: projectName,
            attributes: [.font: NSFont.boldSystemFont(ofSize: 13)]
        )
        result.append(name)

        // Branch (max 28 chars)
        if let branch = deployment.branch {
            let truncated = branch.count > 28 ? String(branch.prefix(26)) + "…" : branch
            let branchStr = NSAttributedString(
                string: "  \(truncated)",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
            )
            result.append(branchStr)
        }

        // Time
        let timeStr = NSAttributedString(
            string: "  \(deployment.relativeTime)",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.tertiaryLabelColor
            ]
        )
        result.append(timeStr)

        return result
    }

    private static func sectionHeaderTitle(_ name: String) -> NSAttributedString {
        NSAttributedString(
            string: name,
            attributes: [
                .font: NSFont.boldSystemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
    }
}
