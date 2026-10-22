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

    private var emptyText: String {
        switch nav.sidebar {
        case .expiring: return "Нет секретов со сроком в ближайшие 30 дней"
        case .project: return "В проекте нет секретов"
        default: return "Секретов пока нет. ⌘N — новый секрет"
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $nav.sidebar) {
                Section("Секреты") {
                    Label("Все", systemImage: "key.fill").badge(store.secrets.count).tag(SidebarItem.all)
                    Label("Истекают", systemImage: "clock.badge.exclamationmark")
                        .badge(store.expiredCount + store.soonCount).tag(SidebarItem.expiring)
                }
                Section("Проекты") {
                    ForEach(store.projects, id: \.name) { p in
                        Label { Text(p.name).lineLimit(1) } icon: { ProjectBadge(project: p.name, size: 16) }
                            .badge(p.count).tag(SidebarItem.project(p.name))
                    }
                }
                Section {
                    Label("Активность", systemImage: "waveform.path.ecg").tag(SidebarItem.activity)
                    Label("Настройки", systemImage: "gearshape").tag(SidebarItem.settings)
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
                            ContentUnavailableView("Выберите секрет", systemImage: "key.horizontal",
                                                   description: Text("↩ копирует значение, ⌘N — новый секрет"))
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
                    Button { Task { await store.lock() } } label: { Label("Заблокировать", systemImage: "lock.fill") }
                        .help("Заблокировать сейчас (⌘L)").keyboardShortcut("l")
                }
                Button { Task { await store.refreshAll() } } label: { Label("Обновить", systemImage: "arrow.clockwise") }
                    .keyboardShortcut("r")
                Button { sheet = .add } label: { Label("Новый секрет", systemImage: "plus") }
                    .help("Новый секрет (⌘N)").keyboardShortcut("n")
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
        .alert("Удалить \(deleting?.name ?? "")?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Удалить", role: .destructive) {
                if let d = deleting { Task { if await store.delete(d) { nav.selection = nil } } }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Восстановить можно только из резервной копии. Ссылки secret:\(deleting?.name ?? "") перестанут работать.")
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
    var emptyText = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Поиск", text: $query).textFieldStyle(.plain).focused($searchFocused)
                    .accessibilityLabel("Поиск по имени и комментарию")
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }.buttonStyle(.plain)
                        .accessibilityLabel("Очистить поиск")
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
                        ContentUnavailableView("Пусто", systemImage: "tray", description: Text(emptyText))
                    } else {
                        ContentUnavailableView("Ничего не найдено", systemImage: "magnifyingglass",
                                               description: Text("Поиск идёт по имени и комментарию, в любой раскладке"))
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
                Text(secret.comment.isEmpty ? "без комментария" : secret.comment)
                    .font(.system(size: 11)).foregroundStyle(secret.comment.isEmpty ? .tertiary : .secondary).lineLimit(1)
            }
            Spacer(minLength: 2)
            if hasRefs { Image(systemName: "link").font(.system(size: 9)).foregroundStyle(.tertiary).help("Есть ссылки в .env") }
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
        Button { Task { await store.copy(secret.name) } } label: { Label("Копировать значение", systemImage: "doc.on.doc") }
        Button { store.copyReference(secret.name) } label: { Label("Копировать ссылку secret:\(secret.name)", systemImage: "link") }
        Divider()
        Button { sheet = .edit(secret) } label: { Label("Изменить…", systemImage: "pencil") }
        Button { sheet = .rename(secret) } label: { Label("Переименовать…", systemImage: "character.cursor.ibeam") }
        Divider()
        Button(role: .destructive) { deleting = secret } label: { Label("Удалить…", systemImage: "trash") }
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
                        Label("Скопировать значение", systemImage: "doc.on.doc.fill").frame(minWidth: 170)
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    Button { store.copyReference(secret.name) } label: { Label("Ссылка", systemImage: "link") }
                        .controlSize(.large)
                        .help("Скопировать secret:\(secret.name) для .env")
                    Menu {
                        Button("Изменить…") { sheet = .edit(secret) }
                        Button("Переименовать…") { sheet = .rename(secret) }
                        Divider()
                        Button("Удалить…", role: .destructive) { deleting = secret }
                    } label: { Image(systemName: "ellipsis") }
                        .menuIndicator(.hidden).fixedSize().controlSize(.large)
                        .accessibilityLabel("Действия").help("Изменить, переименовать, удалить")
                }

                CardSection(title: "Комментарий", symbol: "text.alignleft") {
                    Text(secret.comment.isEmpty ? "Нет комментария. Добавьте: что это и где используется — так секрет поймёт и агент." : secret.comment)
                        .font(.system(size: 13))
                        .foregroundStyle(secret.comment.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }

                CardSection(title: "Срок", symbol: "calendar") {
                    if let d = secret.daysLeft() {
                        HStack(spacing: 8) {
                            Text(secret.expiry).font(.system(size: 13, weight: .medium, design: .monospaced))
                            ExpiryBadge(secret: secret)
                            Text(d < 0 ? "истёк \(-d) дн назад" : "через \(d) дн").font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Без срока").font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                }

                CardSection(title: "Где используется", symbol: "link") {
                    let refs = store.references[secret.name] ?? []
                    if refs.isEmpty {
                        Text("Ссылок secret:\(secret.name) в .env проектов нет.").font(.system(size: 12.5)).foregroundStyle(.secondary)
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
                                .help("Показать в Finder")
                            }
                        }
                    }
                }

                CardSection(title: "Как использовать", symbol: "terminal") {
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
    let title: String
    let symbol: String
    @ViewBuilder let content: Content
    init(title: String, symbol: String, @ViewBuilder content: () -> Content) { self.title = title; self.symbol = symbol; self.content = content() }
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
                .accessibilityLabel(copied ? "Скопировано" : "Скопировать строку").help("Скопировать строку")
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
                    Text(editing == nil ? "Новый секрет" : "Изменить").font(.system(size: 15, weight: .semibold))
                    if let e = editing { Text(e.name).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary) }
                }
            }
            .padding(20)
            Form {
                if editing == nil {
                    TextField("Имя", text: $name, prompt: Text("PROJECT_WHAT"))
                        .font(.system(size: 12.5, design: .monospaced))
                    if !name.isEmpty && !nameOK {
                        Text(nameTaken ? "Такое имя уже есть" : "Латиница, цифры, _ . -; первая — буква или _")
                            .font(.system(size: 11)).foregroundStyle(.red)
                    }
                }
                TextField("Комментарий", text: $comment, prompt: Text("проект: что это и где используется"), axis: .vertical)
                    .lineLimit(2...5)
                Toggle("Срок действия", isOn: $hasExpiry)
                if hasExpiry { DatePicker("Истекает", selection: $expiry, displayedComponents: .date) }
                if editing == nil {
                    Picker("Значение", selection: $generate) {
                        Text("Ввести").tag(false)
                        Text("Сгенерировать").tag(true)
                    }
                    .pickerStyle(.segmented)
                }
                if generate && editing == nil {
                    LabeledContent("Длина") {
                        HStack { Slider(value: $length, in: 8...128, step: 1); Text("\(Int(length))").monospacedDigit().frame(width: 32) }
                    }
                    Picker("Символы", selection: $charset) {
                        Text("Буквы и цифры").tag("alnum")
                        Text("Со спецсимволами").tag("symbols")
                        Text("Hex").tag("hex")
                    }
                    Text("Значение не увидит никто, даже вы: копируйте его из списка.").font(.system(size: 11)).foregroundStyle(.secondary)
                } else {
                    SecureField(editing == nil ? "Значение" : "Новое значение", text: $value,
                                prompt: Text(editing == nil ? "скрытый ввод" : "пусто — оставить прежнее"))
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            HStack {
                Spacer()
                Button("Отмена") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(editing == nil ? "Сохранить" : "Применить") { Task { await save() } }
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
            Text("Переименовать").font(.system(size: 15, weight: .semibold))
            Text(secret.name).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
            TextField("Новое имя", text: $name).font(.system(size: 12.5, design: .monospaced)).textFieldStyle(.roundedBorder)
            let refs = store.references[secret.name] ?? []
            Label(refs.isEmpty ? "Ссылок secret:\(secret.name) в .env не найдено." : "Ссылки в \(refs.count) файлах .env надо поправить самим.",
                  systemImage: refs.isEmpty ? "checkmark.circle" : "exclamationmark.triangle")
                .font(.system(size: 11.5)).foregroundStyle(refs.isEmpty ? Color.secondary : Color.orange)
            HStack {
                Spacer()
                Button("Отмена") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Переименовать") {
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
                ContentUnavailableView("Обращений нет", systemImage: "waveform.path.ecg")
            } else {
                List(store.activity) { e in ActivityRow(entry: e) }
                    .listStyle(.inset)
            }
        }
        .navigationTitle("Активность")
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
            let w = ["agent": "Агент", "shortcuts": "Spotlight или Shortcuts", "secretbar": "Вы · SecretBar"][who] ?? "Вы"
            return "\(w) · \(Self.operations[op] ?? op)\(detail.isEmpty ? "" : " · \(detail)")"
        case .touchID(let r, _):
            return r == "asked" ? "Touch ID спрошен" : r == "confirmed" ? "Touch ID подтверждён" : "Touch ID отклонён"
        }
    }

    private var subtitle: String {
        switch entry.kind {
        case .access(_, _, let names, _): return names
        case .touchID(_, let d): return Self.russian(d)
        }
    }

    // Operations of the access log of `secret`.
    static let operations = ["run": "запуск", "get": "чтение", "copy": "копирование", "export": "резервная копия",
                             "restore": "восстановление", "migrate": "переезд", "gh": "отправка в GitHub"]

    // The agent log is in English: "use A B for sh", "confirmed after 0.7s", "refused after 3.1s".
    static func russian(_ d: String) -> String {
        if d.hasPrefix("use "), let r = d.range(of: " for ", options: .backwards) {
            return "для \(d[r.upperBound...]): \(d[d.index(d.startIndex, offsetBy: 4)..<r.lowerBound])"
        }
        if let r = d.range(of: " after ") {
            let t = d[r.upperBound...].replacingOccurrences(of: "s", with: " с").replacingOccurrences(of: ".", with: ",")
            return (d.hasPrefix("confirmed") ? "за " : "через ") + t
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
                Picker("Без вопроса после Touch ID", selection: $minutes) {
                    Text("Спрашивать каждый раз").tag(0)
                    Text("5 минут простоя").tag(5)
                    Text("15 минут простоя").tag(15)
                    Text("30 минут простоя").tag(30)
                    Text("60 минут простоя").tag(60)
                }
                .onChange(of: minutes) { _, m in
                    guard m * 60 != (store.status.idle ?? -1) else { return }
                    Task { await store.setGrace(m * 60) }
                }
                LabeledContent("Сейчас", value: store.statusLine)
            } header: {
                Label("Touch ID", systemImage: "touchid")
            } footer: {
                Text("Простой — время без обращений к секретам. Предел — 8 часов. Блокировка экрана и сон заканчивают время сразу. Изменение подтверждается Touch ID.")
            }

            Section {
                Toggle("Показывать в Spotlight", isOn: $store.spotlight)
                LabeledContent("Быстрый поиск", value: store.hotKeyOK ? "⌥⌘S" : "⌥⌘S занята другим приложением")
                Toggle("Запускать при входе в систему", isOn: Binding(get: { store.launchAtLogin }, set: { store.toggleLaunchAtLogin($0) }))
            } header: {
                Label("Поиск и запуск", systemImage: "magnifyingglass")
            } footer: {
                Text("В индекс Spotlight попадают только имена и комментарии, значения — никогда. Выключение стирает индекс.")
            }

            Section {
                if let url = exportURL {
                    LabeledContent("Файл", value: url.path)
                    SecureField("Пароль копии", text: $pw1, prompt: Text("12 символов или больше"))
                    SecureField("Повторите пароль", text: $pw2)
                    HStack {
                        Button("Отмена") { exportURL = nil; pw1 = ""; pw2 = "" }
                        Spacer()
                        Button("Сохранить копию") {
                            Task {
                                if await store.export(to: url, password: pw1) { exportURL = nil }
                                pw1 = ""; pw2 = ""
                            }
                        }
                        .buttonStyle(.borderedProminent).disabled(pw1.count < 12 || pw1 != pw2)
                    }
                } else {
                    Button("Сохранить резервную копию…") { chooseFile() }
                }
            } header: {
                Label("Резервная копия", systemImage: "externaldrive.badge.checkmark")
            } footer: {
                Text("Все секреты в одном файле, AES-256 под отдельным паролем. Записи привязаны к этому Mac: на другой Mac их переносит только копия.")
            }

            Section {
                LabeledContent("Хранилище", value: store.storeOn ? "Secure Enclave" : "файловый keychain")
                LabeledContent("Секретов", value: "\(store.secrets.count)")
                LabeledContent("Команда", value: Paths.secret)
                HStack {
                    Button("Журнал агента") { NSWorkspace.shared.open(URL(fileURLWithPath: Paths.agentLog)) }
                    Button("Папка проекта") { NSWorkspace.shared.open(URL(fileURLWithPath: Paths.root)) }
                }
            } header: {
                Label("О программе", systemImage: "info.circle")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Настройки")
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
