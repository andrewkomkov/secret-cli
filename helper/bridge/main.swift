// secret-bridge (030): loopback daemon that takes a Netscape cookie jar from the Safari extension
// and passes it to `secret cookie import --as NAME` on stdin.
//   POST /jar?as=NAME   header X-Secret-Token: TOKEN   body: the jar
// Listens on 127.0.0.1 only. Does not log or print the body.
import Foundation
import Darwin

let defaultPort = 17659
let maxBody = 4 * 1024 * 1024

func fail(_ msg: String, _ code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data("secret-bridge: \(msg)\n".utf8))
    exit(code)
}

let env = ProcessInfo.processInfo.environment
let home = env["HOME"] ?? NSHomeDirectory()
let statePath = env["SECRET_BRIDGE_STATE"] ?? "\(home)/.local/state/secret/bridge.json"
let pidPath = (statePath as NSString).deletingPathExtension + ".pid"

struct State { var token: String; var port: Int? }

func readState() -> State? {
    guard let data = FileManager.default.contents(atPath: statePath),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let token = obj["token"] as? String, !token.isEmpty else { return nil }
    return State(token: token, port: obj["port"] as? Int)
}

guard let state = readState() else { fail("no token in \(statePath): run secret cookie bridge token", 2) }
var port = defaultPort
if let p = state.port, p > 0 && p < 65536 { port = p }
if let e = env["SECRET_BRIDGE_PORT"], let p = Int(e), p > 0 && p < 65536 { port = p }
let secretBin = env["SECRET_BIN"] ?? "secret"

if CommandLine.arguments.dropFirst().contains("--check") {
    print("ok \(port)")
    exit(0)
}

func ctEqual(_ a: String, _ b: String) -> Bool {
    let x = Array(a.utf8), y = Array(b.utf8)
    var diff = x.count ^ y.count
    for i in 0..<max(x.count, y.count) {
        diff |= Int(i < x.count ? x[i] : 0) ^ Int(i < y.count ? y[i] : 0)
    }
    return diff == 0
}

func send(_ fd: Int32, _ status: Int, _ text: String) {
    let reasons: [Int: String] = [200: "OK", 204: "No Content", 400: "Bad Request", 401: "Unauthorized",
                                  403: "Forbidden", 404: "Not Found", 405: "Method Not Allowed",
                                  413: "Payload Too Large", 422: "Unprocessable Entity"]
    let reason = reasons[status] ?? "Error"
    let body = text.isEmpty ? "" : text + "\n"
    let head = "HTTP/1.1 \(status) \(reason)\r\nContent-Type: text/plain\r\nContent-Length: \(body.utf8.count)\r\n"
        + "Access-Control-Allow-Origin: *\r\nAccess-Control-Allow-Headers: X-Secret-Token, Content-Type\r\n"
        + "Access-Control-Allow-Methods: POST, OPTIONS\r\nConnection: close\r\n\r\n" + body
    let bytes = Array(head.utf8)
    var off = 0
    while off < bytes.count {
        let n = bytes.withUnsafeBufferPointer { write(fd, $0.baseAddress! + off, bytes.count - off) }
        if n <= 0 { break }
        off += n
    }
}

func peerIsLoopback(_ fd: Int32) -> Bool {
    var addr = sockaddr_in()
    var len = socklen_t(MemoryLayout<sockaddr_in>.size)
    let rc = withUnsafeMutablePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getpeername(fd, $0, &len) }
    }
    return rc == 0 && addr.sin_family == sa_family_t(AF_INET) && UInt32(bigEndian: addr.sin_addr.s_addr) == 0x7F00_0001
}

func validName(_ s: String) -> Bool {
    return s.range(of: "^[A-Za-z_][A-Za-z0-9_.-]*$", options: .regularExpression) != nil
}

func runImport(name: String, jar: Data) -> Bool {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    p.arguments = [secretBin, "cookie", "import", "--as", name]
    let inPipe = Pipe()
    p.standardInput = inPipe
    p.standardOutput = FileHandle.nullDevice
    p.standardError = FileHandle.nullDevice
    do { try p.run() } catch { return false }
    inPipe.fileHandleForWriting.write(jar)
    try? inPipe.fileHandleForWriting.close()
    p.waitUntilExit()
    return p.terminationStatus == 0
}

func handle(_ fd: Int32) {
    defer { close(fd) }
    var tv = timeval(tv_sec: 15, tv_usec: 0)
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    guard peerIsLoopback(fd) else { send(fd, 403, "forbidden"); return }

    var buf = Data()
    var chunk = [UInt8](repeating: 0, count: 65536)
    let sep = Data("\r\n\r\n".utf8)
    var headEnd: Range<Data.Index>? = nil
    while headEnd == nil {
        let n = read(fd, &chunk, chunk.count)
        if n <= 0 { send(fd, 400, "bad request"); return }
        buf.append(chunk, count: n)
        headEnd = buf.range(of: sep)
        if headEnd == nil && buf.count > 16384 { send(fd, 400, "bad request"); return }
    }
    let headText = String(decoding: buf[buf.startIndex..<headEnd!.lowerBound], as: UTF8.self)
    var lines = headText.components(separatedBy: "\r\n")
    let reqLine = lines.removeFirst().split(separator: " ", omittingEmptySubsequences: true).map(String.init)
    guard reqLine.count >= 2 else { send(fd, 400, "bad request"); return }
    var headers: [String: String] = [:]
    for l in lines {
        guard let i = l.firstIndex(of: ":") else { continue }
        headers[l[l.startIndex..<i].lowercased()] = l[l.index(after: i)...].trimmingCharacters(in: .whitespaces)
    }
    let method = reqLine[0]
    let comps = URLComponents(string: "http://x" + reqLine[1])
    let path = comps?.path ?? ""

    if method == "OPTIONS" { send(fd, 204, ""); return }
    guard path == "/jar" else { send(fd, 404, "not found"); return }
    guard method == "POST" else { send(fd, 405, "method not allowed"); return }

    // DNS rebinding: the Host header must name the loopback address
    let host = (headers["host"] ?? "").split(separator: ":").first.map(String.init) ?? ""
    guard host == "127.0.0.1" || host == "localhost" else { send(fd, 403, "forbidden"); return }

    guard let tok = headers["x-secret-token"], !tok.isEmpty else { send(fd, 401, "token required"); return }
    guard ctEqual(tok, state.token) else { send(fd, 403, "bad token"); return }

    guard let name = comps?.queryItems?.first(where: { $0.name == "as" })?.value, validName(name) else {
        send(fd, 400, "bad or missing name"); return
    }
    guard let lenText = headers["content-length"], let len = Int(lenText), len > 0 else {
        send(fd, 400, "content-length required"); return
    }
    guard len <= maxBody else { send(fd, 413, "too large"); return }
    var body = Data(buf[headEnd!.upperBound...])
    while body.count < len {
        let n = read(fd, &chunk, chunk.count)
        if n <= 0 { send(fd, 400, "short body"); return }
        body.append(chunk, count: n)
    }
    body = Data(body.prefix(len))
    if runImport(name: name, jar: body) { send(fd, 200, "stored \(name)") }
    else { send(fd, 422, "import failed") }
}

signal(SIGPIPE, SIG_IGN)
let sock = socket(AF_INET, SOCK_STREAM, 0)
guard sock >= 0 else { fail("socket failed") }
var one: Int32 = 1
setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &one, socklen_t(MemoryLayout<Int32>.size))
var sa = sockaddr_in()
sa.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
sa.sin_family = sa_family_t(AF_INET)
sa.sin_port = in_port_t(UInt16(port).bigEndian)
sa.sin_addr.s_addr = UInt32(0x7F00_0001).bigEndian   // 127.0.0.1 only
let bound = withUnsafePointer(to: &sa) {
    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
}
guard bound == 0 else { fail("cannot bind 127.0.0.1:\(port)") }
guard listen(sock, 16) == 0 else { fail("listen failed") }

let fm = FileManager.default
try? fm.createDirectory(atPath: (pidPath as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
try? "\(getpid())\n".write(toFile: pidPath, atomically: true, encoding: .utf8)
chmod(pidPath, 0o600)

func stop() -> Never {
    try? fm.removeItem(atPath: pidPath)
    exit(0)
}
signal(SIGTERM, SIG_IGN)
signal(SIGINT, SIG_IGN)
let sigs = [SIGTERM, SIGINT].map { s -> DispatchSourceSignal in
    let src = DispatchSource.makeSignalSource(signal: s, queue: .main)
    src.setEventHandler { stop() }
    src.resume()
    return src
}
_ = sigs
print("listening on 127.0.0.1:\(port)")
fflush(stdout)

DispatchQueue.global().async {
    while true {
        let c = accept(sock, nil, nil)
        if c < 0 { continue }
        DispatchQueue.global().async { handle(c) }
    }
}
dispatchMain()
