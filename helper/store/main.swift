// secret-vault: the Secure Enclave store of secret (017, 018), see plan 017.
import AppKit
import CoreGraphics
import Foundation
import LocalAuthentication
import Security
import CryptoKit

#if SECRET_TEST
// Test build only: one account per test run, the state in the test directory, Touch ID from a file.
let testEnv = ProcessInfo.processInfo.environment
let account = "secret-cli-test." + (testEnv["SECRET_TEST_STORE"] ?? "default")
let stateDir = testEnv["SECRET_TEST_STATE"] ?? (NSTemporaryDirectory() + "secret-store-test")
#else
let account = "secret-cli"
let stateDir = NSHomeDirectory() + "/.local/state/secret"
#endif
let defaultGrace = 1800
let maxGrace = 3600
let idleSeconds = 30.0
let socketPath = stateDir + "/vault-agent.sock"
let lockPath = stateDir + "/vault-agent.lock"
#if SECRET_TEST
let vaultPath = stateDir + "/vault-" + (testEnv["SECRET_TEST_STORE"] ?? "default")
#else
let vaultPath = NSHomeDirectory() + "/.local/share/secret/vault"
#endif
let noDialog = !(ProcessInfo.processInfo.environment["SECRET_NO_DIALOG"] ?? "").isEmpty

func eventLog(_ message: String) {
    let path = stateDir + "/agent.log"
    let stamp = ISO8601DateFormatter().string(from: Date())
    let line = Data("\(stamp) pid=\(getpid()) \(message)\n".utf8)
    if !FileManager.default.fileExists(atPath: path) {
        FileManager.default.createFile(atPath: path, contents: nil, attributes: [.posixPermissions: 0o600])
    }
    guard let h = FileHandle(forWritingAtPath: path) else { return }
    h.seekToEndOfFile(); h.write(line); h.closeFile()
}

func valueTouch(_ what: String) {
    #if SECRET_TEST
    guard let log = testEnv["SECRET_TEST_VALUE_LOG"] else { return }
    if !FileManager.default.fileExists(atPath: log) { FileManager.default.createFile(atPath: log, contents: nil) }
    if let h = FileHandle(forWritingAtPath: log) { h.seekToEndOfFile(); h.write(Data("\(CommandLine.arguments.dropFirst().first ?? "-") \(what)\n".utf8)); h.closeFile() }
    #endif
}

func fail(_ message: String, _ code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data(("secret-vault: " + message + "\n").utf8))
    exit(code)
}

func usage() -> Never {
    fail("""
        usage: secret-vault list | has NAME | read REASON NAME... | write | attrs REASON NAME COMMENT EXPIRY
               delete NAME... | policy init [N] | policy show | policy grace N | lock | grace-status
               ping | kind | clip | status | repair
        """, 64)
}

// MARK: hex

func hex(_ data: Data) -> String { data.isEmpty ? "-" : data.map { String(format: "%02x", $0) }.joined() }
func hex(_ text: String) -> String { hex(Data(text.utf8)) }

func unhex(_ text: Substring) -> Data? {
    if text == "-" { return Data() }
    guard text.count % 2 == 0 else { return nil }
    var bytes = [UInt8]()
    bytes.reserveCapacity(text.count / 2)
    var i = text.startIndex
    while i < text.endIndex {
        let j = text.index(i, offsetBy: 2)
        guard let b = UInt8(text[i..<j], radix: 16) else { return nil }
        bytes.append(b)
        i = j
    }
    return Data(bytes)
}

func unhexText(_ text: Substring) -> String? { unhex(text).map { String(decoding: $0, as: UTF8.self) } }

// MARK: Touch ID

#if SECRET_TEST
// Test build only: the answer comes from a file. The release build has no such path.
func confirm(_ context: LAContext, _ reason: String) -> Bool {
    if let log = testEnv["SECRET_TEST_AUTH_LOG"] {
        if !FileManager.default.fileExists(atPath: log) { FileManager.default.createFile(atPath: log, contents: nil) }
        if let h = FileHandle(forWritingAtPath: log) { h.seekToEndOfFile(); h.write(Data((reason + "\n").utf8)); h.closeFile() }
    }
    guard let file = testEnv["SECRET_TEST_AUTH"], let answer = try? String(contentsOfFile: file, encoding: .utf8) else { return false }
    return answer.trimmingCharacters(in: .whitespacesAndNewlines) == "allow"
}
#endif

// MARK: agent socket

func makeAddress(_ path: String) -> sockaddr_un {
    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let bytes = Array(path.utf8)
    guard bytes.count < MemoryLayout.size(ofValue: addr.sun_path) else { fail("socket path too long: \(path)") }
    withUnsafeMutableBytes(of: &addr.sun_path) { raw in
        raw.copyBytes(from: bytes)
        raw[bytes.count] = 0
    }
    return addr
}

func connectAgent() -> Int32? {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { return nil }
    var addr = makeAddress(socketPath)
    let r = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
    }
    if r != 0 { close(fd); return nil }
    return fd
}

func writeLine(_ fd: Int32, _ line: String) -> Bool {
    let data = Array((line + "\n").utf8)
    var sent = 0
    while sent < data.count {
        let n = data[sent...].withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
        if n <= 0 { return false }
        sent += n
    }
    return true
}

func readLine(_ fd: Int32) -> String? {
    var data = [UInt8]()
    var byte: UInt8 = 0
    while read(fd, &byte, 1) == 1 {
        if byte == 0x0a { return String(decoding: data, as: UTF8.self) }
        data.append(byte)
    }
    return nil
}

func ensureStateDir() {
    try? FileManager.default.createDirectory(atPath: stateDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
}

// The agent runs in its own session: a shell that ends the command group does not stop it.
func spawnAgent() {
    guard let path = Bundle.main.executablePath else { fail("cannot find the helper path") }
    var attr: posix_spawnattr_t?
    posix_spawnattr_init(&attr)
    posix_spawnattr_setflags(&attr, Int16(POSIX_SPAWN_SETSID))
    var actions: posix_spawn_file_actions_t?
    posix_spawn_file_actions_init(&actions)
    for fd: Int32 in 0...2 {
        posix_spawn_file_actions_addopen(&actions, fd, "/dev/null", fd == 0 ? O_RDONLY : O_WRONLY, 0)
    }
    var pid: pid_t = 0
    let argv: [UnsafeMutablePointer<CChar>?] = [strdup(path), strdup("agent"), nil]
    let r = posix_spawn(&pid, path, &actions, &attr, argv, environ)
    argv.forEach { free($0) }
    posix_spawn_file_actions_destroy(&actions)
    posix_spawnattr_destroy(&attr)
    guard r == 0 else { fail("cannot start the agent: \(r)") }
}

// Send one request to the agent, start it when it is not running. Prints the error and exits
// with its code when the agent answers "err".
// An agent at the end of its grace can close a connection without an answer: then the request
// goes again, to a new agent. Read and attrs are safe to repeat.
func request(_ line: String) -> [Substring] {
    ensureStateDir()
    var answer: String?
    for _ in 0..<3 {
        var fd = connectAgent()
        if fd == nil {
            spawnAgent()
            for _ in 0..<150 {
                usleep(20_000)
                fd = connectAgent()
                if fd != nil { break }
            }
        }
        guard let f = fd else { fail("cannot connect to the agent") }
        if writeLine(f, line) { answer = readLine(f) }
        close(f)
        if answer != nil { break }
        usleep(50_000)
    }
    guard let answer = answer else { fail("no answer from the agent") }
    let fields = answer.split(separator: "\t", omittingEmptySubsequences: false)
    if fields.first == "err" {
        let code = fields.count > 1 ? Int32(fields[1]) ?? 1 : 1
        fail(fields.count > 2 ? String(fields[2]) : "agent error", code)
    }
    return Array(fields.dropFirst())
}

// MARK: agent

// Clocks: monotonic counts the sleep of the Mac, uptime does not. A gap between them is a sleep.
func monotonic() -> TimeInterval { TimeInterval(clock_gettime_nsec_np(CLOCK_MONOTONIC)) / 1e9 }
func uptime() -> TimeInterval { TimeInterval(clock_gettime_nsec_np(CLOCK_UPTIME_RAW)) / 1e9 }

#if SECRET_TEST
let maxSession = TimeInterval(testEnv["SECRET_TEST_MAX_GRACE"].flatMap { Int($0) } ?? 8 * 3600)
let contextFresh = TimeInterval(testEnv["SECRET_TEST_CONTEXT_FRESH"].flatMap { Int($0) } ?? 480)
let testLockNotification = Notification.Name("secretcli.test.lock." + account)
#else
let maxSession: TimeInterval = 8 * 3600
// The keychain takes a confirmed context for about 10 minutes (research 010 R11).
let contextFresh: TimeInterval = 480
#endif

func screenLocked() -> Bool {
    guard let d = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
    return (d["CGSSessionScreenIsLocked"] as? Bool) ?? false
}

// Grace is sliding (010): each served request moves the end to now + idle, but not past
// maxSession from the Touch ID. A locked screen, a sleep or `lock` ends it at once.
// The keychain takes a context for about 10 minutes only, so the agent keeps the values it read
// (R11). A value goes out of memory when its item has a new persistent reference.
final class Agent {
    var context: LAContext?
    var contextAt: TimeInterval = 0
    var cache = [String: (ref: Data, value: Data)]()
    var idle: TimeInterval = 0
    var confirmedAt: TimeInterval = 0
    var deadline: TimeInterval = 0
    var startedAt = monotonic()
    var lastMono = monotonic()
    var lastUptime = uptime()
    var listenFD: Int32 = -1
    var source: DispatchSourceRead?
    var timer: DispatchSourceTimer?

    // A confirmed context: the one in grace, or a new one after Touch ID.
    func authorized(_ reason: String, _ nodialog: Bool) -> Result<LAContext, AgentError> {
        if let c = context, monotonic() < deadline { return .success(c) }
        context?.invalidate()
        context = nil
        if nodialog { return .failure(AgentError(code: 5, message: "Touch ID confirmation needed, SECRET_NO_DIALOG is set")) }
        let c: LAContext
        switch confirmedContext(reason) {
        case .failure(let e): return .failure(e)
        case .success(let x): c = x
        }
        context = c
        idle = TimeInterval(grace(c))
        confirmedAt = monotonic()
        contextAt = confirmedAt
        deadline = confirmedAt + idle
        cache.removeAll()
        if idle > 0 { preload(c) }
        return .success(c)
    }

    func preload(_ c: LAContext) {
        if let (d, k, _) = try? readDoc() {
            for it in d.items {
                valueTouch("read " + it.n)
                if let v = try? unseal(it.v, it.n, k.se, c) { cache[it.n] = (Data(it.r.utf8), v) }
            }
        }
        eventLog("preload: \(cache.count) values")
    }

    // The value of NAME: from memory, or from the keychain with a context that is still new.
    func value(_ name: String, _ reason: String, _ nodialog: Bool) -> Result<Data, AgentError> {
        let found: (VaultDoc, VaultKeys, VaultHeader)?
        do { found = try readDoc() } catch { return .failure(AgentError(code: 1, message: vaultMessage(error))) }
        guard let (_, k, _) = found, let item = found?.0.items.first(where: { $0.n == name }) else {
            return .failure(AgentError(code: 3, message: "not found: \(name)"))
        }
        let ref = Data(item.r.utf8)
        if let e = cache[name], e.ref == ref { return .success(e.value) }
        if monotonic() - contextAt > contextFresh {
            if nodialog { return .failure(AgentError(code: 5, message: "Touch ID confirmation needed, SECRET_NO_DIALOG is set")) }
            let c: LAContext
            switch confirmedContext(reason) {
            case .failure(let e): return .failure(e)
            case .success(let x): c = x
            }
            context?.invalidate()
            context = c
            contextAt = monotonic()
        }
        guard let c = context else { return .failure(AgentError(code: 1, message: "no context")) }
        do {
            valueTouch("read " + name)
            let v = try unseal(item.v, name, k.se, c)
            cache[name] = (ref, v)
            return .success(v)
        } catch { return .failure(AgentError(code: 1, message: "cannot read \(name): \(error)")) }
    }

    func extend() {
        guard context != nil else { return }
        deadline = min(monotonic() + idle, confirmedAt + maxSession)
    }

    // Grace from the policy, read with the confirmed context. No policy, an item without
    // protection or a value over the limit: 0.
    func grace(_ c: LAContext) -> Int {
        guard let g = (try? keys())?.grace, g >= 0, g <= maxGrace else { return 0 }
        return g
    }

    func handle(_ line: String) -> (String, Bool) {
        let f = line.split(separator: "\t", omittingEmptySubsequences: false)
        guard let op = f.first else { return ("err\t64\tempty request", false) }
        switch op {
        case "lock":
            return ("ok", true)
        case "status":
            let now = monotonic()
            guard context != nil, now < deadline else { return ("ok\toff", false) }
            return ("ok\tactive\t\(Int(deadline - now))\t\(Int(idle))\t\(Int(confirmedAt + maxSession - now))", false)
        case "read" where f.count == 4:
            guard let reason = unhexText(f[2]) else { return ("err\t64\tbad request", false) }
            var names = [String]()
            for h in f[3].split(separator: ",") {
                guard let n = unhexText(h), !n.hasPrefix("__secret-cli.") else { return ("err\t64\tbad request", false) }
                names.append(n)
            }
            if case .failure(let e) = authorized(reason, f[1] == "1") { return ("err\t\(e.code)\t\(e.message)", false) }
            var values = [String]()
            for n in names {
                switch value(n, reason, f[1] == "1") {
                case .failure(let e): return ("err\t\(e.code)\t\(e.message)", false)
                case .success(let v): values.append(hex(v))
                }
            }
            extend()
            return ("ok\t" + values.joined(separator: ","), false)
        default:
            return ("err\t64\tunknown request", false)
        }
    }

    // End of grace: the deadline passed, the Mac slept, or the screen is locked. Without a
    // context the agent ends after idleSeconds.
    func check() {
        let mono = monotonic(), up = uptime()
        let slept = (mono - lastMono) - (up - lastUptime) > 2
        lastMono = mono
        lastUptime = up
        if slept || screenLocked() { stop() }
        if context != nil {
            if mono >= deadline { stop() }
        } else if mono - startedAt >= idleSeconds {
            stop()
        }
    }

    func serve() {
        let client = accept(listenFD, nil, nil)
        guard client >= 0 else { return }
        defer { close(client) }
        var uid: uid_t = 0, gid: gid_t = 0
        guard getpeereid(client, &uid, &gid) == 0, uid == getuid() else { return }
        check()  // a request right after a wake or a lock gets no old grace
        guard let line = readLine(client) else { return }
        let (answer, exitNow) = handle(line)
        _ = writeLine(client, answer)
        if exitNow { close(client); stop() }
        if context == nil { startedAt = monotonic() }
    }

    func run() -> Never {
        ensureStateDir()
        let lockFD = open(lockPath, O_CREAT | O_RDWR, 0o600)
        guard lockFD >= 0, flock(lockFD, LOCK_EX | LOCK_NB) == 0 else { exit(0) }  // another agent runs
        unlink(socketPath)
        listenFD = socket(AF_UNIX, SOCK_STREAM, 0)
        var addr = makeAddress(socketPath)
        let old = umask(0o077)
        let b = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(listenFD, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        umask(old)
        guard listenFD >= 0, b == 0, listen(listenFD, 16) == 0 else { exit(1) }
        let src = DispatchSource.makeReadSource(fileDescriptor: listenFD, queue: .main)
        src.setEventHandler { [unowned self] in self.serve() }
        src.resume()
        source = src
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + 1, repeating: 1)
        t.setEventHandler { [unowned self] in self.check() }
        t.resume()
        timer = t
        let center = DistributedNotificationCenter.default()
        center.addObserver(forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [unowned self] _ in self.stop() }
        #if SECRET_TEST
        center.addObserver(forName: testLockNotification, object: nil, queue: .main) { [unowned self] _ in self.stop() }
        #endif
        RunLoop.main.run()
        stop()
    }

    func stop() -> Never {
        unlink(socketPath)  // first: new clients start a new agent
        cache.removeAll()
        context?.invalidate()
        close(listenFD)
        exit(0)
    }
}

struct AgentError: Error { let code: Int32; let message: String }

func stopAgent() {
    guard let fd = connectAgent() else { return }
    _ = writeLine(fd, "lock")
    _ = readLine(fd)
    close(fd)
}

// MARK: vault (017)

// Values are sealed to a Secure Enclave key with .userPresence, the payload to the file key. The
// file key and the grace live in a login keychain item that only this helper reads silently; any
// other program can overwrite it, so a read that would ask is refused (keyChanged). The header
// keeps the file key sealed to the Secure Enclave key for `repair` (plan 017).

let vaultMagic = Data("SCV2".utf8)
let checkText = Data("secret-cli check".utf8)
let checkName = "__check"
let fileKeyName = "__file-key"
let keyService = "secret-cli.vault"

struct VaultItem: Codable {
    var n: String    // name
    var c: String    // comment
    var x: String    // expiry, YYYY-MM-DD or ""
    var v: Data      // ECIES of the value
    var r: String    // version mark, new on each write of the value
}

struct VaultDoc: Codable {
    var check: Data  // ECIES of checkText: one Secure Enclave operation is the Touch ID question
    var items: [VaultItem]
}

// The file header, readable without keys; the payload authenticates it.
struct VaultHeader: Codable {
    var pub: Data    // x963 public key of the Secure Enclave key
    var se: Data     // the wrapped Secure Enclave key (raw software key in the test build)
    var wm: Data     // ECIES of the file key, for repair
}

// The keychain item.
struct VaultKeys: Codable {
    var m: Data      // the file key
    var pub: Data
    var se: Data
    var grace: Int?
    var fileKey: SymmetricKey { SymmetricKey(data: m) }
}

enum VaultError: Error { case damaged(String), missingKey, keyChanged, keychain(OSStatus), noPresence }

func vaultMessage(_ e: Error) -> String {
    switch e {
    case VaultError.damaged(let s): return "the store file is damaged or not ours: \(s)"
    case VaultError.missingKey: return "the key item of the store is missing: secret touchid repair rebuilds it (Touch ID)"
    case VaultError.keyChanged: return "another program changed the key item of the store, or the helper lost its signature: secret touchid repair rebuilds it (Touch ID)"
    case VaultError.keychain(let r): return "cannot use the key item of the store: \(r)"
    case VaultError.noPresence: return "the Secure Enclave key of the store works without Touch ID: it is not ours"
    default: return "\(e)"
    }
}

#if SECRET_TEST
let keyFile = stateDir + "/vault-" + (testEnv["SECRET_TEST_STORE"] ?? "default") + ".key"

func storedKeys() throws -> Data? { FileManager.default.contents(atPath: keyFile) }

func saveKeys(_ d: Data, new: Bool) throws {
    unlink(keyFile)
    guard FileManager.default.createFile(atPath: keyFile, contents: d, attributes: [.posixPermissions: 0o600]) else {
        throw VaultError.keychain(errSecIO)
    }
}

func newPrivateKey() throws -> (pub: Data, se: Data) {
    let k = P256.KeyAgreement.PrivateKey()
    return (k.publicKey.x963Representation, k.rawRepresentation)
}

func sharedSecret(_ se: Data, _ eph: P256.KeyAgreement.PublicKey, _ ctx: LAContext?) throws -> SharedSecret {
    try P256.KeyAgreement.PrivateKey(rawRepresentation: se).sharedSecretFromKeyAgreement(with: eph)
}
#else
func keyQuery(_ extra: [String: Any] = [:]) -> CFDictionary {
    // no kSecUseDataProtectionKeychain: the item lives in the login keychain, its ACL names the helper
    let q: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: keyService,
        kSecAttrAccount as String: account,
    ]
    return q.merging(extra) { $1 } as CFDictionary
}

// Silent only: a question here means that the ACL no longer names this helper.
func storedKeys() throws -> Data? {
    var out: CFTypeRef?
    let r = SecItemCopyMatching(keyQuery([
        kSecReturnData as String: true,
        kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail,
    ]), &out)
    if r == errSecItemNotFound { return nil }
    if r == errSecUserCanceled || r == errSecInteractionNotAllowed || r == errSecAuthFailed { throw VaultError.keyChanged }
    guard r == errSecSuccess, let d = out as? Data else { throw VaultError.keychain(r) }
    return d
}

// New data keeps the ACL of the item. A new item replaces a changed one: the owner can delete it.
func saveKeys(_ d: Data, new: Bool) throws {
    if !new {
        let r = SecItemUpdate(keyQuery([kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail]),
                              [kSecValueData as String: d] as CFDictionary)
        guard r == errSecSuccess else { throw VaultError.keychain(r) }
        return
    }
    let del = SecItemDelete(keyQuery())
    guard del == errSecSuccess || del == errSecItemNotFound else { throw VaultError.keychain(del) }
    let r = SecItemAdd(keyQuery([
        kSecValueData as String: d,
        kSecAttrLabel as String: "secret-cli store key",
        kSecAttrDescription as String: "secret-cli",
    ]), nil)
    guard r == errSecSuccess else { throw VaultError.keychain(r) }
}

func newPrivateKey() throws -> (pub: Data, se: Data) {
    var error: Unmanaged<CFError>?
    guard let ac = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                                   [.privateKeyUsage, .userPresence], &error) else {
        throw VaultError.keychain(errSecParam)
    }
    let k = try SecureEnclave.P256.KeyAgreement.PrivateKey(accessControl: ac)
    return (k.publicKey.x963Representation, k.dataRepresentation)
}

func sharedSecret(_ se: Data, _ eph: P256.KeyAgreement.PublicKey, _ ctx: LAContext?) throws -> SharedSecret {
    try SecureEnclave.P256.KeyAgreement.PrivateKey(dataRepresentation: se, authenticationContext: ctx)
        .sharedSecretFromKeyAgreement(with: eph)
}
#endif

func vaultKey(_ secret: SharedSecret, _ eph: P256.KeyAgreement.PublicKey, _ name: String) -> SymmetricKey {
    secret.hkdfDerivedSymmetricKey(using: SHA256.self, salt: eph.x963Representation,
                                   sharedInfo: Data(("secret-cli vault v1|" + name).utf8), outputByteCount: 32)
}

// ECIES: an ephemeral key, ECDH with the Secure Enclave public key, HKDF bound to the name.
func seal(_ plain: Data, _ name: String, _ pub: Data) throws -> Data {
    let eph = P256.KeyAgreement.PrivateKey()
    let s = try eph.sharedSecretFromKeyAgreement(with: try P256.KeyAgreement.PublicKey(x963Representation: pub))
    guard let box = try AES.GCM.seal(plain, using: vaultKey(s, eph.publicKey, name)).combined else { throw VaultError.damaged("seal") }
    return eph.publicKey.x963Representation + box
}

// Needs a context that passed .userPresence, else the system asks for Touch ID here.
func unseal(_ blob: Data, _ name: String, _ se: Data, _ ctx: LAContext?) throws -> Data {
    guard blob.count > 65 + 28 else { throw VaultError.damaged(name) }
    let eph = try P256.KeyAgreement.PublicKey(x963Representation: blob.prefix(65))
    let s = try sharedSecret(se, eph, ctx)
    return try AES.GCM.open(AES.GCM.SealedBox(combined: blob.dropFirst(65)), using: vaultKey(s, eph, name))
}

// A key that works with a context that cannot ask has no .userPresence: this helper did not make it.
// Only "interaction required" passes; any other result fails closed.
func requirePresence(_ sealed: Data, _ name: String, _ se: Data) throws {
    #if !SECRET_TEST
    let c = LAContext()
    c.interactionNotAllowed = true
    do {
        _ = try unseal(sealed, name, se, c)
    } catch let e as NSError where e.domain == LAErrorDomain && e.code == LAError.notInteractive.rawValue {
        return
    } catch {
        throw VaultError.damaged("cannot check the Secure Enclave key: \(error)")
    }
    throw VaultError.noPresence
    #endif
}

var loadedKeys: VaultKeys?

// Without a file a changed key item protects nothing: a new one replaces it.
func keysWithoutFile() throws -> VaultKeys? {
    do { return try keys() } catch VaultError.keyChanged { return nil }
}

func keys() throws -> VaultKeys? {
    if let k = loadedKeys { return k }
    guard let d = try storedKeys() else { return nil }
    do { loadedKeys = try JSONDecoder().decode(VaultKeys.self, from: d) } catch { throw VaultError.keyChanged }
    return loadedKeys
}

func storeKeys(_ k: VaultKeys, new: Bool) throws {
    try saveKeys(try JSONEncoder().encode(k), new: new)
    loadedKeys = k
}

// File: magic, header length (4 bytes, big endian), header JSON, sealed payload. The payload is
// sealed with the file key and authenticates the magic and the header.
func splitFile(_ blob: Data) throws -> (VaultHeader, Data, Data) {
    guard blob.count > 8, blob.prefix(4) == vaultMagic else { throw VaultError.damaged("no mark") }
    let b = [UInt8](blob)
    let n = Int(b[4]) << 24 | Int(b[5]) << 16 | Int(b[6]) << 8 | Int(b[7])
    guard n > 0, 8 + n < b.count else { throw VaultError.damaged("bad header") }
    let headerBytes = Data(b[8..<(8 + n)])
    guard let h = try? JSONDecoder().decode(VaultHeader.self, from: headerBytes) else { throw VaultError.damaged("bad header") }
    return (h, Data(b[0..<(8 + n)]), Data(b[(8 + n)...]))
}

func joinFile(_ h: VaultHeader, _ d: VaultDoc, _ fileKey: SymmetricKey) throws -> Data {
    let hb = try JSONEncoder().encode(h)
    let n = UInt32(hb.count)
    let aad = vaultMagic + Data([UInt8(n >> 24 & 0xff), UInt8(n >> 16 & 0xff), UInt8(n >> 8 & 0xff), UInt8(n & 0xff)]) + hb
    guard let box = try AES.GCM.seal(try JSONEncoder().encode(d), using: fileKey, authenticating: aad).combined else {
        throw VaultError.damaged("seal")
    }
    return aad + box
}

func openPayload(_ sealed: Data, _ aad: Data, _ fileKey: SymmetricKey) throws -> VaultDoc {
    let json: Data
    do {
        json = try AES.GCM.open(AES.GCM.SealedBox(combined: sealed), using: fileKey, authenticating: aad)
    } catch { throw VaultError.damaged("the file key does not open it") }
    do { return try JSONDecoder().decode(VaultDoc.self, from: json) } catch { throw VaultError.damaged("bad content") }
}

// The store, or nil when there is no file yet.
func readDoc() throws -> (VaultDoc, VaultKeys, VaultHeader)? {
    guard let blob = FileManager.default.contents(atPath: vaultPath) else { return nil }
    guard let k = try keys() else { throw VaultError.missingKey }
    let (h, aad, sealed) = try splitFile(blob)
    guard h.pub == k.pub, h.se == k.se else { throw VaultError.damaged("another key") }
    return (try openPayload(sealed, aad, k.fileKey), k, h)
}

func doc() -> (VaultDoc, VaultKeys, VaultHeader)? {
    do { return try readDoc() } catch { fail(vaultMessage(error)) }
}

// The grace of the store; nil: no policy yet.
func vaultGrace() -> Int? {
    do {
        return FileManager.default.fileExists(atPath: vaultPath) ? try keys()?.grace : try keysWithoutFile()?.grace
    } catch { fail(vaultMessage(error)) }
}

func ensureVaultDir() {
    try? FileManager.default.createDirectory(atPath: (vaultPath as NSString).deletingLastPathComponent,
                                             withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
}

func withStoreLock(_ body: () -> Void) {
    ensureVaultDir()
    let fd = open(vaultPath + ".lock", O_CREAT | O_RDWR, 0o600)
    guard fd >= 0, flock(fd, LOCK_EX) == 0 else { fail("cannot lock the store") }
    defer { flock(fd, LOCK_UN); close(fd) }
    body()
}

func writeFile(_ data: Data) {
    let tmp = vaultPath + ".new"
    unlink(tmp)
    guard FileManager.default.createFile(atPath: tmp, contents: data, attributes: [.posixPermissions: 0o600]) else {
        fail("cannot write \(tmp)")
    }
    if FileManager.default.fileExists(atPath: vaultPath) {
        unlink(vaultPath + ".prev")
        guard link(vaultPath, vaultPath + ".prev") == 0 else { fail("cannot keep the old store file") }
    }
    guard rename(tmp, vaultPath) == 0 else { fail("cannot replace the store file") }
}

// Change the store under a lock; the old file stays as .prev. Only a store without a file gets
// new keys: a file without its keys is an error, never a reason for keys that cannot open it.
func mutate(_ change: (inout VaultDoc, VaultKeys) throws -> Void) {
    withStoreLock {
        do {
            var d: VaultDoc
            let k: VaultKeys
            let h: VaultHeader
            if let (od, ok, oh) = try readDoc() {
                d = od; k = ok; h = oh
            } else if let ok = try keysWithoutFile() {
                // no file, but keys: keep them, an old .prev still opens
                k = ok
                h = VaultHeader(pub: k.pub, se: k.se, wm: try seal(k.m, fileKeyName, k.pub))
                d = VaultDoc(check: try seal(checkText, checkName, k.pub), items: [])
            } else {
                let (pub, se) = try newPrivateKey()
                let m = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
                k = VaultKeys(m: m, pub: pub, se: se, grace: nil)
                try storeKeys(k, new: true)
                h = VaultHeader(pub: pub, se: se, wm: try seal(m, fileKeyName, pub))
                d = VaultDoc(check: try seal(checkText, checkName, pub), items: [])
            }
            try change(&d, k)
            writeFile(try joinFile(h, d, k.fileKey))
        } catch let e as AgentError {
            fail(e.message, e.code)
        } catch {
            fail(vaultMessage(error))
        }
    }
}

// The grace in the key item: an old copy of the file cannot bring an old grace.
func setGrace(_ g: Int) {
    withStoreLock {
        do {
            guard var k = try keys() else { throw VaultError.missingKey }
            k.grace = g
            try storeKeys(k, new: false)
        } catch { fail(vaultMessage(error)) }
    }
}

// A context that passed .userPresence: the Secure Enclave opens the check value and asks for Touch
// ID, Apple Watch or the Mac password with REASON. The test build asks the answer file first.
func confirmedContext(_ reason: String) -> Result<LAContext, AgentError> {
    let c = LAContext()
    c.localizedReason = reason
    #if SECRET_TEST
    guard confirm(c, reason) else { return .failure(AgentError(code: 5, message: "not confirmed")) }
    #endif
    let found: (VaultDoc, VaultKeys, VaultHeader)?
    do { found = try readDoc() } catch { return .failure(AgentError(code: 1, message: vaultMessage(error))) }
    guard let (d, k, _) = found else { return .failure(AgentError(code: 3, message: "the store is empty")) }
    do { try requirePresence(d.check, checkName, k.se) } catch { return .failure(AgentError(code: 1, message: vaultMessage(error))) }
    let t0 = Date()
    eventLog("touch id asked: \(reason)")
    do {
        guard try unseal(d.check, checkName, k.se, c) == checkText else {
            return .failure(AgentError(code: 1, message: "the check value of the store is wrong"))
        }
    } catch {
        eventLog(String(format: "touch id refused after %.1fs: %@", Date().timeIntervalSince(t0), "\(error)"))
        return .failure(AgentError(code: 5, message: "not confirmed"))
    }
    eventLog(String(format: "touch id confirmed after %.1fs", Date().timeIntervalSince(t0)))
    c.interactionNotAllowed = true
    return .success(c)
}

// A new key item from the file header after Touch ID. The payload must open with the file key
// from the header, so the header and the payload are one file.
func repair() {
    guard let blob = FileManager.default.contents(atPath: vaultPath) else { fail("no store file: nothing to repair", 3) }
    withStoreLock {
        do {
            let (h, aad, sealed) = try splitFile(blob)
            try requirePresence(h.wm, fileKeyName, h.se)
            let c = LAContext()
            c.localizedReason = "repair the secret store"
            #if SECRET_TEST
            guard confirm(c, "repair the secret store") else { fail("not confirmed", 5) }
            #endif
            guard let m = try? unseal(h.wm, fileKeyName, h.se, c) else { fail("not confirmed", 5) }
            let d = try openPayload(sealed, aad, SymmetricKey(data: m))
            try storeKeys(VaultKeys(m: m, pub: h.pub, se: h.se, grace: defaultGrace), new: true)
            print("repair: a new key item, \(d.items.count) secrets, grace \(defaultGrace)s")
        } catch { fail(vaultMessage(error)) }
    }
}

// MARK: main

let args = CommandLine.arguments
guard args.count >= 2 else { usage() }

#if !SECRET_TEST
// No keychain window in this process: kSecUseAuthenticationUIFail does not stop the password
// window for a key item that another program changed (live check 017). Touch ID is not a
// keychain window and stays.
SecKeychainSetUserInteractionAllowed(false)
#endif

func checkName(_ n: String) {
    guard n.range(of: "^[A-Za-z_][A-Za-z0-9_.-]*$", options: .regularExpression) != nil else { fail("bad name: \(n)", 64) }
}

func isReserved(_ n: String) -> Bool { n.hasPrefix("__secret-cli.") }

func checkUserName(_ n: String) {
    checkName(n)
    guard !isReserved(n) else { fail("reserved name: \(n)", 64) }
}

switch args[1] {
case "agent":
    Agent().run()

case "list":
    for it in (doc()?.0.items ?? []).sorted(by: { $0.n.utf8.lexicographicallyPrecedes($1.n.utf8) }) {
        let c = it.c.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ")
        print("\(it.n)\t\(c.isEmpty ? "-" : c)\t\(it.x.isEmpty ? "-" : it.x)")
    }

case "has":
    guard args.count == 3 else { usage() }
    exit(doc()?.0.items.contains { $0.n == args[2] } == true ? 0 : 3)

case "read":
    guard args.count >= 4 else { usage() }
    let names = Array(args[3...])
    names.forEach(checkUserName)
    let values = request(["read", noDialog ? "1" : "0", hex(args[2]), names.map { hex($0) }.joined(separator: ",")].joined(separator: "\t"))
    for v in (values.first ?? "").split(separator: ",", omittingEmptySubsequences: false) {
        // a value is one line: print it as hex, bash decodes it
        print(v == "-" ? "" : v)
    }

case "write":
    // stdin: hex(name) hex(value) hex(comment) hex(expiry) per line
    var records = [(String, Data, String, String)]()
    while let line = Swift.readLine() {
        let f = line.split(separator: " ")
        guard f.count == 4, let name = unhexText(f[0]), let value = unhex(f[1]), let comment = unhexText(f[2]),
              let expiry = unhexText(f[3]) else { fail("bad write record", 64) }
        checkUserName(name)
        guard !value.isEmpty else { fail("empty value: \(name)", 64) }
        records.append((name, value, comment, expiry))
    }
    mutate { d, k in
        for (n, v, c, e) in records {
            d.items.removeAll { $0.n == n }
            d.items.append(VaultItem(n: n, c: c, x: e, v: try seal(v, n, k.pub), r: UUID().uuidString))
        }
    }

case "attrs":
    // the file key opens the comment and the expiry: no Touch ID
    guard args.count == 6 else { usage() }
    checkUserName(args[3])
    guard doc() != nil else { fail("not found: \(args[3])", 3) }
    mutate { d, _ in
        guard let i = d.items.firstIndex(where: { $0.n == args[3] }) else { throw AgentError(code: 3, message: "not found: \(args[3])") }
        d.items[i].c = args[4]
        d.items[i].x = args[5]
    }

case "delete":
    guard args.count >= 3 else { usage() }
    args[2...].forEach(checkUserName)
    guard doc() != nil else { exit(3) }
    var missing = false
    mutate { d, _ in
        for n in args[2...] {
            if d.items.contains(where: { $0.n == n }) { d.items.removeAll { $0.n == n } } else { missing = true }
        }
    }
    if missing { exit(3) }

case "policy":
    guard args.count >= 3 else { usage() }
    switch args[2] {
    case "show":
        if let g = vaultGrace() { print("grace=\(g)") } else { print("none") }
    case "init":
        // the first policy of an empty store; an existing one is kept
        let g = args.count > 3 ? Int(args[3]) ?? defaultGrace : defaultGrace
        guard g >= 0, g <= maxGrace else { fail("grace must be 0..\(maxGrace)", 64) }
        if vaultGrace() == nil {
            mutate { d, _ in
                guard d.items.isEmpty else {
                    throw AgentError(code: 1, message: "the store has secrets but no policy: secret touchid grace N sets it")
                }
            }
            setGrace(g)
        }
    case "grace":
        guard args.count == 4, let g = Int(args[3]), g >= 0 else { usage() }
        guard g <= maxGrace else { fail("grace must be 0..\(maxGrace)", 64) }
        guard !noDialog else { fail("Touch ID confirmation needed, SECRET_NO_DIALOG is set", 5) }
        if doc() == nil { mutate { _, _ in } }
        if case .failure(let e) = confirmedContext("change the Touch ID time for secret") { fail(e.message, e.code) }
        setGrace(g)
        stopAgent()
    default: usage()
    }

case "lock":
    stopAgent()

case "repair":
    // a new key item from the store file, after Touch ID (017)
    guard !noDialog else { fail("Touch ID confirmation needed, SECRET_NO_DIALOG is set", 5) }
    repair()
    stopAgent()

case "ping":
    // opens the file: a damaged file or a changed key item stops each command here (017)
    _ = doc()
    print("ok")

case "clip":
    // The value from stdin to the clipboard, marked org.nspasteboard.ConcealedType: clipboard
    // managers (Raycast, Alfred, Paste) do not keep it in their history (014). Empty stdin clears.
    let text = String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)
    #if SECRET_TEST
    guard let pbName = testEnv["SECRET_TEST_PASTEBOARD"] else { fail("test build: SECRET_TEST_PASTEBOARD is needed", 64) }
    let pb = NSPasteboard(name: NSPasteboard.Name(pbName))
    #else
    let pb = NSPasteboard.general
    #endif
    pb.clearContents()
    if !text.isEmpty {
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        item.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        guard pb.writeObjects([item]) else { fail("cannot write the clipboard") }
    }

case "status":
    // One line for SecretBar (014): "ok off grace=N" or "ok active LEFT IDLE LIMIT grace=N".
    // It does not start the agent.
    var g = "off"
    if let fd = connectAgent() {
        if writeLine(fd, "status"), let a = readLine(fd) {
            let f = a.split(separator: "\t")
            if f.count >= 5, f[1] == "active" { g = "active \(f[2]) \(f[3]) \(f[4])" }
        }
        close(fd)
    }
    let policy = vaultGrace().map { "grace=\($0)" } ?? "grace=none"
    print("ok \(g) \(policy)")

case "kind":
    // bin/secret takes a replaced helper only when it is a test build (013)
    #if SECRET_TEST
    print("test")
    #else
    print("release")
    #endif

case "grace-status":
    // the state of the agent; a missing agent is no grace, and this command does not start one
    guard let fd = connectAgent() else { print("off"); exit(0) }
    defer { close(fd) }
    guard writeLine(fd, "status"), let answer = readLine(fd) else { print("off"); exit(0) }
    print(answer.split(separator: "\t").dropFirst().joined(separator: " "))


#if SECRET_TEST
case "test-lock":
    DistributedNotificationCenter.default().postNotificationName(testLockNotification, object: nil, userInfo: nil, deliverImmediately: true)

case "test-paste":
    // test build only: the string and the concealed mark of the test pasteboard
    guard let pbName = testEnv["SECRET_TEST_PASTEBOARD"] else { fail("SECRET_TEST_PASTEBOARD is needed", 64) }
    let pb = NSPasteboard(name: NSPasteboard.Name(pbName))
    let concealed = pb.types?.contains(NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")) ?? false
    print("\(concealed ? "concealed" : "plain") \(pb.string(forType: .string) ?? "")")

case "wipe":
    stopAgent()
    for f in [vaultPath, vaultPath + ".prev", vaultPath + ".lock", vaultPath + ".new", keyFile] { unlink(f) }
#endif

default:
    usage()
}
