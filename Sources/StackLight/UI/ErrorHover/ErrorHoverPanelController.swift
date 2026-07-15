import AppKit
import SwiftUI
import Combine
import StackLightCore

/// Shows a floating error-detail card next to a hovered failed row in the
/// menu bar panel.
///
/// Window-activation rules this must respect (menu bar apps are fragile
/// here):
/// - The `MenuBarExtra(.window)` panel dismisses itself when it stops being
///   the key window. The hover card therefore uses an `NSPanel` that
///   **cannot become key or main** — clicks on its buttons are delivered
///   without any key-window change, so the menu stays open.
/// - The panel is `.nonactivatingPanel`, so showing it (or clicking it)
///   never activates the app or steals focus from whatever app the user was
///   in — same contract as the menu bar panel itself.
/// - It's attached as a *child window* of the menu panel: it moves with it,
///   stays above it, and is torn down when the menu closes (we also observe
///   `willCloseNotification` for the explicit hide).
/// - Copying to `NSPasteboard` requires no window/app activation at all,
///   which is why the card's actions work from this non-key panel.
/// - "Open in Terminal/browser" intentionally activates another app; the
///   menu closes in response and the close observer tears the card down.
@MainActor
final class ErrorHoverPanelController {
    static let shared = ErrorHoverPanelController()

    /// Panel that never takes key/main status — see class comment.
    private final class HoverPanel: NSPanel {
        override var canBecomeKey: Bool { false }
        override var canBecomeMain: Bool { false }
    }

    /// Container that reports pointer enter/exit so the card survives the
    /// mouse travelling from the row into the card (grace period).
    private final class TrackingContainerView: NSView {
        var onHoverChange: ((Bool) -> Void)?
        private var trackingArea: NSTrackingArea?

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let trackingArea { removeTrackingArea(trackingArea) }
            let area = NSTrackingArea(
                rect: .zero,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(area)
            trackingArea = area
        }

        override func mouseEntered(with event: NSEvent) { onHoverChange?(true) }
        override func mouseExited(with event: NSEvent) { onHoverChange?(false) }
    }

    private var panel: HoverPanel?
    private var container: TrackingContainerView?
    private var hostingView: NSHostingView<ErrorDetailCard>?

    private weak var parentWindow: NSWindow?
    private var parentCloseObserver: NSObjectProtocol?
    private var storeObserver: AnyCancellable?

    private var currentKey: String?
    private var pointerInPanel = false
    private var showWork: DispatchWorkItem?
    private var hideWork: DispatchWorkItem?

    // Tuning. Show is delayed so scanning the menu doesn't flash cards;
    // hide has a grace window so the pointer can cross the gap into the card.
    private let showDelay: TimeInterval = 0.32
    private let hideGrace: TimeInterval = 0.20
    private let gap: CGFloat = 10

    // MARK: - Row hover entry points (called by ErrorHoverAnchor)

    func rowHoverBegan(_ deployment: Deployment, providerName: String, anchor: NSView) {
        hideWork?.cancel()
        hideWork = nil

        let key = FailureDetailsStore.key(for: deployment)
        if key == currentKey, panel?.isVisible == true {
            return
        }

        // Prefetch during the show delay so the card often opens populated.
        FailureDetailsStore.shared.load(deployment)

        showWork?.cancel()
        let work = DispatchWorkItem { [weak self, weak anchor] in
            guard let self, let anchor, anchor.window != nil else { return }
            self.presentPanel(for: deployment, providerName: providerName, anchor: anchor)
        }
        showWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + showDelay, execute: work)
    }

    func rowHoverEnded(_ deployment: Deployment) {
        showWork?.cancel()
        showWork = nil
        scheduleHide()
    }

    /// Immediate teardown — menu closed, row scrolled away, app quitting.
    func hideNow() {
        showWork?.cancel()
        showWork = nil
        hideWork?.cancel()
        hideWork = nil
        currentKey = nil
        pointerInPanel = false
        storeObserver = nil

        if let observer = parentCloseObserver {
            NotificationCenter.default.removeObserver(observer)
            parentCloseObserver = nil
        }
        if let panel {
            panel.parent?.removeChildWindow(panel)
            panel.orderOut(nil)
        }
        parentWindow = nil
    }

    // MARK: - Presentation

    private func presentPanel(for deployment: Deployment, providerName: String, anchor: NSView) {
        guard let window = anchor.window else { return }

        let card = ErrorDetailCard(deployment: deployment, providerName: providerName)
        let hosting = NSHostingView(rootView: card)
        hosting.translatesAutoresizingMaskIntoConstraints = false

        let container = TrackingContainerView()
        container.onHoverChange = { [weak self] inside in
            self?.panelHoverChanged(inside)
        }
        container.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        let panel = self.panel ?? makePanel()
        self.panel = panel
        self.container = container
        self.hostingView = hosting
        panel.contentView = container

        // Track the parent so we tear down when the menu closes.
        if parentWindow !== window {
            if let observer = parentCloseObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            parentCloseObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.hideNow()
                }
            }
            parentWindow = window
        }

        currentKey = FailureDetailsStore.key(for: deployment)
        pointerInPanel = false

        layoutPanel(panel, anchor: anchor, in: window)

        // Match the menu panel's level & spaces behavior so the card is
        // visible wherever the menu is (full-screen apps included).
        panel.level = window.level
        panel.collectionBehavior = window.collectionBehavior.union([.fullScreenAuxiliary])

        if panel.parent !== window {
            panel.parent?.removeChildWindow(panel)
            window.addChildWindow(panel, ordered: .above)
        }
        // orderFront only — never makeKey (see class comment).
        panel.orderFront(nil)

        // The card's height changes as details load; follow the SwiftUI
        // fitting size whenever the store updates.
        storeObserver = FailureDetailsStore.shared.$states
            .receive(on: RunLoop.main)
            .sink { [weak self, weak anchor] _ in
                guard let self, let panel = self.panel, panel.isVisible,
                      let anchor, let window = anchor.window else { return }
                self.layoutPanel(panel, anchor: anchor, in: window)
            }
    }

    private func makePanel() -> HoverPanel {
        let panel = HoverPanel(
            contentRect: NSRect(x: 0, y: 0, width: ErrorDetailCard.cardWidth, height: 120),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.animationBehavior = .utilityWindow
        panel.isMovable = false
        return panel
    }

    /// Places the card beside the menu window, top-aligned with the hovered
    /// row: left of the menu when there's room (the menu usually hugs the
    /// right screen edge), otherwise right, clamped to the visible frame.
    private func layoutPanel(_ panel: NSPanel, anchor: NSView, in window: NSWindow) {
        guard let hostingView else { return }
        let size = hostingView.fittingSize
        let height = max(size.height, 60)
        let width = max(size.width, ErrorDetailCard.cardWidth)

        let rowRectInWindow = anchor.convert(anchor.bounds, to: nil)
        let rowRect = window.convertToScreen(rowRectInWindow)
        let menuFrame = window.frame
        let screenFrame = (window.screen ?? NSScreen.main)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        var x = menuFrame.minX - width - gap
        if x < screenFrame.minX {
            x = menuFrame.maxX + gap
            if x + width > screenFrame.maxX {
                // No side room at all — overlap the menu's left edge rather
                // than covering the hovered row completely.
                x = max(screenFrame.minX, menuFrame.minX - width * 0.6)
            }
        }

        // Top-align the card with the hovered row.
        var y = rowRect.maxY - height
        y = min(max(y, screenFrame.minY), screenFrame.maxY - height)

        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }

    // MARK: - Panel hover

    private func panelHoverChanged(_ inside: Bool) {
        pointerInPanel = inside
        if inside {
            hideWork?.cancel()
            hideWork = nil
        } else {
            scheduleHide()
        }
    }

    private func scheduleHide() {
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.pointerInPanel else { return }
            self.hideNow()
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + hideGrace, execute: work)
    }
}

// MARK: - Row anchor

/// Invisible view layered behind a failed deployment row. It owns the
/// tracking area that drives the hover card and hands the controller a
/// concrete NSView to anchor to (for screen-coordinate math). `hitTest`
/// returns nil so clicks fall through to the row's button.
struct ErrorHoverAnchor: NSViewRepresentable {
    let deployment: Deployment
    let providerName: String

    final class AnchorView: NSView {
        var deployment: Deployment?
        var providerName: String = ""
        private var trackingArea: NSTrackingArea?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let trackingArea { removeTrackingArea(trackingArea) }
            let area = NSTrackingArea(
                rect: .zero,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(area)
            trackingArea = area
        }

        override func mouseEntered(with event: NSEvent) {
            guard let deployment else { return }
            ErrorHoverPanelController.shared.rowHoverBegan(
                deployment, providerName: providerName, anchor: self
            )
        }

        override func mouseExited(with event: NSEvent) {
            guard let deployment else { return }
            ErrorHoverPanelController.shared.rowHoverEnded(deployment)
        }
    }

    func makeNSView(context: Context) -> AnchorView {
        let view = AnchorView()
        view.deployment = deployment
        view.providerName = providerName
        return view
    }

    func updateNSView(_ nsView: AnchorView, context: Context) {
        nsView.deployment = deployment
        nsView.providerName = providerName
    }
}
