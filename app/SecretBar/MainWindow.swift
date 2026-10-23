// The main window (014): projects on the left, the list, the card of a secret; activity and
// settings. Forms are sheets of this window, so the Touch ID window does not close them.
import AppKit
import SwiftUI

enum SidebarItem: Hashable {
    case all, expiring, project(String), activity, settings
}

enum Sheet: Identifiable {
    case add, edit(Secret), rename(Secret)
    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let s): return "edit." + s.name
        case .rename(let s): return "rename." + s.name
        }
    }
}

struct MainWindow: View {
    @EnvironmentObject var store: Store
    @ObservedObject var nav = Navigation.shared
    @State private var query = ""
    @State private var sheet: Sheet?
    @State private var deleting: Secret?

    private func takeAddRequest() {
        guard nav.addPending else { return }
        nav.addPending = false
        if sheet == nil { sheet = .add }
    }

    private var listed: [Secret] {
        let base: [Secret]
        switch nav.sidebar {
        case .all: base = store.secrets
        case .expiring: base = store.secrets.filter { ($0.daysLeft() ?? 99) <= 30 }.sorted { ($0.daysLeft() ?? 0) < ($1.daysLeft() ?? 0) }
        case .project(let p): base = store.secrets.filter { $0.project == p }
        default: base = []
        }
        return store.filter(query, in: base)
    }

    // The card shows only a secret of the current list (015).
    private var selected: Secret? { listed.first { $0.name == nav.selection } }

    private var emptyText: LocalizedStringKey {
        switch nav.sidebar {
        case .expiring: return "No secrets expire in the next 30 days"
        case .project: return "No secrets in this project"
        default: return "No secrets yet. ⌘N adds one"
        }
    }

    private func projectRow(_ name: String, _ count: Int) -> some View {
        Label { Text(verbatim: name).lineLimit(1) } icon: { ProjectBadge(project: name, size: 16) }
            .badge(count).tag(SidebarItem.project(name))
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $nav.sidebar) {
                Section("Secrets") {
                    Label("All", systemImage: "key.fill").badge(store.secrets.count).tag(SidebarItem.all)
                    Label("Expiring", systemImage: "clock.badge.exclamationmark")
                        .badge(store.expiredCount + store.soonCount).tag(SidebarItem.expiring)
                }
                Section("Projects") {
                    ForEach(store.projects, id: \.name) { p in projectRow(p.name, p.count) }
                }
                Section {
                    Label("Activity", systemImage: "waveform.path.ecg").tag(SidebarItem.activity)
                    Label("Settings", systemImage: "gearshape").tag(SidebarItem.settings)
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            switch nav.sidebar {
            case .activity: ActivityView()
            case .settings: SettingsView()
            default:
                HStack(spacing: 0) {
                    SecretList(secrets: listed, query: $query, sheet: $sheet, deleting: $deleting, emptyText: emptyText)
                        .frame(width: 340)
                    Divider()
                    Group {
                        if let s = selected {
                            SecretCard(secret: s, sheet: $sheet, deleting: $deleting).id(s.name)
                        } else {
                            ContentUnavailableView("Select a Secret", systemImage: "key.horizontal",
                                                   description: Text("↩ copies the value, ⌘N adds a secret"))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) { StatusPill() }
            ToolbarItemGroup(placement: .primaryAction) {
                if store.busy != nil { ProgressView().controlSize(.small) }
                if store.isOpen {
                    Button { Task { await store.lock() } } label: { Label("Lock", systemImage: "lock.fill") }
                        .help("Lock now (⌘L)").keyboardShortcut("l")
                }
                Button { Task { await store.refreshAll() } } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                    .keyboardShortcut("r")
                Button { sheet = .add } label: { Label("New Secret", systemImage: "plus") }
                    .help("New secret (⌘N)").keyboardShortcut("n")
            }
        }
        .navigationTitle("SecretBar")
        .onAppear(perform: takeAddRequest)
        .onChange(of: nav.addPending) { takeAddRequest() }
        .sheet(item: $sheet) { s in
            switch s {
            case .add: EditorSheet(editing: nil)
            case .edit(let x): EditorSheet(editing: x)
            case .rename(let x): RenameSheet(secret: x)
            }
        }
        .alert("Delete \(deleting?.name ?? "")?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Delete", role: .destructive) {
                if let d = deleting { Task { if await store.delete(d) { nav.selection = nil } } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Only a backup can restore it. References secret:\(deleting?.name ?? "") will stop working.")
        }
        .overlay(alignment: .bottom) {
            if let t = store.toast { ToastView(toast: t).padding(.bottom, 18).transition(.move(edge: .bottom).combined(with: .opacity)) }
        }
        .frame(minWidth: 900, minHeight: 560)
        .onAppear { store.visibleWindows += 1; Task { await store.refreshAll() } }
        .onDisappear { store.visibleWindows -= 1 }
    }
}

// MARK: list

struct SecretList: View {
    @EnvironmentObject var store: Store
    @ObservedObject var nav = Navigation.shared
    let secrets: [Secret]
    @Binding var query: String
    @Binding var sheet: Sheet?
    @Binding var deleting: Secret?
    var emptyText: LocalizedStringKey = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search", text: $query).textFieldStyle(.plain).focused($searchFocused)
                    .accessibilityLabel("Search by name and comment")
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }.buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.primary.opacity(0.06)))
            .padding(10)
            .background { Button("") { searchFocused = true }.keyboardShortcut("f").hidden() }

            if secrets.isEmpty {
                // fills the column, so the search field stays at the top (015)
                Group {
                    if query.isEmpty {
                        ContentUnavailableView("Empty", systemImage: "tray", description: Text(emptyText))
                    } else {
                        ContentUnavailableView("Nothing Found", systemImage: "magnifyingglass",
                                               description: Text("Search looks at the name and the comment, in any keyboard layout"))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $nav.selection) {
                    ForEach(secrets) { s in
                        ListRow(secret: s, hasRefs: !(store.references[s.name] ?? []).isEmpty).tag(s.name)
                            .contextMenu { SecretMenu(secret: s, sheet: $sheet, deleting: $deleting) }
                    }
                }
                .listStyle(.inset)
                .onKeyPress(.return) {
                    guard let n = nav.selection else { return .ignored }
                    Task { await store.copy(n) }
                    return .handled
                }
            }
        }
    }
}

struct ListRow: View {
    let secret: Secret
    let hasRefs: Bool
    var body: some View {
        HStack(spacing: 10) {
            ProjectBadge(project: secret.project, size: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(secret.name).font(.system(size: 12, weight: .semibold, design: .monospaced)).lineLimit(1).truncationMode(.middle)
                Text(secret.comment.isEmpty ? String(localized: "no comment") : secret.comment)
                    .font(.system(size: 11)).foregroundStyle(secret.comment.isEmpty ? .tertiary : .secondary).lineLimit(1)
            }
            Spacer(minLength: 2)
            if hasRefs { Image(systemName: "link").font(.system(size: 9)).foregroundStyle(.tertiary).help("Referenced in .env files") }
            ExpiryBadge(secret: secret)
        }
        .padding(.vertical, 3)
    }
}

struct SecretMenu: View {
    @EnvironmentObject var store: Store
    let secret: Secret
    @Binding var sheet: Sheet?
    @Binding var deleting: Secret?
    var body: some View {
        Button { Task { await store.copy(secret.name) } } label: { Label("Copy Value", systemImage: "doc.on.doc") }
        Button { store.copyReference(secret.name) } label: { Label("Copy Reference secret:\(secret.name)", systemImage: "link") }
        Divider()
        Button { sheet = .edit(secret) } label: { Label("Edit…", systemImage: "pencil") }
        Button { sheet = .rename(secret) } label: { Label("Rename…", systemImage: "character.cursor.ibeam") }
        Divider()
        Button(role: .destructive) { deleting = secret } label: { Label("Delete…", systemImage: "trash") }
    }
}

// MARK: card

struct SecretCard: View {
    @EnvironmentObject var store: Store
    let secret: Secret
    @Binding var sheet: Sheet?
    @Binding var deleting: Secret?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .center, spacing: 16) {
                    ProjectBadge(project: secret.project, size: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(secret.name)
                            .font(.system(size: 19, weight: .bold, design: .monospaced))
                            .textSelection(.enabled)
                            .lineLimit(2)
                        Text(secret.project).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 10) {
                    Button { Task { await store.copy(secret.name) } } label: {
                        Label("Copy Value", systemImage: "doc.on.doc.fill").frame(minWidth: 170)
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    Button { store.copyReference(secret.name) } label: { Label("Reference", systemImage: "link") }
                        .controlSize(.large)
                        .help("Copy secret:\(secret.name) for .env")
                    Menu {
                        Button("Edit…") { sheet = .edit(secret) }
                        Button("Rename…") { sheet = .rename(secret) }
                        Divider()
                        Button("Delete…", role: .destructive) { deleting = secret }
                    } label: { Image(systemName: "ellipsis") }
                        .menuIndicator(.hidden).fixedSize().controlSize(.large)
                        .accessibilityLabel("Actions").help("Edit, rename, delete")
                }

                CardSection(title: "Comment", symbol: "text.alignleft") {
                    Text(secret.comment.isEmpty ? String(localized: "No comment. Add what it is and where it is used, so that the agent understands it too.") : secret.comment)
                        .font(.system(size: 13))
                        .foregroundStyle(secret.comment.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }

                CardSection(title: "Expiry", symbol: "calendar") {
                    if let d = secret.daysLeft() {
                        HStack(spacing: 8) {
                            Text(secret.expiry).font(.system(size: 13, weight: .medium, design: .monospaced))
                            ExpiryBadge(secret: secret)
                            Text(d < 0 ? "expired \(-d) d ago" : "in \(d) d").font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                    } else {
                        Text("No expiry").font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                }

                CardSection(title: "Where It Is Used", symbol: "link") {
                    let refs = store.references[secret.name] ?? []
                    if refs.isEmpty {
                        Text("No .env file of a project refers to secret:\(secret.name).").font(.system(size: 12.5)).foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(refs, id: \.self) { r in
                                Button {
                                    let path = r.replacingOccurrences(of: "~/", with: Paths.home + "/", options: .anchored)
                                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "doc.text").foregroundStyle(.secondary)
                                        Text(r).font(.system(size: 12, design: .monospaced))
                                        Image(systemName: "arrow.up.forward").font(.system(size: 9)).foregroundStyle(.tertiary)
                                    }
                                }
                                .buttonStyle(.plain)
                                .help("Show in Finder")
                            }
                        }
                    }
                }

                CardSection(title: "How to Use", symbol: "terminal") {
                    VStack(alignment: .leading, spacing: 6) {
                        CodeLine("secret run --mask \(secret.name) -- cmd")
                        CodeLine("\(envKey)=secret:\(secret.name)")
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 640, alignment: .leading)
        }
    }

    // The key in .env: the key of an existing reference, else the name without the project
    // prefix (SHOP_DB_PASSWORD → PASSWORD).
    private var envKey: String {
        if let k = store.envKeys[secret.name] { return k }
        let prefix = secret.project.uppercased().replacingOccurrences(of: "-", with: "_").replacingOccurrences(of: " ", with: "_") + "_"
        if secret.name.hasPrefix(prefix), secret.name.count > prefix.count { return String(secret.name.dropFirst(prefix.count)) }
        return secret.name
    }
}

struct CardSection<Content: View>: View {
    let title: LocalizedStringKey
    let symbol: String
    @ViewBuilder let content: Content
    init(title: LocalizedStringKey, symbol: String, @ViewBuilder content: () -> Content) { self.title = title; self.symbol = symbol; self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).textCase(.uppercase)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.primary.opacity(0.06)))
    }
}

struct CodeLine: View {
    let text: String
    @State private var copied = false
    init(_ text: String) { self.text = text }
    var body: some View {
        HStack {
            Text(text).font(.system(size: 12, design: .monospaced)).textSelection(.enabled).lineLimit(1).truncationMode(.middle)
            Spacer()
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                copied = true
                Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
            } label: { Image(systemName: copied ? "checkmark" : "doc.on.doc").font(.system(size: 11)) }
                .buttonStyle(.borderless)
                .accessibilityLabel(copied ? Text("Copied") : Text("Copy line")).help("Copy line")
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.06)))
    }
}

// MARK: sheets

struct EditorSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let editing: Secret?
    @State private var name = ""
    @State private var comment = ""
    @State private var hasExpiry = false
    @State private var expiry = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var generate = false
    @State private var value = ""
    @State private var length = 32.0
    @State private var charset = "alnum"
    @State private var saving = false

    private var expiryText: String {
        guard hasExpiry else { return "" }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: expiry)
    }
    private var nameTaken: Bool { store.secrets.contains { $0.name == name } }
    private var nameOK: Bool { editing != nil || (Parse.validName(name) && !nameTaken) }
    private var canSave: Bool { nameOK && !saving && (editing != nil || generate || !value.isEmpty) && !value.contains("\n") }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                ProjectBadge(project: editing?.project ?? Parse.project(comment), size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(editing == nil ? "New Secret" : "Edit").font(.system(size: 15, weight: .semibold))
                    if let e = editing { Text(e.name).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary) }
                }
            }
            .padding(20)
            Form {
                if editing == nil {
                    TextField("Name", text: $name, prompt: Text("PROJECT_WHAT"))
                        .font(.system(size: 12.5, design: .monospaced))
                    if !name.isEmpty && !nameOK {
                        Text(nameTaken ? "This name already exists" : "Latin letters, digits, _ . -; the first is a letter or _")
                            .font(.system(size: 11)).foregroundStyle(.red)
                    }
                }
                TextField("Comment", text: $comment, prompt: Text("project: what it is and where it is used"), axis: .vertical)
                    .lineLimit(2...5)
                Toggle("Expiry date", isOn: $hasExpiry)
                if hasExpiry { DatePicker("Expires", selection: $expiry, displayedComponents: .date) }
                if editing == nil {
                    Picker("Value", selection: $generate) {
                        Text("Type").tag(false)
                        Text("Generate").tag(true)
                    }
                    .pickerStyle(.segmented)
                }
                if generate && editing == nil {
                    LabeledContent("Length") {
                        HStack { Slider(value: $length, in: 8...128, step: 1); Text("\(Int(length))").monospacedDigit().frame(width: 32) }
                    }
                    Picker("Characters", selection: $charset) {
                        Text("Letters and digits").tag("alnum")
                        Text("With symbols").tag("symbols")
                        Text("Hex").tag("hex")
                    }
                    Text("Nobody sees the value, not even you: copy it from the list.").font(.system(size: 11)).foregroundStyle(.secondary)
                } else {
                    SecureField(editing == nil ? "Value" : "New value", text: $value,
                                prompt: Text(editing == nil ? "hidden input" : "empty keeps the current value"))
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(editing == nil ? "Save" : "Apply") { Task { await save() } }
                    .keyboardShortcut(.defaultAction).disabled(!canSave).buttonStyle(.borderedProminent)
            }
            .padding(20)
        }
        .frame(width: 480)
        .onAppear {
            if let s = editing {
                comment = s.comment
                if let d = Parse.day(s.expiry) { hasExpiry = true; expiry = d }
            }
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        let ok: Bool
        if let s = editing {
            ok = await store.update(s, comment: comment, expiry: expiryText, newValue: value)
        } else if generate {
            ok = await store.generate(name: name, comment: comment, expiry: expiryText, length: Int(length), charset: charset)
        } else {
            ok = await store.add(name: name, comment: comment, expiry: expiryText, value: value)
        }
        value = ""
        if ok {
            if editing == nil {
                Navigation.shared.selection = name
                store.copyReference(name, saved: true)
            }
            dismiss()
        }
    }
}

struct RenameSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let secret: Secret
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Rename").font(.system(size: 15, weight: .semibold))
            Text(secret.name).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
            TextField("New name", text: $name).font(.system(size: 12.5, design: .monospaced)).textFieldStyle(.roundedBorder)
            let refs = store.references[secret.name] ?? []
            Label(refs.isEmpty ? "No .env file refers to secret:\(secret.name)." : "Fix the references in \(refs.count) .env files yourself.",
                  systemImage: refs.isEmpty ? "checkmark.circle" : "exclamationmark.triangle")
                .font(.system(size: 11.5)).foregroundStyle(refs.isEmpty ? Color.secondary : Color.orange)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Rename") {
                    Task {
                        if await store.rename(secret, to: name) { Navigation.shared.selection = name; dismiss() }
                    }
                }
                .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
                .disabled(!Parse.validName(name) || name == secret.name || store.secrets.contains { $0.name == name })
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear { name = secret.name }
    }
}

// MARK: activity

struct ActivityView: View {
    @EnvironmentObject var store: Store
    let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if store.activity.isEmpty {
                ContentUnavailableView("No Activity", systemImage: "waveform.path.ecg")
            } else {
                List(store.activity) { e in ActivityRow(entry: e) }
                    .listStyle(.inset)
            }
        }
        .navigationTitle("Activity")
        .onAppear { store.refreshActivity() }
        .onReceive(timer) { _ in store.refreshActivity() }
    }
}

struct ActivityRow: View {
    let entry: ActivityEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            icon
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title).font(.system(size: 12.5, weight: .semibold))
                    Spacer()
                    if let t = entry.time {
                        Text(t, style: .relative).font(.system(size: 11)).foregroundStyle(.tertiary)
                    }
                }
                Text(subtitle).font(.system(size: 11.5, design: isAccess ? .monospaced : .default)).foregroundStyle(.secondary).lineLimit(3)
            }
        }
        .padding(.vertical, 4)
    }

    private var isAccess: Bool { if case .access = entry.kind { return true } else { return false } }

    private var icon: some View {
        let (symbol, color): (String, Color) = {
            switch entry.kind {
            case .access(_, let who, _, _):
                switch who {
                case "agent": return ("cpu", .purple)
                case "shortcuts": return ("square.stack.3d.up.fill", .pink)
                case "secretbar": return ("lock.rectangle.stack.fill", .indigo)
                default: return ("person.fill", .blue)
                }
            case .touchID(let r, _): return ("touchid", r == "confirmed" ? .green : r == "refused" ? .red : .orange)
            }
        }()
        return Image(systemName: symbol)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 28, height: 28)
            .background(Circle().fill(color.opacity(0.13)))
    }

    private var title: String {
        switch entry.kind {
        case .access(let op, let who, _, let detail):
            let w = ["agent": String(localized: "Agent"), "shortcuts": String(localized: "Spotlight or Shortcuts"), "secretbar": String(localized: "You · SecretBar")][who] ?? String(localized: "You")
            return "\(w) · \(Self.operations[op] ?? op)\(detail.isEmpty ? "" : " · \(detail)")"
        case .touchID(let r, _):
            return r == "asked" ? String(localized: "Touch ID asked") : r == "confirmed" ? String(localized: "Touch ID confirmed") : String(localized: "Touch ID refused")
        }
    }

    private var subtitle: String {
        switch entry.kind {
        case .access(_, _, let names, _): return names
        case .touchID(_, let d): return Self.describe(d)
        }
    }

    // Operations of the access log of `secret`.
    static let operations = ["run": String(localized: "run"), "get": String(localized: "read"), "copy": String(localized: "copy"),
                             "export": String(localized: "backup"), "restore": String(localized: "restore"),
                             "migrate": String(localized: "migration"), "gh": String(localized: "push to GitHub")]

    // The agent log is in English: "use A B for sh", "confirmed after 0.7s", "refused after 3.1s".
    static func describe(_ d: String) -> String {
        if d.hasPrefix("use "), let r = d.range(of: " for ", options: .backwards) {
            let program = String(d[r.upperBound...]), names = String(d[d.index(d.startIndex, offsetBy: 4)..<r.lowerBound])
            return String(localized: "for \(program): \(names)")
        }
        if let r = d.range(of: " after "), let s = Double(d[r.upperBound...].dropLast()) {
            let t = s.formatted(.number.precision(.fractionLength(1)))
            return d.hasPrefix("confirmed") ? String(localized: "in \(t) s") : String(localized: "after \(t) s")
        }
        return d
    }
}

// MARK: settings

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @State private var minutes = 30
    @State private var exportURL: URL?
    @State private var pw1 = ""
    @State private var pw2 = ""

    var body: some View {
        Form {
            Section {
                Picker("No question after Touch ID", selection: $minutes) {
                    Text("Ask every time").tag(0)
                    Text("5 idle minutes").tag(5)
                    Text("15 idle minutes").tag(15)
                    Text("30 idle minutes").tag(30)
                    Text("60 idle minutes").tag(60)
                }
                .onChange(of: minutes) { _, m in
                    guard m * 60 != (store.status.idle ?? -1) else { return }
                    Task { await store.setGrace(m * 60) }
                }
                LabeledContent("Now", value: store.statusLine)
            } header: {
                Label("Touch ID", systemImage: "touchid")
            } footer: {
                Text("Idle time is the time without requests for secrets. The limit is 8 hours. A screen lock or sleep ends it at once. A change needs Touch ID.")
            }

            Section {
                Toggle("Show in Spotlight", isOn: $store.spotlight)
                LabeledContent("Quick search", value: store.hotKeyOK ? "⌥⌘S" : String(localized: "⌥⌘S is used by another app"))
                Toggle("Open at login", isOn: Binding(get: { store.launchAtLogin }, set: { store.toggleLaunchAtLogin($0) }))
            } header: {
                Label("Search and Launch", systemImage: "magnifyingglass")
            } footer: {
                Text("The Spotlight index gets only names and comments, never values. Turning it off erases the index.")
            }

            Section {
                if let url = exportURL {
                    LabeledContent("File", value: url.path)
                    SecureField("Backup password", text: $pw1, prompt: Text("12 characters or more"))
                    SecureField("Repeat the password", text: $pw2)
                    HStack {
                        Button("Cancel") { exportURL = nil; pw1 = ""; pw2 = "" }
                        Spacer()
                        Button("Save Backup") {
                            Task {
                                if await store.export(to: url, password: pw1) { exportURL = nil }
                                pw1 = ""; pw2 = ""
                            }
                        }
                        .buttonStyle(.borderedProminent).disabled(pw1.count < 12 || pw1 != pw2)
                    }
                } else {
                    Button("Save a Backup…") { chooseFile() }
                }
            } header: {
                Label("Backup", systemImage: "externaldrive.badge.checkmark")
            } footer: {
                Text("All secrets in one file, AES-256 under a separate password. The items are bound to this Mac: only a backup moves them to another Mac.")
            }

            Section {
                LabeledContent("Store", value: store.storeOn ? "Secure Enclave" : String(localized: "file keychain"))
                LabeledContent("Secrets", value: "\(store.secrets.count)")
                LabeledContent("Command", value: Paths.secret)
                HStack {
                    Button("Agent Log") { NSWorkspace.shared.open(URL(fileURLWithPath: Paths.agentLog)) }
                    Button("Project Folder") { NSWorkspace.shared.open(URL(fileURLWithPath: Paths.root)) }
                }
            } header: {
                Label("About", systemImage: "info.circle")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .onAppear { if let i = store.status.idle { minutes = i / 60 } }
    }

    private func chooseFile() {
        let panel = NSSavePanel()
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        panel.nameFieldStringValue = "secrets-\(f.string(from: Date())).bak"
        panel.directoryURL = URL(fileURLWithPath: Paths.home)
        if panel.runModal() == .OK { exportURL = panel.url }
    }
}
