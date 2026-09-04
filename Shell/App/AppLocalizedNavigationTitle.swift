import SwiftUI

private struct AppLocalizedNavigationTitle: ViewModifier {
    @Environment(LanguageController.self) private var language
    let key: String

    func body(content: Content) -> some View {
        content.navigationTitle(
            Text(verbatim: AppLocalization.string(key, locale: language.locale))
        )
    }
}

extension View {
    /// Resolves navigation titles from the in-app language controller instead of
    /// relying on NavigationStack's cached LocalizedStringKey environment.
    func appNavigationTitle(_ key: String) -> some View {
        modifier(AppLocalizedNavigationTitle(key: key))
    }
}
