// `SecretBar --snapshot DIR`: each screen to PNG, light and dark, with demo data (014). The demo
// store runs no command, so no real secret name gets into the pictures.
import AppKit
import SwiftUI

@MainActor
enum Snapshot {
    static func run(to dir: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let store = Store(demo: true)
        Navigation.shared.selection = "SHOP_DB_PASSWORD"
        let screens: [(String, AnyView, CGSize)] = [
            ("menubar", AnyView(MenuBarView().environmentObject(store)), CGSize(width: 380, height: 500)),
            ("quick", AnyView(QuickSearchView(close: {}).environmentObject(store).padding(30)), CGSize(width: 700, height: 480)),
            ("main", AnyView(MainWindow().environmentObject(store)), CGSize(width: 1080, height: 680)),
            ("activity", AnyView(ActivityView().environmentObject(store).frame(width: 640, height: 480)), CGSize(width: 640, height: 480)),
            ("settings", AnyView(SettingsView().environmentObject(store).frame(width: 640, height: 760)), CGSize(width: 640, height: 760)),
            ("editor", AnyView(EditorSheet(editing: nil).environmentObject(store)), CGSize(width: 480, height: 520)),
            ("hud", AnyView(HUDView(text: "BILLING_API_TOKEN скопирован · очистится через 30 с", symbol: "doc.on.clipboard.fill", error: false).padding(20)), CGSize(width: 520, height: 110)),
        ]
        // One theme per run (--theme dark|light), set before the first window: AppKit does not
        // redraw scroll views and forms when the appearance changes later.
        let dark = CommandLine.arguments.contains("dark")
        NSApp.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        for (name, view, size) in screens {
            render(view, size: size, dark: dark, to: "\(dir)/\(name)-\(dark ? "dark" : "light").png")
        }
        if !dark {
            Navigation.shared.sidebar = .settings
            render(AnyView(MainWindow().environmentObject(store)), size: CGSize(width: 1080, height: 680), dark: false, to: "\(dir)/main-settings-light.png")
        }
        // 015: an empty section (the search stays on top, no card) and a list of 300 secrets
        Navigation.shared.sidebar = .project("нет такого проекта")
        render(AnyView(MainWindow().environmentObject(store)), size: CGSize(width: 1080, height: 680), dark: dark, to: "\(dir)/main-empty-\(dark ? "dark" : "light").png")
        let many = Store(demo: true)
        many.secrets = (0..<300).map { Secret(name: "PROJECT\($0 % 30)_SERVICE_TOKEN_\($0)", comment: "project\($0 % 30): токен сервиса номер \($0)", expiry: $0 % 7 == 0 ? "2026-10-20" : "") }
        Navigation.shared.sidebar = .all
        Navigation.shared.selection = "PROJECT7_SERVICE_TOKEN_7"
        render(AnyView(MainWindow().environmentObject(many)), size: CGSize(width: 1080, height: 680), dark: dark, to: "\(dir)/main-many-\(dark ? "dark" : "light").png")
        print("snapshot: \(dir)")
    }

    // A real window off the screen: AppKit controls (fields, lists, pickers) draw only in a window.
    private static func render(_ view: AnyView, size: CGSize, dark: Bool, to path: String) {
        let window = NSWindow(contentRect: NSRect(origin: CGPoint(x: -20000, y: -20000), size: size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.backgroundColor = dark ? NSColor(white: 0.13, alpha: 1) : NSColor(white: 0.96, alpha: 1)
        let host = NSHostingView(rootView: view.frame(width: size.width, height: size.height)
            .preferredColorScheme(dark ? .dark : .light))
        host.appearance = window.appearance
        host.frame = NSRect(origin: .zero, size: size)
        host.wantsLayer = true
        window.contentView = host
        window.orderFrontRegardless()
        // let SwiftUI lay out and AppKit draw
        for _ in 0..<6 { RunLoop.main.run(until: Date().addingTimeInterval(0.15)) }
        host.layoutSubtreeIfNeeded()
        // the layer tree, as Core Animation composes it: cacheDisplay mixes the appearance of layers
        let scale: CGFloat = 2
        let w = Int(size.width * scale), h = Int(size.height * scale)
        guard let layer = host.layer,
              let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        ctx.setFillColor((dark ? NSColor(white: 0.12, alpha: 1) : NSColor(white: 0.97, alpha: 1)).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: scale, y: -scale)  // the layer tree of a flipped hosting view
        NSAppearance(named: dark ? .darkAqua : .aqua)?.performAsCurrentDrawingAppearance {
            layer.render(in: ctx)
        }
        guard let img = ctx.makeImage() else { return }
        try? NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        window.orderOut(nil)
    }
}
