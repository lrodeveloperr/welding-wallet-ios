import XCTest
@testable import WeldingGasWallet

@MainActor
final class WeldingGasWalletTests: XCTestCase {
    func testAllMonetizationModesResolveAccess() {
        for mode in [MonetizationMode.free, .freemiumWithSubscription] {
            XCTAssertEqual(resolve(mode, entitled: false, checking: true, free: false), .allowed)
            XCTAssertEqual(resolve(mode, entitled: false, checking: false, free: false), .allowed)
        }
        for mode in [MonetizationMode.oneTimeUnlock, .subscription] {
            XCTAssertEqual(resolve(mode, entitled: true, checking: false, free: false), .allowed)
            XCTAssertEqual(resolve(mode, entitled: false, checking: true, free: false), .checkingEntitlement)
            XCTAssertEqual(resolve(mode, entitled: false, checking: false, free: false), .purchaseRequired)
        }
        for mode in [MonetizationMode.usageCapWithOneTimeUnlock, .usageCapWithSubscription] {
            XCTAssertEqual(resolve(mode, entitled: false, checking: true, free: true), .allowed)
            XCTAssertEqual(resolve(mode, entitled: true, checking: false, free: false), .allowed)
            XCTAssertEqual(resolve(mode, entitled: false, checking: true, free: false), .checkingEntitlement)
            XCTAssertEqual(resolve(mode, entitled: false, checking: false, free: false), .usageLimitReached)
        }
    }

    func testSuccessfulUsageIsPersistentAndDeduplicated() {
        let defaults = makeDefaults()
        let store = UserDefaultsUsageStore(defaults: defaults, key: "usage")
        let first = UsageLedger(limit: 2, store: store)
        XCTAssertEqual(first.recordSuccessfulAction(id: "operation-1"), .recorded(remaining: 1))
        XCTAssertEqual(first.recordSuccessfulAction(id: "operation-1"), .duplicate(remaining: 1))
        XCTAssertEqual(first.recordSuccessfulAction(id: "  "), .invalidIdentifier)
        XCTAssertEqual(first.recordSuccessfulAction(id: String(repeating: "a", count: 129)), .invalidIdentifier)
        let relaunched = UsageLedger(limit: 2, store: store)
        XCTAssertEqual(relaunched.successfulActionCount, 1)
        XCTAssertEqual(relaunched.recordSuccessfulAction(id: "operation-2"), .recorded(remaining: 0))
        XCTAssertFalse(relaunched.hasFreeActionRemaining)
        XCTAssertEqual(relaunched.recordSuccessfulAction(id: "operation-3"), .limitReached)
    }

    func testLegalAcceptanceIsVersionedAndForcesReconsent() {
        let defaults = makeDefaults()
        let first = LegalConsentStore(defaults: defaults, requiredVersion: "2026-09")
        XCTAssertTrue(first.requiresPresentation)
        XCTAssertFalse(first.isReconsent)
        first.acceptCurrentLegalVersion()
        XCTAssertFalse(first.requiresPresentation)
        XCTAssertFalse(LegalConsentStore(defaults: defaults, requiredVersion: "2026-09").requiresPresentation)
        let revised = LegalConsentStore(defaults: defaults, requiredVersion: "2026-10")
        XCTAssertTrue(revised.requiresPresentation)
        XCTAssertTrue(revised.isReconsent)
    }

    func testSubscriptionCacheExpiresButLifetimeCacheDoesNot() {
        let now = Date(timeIntervalSince1970: 1_000)
        let snapshot = EntitlementSnapshot(
            entitledProductIDs: ["lifetime", "monthly"],
            subscriptionExpiryByProductID: ["monthly": now.addingTimeInterval(60)],
            verifiedAt: now
        )
        XCTAssertTrue(snapshot.isEntitled(to: ["monthly"], at: now))
        XCTAssertFalse(snapshot.isEntitled(to: ["monthly"], at: now.addingTimeInterval(61)))
        XCTAssertTrue(snapshot.isEntitled(to: ["lifetime"], at: now.addingTimeInterval(1_000_000)))
        XCTAssertFalse(snapshot.isEntitled(to: ["unknown"], at: now))
    }

    func testSubscriptionCancellationKeepsAccessUntilPaidExpiration() {
        let now = Date(timeIntervalSince1970: 1_000)
        let expiration = now.addingTimeInterval(60)
        let cancelledRenewal = SubscriptionCondition.subscribed(willAutoRenew: false, expirationDate: expiration)
        XCTAssertTrue(SubscriptionAccessEvaluation.resolve(condition: cancelledRenewal, at: now).grantsAccess)
        XCTAssertFalse(SubscriptionAccessEvaluation.resolve(condition: cancelledRenewal, at: expiration).grantsAccess)
    }

    func testGracePeriodGrantsAccessButBillingRetryAndRevocationDoNot() {
        let now = Date(timeIntervalSince1970: 1_000)
        XCTAssertTrue(SubscriptionAccessEvaluation.resolve(condition: .gracePeriod(expirationDate: now.addingTimeInterval(60)), at: now).grantsAccess)
        XCTAssertFalse(SubscriptionAccessEvaluation.resolve(condition: .billingRetry, at: now).grantsAccess)
        XCTAssertFalse(SubscriptionAccessEvaluation.resolve(condition: .expired, at: now).grantsAccess)
        XCTAssertFalse(SubscriptionAccessEvaluation.resolve(condition: .revoked, at: now).grantsAccess)
    }

    func testSettingsOnlyOffersSubscriptionManagementForRelevantStoreStates() {
        XCTAssertNil(SubscriptionSettingsPresentation.resolve(.notApplicable))
        XCTAssertNil(SubscriptionSettingsPresentation.resolve(.expired))
        XCTAssertNil(SubscriptionSettingsPresentation.resolve(.revoked))

        let checking = SubscriptionSettingsPresentation.resolve(.checking)
        XCTAssertEqual(checking?.showsManagement, false)
        XCTAssertEqual(checking?.symbol, "hourglass")

        let expiration = Date(timeIntervalSince1970: 2_000)
        XCTAssertEqual(
            SubscriptionSettingsPresentation.resolve(.subscribed(willAutoRenew: true, expirationDate: expiration))?.showsManagement,
            true
        )
        XCTAssertEqual(
            SubscriptionSettingsPresentation.resolve(.subscribed(willAutoRenew: false, expirationDate: expiration))?.showsManagement,
            true
        )
        XCTAssertEqual(SubscriptionSettingsPresentation.resolve(.gracePeriod(expirationDate: expiration))?.showsManagement, true)
        XCTAssertEqual(SubscriptionSettingsPresentation.resolve(.billingRetry)?.showsManagement, true)
        XCTAssertEqual(SubscriptionSettingsPresentation.resolve(.offlineCached(expirationDate: expiration))?.showsManagement, true)
    }

    func testProductIdentifiersAreSelectedByProfile() {
        XCTAssertEqual(configuration(.free).productIDs, [])
        XCTAssertEqual(configuration(.freemiumWithSubscription).productIDs, ["monthly"])
        XCTAssertEqual(configuration(.oneTimeUnlock).productIDs, ["lifetime"])
        XCTAssertEqual(configuration(.subscription).productIDs, ["monthly"])
        XCTAssertEqual(configuration(.usageCapWithOneTimeUnlock).productIDs, ["lifetime"])
        XCTAssertEqual(configuration(.usageCapWithSubscription).productIDs, ["monthly"])
    }

    func testTemplateNavigationAndLanguagesAreBounded() {
        XCTAssertFalse(ShellConfiguration.destinations.isEmpty)
        XCTAssertLessThanOrEqual(ShellConfiguration.destinations.count, 5)
        XCTAssertEqual(Set(ShellConfiguration.destinations.map(\.id)).count, ShellConfiguration.destinations.count)
        XCTAssertFalse(ShellConfiguration.supportedLanguages.contains { $0.id == "system" })
        XCTAssertTrue(ShellConfiguration.supportedLanguages.contains { $0.id == "en" })
        XCTAssertEqual(ShellConfiguration.supportedLanguages.map(\.id), [
            "en", "es-419", "pt", "fr", "de", "it", "nl", "pl", "tr", "ro",
            "cs", "uk", "ru", "ar", "zh-Hans", "ja", "ko", "hi", "ur", "bn",
            "vi", "id", "th", "fil", "ms", "fi", "sv", "da", "nb", "el", "he",
        ])
        XCTAssertEqual(LanguageController.closestSupported(to: "es-MX"), "es-419")
        XCTAssertEqual(LanguageController.closestSupported(to: "zh-Hant"), "zh-Hans")
        XCTAssertEqual(LanguageController.closestSupported(to: "fr-CA"), "fr")
        XCTAssertEqual(LanguageController.closestSupported(to: "pt-BR"), "pt")
        XCTAssertEqual(LanguageController.closestSupported(to: "ar-SA"), "ar")
        XCTAssertEqual(LanguageController.closestSupported(to: "he-IL"), "he")
        XCTAssertEqual(LanguageController.closestSupported(to: "xx-YY"), "en")
        XCTAssertTrue(SupportedLocaleResolver.isRightToLeft("ar"))
        XCTAssertFalse(SupportedLocaleResolver.isRightToLeft("en"))
    }

    func testStaleStoredLanguageFallsBackToSupportedLocale() {
        let defaults = makeDefaults()
        defaults.set("xx-YY", forKey: "wallet.language")
        let controller = LanguageController(defaults: defaults, preferredLanguages: ["es-MX"])
        XCTAssertEqual(controller.selection, "es-419")
    }

    func testEveryPublishedLegalDestinationIsSecureAndProductSpecific() {
        let urls = [
            ShellConfiguration.legal.privacyURL,
            ShellConfiguration.legal.termsURL,
            ShellConfiguration.legal.supportURL,
            ShellConfiguration.legal.deletionURL,
            ShellConfiguration.legal.safetyURL,
        ]
        XCTAssertEqual(Set(urls).count, urls.count)
        for url in urls {
            XCTAssertEqual(url.scheme, "https")
            XCTAssertEqual(url.host, "lrodeveloperr.github.io")
            XCTAssertTrue(url.path.hasPrefix("/privacy-policy/welding-gas-wallet/"))
        }
    }

    func testSafeTemplateDefaultsAndSharedLocalizationContract() {
        XCTAssertTrue(ShellConfiguration.backup.enabled)
        XCTAssertEqual(LocalizationBaseline.localeIdentifiers.count, 31)
        XCTAssertEqual(LocalizationBaseline.sharedKeys.count, 18)
        XCTAssertEqual(ShellContract.currentVersion.split(separator: ".").count, 3)
    }

    func testFreeBackupRestorePreservesDataButLocksExcessCylinders() throws {
        let source = WalletStore(fileURL: temporaryWalletURL(), loadExisting: false)
        for index in 1...4 {
            XCTAssertNotNil(source.addCylinder(gas: "Argon", capacity: 80, unit: "ft3", supplierID: nil, relationship: .owned, serial: "LIMIT-\(index)", isEntitled: true))
        }
        let target = WalletStore(fileURL: temporaryWalletURL(), loadExisting: false)
        try target.restore(from: source.exportData(), isEntitled: false)
        XCTAssertEqual(target.activeCylinders.count, 4)
        XCTAssertTrue(target.requiresFreeCylinderSelection(isEntitled: false))
        XCTAssertTrue(target.activeCylinders.allSatisfy { !target.canManageCylinder($0.id, isEntitled: false) })
    }

    func testExpiredSubscriberChoosesThreeAndExcessMutationsStayLocked() {
        let store = WalletStore(fileURL: temporaryWalletURL(), loadExisting: false)
        for index in 1...5 {
            XCTAssertNotNil(store.addCylinder(gas: "Argon", capacity: 80, unit: "ft3", supplierID: nil, relationship: .owned, serial: "PRO-\(index)", isEntitled: true))
        }
        store.reconcileAccess(isEntitled: false)
        XCTAssertTrue(store.requiresFreeCylinderSelection(isEntitled: false))

        let managed = Set(store.activeCylinders.prefix(3).map(\.id))
        XCTAssertTrue(store.selectFreeManagedCylinders(managed, isEntitled: false))
        let locked = store.activeCylinders.first { !managed.contains($0.id) }!
        XCTAssertFalse(store.canManageCylinder(locked.id, isEntitled: false))
        XCTAssertFalse(store.setStatus(.low, for: locked.id, isEntitled: false))
        XCTAssertFalse(store.setReminder(.now, for: locked.id, isEntitled: false))
        XCTAssertFalse(store.recordService(for: locked.id, kind: .refill, amount: 10, currency: "USD", date: .now, isEntitled: false))
        XCTAssertNil(store.duplicate(locked, isEntitled: false))
        XCTAssertNil(store.addCylinder(gas: "Oxygen", capacity: 40, unit: "ft3", supplierID: nil, relationship: .owned, serial: "BLOCKED", isEntitled: false))

        var editedLocked = locked
        editedLocked.notes = "Must not save"
        XCTAssertFalse(store.update(editedLocked, isEntitled: false))

        store.reconcileAccess(isEntitled: true)
        XCTAssertTrue(store.canManageCylinder(locked.id, isEntitled: true))
        XCTAssertTrue(store.update(editedLocked, isEntitled: true))
    }

    func testFreeSlotCannotBeSwappedUntilManagedCylinderLeavesActiveInventory() {
        let store = WalletStore(fileURL: temporaryWalletURL(), loadExisting: false)
        for index in 1...5 {
            XCTAssertNotNil(store.addCylinder(gas: "Argon", capacity: 80, unit: "ft3", supplierID: nil, relationship: .owned, serial: "SLOT-\(index)", isEntitled: true))
        }
        let managed = Set(store.activeCylinders.prefix(3).map(\.id))
        XCTAssertTrue(store.selectFreeManagedCylinders(managed, isEntitled: false))
        let replacement = store.activeCylinders.first { !managed.contains($0.id) }!.id
        XCTAssertFalse(store.selectFreeManagedCylinders(Set([replacement]), isEntitled: false))

        let departing = managed.first!
        store.archive(departing, as: .archived)
        let retained = store.freeManagedCylinderIDs
        XCTAssertEqual(retained.count, 2)
        XCTAssertTrue(store.selectFreeManagedCylinders(retained.union([replacement]), isEntitled: false))
    }

    func testDeleteAddUndoCannotCreateAFreeFourthManagedCylinder() {
        let store = WalletStore(fileURL: temporaryWalletURL(), loadExisting: false)
        for index in 1...3 {
            XCTAssertNotNil(store.addCylinder(gas: "Argon", capacity: 80, unit: "ft3", supplierID: nil, relationship: .owned, serial: "UNDO-\(index)", isEntitled: false))
        }
        store.reconcileAccess(isEntitled: false)
        store.delete(store.activeCylinders[0].id)
        XCTAssertNotNil(store.addCylinder(gas: "Oxygen", capacity: 40, unit: "ft3", supplierID: nil, relationship: .owned, serial: "UNDO-4", isEntitled: false))
        store.undoDelete()
        XCTAssertEqual(store.activeCylinders.count, 4)
        XCTAssertTrue(store.requiresFreeCylinderSelection(isEntitled: false))
        XCTAssertNil(store.addCylinder(gas: "Helium", capacity: 20, unit: "ft3", supplierID: nil, relationship: .owned, serial: "UNDO-5", isEntitled: false))
    }

    func testInvalidBackupCannotReplaceExistingWallet() throws {
        let store = WalletStore(fileURL: temporaryWalletURL(), loadExisting: false)
        XCTAssertNotNil(store.addCylinder(gas: "Argon", capacity: 80, unit: "ft3", supplierID: nil, relationship: .owned, serial: "SAFE", isEntitled: true))
        let malformed = Data("{\"format\":\"welding-gas-wallet\",\"version\":2,\"cylinders\":[".utf8)
        XCTAssertThrowsError(try store.restore(from: malformed, isEntitled: true))
        XCTAssertEqual(store.cylinders.map(\.serial), ["SAFE"])
    }

    func testInvalidAndOverflowingMutationsAreRejected() {
        let store = WalletStore(fileURL: temporaryWalletURL(), loadExisting: false)
        XCTAssertNil(store.addCylinder(gas: "Argon", capacity: .infinity, unit: "ft3", supplierID: nil, relationship: .owned, serial: "INF", isEntitled: true))
        let cylinder = store.addCylinder(gas: "Argon", capacity: 80, unit: "ft3", supplierID: nil, relationship: .owned, serial: "VALID", isEntitled: true)!
        XCTAssertFalse(store.recordService(for: cylinder.id, kind: .cost, amount: Decimal(string: "99999999999999999999999999999999999999")!, currency: "USD", date: .now, isEntitled: true))
        XCTAssertFalse(store.recordService(for: cylinder.id, kind: .exchange, amount: 10, currency: "USD", date: .now, replacementUnit: "L", isEntitled: true))
        XCTAssertFalse(store.setReminder(.distantPast, for: cylinder.id, isEntitled: true))
    }

    func testInactiveCylinderIsHistoryOnlyButCanStillBeDeleted() {
        let store = WalletStore(fileURL: temporaryWalletURL(), loadExisting: false)
        let cylinder = store.addCylinder(gas: "Argon", capacity: 80, unit: "ft3", supplierID: nil, relationship: .owned, serial: "OLD", isEntitled: true)!
        XCTAssertTrue(store.archive(cylinder.id, as: .archived))
        XCTAssertFalse(store.canManageCylinder(cylinder.id, isEntitled: true))
        XCTAssertFalse(store.setStatus(.low, for: cylinder.id, isEntitled: true))
        XCTAssertTrue(store.delete(cylinder.id))
    }

    func testPersistenceFailureRollsBackMutation() {
        let directory = FileManager.default.temporaryDirectory.appending(path: "wallet-unwritable-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = WalletStore(fileURL: directory, loadExisting: false)
        XCTAssertNil(store.addSupplier(name: "Must not appear"))
        XCTAssertTrue(store.suppliers.isEmpty)
        XCTAssertNotNil(store.persistenceError)
    }

    private func resolve(_ mode: MonetizationMode, entitled: Bool, checking: Bool, free: Bool) -> AccessDecision {
        AccessController.resolveDecision(mode: mode, isEntitled: entitled, isChecking: checking, hasFreeActionRemaining: free)
    }

    private func configuration(_ mode: MonetizationMode) -> MonetizationConfiguration {
        MonetizationConfiguration(mode: mode, freeSuccessfulActions: 3, lifetimeProductID: "lifetime", subscriptionProductID: "monthly")
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "WeldingGasWalletTests.\(UUID().uuidString)")!
    }

    private func temporaryWalletURL() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "wallet-test-\(UUID().uuidString).json")
    }
}
