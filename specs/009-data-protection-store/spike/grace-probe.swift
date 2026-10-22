import Foundation
import LocalAuthentication
import Security

let service = "secret-cli-dp-probe"
func q(_ extra: [String: Any]) -> CFDictionary {
    ([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
      kSecUseDataProtectionKeychain as String: true] as [String: Any]).merging(extra) { $1 } as CFDictionary
}
setvbuf(stdout, nil, _IOLBF, 0)
SecItemDelete(q([:]))
var err: Unmanaged<CFError>?
let ac = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenUnlockedThisDeviceOnly, .userPresence, &err)!
print("add:", SecItemAdd(q([kSecAttrAccount as String: "a", kSecValueData as String: Data("v1".utf8), kSecAttrAccessControl as String: ac]), nil))
let ctx = LAContext(); ctx.interactionNotAllowed = false
let sem = DispatchSemaphore(value: 0); var ok = false
ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "secret-cli grace probe: one prompt, reads for 5 minutes") { o, _ in ok = o; sem.signal() }
sem.wait(); print("evaluate:", ok, Date())
// After the prompt, no more UI: a read that needs a new prompt fails instead of asking.
ctx.interactionNotAllowed = true
var last = 0
for t in [10, 120, 290] {
    sleep(UInt32(t - last)); last = t
    var out: CFTypeRef?
    let r = SecItemCopyMatching(q([kSecAttrAccount as String: "a", kSecReturnData as String: true, kSecUseAuthenticationContext as String: ctx]), &out)
    print("read at \(t)s:", r, (out as? Data).map { String(decoding: $0, as: UTF8.self) } ?? "-")
}
print("cleanup:", SecItemDelete(q([:])))
