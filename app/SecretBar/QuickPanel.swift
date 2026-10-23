// Quick panel (⌥⌘S from any app), the copy HUD near the menu bar, the global hot key and the
// navigation into the main window (014).
import AppKit
import Carbon.HIToolbox
import SwiftUI

// MARK: navigation

// Opens the main window, optionally on one secret. SwiftUI gives `openWindow` only to views, so
// the app keeps it here when the first view appears.
@MainActor
final class Navigation: ObservableObject {
    static let shared = Navigation()
    @Published var selection: String?
    @Published var sidebar: SidebarItem = .all
    var openMain: (() -> Void)?

    func select(_ name: String?) {
        if let n = name { selection = n; sidebar = .all }
        showMain()
    }

    func showMain() {
        NSApp.activate(ignoringOtherApps: true)
        openMain?()
    }

    // The main window takes the request on appear or on change and opens the add sheet (019).
    @Published var addPending = false
    var addName = ""
    func newSecret(name: String = "") {
        addName = name
        addPending = true
        showMain()
    }
}

// MARK: hot key

// Carbon RegisterEventHotKey: a global key without the Accessibility permission.
final class HotKey {
    static let shared = HotKey()
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var action: (() -> Void)?

    // ⌥⌘S. False: another app holds the key.
    @discardableResult
    func register() -> Bool {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { HotKey.shared.action?() }
            return noErr
        }, 1, &spec, nil, &handler)
        let id = EventHotKeyID(signature: OSType(0x5342_4152), id: 1)  // "SBAR"
        let status = RegisterEventHotKey(UInt32(kVK_ANSI_S), UInt32(cmdKey | optionKey), id, GetApplicationEventTarget(), 0, &ref)
        return status == noErr
    }
}

// MARK: quick panel

final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class QuickPanel: NSObject, NSWindowDelegate {
    static let shared = QuickPanel()
    private var panel: KeyPanel?

    func toggle() {
        if let p = panel, p.isVisible { close(); return }
        show()
    }

    func show() {
        let p = KeyPanel(contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
                         styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless], backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.level = .modalPanel
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.isMovableByWindowBackground = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.delegate = self
        let host = NSHostingView(rootView: QuickSearchView(close: { [weak self] in self?.close() }).environmentObject(Store.shared))
        p.contentView = host
        // in the upper third of the screen with the mouse, as Spotlight
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let f = screen?.visibleFrame {
            p.setFrameOrigin(NSPoint(x: f.midX - 320, y: f.maxY - f.height * 0.28 - 420))
        }
        panel = p
        Store.shared.visibleWindows += 1
        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        Task { await Store.shared.refreshList() }
    }

    func close() {
        guard let p = panel else { return }
        panel = nil
        Store.shared.visibleWindows -= 1
        p.orderOut(nil)
    }

    nonisolated func windowDidResignKey(_ notification: Notification) {
        Task { @MainActor in self.close() }
    }
}

struct QuickSearchView: View {
    @EnvironmentObject var store: Store
    let close: () -> Void
    @State private var query = ""
    @State private var index = 0
    @FocusState private var focused: Bool

    private var results: [Secret] { Array(store.filter(query).prefix(50)) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "key.horizontal.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(LinearGradient(colors: [.indigo, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .accessibilityHidden(true)
                TextField("Secret: name or comment", text: $query)
                    .accessibilityLabel("Search secrets. Return copies the reference, Shift-Return the value")
                    .textFieldStyle(.plain)
                    .font(.system(size: 22, weight: .regular))
                    .focused($focused)
                    .onKeyPress(keys: [.return]) { press in submit(value: press.modifiers.contains(.shift)); return .handled }
                    .onSubmit { submit(value: Store.shiftDown) }
                    .onKeyPress(.downArrow) { index = min(index + 1, max(results.count - 1, 0)); return .handled }
                    .onKeyPress(.upArrow) { index = max(index - 1, 0); return .handled }
                    .onKeyPress(.escape) { close(); return .handled }
                StatusPill()
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
            Divider().opacity(0.5)
            if results.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").font(.system(size: 28)).foregroundStyle(.tertiary)
                    Text("Nothing found").foregroundStyle(.secondary)
                    if let n = Parse.suggestedName(query) {
                        Button { submit(value: false) } label: { Label("Create \(n)", systemImage: "plus") }
                            .buttonStyle(.bordered).padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(results.enumerated()), id: \.element.id) { i, s in
                                QuickRow(secret: s, selected: i == index)
                                    .id(i)
                                    .onTapGesture { index = i; submit(value: Store.shiftDown) }
                            }
                        }
                        .padding(8)
                    }
                    .onChange(of: index) { _, i in withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(i) } }
                }
            }
            Divider().opacity(0.5)
            HStack(spacing: 14) {
                Hint(keys: "↩", text: "reference")
                Hint(keys: "⇧↩", text: "value")
                Hint(keys: "⌘N", text: "new")
                Hint(keys: "esc", text: "close")
                Spacer()
                Button {
                    let sel = results.indices.contains(index) ? results[index].name : nil
                    close()
                    Navigation.shared.select(sel)
                } label: {
                    Text("Open SecretBar").font(.system(size: 11))
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16).padding(.vertical, 9)
        }
        .frame(width: 640, height: 420)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.primary.opacity(0.08)))
        .background { Button("") { newSecret() }.keyboardShortcut("n").hidden() }
        .onChange(of: query) { _, _ in index = 0 }
        .onAppear { focused = true }
    }

    // A found secret: the reference, or the value with ⇧. Nothing found: a new secret with the
    // query as its name (025).
    private func submit(value: Bool) {
        guard results.indices.contains(index) else {
            if Parse.suggestedName(query) != nil { newSecret() }
            return
        }
        let name = results[index].name
        close()  // the Touch ID window takes the focus anyway; the HUD shows the result
        Task { await store.pick(name, value: value) }
    }

    private func newSecret() {
        let n = Parse.suggestedName(query) ?? ""
        close()
        Navigation.shared.newSecret(name: n)
    }
}

struct QuickRow: View {
    let secret: Secret
    let selected: Bool

    var body: some View {
        HStack(spacing: 12) {
            ProjectBadge(project: secret.project, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(secret.name)
                    .font(.system(size: 13.5, weight: .semibold, design: .monospaced))
                    .lineLimit(1).truncationMode(.middle)
                    .foregroundStyle(selected ? Color.white : Color.primary)
                if !secret.comment.isEmpty {
                    Text(secret.comment)
                        .font(.system(size: 11.5))
                        .lineLimit(1)
                        .foregroundStyle(selected ? Color.white.opacity(0.85) : Color.secondary)
                }
            }
            Spacer()
            ExpiryBadge(secret: secret, inverted: selected)
            if selected {
                Image(systemName: "return").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(selected ? AnyShapeStyle(LinearGradient(colors: [.indigo, .blue], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(Color.clear))
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct Hint: View {
    let keys: String
    let text: LocalizedStringKey
    var body: some View {
        HStack(spacing: 4) {
            Text(keys)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.08)))
            Text(text).font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }
}

// MARK: HUD

// A small capsule under the menu bar: copy and lock results, also when no window is open.
@MainActor
final class HUD {
    static let shared = HUD()
    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?

    func show(text: String, symbol: String, error: Bool) {
        guard !Store.shared.demo else { return }
        let view = HUDView(text: text, symbol: symbol, error: error)
        let host = NSHostingView(rootView: view)
        let size = host.fittingSize
        let p = panel ?? {
            let p = NSPanel(contentRect: .zero, styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
            p.level = .statusBar
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = false
            p.ignoresMouseEvents = true
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            return p
        }()
        panel = p
        p.contentView = host
        if let f = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame {
            p.setFrame(NSRect(x: f.midX - size.width / 2, y: f.maxY - size.height - 12, width: size.width, height: size.height), display: true)
        }
        p.alphaValue = 0
        p.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.18; p.animator().alphaValue = 1 }
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(error ? 4 : 2.4))
            guard !Task.isCancelled else { return }
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.35; p.animator().alphaValue = 0 }) { p.orderOut(nil) }
        }
    }
}

struct HUDView: View {
    let text: String
    let symbol: String
    let error: Bool
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(error ? Color.red : Color.green)
                .symbolRenderingMode(.hierarchical)
            Text(text).font(.system(size: 13, weight: .medium)).lineLimit(2)
        }
        .padding(.horizontal, 18).padding(.vertical, 11)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1)))
        .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
        .padding(16)
        .fixedSize()
    }
}
