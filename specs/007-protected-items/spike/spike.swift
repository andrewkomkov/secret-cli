import Foundation
import Security
func die(_ m: String) -> Never { FileHandle.standardError.write(Data((m + "\n").utf8)); exit(1) }
SecKeychainSetUserInteractionAllowed(false)
let a = CommandLine.arguments
var kc: SecKeychain?
guard SecKeychainOpen(a[2], &kc) == errSecSuccess, let keychain = kc else { die("open") }
let svc = a[3], acct = "secret-cli"
switch a[1] {
case "create":
    let value = Array((readLine() ?? "").utf8)
    var trusted: SecTrustedApplication?
    guard SecTrustedApplicationCreateFromPath(nil, &trusted) == errSecSuccess, let t = trusted else { die("trusted") }
    var access: SecAccess?
    guard SecAccessCreate(svc as CFString, [t] as CFArray, &access) == errSecSuccess, let acc = access else { die("access") }
    var item: SecKeychainItem?
    let r = SecKeychainAddGenericPassword(keychain, UInt32(svc.utf8.count), svc, UInt32(acct.utf8.count), acct, UInt32(value.count), value, &item)
    guard r == errSecSuccess, let it = item else { die("add \(r)") }
    let r2 = SecKeychainItemSetAccess(it, acc)
    guard r2 == errSecSuccess else { die("setaccess \(r2)") }
    print("created")
case "read":
    var len: UInt32 = 0; var data: UnsafeMutableRawPointer?
    let r = SecKeychainFindGenericPassword(keychain, UInt32(svc.utf8.count), svc, UInt32(acct.utf8.count), acct, &len, &data, nil)
    guard r == errSecSuccess, let d = data else { die("read \(r)") }
    print(String(decoding: Data(bytes: d, count: Int(len)), as: UTF8.self))
    SecKeychainItemFreeContent(nil, d)
case "delete":
    var item: SecKeychainItem?
    let r = SecKeychainFindGenericPassword(keychain, UInt32(svc.utf8.count), svc, UInt32(acct.utf8.count), acct, nil, nil, &item)
    guard r == errSecSuccess, let it = item else { die("find \(r)") }
    let r2 = SecKeychainItemDelete(it); print("delete \(r2)")
case "attr":
    var item: SecKeychainItem?
    let r = SecKeychainFindGenericPassword(keychain, UInt32(svc.utf8.count), svc, UInt32(acct.utf8.count), acct, nil, nil, &item)
    guard r == errSecSuccess, let it = item else { die("find \(r)") }
    var bytes = Array(a[4].utf8)
    let r2: OSStatus = bytes.withUnsafeMutableBytes { buf in
        var attr = SecKeychainAttribute(tag: SecItemAttr.commentItemAttr.rawValue, length: UInt32(buf.count), data: buf.baseAddress)
        return withUnsafeMutablePointer(to: &attr) { p in
            var list = SecKeychainAttributeList(count: 1, attr: p)
            return SecKeychainItemModifyAttributesAndData(it, &list, 0, nil)
        }
    }
    print("attr \(r2)")
default: die("cmd")
}
// rebuild 1790943532
