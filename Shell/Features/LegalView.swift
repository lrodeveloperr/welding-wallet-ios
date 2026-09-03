import SafariServices
import SwiftUI

enum LegalDocument: String, Identifiable {
    case privacy, terms, support, deletion, safety
    var id: Self { self }

    var url: URL {
        switch self {
        case .privacy: ShellConfiguration.legal.privacyURL
        case .terms: ShellConfiguration.legal.termsURL
        case .support: ShellConfiguration.legal.supportURL
        case .deletion: ShellConfiguration.legal.deletionURL
        case .safety: ShellConfiguration.legal.safetyURL
        }
    }
}

/// Presents the published document in Apple's in-app browser. This avoids stale
/// placeholder legal copy and gives every legal entry point the same destination.
struct LegalView: UIViewControllerRepresentable {
    let document: LegalDocument

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false
        let controller = SFSafariViewController(url: document.url, configuration: configuration)
        controller.preferredControlTintColor = UIColor(ShellConfiguration.tint)
        controller.dismissButtonStyle = .done
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
