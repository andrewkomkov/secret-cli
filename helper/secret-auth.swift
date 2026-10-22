// secret-auth: единственный читатель защищённых записей secret, Touch ID и статус keychain.
// Запись, которую создал helper, без окна читает только он (ACL создателя, research R1).
import CryptoKit
import Foundation
import LocalAuthentication
import Security

let account = "secret-cli"
let policyName = "__secret-cli.policy"

func fail(_ message: String, _ code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data(("secret-auth: " + message + "\n").utf8))
    exit(code)
}

func usage() -> Never {
    fail("""
        usage: secret-auth status KC | auth REASON | read KC REASON NAME... | owner KC NAME...
               write KC NAME [--comment C] [--expiry D]
               attrs KC NAME [--comment C] [--expiry D] | delete KC NAME | policy init|grace|remove|show KC [N]
        """, 64)
}

func hex(_ data: Data) -> String { data.map { String(format: "%02x", $0) }.joined() }

// MARK: keychain

func openKeychain(_ path: String) -> SecKeychain {
    var kc: SecKeychain?
    guard SecKeychainOpen(path, &kc) == errSecSuccess, let keychain = kc else { fail("cannot open \(path)", 2) }
    return keychain
}

func findItem(_ kc: SecKeychain, _ name: String) -> SecKeychainItem? {
    var item: SecKeychainItem?
    let r = SecKeychainFindGenericPassword(kc, UInt32(name.utf8.count), name, UInt32(account.utf8.count), account, nil, nil, &item)
    return r == errSecSuccess ? item : nil
}

enum ReadResult { case value(Data), missing, foreign, error(OSStatus) }

// With UI off, only the creator of the item gets the data (research R5).
func readItem(_ kc: SecKeychain, _ name: String) -> ReadResult {
    var length: UInt32 = 0
    var data: UnsafeMutableRawPointer?
    let r = SecKeychainFindGenericPassword(kc, UInt32(name.utf8.count), name, UInt32(account.utf8.count), account, &length, &data, nil)
    switch r {
    case errSecSuccess:
        guard let d = data else { return .value(Data()) }
        let value = Data(bytes: d, count: Int(length))
        SecKeychainItemFreeContent(nil, d)
        return .value(value)
    case errSecItemNotFound: return .missing
    case errSecAuthFailed, errSecInteractionNotAllowed: return .foreign
    default: return .error(r)
    }
}

func setAttributes(_ item: SecKeychainItem, _ attrs: [(SecItemAttr, String)], data: Data? = nil) -> OSStatus {
    var buffers = [UnsafeMutableRawPointer]()
    defer { buffers.forEach { $0.deallocate() } }
    var list = [SecKeychainAttribute]()
    for (tag, text) in attrs {
        let bytes = Array(text.utf8)
        var pointer: UnsafeMutableRawPointer?
        if !bytes.isEmpty {
            let p = UnsafeMutableRawPointer.allocate(byteCount: bytes.count, alignment: 1)
            p.copyMemory(from: bytes, byteCount: bytes.count)
            buffers.append(p)
            pointer = p
        }
        list.append(SecKeychainAttribute(tag: tag.rawValue, length: UInt32(bytes.count), data: pointer))
    }
    return list.withUnsafeMutableBufferPointer { lp in
        var attrList = SecKeychainAttributeList(count: UInt32(lp.count), attr: lp.baseAddress)
        if let d = data {
            return d.withUnsafeBytes { db in
                SecKeychainItemModifyAttributesAndData(item, &attrList, UInt32(d.count), db.baseAddress)
            }
        }
        return SecKeychainItemModifyAttributesAndData(item, &attrList, 0, nil)
    }
}

func addItem(_ kc: SecKeychain, _ name: String, _ value: Data) -> SecKeychainItem {
    var item: SecKeychainItem?
    let r = value.withUnsafeBytes { vb in
        SecKeychainAddGenericPassword(kc, UInt32(name.utf8.count), name, UInt32(account.utf8.count), account,
                                      UInt32(value.count), vb.baseAddress!, &item)
    }
    guard r == errSecSuccess, let it = item else { fail("cannot add \(name): \(r)") }
    return it
}

func attrList(comment: String, expiry: String) -> [(SecItemAttr, String)] {
    [(.descriptionItemAttr, "secret-cli"), (.commentItemAttr, comment), (.genericItemAttr, expiry.isEmpty ? "" : "expires=" + expiry)]
}

// Write NAME. A foreign item (created by another app) is replaced: NAME#new, delete the old one, rename.
func writeItem(_ kc: SecKeychain, _ name: String, _ value: Data, comment: String, expiry: String) {
    let attrs = attrList(comment: comment, expiry: expiry)
    switch readItem(kc, name) {
    case .missing:
        let item = addItem(kc, name, value)
        guard setAttributes(item, attrs) == errSecSuccess else { fail("cannot set attributes of \(name)") }
    case .value:
        guard let item = findItem(kc, name), setAttributes(item, attrs, data: value) == errSecSuccess else {
            fail("cannot update \(name)")
        }
    case .foreign:
        let temp = name + "#new"
        if let stale = findItem(kc, temp) { SecKeychainItemDelete(stale) }
        let item = addItem(kc, temp, value)
        guard setAttributes(item, attrs) == errSecSuccess else { fail("cannot set attributes of \(temp)") }
        guard case .value(let check) = readItem(kc, temp), check == value else { fail("cannot verify \(temp)") }
        guard let old = findItem(kc, name), SecKeychainItemDelete(old) == errSecSuccess else { fail("cannot delete the old \(name), \(temp) is kept") }
        guard setAttributes(item, [(.serviceItemAttr, name)]) == errSecSuccess else { fail("cannot rename \(temp) to \(name)") }
    case .error(let r):
        fail("cannot read \(name): \(r)")
    }
}

// MARK: Touch ID, policy, grace

#if SECRET_TEST
// Test build only: the answer comes from a file. The release build has no such path.
func confirm(_ reason: String) -> Bool {
    let env = ProcessInfo.processInfo.environment
    if let log = env["SECRET_TEST_AUTH_LOG"], let h = FileHandle(forWritingAtPath: log) ?? {
        FileManager.default.createFile(atPath: log, contents: nil); return FileHandle(forWritingAtPath: log) }() {
        h.seekToEndOfFile(); h.write(Data((reason + "\n").utf8)); h.closeFile()
    }
    guard let file = env["SECRET_TEST_AUTH"], let answer = try? String(contentsOfFile: file, encoding: .utf8) else { return false }
    return answer.trimmingCharacters(in: .whitespacesAndNewlines) == "allow"
}
#else
func confirm(_ reason: String) -> Bool {
    let context = LAContext()
    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
        fail("Touch ID and the Mac password are not available: \(error?.localizedDescription ?? "")", 2)
    }
    let done = DispatchSemaphore(value: 0)
    var granted = false
    context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { ok, _ in
        granted = ok
        done.signal()
    }
    done.wait()
    return granted
}
#endif

struct Policy { var grace: Int; var key: Data }

func parsePolicy(_ data: Data) -> Policy? {
    var grace: Int?
    var key: Data?
    for field in String(decoding: data, as: UTF8.self).split(separator: " ") {
        let kv = field.split(separator: "=", maxSplits: 1).map(String.init)
        guard kv.count == 2 else { continue }
        if kv[0] == "grace" { grace = Int(kv[1]) }
        if kv[0] == "key" {
            var bytes = [UInt8]()
            var s = Substring(kv[1])
            while s.count >= 2 { if let b = UInt8(s.prefix(2), radix: 16) { bytes.append(b) }; s = s.dropFirst(2) }
            key = Data(bytes)
        }
    }
    guard let g = grace, let k = key, k.count == 32 else { return nil }
    return Policy(grace: g, key: k)
}

func encodePolicy(_ p: Policy) -> Data { Data("v1 grace=\(p.grace) key=\(hex(p.key))".utf8) }

// A missing or foreign policy gives no grace: Touch ID every time.
func loadPolicy(_ kc: SecKeychain) -> Policy? {
    if case .value(let d) = readItem(kc, policyName) { return parsePolicy(d) }
    return nil
}

func stampPath() -> String {
    #if SECRET_TEST
    if let p = ProcessInfo.processInfo.environment["SECRET_AUTH_STAMP"] { return p }
    #endif
    return NSHomeDirectory() + "/.local/state/secret/touchid-ok"
}

func stampMAC(_ key: Data, _ time: Int, _ kcPath: String) -> String {
    hex(Data(HMAC<SHA256>.authenticationCode(for: Data("\(time)|\(kcPath)".utf8), using: SymmetricKey(data: key))))
}

func stampValid(_ p: Policy, _ kcPath: String) -> Bool {
    guard p.grace > 0, let text = try? String(contentsOfFile: stampPath(), encoding: .utf8) else { return false }
    let parts = text.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ").map(String.init)
    guard parts.count == 2, let t = Int(parts[0]) else { return false }
    let now = Int(Date().timeIntervalSince1970)
    return t <= now + 5 && now - t < p.grace && parts[1] == stampMAC(p.key, t, kcPath)
}

func writeStamp(_ p: Policy, _ kcPath: String) {
    let t = Int(Date().timeIntervalSince1970)
    let path = stampPath()
    try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    FileManager.default.createFile(atPath: path, contents: Data("\(t) \(stampMAC(p.key, t, kcPath))\n".utf8), attributes: [.posixPermissions: 0o600])
}

func authorize(_ kc: SecKeychain, _ kcPath: String, _ reason: String, fresh: Bool) {
    let policy = loadPolicy(kc)
    if !fresh, let p = policy, stampValid(p, kcPath) { return }
    if !(ProcessInfo.processInfo.environment["SECRET_NO_DIALOG"] ?? "").isEmpty {
        fail("Touch ID confirmation needed, SECRET_NO_DIALOG is set", 5)
    }
    guard confirm(reason) else { fail("not confirmed", 5) }
    if let p = policy { writeStamp(p, kcPath) }
}

func readValue(_ data: Data) -> Data {
    var d = data
    if d.last == 0x0a { d.removeLast() }
    return d
}

func options(_ args: ArraySlice<String>) -> (comment: String, expiry: String) {
    var comment = "", expiry = ""
    var i = args.startIndex
    while i < args.endIndex {
        switch args[i] {
        case "--comment" where i + 1 < args.endIndex: comment = args[i + 1]; i += 2
        case "--expiry" where i + 1 < args.endIndex: expiry = args[i + 1]; i += 2
        default: usage()
        }
    }
    return (comment, expiry)
}

// MARK: main

SecKeychainSetUserInteractionAllowed(false)
let args = CommandLine.arguments
guard args.count >= 3 else { usage() }

switch args[1] {
case "status":
    var status: SecKeychainStatus = 0
    let r = SecKeychainGetStatus(openKeychain(args[2]), &status)
    guard r == errSecSuccess else { fail("status error \(r)", 2) }
    print(status & UInt32(kSecUnlockStateStatus) != 0 ? "unlocked" : "locked")

case "auth":
    guard confirm(args[2]) else { fail("not confirmed", 1) }

case "read":
    guard args.count >= 5 else { usage() }
    let kc = openKeychain(args[2])
    var values = [Data]()
    for name in args[4...] {
        guard !name.hasPrefix("__secret-cli.") else { fail("reserved name: \(name)", 2) }
        switch readItem(kc, name) {
        case .value(let v): values.append(v)
        case .missing: fail("not found: \(name)", 3)
        case .foreign: fail("not protected: \(name) (another app created it)", 4)
        case .error(let r): fail("cannot read \(name): \(r)")
        }
    }
    authorize(kc, args[2], args[3], fresh: false)
    for v in values { print(hex(v)) }

case "owner":
    guard args.count >= 4 else { usage() }
    let kc = openKeychain(args[2])
    for name in args[3...] {
        switch readItem(kc, name) {
        case .value: print("mine")
        case .missing: print("missing")
        case .foreign: print("foreign")
        case .error(let r): fail("cannot check \(name): \(r)")
        }
    }

case "write":
    guard args.count >= 4 else { usage() }
    let o = options(args[4...])
    let value = readValue(FileHandle.standardInput.readDataToEndOfFile())
    guard !value.isEmpty else { fail("empty value", 2) }
    writeItem(openKeychain(args[2]), args[3], value, comment: o.comment, expiry: o.expiry)

case "attrs":
    guard args.count >= 4 else { usage() }
    let o = options(args[4...])
    guard let item = findItem(openKeychain(args[2]), args[3]) else { fail("not found: \(args[3])", 3) }
    guard setAttributes(item, attrList(comment: o.comment, expiry: o.expiry)) == errSecSuccess else { fail("cannot set attributes") }

case "delete":
    guard args.count >= 4 else { usage() }
    guard let item = findItem(openKeychain(args[2]), args[3]) else { fail("not found: \(args[3])", 3) }
    guard SecKeychainItemDelete(item) == errSecSuccess else { fail("cannot delete \(args[3])") }

case "policy":
    guard args.count >= 4 else { usage() }
    let kcPath = args[3]
    let kc = openKeychain(kcPath)
    switch args[2] {
    case "init":
        let grace = args.count > 4 ? (Int(args[4]) ?? 300) : 300
        authorize(kc, kcPath, "turn on Touch ID for secret", fresh: true)
        var key = Data(count: 32)
        guard key.withUnsafeMutableBytes({ SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }) == errSecSuccess else { fail("no random bytes") }
        let p = Policy(grace: grace, key: key)
        writeItem(kc, policyName, encodePolicy(p), comment: "secret-cli: Touch ID policy", expiry: "")
        writeStamp(p, kcPath)
    case "grace":
        guard args.count > 4, let grace = Int(args[4]), grace >= 0 else { usage() }
        authorize(kc, kcPath, "change the Touch ID time for secret", fresh: true)
        let key = loadPolicy(kc)?.key ?? {
            var k = Data(count: 32); _ = k.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }; return k }()
        writeItem(kc, policyName, encodePolicy(Policy(grace: grace, key: key)), comment: "secret-cli: Touch ID policy", expiry: "")
    case "remove":
        authorize(kc, kcPath, "turn off Touch ID for secret", fresh: true)
        if let item = findItem(kc, policyName) { SecKeychainItemDelete(item) }
        try? FileManager.default.removeItem(atPath: stampPath())
    case "show":
        if findItem(kc, policyName) == nil { print("none") }
        else if let p = loadPolicy(kc) { print("grace=\(p.grace)") }
        else { print("damaged") }
    default: usage()
    }

default:
    usage()
}
