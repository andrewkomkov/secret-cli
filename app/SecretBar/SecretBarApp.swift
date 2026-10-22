// SecretBar (012, 014): the menu bar icon with the grace state, the main window, the quick panel
// on ⌥⌘S and the Spotlight actions. `--selftest` checks the parsers, `--snapshot DIR [--theme
// dark]` draws every screen to PNG with demo data, `--spotlight-check` counts the items of the
// app in the Spotlight index (015), `--spotlight-clear` empties it to check the repair (016).
import AppKit
import CoreSpotlight
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        if args.contains("--spotlight-check") {
            SpotlightCheck.run()
            return
        }
        if args.contains("--spotlight-clear") {
            CSSearchableIndex.default().deleteAllSearchableItems { error in
                print(error.map { "spotlight: error \($0.localizedDescription)" } ?? "spotlight: cleared")
                exit(error == nil ? 0 : 1)
            }
            return
        }
        if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count {
            Task { @MainActor in
                Snapshot.run(to: args[i + 1])
                exit(0)
            }
            return
        }
        Task { @MainActor in
            HotKey.shared.action = { QuickPanel.shared.toggle() }
            Store.shared.hotKeyOK = HotKey.shared.register()
            SecretShortcuts.updateAppShortcutParameters()
        }
    }
}

@main
struct SecretBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @ObservedObject private var store = Store.shared

    init() {
        if CommandLine.arguments.contains("--selftest") { exit(SelfTest.run() ? 0 : 1) }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
        } label: {
            MenuIcon()
        }
        .menuBarExtraStyle(.window)

        Window("SecretBar", id: "main") {
            MainWindow()
                .environmentObject(store)
        }
        .defaultSize(width: 1080, height: 680)
        .defaultLaunchBehavior(.suppressed)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

// The label of the menu bar item. Its environment gives `openWindow` to the navigation at launch.
struct MenuIcon: View {
    @ObservedObject var store = Store.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: store.menuSymbol)
            .onAppear { Navigation.shared.openMain = { openWindow(id: "main") } }
    }
}

// Reads the index of this app only (CSSearchQuery sees the items of its own bundle). Prints
// "spotlight: N items" and exits 0 when N > 0. Names only, no values: the index has no values.
enum SpotlightCheck {
    static func run() {
        Task {
            guard let count = await SpotlightIndex.count() else { print("spotlight: error"); exit(2) }
            print("spotlight: \(count) items")
            exit(count > 0 ? 0 : 1)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { print("spotlight: timeout"); exit(2) }
    }
}

// The number of items of this app in the Spotlight index, nil on an error (016).
enum SpotlightIndex {
    static func count() async -> Int? {
        await withCheckedContinuation { done in
            let q = CSSearchQuery(queryString: "kMDItemDisplayName == \"*\"", queryContext: CSSearchQueryContext())
            let lock = NSLock()
            var n = 0
            q.foundItemsHandler = { items in lock.withLock { n += items.count } }
            q.completionHandler = { error in done.resume(returning: error == nil ? lock.withLock { n } : nil) }
            q.start()
        }
    }
}
