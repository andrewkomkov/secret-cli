// Spotlight and Shortcuts (014): each secret is an App Entity with its name and comment, and the
// action "Copy Secret" copies its value through `secret copy`. The index holds names and
// comments only; values never go there. Settings → "Show in Spotlight" turns it off.
import AppIntents
import CoreSpotlight
import SwiftUI

struct SecretEntity: AppEntity, IndexedEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Secret")
    static var defaultQuery = SecretQuery()

    let id: String
    let comment: String

    init(_ s: Secret) {
        id = s.name
        comment = s.comment
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(id)", subtitle: comment.isEmpty ? nil : "\(comment)",
                              image: .init(systemName: "key.fill"))
    }

    // Words for the Spotlight search: the name, its parts and the comment.
    var attributeSet: CSSearchableItemAttributeSet {
        let a = CSSearchableItemAttributeSet(contentType: .text)
        a.displayName = id
        a.contentDescription = comment
        a.keywords = id.split(separator: "_").map(String.init) + [Parse.project(comment), "secret", "password", "секрет", "пароль"]
        return a
    }
}

struct SecretQuery: EntityStringQuery {
    @MainActor
    private func all() async -> [Secret] {
        if Store.shared.secrets.isEmpty { await Store.shared.refreshList() }
        return Store.shared.secrets
    }

    func entities(for identifiers: [String]) async throws -> [SecretEntity] {
        await all().filter { identifiers.contains($0.name) }.map(SecretEntity.init)
    }

    func entities(matching string: String) async throws -> [SecretEntity] {
        await MainActor.run { () -> [Secret] in Store.shared.filter(string) }.map(SecretEntity.init)
    }

    func suggestedEntities() async throws -> [SecretEntity] {
        await all().map(SecretEntity.init)
    }
}

struct CopySecretIntent: AppIntent {
    static var title: LocalizedStringResource = "Copy Secret"
    static var description = IntentDescription("Copies the value of a secret to the clipboard. Touch ID works as in the terminal. The clipboard is cleared after 30 seconds.")
    static var openAppWhenRun = false

    @Parameter(title: "Secret")
    var secret: SecretEntity

    init() {}
    init(secret: SecretEntity) { self.secret = secret }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // the access log names the source: Spotlight or Shortcuts, not the user at the keyboard
        let ok = await Store.shared.copy(secret.id, via: "shortcuts")
        let dialog: IntentDialog = ok ? "\(secret.id) copied. The clipboard is cleared after 30 seconds." : "Could not copy \(secret.id)."
        return .result(dialog: dialog)
    }
}

// Opens SecretBar on the card of the secret: the action for a Spotlight result.
struct OpenSecretIntent: OpenIntent {
    static var title: LocalizedStringResource = "Open in SecretBar"

    @Parameter(title: "Secret")
    var target: SecretEntity

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        Navigation.shared.select(target.id)
        return .result()
    }
}

struct SecretShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: CopySecretIntent(),
                    phrases: ["Copy \(\.$secret) with \(.applicationName)",
                              "Copy a secret with \(.applicationName)",
                              "Скопировать \(\.$secret) в \(.applicationName)",
                              "Скопировать секрет в \(.applicationName)"],
                    shortTitle: "Copy Secret",
                    systemImageName: "key.fill")
    }
}
