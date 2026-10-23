// Shared pieces (badges, status pill, toast) and the window of the menu bar icon: the state of
// grace, a quick search with copy, a way into the main window (014).
import AppKit
import SwiftUI

// MARK: shared

// A colored square with two letters of the project; the color comes from the name, so a project
// keeps it everywhere.
struct ProjectBadge: View {
    let project: String
    var size: CGFloat = 28

    private static let palette: [[Color]] = [
        [.indigo, .blue], [.teal, .cyan], [.orange, .pink], [.purple, .indigo], [.green, .teal],
        [.pink, .purple], [.blue, .cyan], [.brown, .orange], [.mint, .green], [.red, .orange],
    ]

    private var colors: [Color] {
        let h = project.unicodeScalars.reduce(5381) { ($0 << 5) &+ $0 &+ Int($1.value) }
        return Self.palette[abs(h) % Self.palette.count]
    }

    private var letters: String {
        if project == Parse.other { return "•" }
        let parts = project.split(whereSeparator: { "- _".contains($0) })
        let l = parts.count > 1 ? String(parts[0].prefix(1)) + String(parts[1].prefix(1)) : String(project.prefix(2))
        return l.uppercased()
    }

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
            .overlay(Text(letters).font(.system(size: size * 0.38, weight: .bold, design: .rounded)).foregroundStyle(.white))
            .shadow(color: colors[0].opacity(0.25), radius: size * 0.08, y: size * 0.04)
    }
}

struct ExpiryBadge: View {
    let secret: Secret
    var inverted = false
    var body: some View {
        if let d = secret.daysLeft() {
            let (text, color): (String, Color) = d < 0 ? (String(localized: "expired"), .red) : d <= 30 ? (String(localized: "\(d) d"), .orange) : (secret.expiry, .secondary)
            Text(text)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(inverted ? Color.white : color)
                .padding(.horizontal, 7).padding(.vertical, 2.5)
                .background(Capsule().fill(inverted ? Color.white.opacity(0.22) : color.opacity(0.13)))
                .help("Expires: \(secret.expiry)")
        }
    }
}

// Open or closed, with the time left.
struct StatusPill: View {
    @EnvironmentObject var store: Store
    var body: some View {
        let open = store.isOpen
        HStack(spacing: 5) {
            Image(systemName: open ? "lock.open.fill" : "lock.fill").font(.system(size: 10, weight: .bold))
            if case .active(let left, _, _) = store.grace {
                Text(Format.duration(left)).font(.system(size: 11, weight: .semibold, design: .rounded)).monospacedDigit()
            } else {
                Text("closed").font(.system(size: 11, weight: .semibold))
            }
        }
        .foregroundStyle(open ? Color.green : Color.secondary)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(Capsule().fill((open ? Color.green : Color.secondary).opacity(0.13)))
        .help(store.statusLine)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(store.statusLine)
    }
}

struct ToastView: View {
    let toast: Store.Toast
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: toast.symbol).foregroundStyle(toast.error ? .red : .green).symbolRenderingMode(.hierarchical)
            Text(toast.text).font(.system(size: 11.5, weight: .medium)).lineLimit(2)
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08)))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .padding(.horizontal, 16)
    }
}

// MARK: menu bar window

struct MenuBarView: View {
    @EnvironmentObject var store: Store
    @State private var query = ""
    @FocusState private var focused: Bool

    private var results: [Secret] { store.filter(query) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: store.isOpen ? [.green, .mint] : [.indigo, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 34, height: 34)
                    Image(systemName: store.isOpen ? "lock.open.fill" : "lock.fill")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("SecretBar").font(.system(size: 14, weight: .semibold))
                    Text(store.statusLine).font(.system(size: 11)).foregroundStyle(store.problem == nil ? Color.secondary : Color.orange).lineLimit(2)
                }
                Spacer(minLength: 0)
                if store.busy != nil { ProgressView().controlSize(.small) }
                if store.isOpen {
                    Button { Task { await store.lock() } } label: { Image(systemName: "lock.fill") }
                        .buttonStyle(.borderless).help("Lock now")
                }
                Button { Navigation.shared.newSecret(name: Parse.suggestedName(query) ?? "") } label: {
                    Image(systemName: "plus").font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.borderless).help("New secret (⌘N)").accessibilityLabel("New Secret")
                .keyboardShortcut("n")
            }
            .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 10)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Find: ↩ reference, ⇧↩ value", text: $query).textFieldStyle(.plain).focused($focused)
                    .onKeyPress(keys: [.return]) { press in submit(value: press.modifiers.contains(.shift)); return .handled }
                    .onSubmit { submit(value: Store.shiftDown) }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.primary.opacity(0.06)))
            .padding(.horizontal, 12)

            if store.expiredCount + store.soonCount > 0 {
                Button { Navigation.shared.sidebar = .expiring; Navigation.shared.showMain() } label: {
                    Label(store.expiredCount > 0 ? "Expired: \(store.expiredCount)" : "Expire within 30 days: \(store.soonCount)",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(store.expiredCount > 0 ? .red : .orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16).padding(.top, 8)
            }

            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(results) { s in MenuRow(secret: s) }
                    if results.isEmpty, let n = Parse.suggestedName(query) {
                        Button { Navigation.shared.newSecret(name: n) } label: { Label("Create \(n)", systemImage: "plus") }
                            .buttonStyle(.bordered).padding(.top, 16)
                    }
                }
                .padding(.horizontal, 6).padding(.vertical, 6)
            }
            .frame(maxHeight: .infinity)

            Divider()
            HStack(spacing: 6) {
                Button { Navigation.shared.showMain() } label: {
                    Label("Open SecretBar", systemImage: "macwindow")
                }
                .keyboardShortcut("o")
                Spacer()
                Hint(keys: "⌥⌘S", text: "quick search")
                Menu {
                    Button("New Secret…") { Navigation.shared.newSecret() }
                    Button("Refresh") { Task { await store.refreshAll() } }
                    Button("Settings…") { Navigation.shared.sidebar = .settings; Navigation.shared.showMain() }
                    Divider()
                    Button("Quit SecretBar") { NSApp.terminate(nil) }
                } label: { Image(systemName: "ellipsis.circle") }
                    .accessibilityLabel("More")
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            }
            .buttonStyle(.borderless)
            .font(.system(size: 12))
            .padding(.horizontal, 14).padding(.vertical, 9)
        }
        .frame(width: 380, height: 500)
        .overlay(alignment: .bottom) {
            if let t = store.toast { ToastView(toast: t).padding(.bottom, 50).transition(.move(edge: .bottom).combined(with: .opacity)) }
        }
        .onAppear {
            store.visibleWindows += 1
            focused = true
            Task { await store.refreshList() }
        }
        .onDisappear { store.visibleWindows -= 1 }
    }

    private func submit(value: Bool) {
        if let s = results.first { Task { await store.pick(s.name, value: value) } }
        else if let n = Parse.suggestedName(query) { Navigation.shared.newSecret(name: n) }
    }
}

struct MenuRow: View {
    @EnvironmentObject var store: Store
    let secret: Secret
    @State private var hover = false

    var body: some View {
        HStack(spacing: 10) {
            ProjectBadge(project: secret.project, size: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(secret.name).font(.system(size: 12, weight: .semibold, design: .monospaced)).lineLimit(1).truncationMode(.middle)
                if !secret.comment.isEmpty {
                    Text(secret.comment).font(.system(size: 10.5)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            ExpiryBadge(secret: secret)
            Image(systemName: "link").font(.system(size: 11)).foregroundStyle(.secondary).opacity(hover ? 1 : 0)
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(hover ? Color.primary.opacity(0.07) : .clear))
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture { Task { await store.pick(secret.name, value: Store.shiftDown) } }
        .help("Click copies the reference, ⇧-click the value")
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Copy the reference")
        .accessibilityAction { store.copyReference(secret.name) }
        .contextMenu {
            Button("Copy Reference secret:\(secret.name)") { store.copyReference(secret.name) }
            Button("Copy Value") { Task { await store.copy(secret.name) } }
            Button("Open in SecretBar") { Navigation.shared.select(secret.name) }
        }
    }
}
