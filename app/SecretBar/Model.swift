// Model of SecretBar: it runs `bin/secret` and the store helper and parses their output.
// The app never calls the keychain itself and never reads a value into its memory (constitution
// 1.4.0, III): a value goes to the clipboard through `secret copy` (the helper marks it concealed)
// and in through stdin of `secret set`.
import AppIntents
import CoreSpotlight
import Foundation
import ServiceManagement
import SwiftUI
import UserNotifications

// MARK: data

struct Secret: Identifiable, Hashable {
    let name: String
    let comment: String
    let expiry: String  // YYYY-MM-DD or empty
    var id: String { name }

    // Days from today to the expiry date; negative when it passed; nil without a date.
    func daysLeft(today: Date = Date()) -> Int? {
        guard let d = Parse.day(expiry) else { return nil }
        let cal = Calendar(identifier: .gregorian)
        return cal.dateComponents([.day], from: cal.startOfDay(for: today), to: d).day
    }

    // The project: the text before ":" of the comment ("shop: password ..."), the convention of
    // the agent rules. Without it: Parse.other.
    var project: String { Parse.project(comment) }
}

enum ActivityKind: Hashable {
    case access(op: String, who: String, names: String, detail: String)
    case touchID(result: String, detail: String)  // asked, confirmed, refused
}

struct ActivityEntry: Identifiable, Hashable {
    let id: String
    let time: Date?
    let kind: ActivityKind
}

enum Grace: Equatable {
    case off
    case active(left: Int, idle: Int, limit: Int)
}

struct Status: Equatable {
    var grace: Grace = .off
    var idle: Int?
}

struct CommandResult {
    let status: Int32
    let out: String
    let err: String
    var ok: Bool { status == 0 }
    // The last line of stderr without the "secret: " prefix: the message for the user.
    var message: String {
        let line = err.split(separator: "\n").last.map(String.init) ?? out.split(separator: "\n").last.map(String.init) ?? ""
        return line.replacingOccurrences(of: "secret: ", with: "").replacingOccurrences(of: "secret-vault: ", with: "")
    }
}

// MARK: paths

// Where the command lives. ~/.local/bin/secret is a symlink into the repository (install.sh), so
// the repository root holds the helper and install.sh. SECRETBAR_ROOT overrides it.
enum Paths {
    static let home = NSHomeDirectory()
    static let root: String = {
        if let r = ProcessInfo.processInfo.environment["SECRETBAR_ROOT"], !r.isEmpty { return r }
        let link = URL(fileURLWithPath: home + "/.local/bin/secret").resolvingSymlinksInPath()
        return link.deletingLastPathComponent().deletingLastPathComponent().path
    }()
    static var secret: String { root + "/bin/secret" }
    // The helper of the Secure Enclave store (017, 018).
    static var store: String { root + "/build/secret-vault" }
    static var modeText: String {
        (try? String(contentsOfFile: mode, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    static let state = home + "/.local/state/secret"
    static var accessLog: String { state + "/access.log" }
    static var agentLog: String { state + "/agent.log" }
    static var mode: String { state + "/store" }
    // Where SecretBar looks for references secret:NAME in .env files: the setting projectsDir
    // (defaults write local.secretcli.bar projectsDir ~/code), else the home folder (022).
    static var projects: String {
        guard let p = UserDefaults.standard.string(forKey: "projectsDir"), !p.isEmpty else { return home }
        let full = (p as NSString).expandingTildeInPath
        return FileManager.default.fileExists(atPath: full) ? full : home
    }
}

// MARK: process

// Runs a command off the main thread. CLAUDECODE goes away: the app works for a human, so the
// access log marks it "human" and `run` does not force the mask.
// `via` goes to the access log of `secret` as the source: "secretbar" or "shortcuts" (014).
func runCommand(_ path: String, _ args: [String], input: Data? = nil, via: String = "secretbar") async -> CommandResult {
    await withCheckedContinuation { cont in
        DispatchQueue.global(qos: .userInitiated).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: path)
            p.arguments = args
            var env = ProcessInfo.processInfo.environment
            env.removeValue(forKey: "CLAUDECODE")
            env["SECRET_VIA"] = via
            env["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:" + (env["PATH"] ?? "")
            p.environment = env
            let out = Pipe(), err = Pipe(), inp = Pipe()
            p.standardOutput = out
            p.standardError = err
            p.standardInput = inp
            do { try p.run() } catch {
                cont.resume(returning: CommandResult(status: -1, out: "", err: "\(path): \(error.localizedDescription)"))
                return
            }
            if let d = input { inp.fileHandleForWriting.write(d) }
            try? inp.fileHandleForWriting.close()
            var e = Data()
            let group = DispatchGroup()
            group.enter()
            DispatchQueue.global().async { e = err.fileHandleForReading.readDataToEndOfFile(); group.leave() }
            let o = out.fileHandleForReading.readDataToEndOfFile()
            group.wait()
            p.waitUntilExit()
            cont.resume(returning: CommandResult(status: p.terminationStatus,
                                                 out: String(decoding: o, as: UTF8.self),
                                                 err: String(decoding: e, as: UTF8.self)))
        }
    }
}

// MARK: parsing (also checked by --selftest)

enum Parse {
    static func day(_ s: String) -> Date? {
        guard s.count == 10 else { return nil }
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)
    }

    // `secret-vault list`: NAME<TAB>COMMENT<TAB>EXPIRY, "-" for empty.
    static func list(_ text: String) -> [Secret] {
        text.split(separator: "\n").compactMap { line in
            let f = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard f.count == 3, !f[0].isEmpty else { return nil }
            return Secret(name: f[0], comment: f[1] == "-" ? "" : f[1], expiry: f[2] == "-" ? "" : f[2])
        }
    }

    // `secret-vault status`: "ok off grace=N" or "ok active LEFT IDLE LIMIT grace=N".
    static func status(_ text: String) -> Status? {
        let f = text.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ").map(String.init)
        guard f.first == "ok", let last = f.last else { return nil }
        var s = Status()
        if last.hasPrefix("grace=") { s.idle = Int(last.dropFirst(6)) }
        if f.count == 6, f[1] == "active", let l = Int(f[2]), let i = Int(f[3]), let m = Int(f[4]) {
            s.grace = .active(left: l, idle: i, limit: m)
        }
        return s
    }

    // Access log of `secret`: TIME<TAB>OP<TAB>WHO<TAB>NAMES<TAB>DETAIL. No values in it.
    static func access(_ text: String) -> [ActivityEntry] {
        let iso = ISO8601DateFormatter()
        return text.split(separator: "\n").enumerated().compactMap { i, line in
            let f = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard f.count >= 4 else { return nil }
            return ActivityEntry(id: "a\(i)", time: iso.date(from: f[0]),
                                 kind: .access(op: f[1], who: f[2], names: f[3], detail: f.count > 4 && f[4] != "-" ? f[4] : ""))
        }
    }

    // Agent log of the helper: "TIME pid=N touch id asked: REASON", "... touch id confirmed after 0.7s".
    static func touchID(_ text: String) -> [ActivityEntry] {
        let iso = ISO8601DateFormatter()
        return text.split(separator: "\n").enumerated().compactMap { i, line in
            let parts = line.split(separator: " ", maxSplits: 2).map(String.init)
            guard parts.count == 3, parts[2].hasPrefix("touch id ") else { return nil }
            let rest = String(parts[2].dropFirst(9))
            let result: String, detail: String
            if rest.hasPrefix("asked: ") { result = "asked"; detail = String(rest.dropFirst(7)) }
            else if rest.hasPrefix("confirmed") { result = "confirmed"; detail = rest }
            else if rest.hasPrefix("refused") { result = "refused"; detail = rest }
            else { return nil }
            return ActivityEntry(id: "t\(i)", time: iso.date(from: parts[0]), kind: .touchID(result: result, detail: detail))
        }
    }

    // Both logs, newest first.
    static func activity(access: String, agent: String, limit: Int) -> [ActivityEntry] {
        let all = Parse.access(access) + Parse.touchID(agent)
        return Array(all.sorted { ($0.time ?? .distantPast) > ($1.time ?? .distantPast) }.prefix(limit))
    }

    static let other = String(localized: "Other")

    static func project(_ comment: String) -> String {
        guard let r = comment.range(of: ":") else { return other }
        let p = comment[..<r.lowerBound].trimmingCharacters(in: .whitespaces)
        return p.isEmpty || p.count > 40 ? other : p
    }

    // References KEY=secret:NAME in the text of a dotenv file: (key, name).
    static func references(_ text: String) -> [(key: String, name: String)] {
        var out = [(key: String, name: String)]()
        for line in text.split(separator: "\n") {
            guard let r = line.range(of: "=secret:") else { continue }
            let name = line[r.upperBound...].prefix { $0.isLetter || $0.isNumber || "_.-".contains($0) }
            var key = line[..<r.lowerBound].trimmingCharacters(in: .whitespaces)
            if key.hasPrefix("export ") { key = String(key.dropFirst(7)).trimmingCharacters(in: .whitespaces) }
            // the key goes to the card and to the clipboard: a variable name only, else no key
            // (a .env of a cloned repo can hold any text before =secret:)
            // ASCII checked by hand: `$` of a regex also matches before a final \r or \n
            if !Parse.isVariableName(key) { key = "" }
            if !name.isEmpty { out.append((key, String(name))) }
        }
        return out
    }

    // A shell variable name: [A-Za-z_][A-Za-z0-9_]*, 1...64 ASCII characters.
    static func isVariableName(_ s: String) -> Bool {
        let u = Array(s.utf8)
        guard (1...64).contains(u.count), !(48...57).contains(u[0]) else { return false }
        return u.allSatisfy { (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 95 }
    }

    // The same keys in the other layout: ЙЦУКЕН ↔ QWERTY (Mac "Russian" and "ABC"). nil when the
    // query has letters of both layouts or none to change.
    private static let en = Array("`qwertyuiop[]asdfghjkl;'zxcvbnm,.")
    private static let ru = Array("ёйцукенгшщзхъфывапролджэячсмитьбю")
    private static let enToRu = Dictionary(uniqueKeysWithValues: zip(en, ru))
    private static let ruToEn = Dictionary(uniqueKeysWithValues: zip(ru, en))

    static func swapLayout(_ q: String) -> String? {
        let s = q.lowercased()
        let hasRu = s.contains { ruToEn[$0] != nil }
        let hasEn = s.contains { $0.isLetter && enToRu[$0] != nil }
        guard hasRu != hasEn else { return nil }
        let map = hasRu ? ruToEn : enToRu
        return String(s.map { map[$0] ?? $0 })
    }

    static func validName(_ n: String) -> Bool {
        n.range(of: "^[A-Za-z_][A-Za-z0-9_.-]*$", options: .regularExpression) != nil && !n.hasPrefix("__secret-cli.")
    }
}

// MARK: store

@MainActor
final class Store: ObservableObject {
    // A run with --spotlight-check, --spotlight-clear or --snapshot is a tool, not the app: no
    // commands, no index updates, else the check itself rebuilds the index it checks (016).
    static let shared = Store(demo: CommandLine.arguments.contains { $0.hasPrefix("--spotlight-") || $0 == "--snapshot" })

    @Published var secrets: [Secret] = []
    @Published var status = Status()
    @Published var storeOn = true
    @Published var activity: [ActivityEntry] = []
    @Published var references: [String: [String]] = [:]  // NAME → .env files with secret:NAME
    @Published var envKeys: [String: String] = [:]        // NAME → the key that holds secret:NAME
    @Published var busy: String?
    @Published var toast: Toast?
    @Published var problem: String?
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published var hotKeyOK = true
    // Names and comments of the secrets in the Spotlight index; values never go there.
    @Published var spotlight = UserDefaults.standard.object(forKey: "spotlight") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(spotlight, forKey: "spotlight")
            Task { await updateSpotlight() }
        }
    }

    // How many windows of the app are open: the poll is every 5 s with a window, every 30 s without.
    var visibleWindows = 0 { didSet { if visibleWindows > 0 { Task { await refreshStatus() } } } }
    let demo: Bool
    private var timer: Timer?
    private var tick = 0

    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let symbol: String
        let error: Bool
    }

    init(demo: Bool = false) {
        self.demo = demo
        if demo { loadDemo(); return }
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.poll() }
        }
        Task {
            await refreshAll()
            await healSpotlight()
            await Notifier.requestAuthorization()
            checkNotifications()
        }
    }

    // MARK: state

    var grace: Grace { status.grace }
    var isOpen: Bool { if case .active = grace { return true } else { return false } }
    var expiredCount: Int { secrets.filter { ($0.daysLeft() ?? 1) < 0 }.count }
    var soonCount: Int { secrets.filter { if let d = $0.daysLeft() { return d >= 0 && d <= 30 } else { return false } }.count }
    var needsAttention: Bool { problem != nil || expiredCount > 0 }
    var projects: [(name: String, count: Int)] {
        Dictionary(grouping: secrets, by: \.project).map { ($0.key, $0.value.count) }
            .sorted { $0.name == Parse.other ? false : $1.name == Parse.other ? true : $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var menuSymbol: String {
        if needsAttention { return "lock.trianglebadge.exclamationmark.fill" }
        return isOpen ? "lock.open.fill" : "lock.fill"
    }

    var statusLine: String {
        if let p = problem { return p }
        switch grace {
        case .off: return String(localized: "Closed · the next read asks for Touch ID")
        case .active(let left, _, _): return String(localized: "Open · \(Format.duration(left)) more without a question")
        }
    }

    // The name first, then the comment; then the same for the query in the other keyboard layout
    // (пшерги finds GITHUB, 015).
    func filter(_ query: String, in list: [Secret]? = nil) -> [Secret] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let base = list ?? secrets
        guard !q.isEmpty else { return base }
        var out = [Secret]()
        var seen = Set<String>()
        for term in [q, Parse.swapLayout(q)].compactMap({ $0 }) {
            let lname = base.filter { $0.name.lowercased().contains(term) }
            let lcomment = base.filter { $0.comment.lowercased().contains(term) }
            for s in lname + lcomment where seen.insert(s.name).inserted { out.append(s) }
        }
        return out
    }

    // MARK: refresh

    private func poll() async {
        tick += 1
        if visibleWindows > 0 || tick % 6 == 0 { await refreshStatus() }
        if tick % 720 == 0 { checkNotifications() }  // every hour
        if tick % 120 == 0 { await healSpotlight() }  // every 10 minutes
    }

    func refreshAll() async {
        await refreshStatus()
        await refreshList()
        refreshActivity()
        refreshReferences()
    }

    func refreshStatus() async {
        guard !demo else { return }
        storeOn = Paths.modeText == "vault"
        guard storeOn else { problem = String(localized: "The Touch ID store is off: secret migrate"); return }
        let r = await runCommand(Paths.store, ["status"])
        guard r.ok, let s = Parse.status(r.out) else {
            problem = String(localized: "The helper does not start. Run ./install.sh again.")
            status.grace = .off
            return
        }
        problem = nil
        if s != status { status = s }
    }

    func refreshList() async {
        guard !demo else { return }
        let r = await runCommand(Paths.store, ["list"])
        guard r.ok else { return }
        let list = Parse.list(r.out)
        if list != secrets {
            secrets = list
            await updateSpotlight()
        }
    }

    func refreshActivity() {
        guard !demo else { return }
        let a = (try? String(contentsOfFile: Paths.accessLog, encoding: .utf8)) ?? ""
        let g = (try? String(contentsOfFile: Paths.agentLog, encoding: .utf8)) ?? ""
        activity = Parse.activity(access: String(a.suffix(200_000)), agent: String(g.suffix(200_000)), limit: 40)
    }

    // .env files under the projects folder, 4 levels deep, without node_modules, .git, venvs.
    func refreshReferences() {
        guard !demo else { return }
        Task.detached(priority: .utility) {
            let (map, keys) = Store.scanReferences(root: Paths.projects)
            await MainActor.run {
                Store.shared.references = map
                Store.shared.envKeys = keys
            }
        }
    }

    nonisolated static func scanReferences(root: String) -> ([String: [String]], [String: String]) {
        var map = [String: [String]]()
        var keys = [String: String]()
        let skip: Set<String> = ["node_modules", ".git", ".venv", "venv", "site-packages", "Library", ".Trash", "OrbStack"]
        guard let e = FileManager.default.enumerator(at: URL(fileURLWithPath: root), includingPropertiesForKeys: [.isDirectoryKey],
                                                     options: [.skipsPackageDescendants]) else { return (map, keys) }
        while let url = e.nextObject() as? URL {
            let name = url.lastPathComponent
            if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                if skip.contains(name) || e.level > 4 { e.skipDescendants() }
                continue
            }
            guard name == ".env" || name.hasPrefix(".env.") || name.hasSuffix(".env") else { continue }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let rel = url.path.replacingOccurrences(of: Paths.home + "/", with: "~/")
            for r in Parse.references(text) {
                map[r.name, default: []].append(rel)
                if keys[r.name] == nil, !r.key.isEmpty { keys[r.name] = r.key }
            }
        }
        return (map, keys)
    }

    // MARK: actions

    func show(_ text: String, symbol: String = "checkmark.circle.fill", error: Bool = false) {
        let t = Toast(text: text, symbol: symbol, error: error)
        withAnimation(.spring(duration: 0.3)) { toast = t }
        HUD.shared.show(text: text, symbol: symbol, error: error)
        Task {
            try? await Task.sleep(for: .seconds(error ? 5 : 3))
            if toast == t { withAnimation(.easeOut) { toast = nil } }
        }
    }

    @discardableResult
    private func perform(_ label: String, _ args: [String], input: Data? = nil, done: String, symbol: String = "checkmark.circle.fill",
                         refresh: Bool = true, via: String = "secretbar") async -> Bool {
        busy = label
        defer { busy = nil }
        let r = await runCommand(Paths.secret, args, input: input, via: via)
        if r.ok {
            show(done, symbol: symbol)
            if refresh { await refreshList(); refreshReferences() }
            await refreshStatus()
            refreshActivity()
        } else {
            let m = r.message
            show(m.contains("not confirmed") ? String(localized: "Touch ID not confirmed") : m.isEmpty ? String(localized: "Error") : m, symbol: "xmark.octagon.fill", error: true)
        }
        return r.ok
    }

    func lock() async {
        guard !demo else { return }
        busy = "Lock"
        _ = await runCommand(Paths.store, ["lock"])
        busy = nil
        await refreshStatus()
        show(String(localized: "Locked"), symbol: "lock.fill")
    }

    // The value goes from the agent to the clipboard inside `secret copy`; the app never sees it.
    @discardableResult
    func copy(_ name: String, via: String = "secretbar") async -> Bool {
        guard !demo else { return true }
        return await perform("Copy \(name)", ["copy", name, "30"], done: String(localized: "\(name) copied · cleared in 30 s"),
                             symbol: "doc.on.clipboard.fill", refresh: false, via: via)
    }

    // saved: right after the add sheet (019), one toast for both facts.
    func copyReference(_ name: String, saved: Bool = false) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("secret:\(name)", forType: .string)
        show(saved ? String(localized: "\(name) saved · reference secret:\(name) copied") : String(localized: "Reference secret:\(name) copied"), symbol: "link")
    }

    func add(name: String, comment: String, expiry: String, value: String) async -> Bool {
        var args = ["set", "-c", comment]
        if !expiry.isEmpty { args += ["-x", expiry] }
        args.append(name)
        return await perform("Save \(name)", args, input: Data(value.utf8), done: String(localized: "\(name) saved"))
    }

    func generate(name: String, comment: String, expiry: String, length: Int, charset: String) async -> Bool {
        guard await perform("Generate \(name)", ["gen", "-l", String(length), "-s", charset, "-c", comment, name], done: String(localized: "\(name) generated")) else { return false }
        if !expiry.isEmpty { return await perform("Expiry \(name)", ["expire", name, expiry], done: String(localized: "\(name) generated")) }
        return true
    }

    func update(_ s: Secret, comment: String, expiry: String, newValue: String) async -> Bool {
        if comment != s.comment {
            guard await perform("Comment", ["note", s.name, comment], done: String(localized: "Saved")) else { return false }
        }
        if expiry != s.expiry {
            guard await perform("Expiry", ["expire", s.name, expiry.isEmpty ? "none" : expiry], done: String(localized: "Saved")) else { return false }
        }
        if !newValue.isEmpty {
            guard await perform("Value", ["set", s.name], input: Data(newValue.utf8), done: String(localized: "Value of \(s.name) replaced")) else { return false }
        }
        return true
    }

    func rename(_ s: Secret, to new: String) async -> Bool {
        await perform("Rename", ["mv", s.name, new], done: "\(s.name) → \(new)")
    }

    func delete(_ s: Secret) async -> Bool {
        await perform("Delete", ["rm", s.name], done: String(localized: "\(s.name) deleted"), symbol: "trash.fill")
    }

    func setGrace(_ seconds: Int) async {
        await perform("Grace", ["touchid", "grace", String(seconds)],
                      done: seconds == 0 ? String(localized: "Touch ID for each read") : String(localized: "No question for \(seconds / 60) idle min"), refresh: false)
    }

    func export(to url: URL, password: String) async -> Bool {
        await perform("Backup", ["export", "-f", "--pass-stdin", url.path], input: Data((password + "\n").utf8),
                      done: String(localized: "Backup saved: \(url.lastPathComponent)"), symbol: "externaldrive.fill.badge.checkmark", refresh: false)
    }

    func toggleLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            show(String(localized: "Open at login: \(error.localizedDescription)"), symbol: "xmark.octagon.fill", error: true)
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: Spotlight

    // Names and comments only, never values. Off: the index of the app is deleted.
    func updateSpotlight() async {
        guard !demo else { return }
        let index = CSSearchableIndex.default()
        try? await index.deleteAllSearchableItems()
        guard spotlight else { return }
        let entities = secrets.map(SecretEntity.init)
        try? await index.indexAppEntities(entities)
    }

    // The system can empty the index of the app after it was built, for example on a reinstall.
    // The list did not change, so updateSpotlight does not run again: compare the counts (016).
    func healSpotlight() async {
        guard !demo, spotlight, !secrets.isEmpty, let n = await SpotlightIndex.count(), n != secrets.count else { return }
        await updateSpotlight()
    }

    // MARK: notifications

    func checkNotifications() {
        guard !demo else { return }
        let expired = secrets.filter { ($0.daysLeft() ?? 1) < 0 }
        let soon = secrets.filter { if let d = $0.daysLeft() { return d >= 0 && d <= 7 } else { return false } }
        if !expired.isEmpty {
            Notifier.once(key: "expired", title: String(localized: "Expired secrets: \(expired.count)"),
                          body: expired.prefix(4).map(\.name).joined(separator: ", "))
        } else if !soon.isEmpty {
            Notifier.once(key: "soon", title: String(localized: "Secrets expire within 7 days: \(soon.count)"),
                          body: soon.prefix(4).map(\.name).joined(separator: ", "))
        }
        if problem != nil { Notifier.once(key: "problem", title: "SecretBar", body: problem ?? "") }
    }

    // MARK: demo (for --snapshot; no command runs)

    private func loadDemo() {
        let cal = Calendar.current
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        func day(_ n: Int) -> String { f.string(from: cal.date(byAdding: .day, value: n, to: Date())!) }
        secrets = [
            Secret(name: "SHOP_DB_PASSWORD", comment: "shop: PostgreSQL password of USER, works on both replicas", expiry: ""),
            Secret(name: "SHOP_DB_USER", comment: "shop: PostgreSQL login", expiry: ""),
            Secret(name: "SHOP_GRAFANA_PASSWORD", comment: "shop: Grafana password (admin)", expiry: day(5)),
            Secret(name: "SHOP_JWT_SECRET", comment: "shop: prod API JWT signing key", expiry: ""),
            Secret(name: "BILLING_API_TOKEN", comment: "billing: prod API token for the billing service", expiry: day(120)),
            Secret(name: "ETL_FERNET_KEY", comment: "etl: Fernet key of the local stack", expiry: ""),
            Secret(name: "GITHUB_TOKEN", comment: "GitHub personal token for gh", expiry: day(-3)),
            Secret(name: "JENKINS_ADMIN_PASSWORD", comment: "jenkins: admin password of the local Jenkins", expiry: ""),
            Secret(name: "WIKI_ADMIN_PASSWORD", comment: "wiki: prod wiki admin password", expiry: day(40)),
        ]
        status = Status(grace: .active(left: 1640, idle: 1800, limit: 26880), idle: 1800)
        references = ["SHOP_DB_PASSWORD": ["~/projects/shop/.env", "~/projects/shop-worker/.env"],
                      "BILLING_API_TOKEN": ["~/projects/billing/.env", "~/projects/billing-web/.env"]]
        let now = Date()
        activity = [
            ActivityEntry(id: "1", time: now.addingTimeInterval(-40), kind: .access(op: "run", who: "agent", names: "SHOP_DB_USER SHOP_DB_PASSWORD", detail: "sh")),
            ActivityEntry(id: "2", time: now.addingTimeInterval(-160), kind: .touchID(result: "confirmed", detail: "confirmed after 0.7s")),
            ActivityEntry(id: "3", time: now.addingTimeInterval(-162), kind: .touchID(result: "asked", detail: "use SHOP_DB_USER SHOP_DB_PASSWORD for sh")),
            ActivityEntry(id: "4", time: now.addingTimeInterval(-900), kind: .access(op: "copy", who: "human", names: "BILLING_API_TOKEN", detail: "")),
            ActivityEntry(id: "5", time: now.addingTimeInterval(-3600), kind: .access(op: "run", who: "agent", names: "ETL_FERNET_KEY", detail: "docker")),
        ]
    }
}

// MARK: notifications

enum Notifier {
    static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    // One notification per key and day.
    static func once(key: String, title: String, body: String) {
        let today = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        let k = "notified." + key
        guard UserDefaults.standard.double(forKey: k) < today else { return }
        UserDefaults.standard.set(today, forKey: k)
        let c = UNMutableNotificationContent()
        c.title = title
        c.body = body
        c.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: k, content: c, trigger: nil))
    }
}

// MARK: format

enum Format {
    static func duration(_ seconds: Int) -> String {
        if seconds >= 3600 { return String(localized: "\(seconds / 3600) h \(seconds % 3600 / 60) min") }
        if seconds >= 60 { return String(localized: "\(seconds / 60) min") }
        return String(localized: "\(seconds) s")
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

// MARK: selftest

// `SecretBar --selftest`: the parsers, without the interface (tests/run.sh, 012, 014).
enum SelfTest {
    @MainActor
    static func run() -> Bool {
        var failed = 0
        func check(_ name: String, _ ok: Bool) {
            print((ok ? "ok    " : "FAIL  ") + name)
            if !ok { failed += 1 }
        }
        let list = Parse.list("A_ONE\tкоммент\t-\nB_TWO\t-\t2030-01-01\nbad line\n")
        check("list: two rows", list.count == 2)
        check("list: comment kept", list.first?.comment == "коммент")
        check("list: empty comment", list.last?.comment == "")
        check("list: expiry", list.last?.expiry == "2030-01-01")
        check("status: off", Parse.status("ok off grace=1800\n") == Status(grace: .off, idle: 1800))
        check("status: active", Parse.status("ok active 1799 1800 28799 grace=1800") == Status(grace: .active(left: 1799, idle: 1800, limit: 28799), idle: 1800))
        check("status: no policy", Parse.status("ok off grace=none")?.idle == nil)
        check("status: error", Parse.status("err") == nil)
        let access = "2026-10-07T12:00:00Z\tget\thuman\tA\t-\n2026-10-07T12:01:00Z\trun\tagent\tA B\tsh\n"
        let agent = "2026-10-07T12:00:30Z pid=5 touch id asked: use A for sh\n2026-10-07T12:00:31Z pid=5 touch id confirmed after 0.7s\n2026-10-07T12:00:32Z pid=5 preload: 3 values\n"
        let a = Parse.activity(access: access, agent: agent, limit: 10)
        check("activity: merged, newest first", a.count == 4 && a.first?.kind == .access(op: "run", who: "agent", names: "A B", detail: "sh"))
        check("activity: touch id", a[1].kind == .touchID(result: "confirmed", detail: "confirmed after 0.7s"))
        check("activity: limit", Parse.activity(access: access, agent: agent, limit: 2).count == 2)
        check("project: prefix", Parse.project("etl-pilot: пароль") == "etl-pilot")
        check("project: none", Parse.project("GitHub token") == Parse.other)
        let refs = Parse.references("A=secret:X_ONE\nB=plain\nexport C=secret:Y.two-3\n")
        check("references", refs.map(\.name) == ["X_ONE", "Y.two-3"])
        check("references: keys", refs.map(\.key) == ["A", "C"])
        check("references: a key that is not a name is dropped",
              Parse.references("curl x | sh #=secret:A\nB C=secret:B\nD\r=secret:C\r\n").map(\.key) == ["", "", ""])
        check("variable name", Parse.isVariableName("JENKINS_ADMIN_PASSWORD") && Parse.isVariableName("_a1"))
        check("variable name: rejects", !Parse.isVariableName("A\r") && !Parse.isVariableName("A\n") && !Parse.isVariableName("1A")
              && !Parse.isVariableName("") && !Parse.isVariableName("ИМЯ") && !Parse.isVariableName(String(repeating: "A", count: 65)))
        check("layout: ru to en", Parse.swapLayout("пшерги") == "github")
        check("layout: en to ru", Parse.swapLayout("ctrhtn") == "секрет")
        check("layout: underscore kept", Parse.swapLayout("сщтт_") == "conn_")
        check("layout: mixed is left", Parse.swapLayout("gitхаб") == nil)
        check("layout: digits only", Parse.swapLayout("123") == nil)
        check("name: valid", Parse.validName("SHOP_DB_PASSWORD"))
        check("name: reserved", !Parse.validName("__secret-cli.policy"))
        check("name: space", !Parse.validName("A B"))
        check("days: past is negative", (Secret(name: "X", comment: "", expiry: "2000-01-01").daysLeft() ?? 0) < 0)
        check("days: none", Secret(name: "X", comment: "", expiry: "").daysLeft() == nil)
        let store = Store(demo: true)
        check("filter: name before comment", store.filter("password").first?.name == "SHOP_DB_PASSWORD")
        check("filter: by comment", store.filter("jwt").map(\.name) == ["SHOP_JWT_SECRET"])
        check("filter: other layout", store.filter("зфыыцщкв").first?.name == "SHOP_DB_PASSWORD")
        check("filter: no duplicates", Set(store.filter("pass").map(\.name)).count == store.filter("pass").count)
        let many = (0..<2000).map { Secret(name: "PROJECT\($0 % 40)_KEY_\($0)", comment: "project\($0 % 40): ключ номер \($0)", expiry: "") }
        let t0 = Date()
        for q in ["key_19", "ключ", "лун", "zzz"] { _ = store.filter(q, in: many) }
        let ms = Date().timeIntervalSince(t0) * 1000 / 4
        check("filter: 2000 secrets under 50 ms (\(Int(ms)) ms)", ms < 50)
        print("selftest: \(failed == 0 ? "passed" : "\(failed) failed")")
        return failed == 0
    }
}
