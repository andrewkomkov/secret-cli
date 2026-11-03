// secret-cookies: reads Safari Cookies.binarycookies (027). Only `value` prints a value.
//   list DOMAIN               name<TAB>path<TAB>flags<TAB>expiry
//   value DOMAIN NAME [PATH]  the value of one cookie on stdout
//   path                      the file that is read
// Exit: 1 not found, 3 several match (paths on stderr), 64 usage, 65 bad file, 77 no access.
import Foundation

#if SECRET_TEST
let cookiesPath = ProcessInfo.processInfo.environment["SECRET_TEST_COOKIES"] ?? "/nonexistent/Cookies.binarycookies"
#else
let cookiesPath = NSHomeDirectory() + "/Library/Containers/com.apple.Safari/Data/Library/Cookies/Cookies.binarycookies"
#endif

func fail(_ message: String, _ code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data(("secret-cookies: " + message + "\n").utf8))
    exit(code)
}

struct Cookie {
    var domain: String
    var name: String
    var path: String
    var value: String
    var secure: Bool
    var httpOnly: Bool
    var expiry: Double? // Unix time, nil for a cookie without a date
}

// Every read is bounds-checked: a damaged file ends in an error, not a crash.
struct Reader {
    let d: [UInt8]
    func u32le(_ o: Int) -> Int? {
        guard o >= 0, o + 4 <= d.count else { return nil }
        return Int(d[o]) | Int(d[o + 1]) << 8 | Int(d[o + 2]) << 16 | Int(d[o + 3]) << 24
    }
    func u32be(_ o: Int) -> Int? {
        guard o >= 0, o + 4 <= d.count else { return nil }
        return Int(d[o]) << 24 | Int(d[o + 1]) << 16 | Int(d[o + 2]) << 8 | Int(d[o + 3])
    }
    func f64le(_ o: Int) -> Double? {
        guard o >= 0, o + 8 <= d.count else { return nil }
        var bits: UInt64 = 0
        for i in 0..<8 { bits |= UInt64(d[o + i]) << UInt64(8 * i) }
        return Double(bitPattern: bits)
    }
    func cstr(_ o: Int, limit: Int) -> String? {
        guard o >= 0, o < limit, limit <= d.count else { return nil }
        var e = o
        while e < limit && d[e] != 0 { e += 1 }
        guard e < limit else { return nil }
        return String(decoding: d[o..<e], as: UTF8.self)
    }
}

let macEpochOffset = 978307200.0

func parse(_ bytes: [UInt8]) -> [Cookie]? {
    let r = Reader(d: bytes)
    guard bytes.count >= 8, bytes[0] == 0x63, bytes[1] == 0x6f, bytes[2] == 0x6f, bytes[3] == 0x6b, // "cook"
          let pages = r.u32be(4), pages < 100000 else { return nil }
    var sizes: [Int] = []
    for i in 0..<pages {
        guard let s = r.u32be(8 + 4 * i) else { return nil }
        sizes.append(s)
    }
    var out: [Cookie] = []
    var pageStart = 8 + 4 * pages
    for size in sizes {
        let pageEnd = pageStart + size
        guard size >= 8, pageEnd <= bytes.count else { return nil }
        guard r.u32be(pageStart) == 0x00000100, let count = r.u32le(pageStart + 4),
              pageStart + 8 + 4 * count <= pageEnd else { return nil }
        for i in 0..<count {
            guard let off = r.u32le(pageStart + 8 + 4 * i) else { return nil }
            let rec = pageStart + off
            // record: size, 4 unknown, flags, 4 unknown, offsets of domain, name, path, value,
            // 8 bytes end of comment, expiry and creation date as float64
            guard let rsize = r.u32le(rec), rsize >= 56, rec + rsize <= pageEnd,
                  let flags = r.u32le(rec + 8),
                  let od = r.u32le(rec + 16), let on = r.u32le(rec + 20),
                  let op = r.u32le(rec + 24), let ov = r.u32le(rec + 28),
                  let exp = r.f64le(rec + 40) else { return nil }
            let lim = rec + rsize
            guard let domain = r.cstr(rec + od, limit: lim), let name = r.cstr(rec + on, limit: lim),
                  let path = r.cstr(rec + op, limit: lim), let value = r.cstr(rec + ov, limit: lim) else { return nil }
            let unix = exp + macEpochOffset
            out.append(Cookie(domain: domain, name: name, path: path, value: value,
                              secure: flags & 1 != 0, httpOnly: flags & 4 != 0,
                              expiry: (exp > 0 && unix.isFinite && unix < 4e11) ? unix : nil))
        }
        pageStart = pageEnd
    }
    return out
}

func loadCookies() -> [Cookie] {
    let fd = open(cookiesPath, O_RDONLY)
    if fd < 0 {
        if errno == EPERM || errno == EACCES { fail("no access to \(cookiesPath)", 77) }
        if errno == ENOENT { fail("no cookie file: \(cookiesPath)", 1) }
        fail("cannot open \(cookiesPath): \(String(cString: strerror(errno)))", 1)
    }
    let h = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    var data = Data()
    do { data = try h.readToEnd() ?? Data() } catch {
        let code = (error as NSError).code
        if code == Int(EPERM) || code == Int(EACCES) { fail("no access to \(cookiesPath)", 77) }
        fail("cannot read \(cookiesPath)", 1)
    }
    guard let cookies = parse([UInt8](data)) else { fail("not a Cookies.binarycookies file: \(cookiesPath)", 65) }
    return cookies
}

// Like a browser: ".example.com" covers example.com and its subdomains, "example.com" that host only.
func matches(_ c: Cookie, _ query: String) -> Bool {
    var q = query.lowercased()
    if q.hasPrefix(".") { q.removeFirst() }
    let d = c.domain.lowercased()
    if d.hasPrefix(".") {
        let base = String(d.dropFirst())
        return q == base || q.hasSuffix("." + base)
    }
    return q == d
}

func flagsText(_ c: Cookie) -> String {
    var f: [String] = []
    if c.secure { f.append("Secure") }
    if c.httpOnly { f.append("HTTPOnly") }
    return f.isEmpty ? "-" : f.joined(separator: ",")
}

func dateText(_ c: Cookie) -> String {
    guard let e = c.expiry else { return "-" }
    var t = time_t(e)
    var tmv = tm()
    gmtime_r(&t, &tmv)
    return String(format: "%04d-%02d-%02d", Int(tmv.tm_year) + 1900, Int(tmv.tm_mon) + 1, Int(tmv.tm_mday))
}

func clean(_ s: String) -> String {
    String(s.map { $0 == "\t" || $0 == "\n" || $0 == "\r" ? " " : $0 })
}

func err(_ s: String) { FileHandle.standardError.write(Data((s + "\n").utf8)) }

let args = Array(CommandLine.arguments.dropFirst())
switch args.first {
case "list" where args.count == 2:
    for c in loadCookies() where matches(c, args[1]) {
        print([clean(c.name), clean(c.path), flagsText(c), dateText(c)].joined(separator: "\t"))
    }
case "value" where args.count == 3 || args.count == 4:
    let found = loadCookies().filter { matches($0, args[1]) && $0.name == args[2] && (args.count == 3 || $0.path == args[3]) }
    if found.isEmpty { fail("no cookie \(clean(args[2])) for \(clean(args[1]))", 1) }
    if found.count > 1 {
        let hint = args.count == 3 ? "give PATH" : "same path in several domains"
        err("secret-cookies: \(found.count) cookies \(clean(args[2])) for \(clean(args[1])), \(hint):")
        for c in found { err("  \(clean(c.path))\t\(clean(c.domain))") }
        exit(3)
    }
    FileHandle.standardOutput.write(Data(found[0].value.utf8))
case "path" where args.count == 1:
    print(cookiesPath)
default:
    fail("usage: secret-cookies list DOMAIN | value DOMAIN NAME [PATH] | path", 64)
}
