import StoreKit
import SwiftUI

/// Commerce surfaces deliberately contain no app icon, logo, custom image
/// asset, or brand mark. Keep all benefits factual and product-specific.
struct PaywallView: View {
    @Environment(ShellModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var legalDocument: LegalDocument?
    @State private var showingManageSubscriptions = false
    let showsDoneButton: Bool

    init(showsDoneButton: Bool = false) {
        self.showsDoneButton = showsDoneButton
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("paywall.title")
                    .font(.largeTitle.bold())
                    .fixedSize(horizontal: false, vertical: true)
                Text("paywall.message")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                ForEach(["paywall.benefit.unlimited", "paywall.benefit.readiness", "paywall.benefit.history"], id: \.self) { benefit in
                    Label(LocalizedStringKey(benefit), systemImage: "checkmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                }

                if model.access.purchases.subscriptionCondition == .billingRetry {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("paywall.billingRetry.title", systemImage: "creditcard.trianglebadge.exclamationmark")
                            .font(.headline)
                        Text("paywall.billingRetry.message").foregroundStyle(.secondary)
                        Button { showingManageSubscriptions = true } label: {
                            Text("subscription.manage").frame(maxWidth: .infinity, minHeight: 44)
                        }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .frame(maxWidth: .infinity)
                    }
                } else if let product = model.access.purchases.primaryProduct {
                    Button {
                        Task { await model.access.purchases.purchasePrimary() }
                    } label: {
                        VStack(spacing: 2) {
                            Text(product.displayName)
                                .font(.headline)
                            Group {
                                if let subscription = product.subscription {
                                    Text(product.displayPrice) + Text(" · ") + Text(periodText(subscription.subscriptionPeriod))
                                } else {
                                    Text(product.displayPrice)
                                }
                            }
                            .font(.title2.bold())
                            Text("paywall.purchase")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("shell.paywall.purchase")
                    .disabled(model.access.purchases.isWorking || model.access.purchases.isEntitled)
                } else if model.access.purchases.isLoadingProducts {
                    ProgressView("paywall.loadingProduct").frame(maxWidth: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("purchase.productUnavailable")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button {
                            Task { await model.access.purchases.retryProducts() }
                        } label: {
                            Text("tryAgain")
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("shell.paywall.retryProduct")
                        .disabled(model.access.purchases.isWorking)
                    }
                }

                if model.access.purchases.primaryProduct?.subscription != nil {
                    Text("paywall.subscriptionDisclosure")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button { Task { await model.access.purchases.restore() } } label: {
                    Text("paywall.restore").frame(maxWidth: .infinity, minHeight: 44)
                }
                    .accessibilityIdentifier("shell.paywall.restore")
                    .disabled(model.access.purchases.isWorking)

                HStack {
                    Button("privacy") { legalDocument = .privacy }.frame(minHeight: 44)
                    Spacer()
                    Button("terms") { legalDocument = .terms }.frame(minHeight: 44)
                }
                .font(.footnote)
            }
            .frame(maxWidth: 560)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .appNavigationTitle("upgrade")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("shell.paywall")
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .confirmationAction) { Button("done") { dismiss() } }
            }
        }
        .sheet(item: $legalDocument) { document in
            LegalView(document: document)
                .ignoresSafeArea()
        }
        .manageSubscriptionsSheet(isPresented: $showingManageSubscriptions)
        .onChange(of: model.access.purchases.isEntitled) { _, entitled in
            if entitled { dismiss() }
        }
        .alert(Text(verbatim: "App Store"), isPresented: purchaseErrorBinding) {
            Button("ok") {}
        } message: {
            Text(model.access.purchases.message)
        }
    }

    private var purchaseErrorBinding: Binding<Bool> {
        Binding(
            get: { model.access.purchases.showingError },
            set: { model.access.purchases.showingError = $0 }
        )
    }

    private func periodText(_ period: Product.SubscriptionPeriod) -> String {
        let unit: NSCalendar.Unit
        switch period.unit {
        case .day: unit = .day
        case .week: unit = .weekOfMonth
        case .month: unit = .month
        case .year: unit = .year
        @unknown default: return AppLocalization.string("paywall.period.unknown", locale: model.language.locale)
        }
        return AppLocalization.duration(period.value, unit: unit, locale: model.language.locale)
            ?? AppLocalization.string("paywall.period.unknown", locale: model.language.locale)
    }
}
