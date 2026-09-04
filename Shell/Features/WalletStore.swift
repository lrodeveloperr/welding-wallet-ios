import Foundation
import Observation
import UniformTypeIdentifiers
import SwiftUI

enum CylinderStatus: String, Codable, CaseIterable, Identifiable {
    case ready = "Ready", low = "Low", empty = "Empty", away = "Away"
    var id: String { rawValue }
    var localizationKey: String { "status.\(rawValue.lowercased())" }
    var symbol: String {
        switch self { case .ready: "checkmark.circle"; case .low: "exclamationmark.triangle"; case .empty: "xmark.circle"; case .away: "truck.box" }
    }
}

enum CylinderLifecycle: String, Codable {
    case active, returned, archived
    var localizationKey: String { "lifecycle.\(rawValue)" }
}
enum Relationship: String, Codable, CaseIterable, Identifiable {
    case owned = "Owned", rental = "Rental", leased = "Leased", deposit = "Deposit", notSet = "Not set"
    var id: String { rawValue }
    var localizationKey: String {
        switch self {
        case .owned: "relationship.owned"
        case .rental: "relationship.rental"
        case .leased: "relationship.leased"
        case .deposit: "relationship.deposit"
        case .notSet: "common.notSet"
        }
    }
}

enum ActivityKind: String, Codable, CaseIterable {
    case created, status, refill, exchange, cost, returned, archived
    var localizationKey: String { "activity.kind.\(rawValue)" }
}

struct CylinderRecord: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var gas: String
    var capacityValue: Double
    var capacityUnit: String
    var supplierID: UUID?
    var relationship: Relationship
    var serial: String
    var status: CylinderStatus = .ready
    var lifecycle: CylinderLifecycle = .active
    var acquiredAt: Date = .now
    var reminderAt: Date?
    var notes: String = ""

    var capacityLabel: String {
        let value = capacityValue.rounded() == capacityValue ? String(Int(capacityValue)) : String(format: "%.1f", capacityValue)
        return "\(value) \(capacityUnit.replacingOccurrences(of: "3", with: "³"))"
    }

    func capacityLabel(locale: Locale) -> String {
        "\(AppLocalization.number(capacityValue, locale: locale)) \(capacityUnit.replacingOccurrences(of: "3", with: "³"))"
    }
}

struct SupplierRecord: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var phone: String = ""
    var notes: String = ""
}

struct ActivityRecord: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var cylinderID: UUID
    var kind: ActivityKind
    var occurredAt: Date = .now
    var title: String
    var detail: String
    var amountMinor: Int64?
    var currencyCode: String?
}

struct CylinderDefaults: Codable, Hashable {
    var supplierID: UUID?
    var relationship: Relationship = .notSet
    var capacityUnit: String
}

struct WalletSnapshot: Codable {
    var format = "welding-gas-wallet"
    var version = 2
    var exportedAt = Date.now
    var cylinders: [CylinderRecord]
    var suppliers: [SupplierRecord]
    var activity: [ActivityRecord]
    var currencyOverride: String?
    var defaults: CylinderDefaults
    /// Product access metadata only. It never represents a StoreKit entitlement.
    /// A restore sanitizes or discards it before applying the current device policy.
    var freeManagedCylinderIDs: Set<UUID>? = nil
}

struct DeletedCylinderSnapshot {
    let cylinder: CylinderRecord
    let activity: [ActivityRecord]
}

@MainActor
@Observable
final class WalletStore {
    static let freeActiveCylinderLimit = 3
    private(set) var cylinders: [CylinderRecord] = []
    private(set) var suppliers: [SupplierRecord] = []
    private(set) var activity: [ActivityRecord] = []
    private(set) var lastDeleted: DeletedCylinderSnapshot?
    private(set) var freeManagedCylinderIDs: Set<UUID> = []
    private(set) var persistenceError: String?
    var currencyOverride: String?
    var defaults: CylinderDefaults
    private let fileURL: URL
    private var undoTask: Task<Void, Never>?

    private struct StoreState {
        let cylinders: [CylinderRecord]
        let suppliers: [SupplierRecord]
        let activity: [ActivityRecord]
        let lastDeleted: DeletedCylinderSnapshot?
        let freeManagedCylinderIDs: Set<UUID>
        let currencyOverride: String?
        let defaults: CylinderDefaults
    }

    init(fileURL: URL? = nil, loadExisting: Bool = true) {
        let regionUnit = Locale.current.region?.identifier == "US" ? "ft3" : "L"
        defaults = CylinderDefaults(capacityUnit: regionUnit)
        self.fileURL = fileURL ?? Self.defaultFileURL
        if loadExisting { load() }
    }

    var activeCylinders: [CylinderRecord] { cylinders.filter { $0.lifecycle == .active } }
    var automaticCurrency: String { Locale.current.currency?.identifier ?? "USD" }
    var defaultCurrency: String { currencyOverride ?? automaticCurrency }

    func clearPersistenceError() { persistenceError = nil }

    func currencySign(for code: String) -> String {
        let known: [String: String] = [
            "USD": "$", "CAD": "$", "AUD": "$", "NZD": "$", "SGD": "$", "HKD": "$",
            "EUR": "€", "GBP": "£", "JPY": "¥", "CNY": "¥", "KRW": "₩", "INR": "₹",
            "NGN": "₦", "RUB": "₽", "TRY": "₺", "UAH": "₴", "THB": "฿", "PHP": "₱",
            "VND": "₫", "ILS": "₪", "BDT": "৳", "PKR": "₨", "IDR": "Rp", "MYR": "RM",
            "BRL": "R$", "MXN": "$", "ARS": "$", "CLP": "$", "COP": "$", "PEN": "S/",
            "ZAR": "R", "GHS": "₵", "KES": "KSh", "AED": "د.إ", "SAR": "﷼", "IRR": "﷼",
        ]
        if let sign = known[code] { return sign }
        let formatter = NumberFormatter(); formatter.numberStyle = .currency; formatter.currencyCode = code; formatter.locale = .current
        return formatter.currencySymbol ?? "¤"
    }

    func supplierName(_ id: UUID?) -> String {
        guard let id else { return "Not set" }
        return suppliers.first { $0.id == id }?.name ?? "Not set"
    }

    @discardableResult
    func addSupplier(name: String, phone: String = "", notes: String = "") -> SupplierRecord? {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, !suppliers.contains(where: { $0.name.localizedCaseInsensitiveCompare(cleaned) == .orderedSame }) else { return nil }
        let supplier = SupplierRecord(name: cleaned, phone: phone.trimmed, notes: notes.trimmed)
        return commit({ suppliers.append(supplier) }) ? supplier : nil
    }

    @discardableResult
    func canAddCylinder(isEntitled: Bool) -> Bool {
        isEntitled || activeCylinders.count < Self.freeActiveCylinderLimit
    }

    func canManageCylinder(_ id: UUID, isEntitled: Bool) -> Bool {
        guard let cylinder = cylinders.first(where: { $0.id == id }) else { return false }
        return cylinder.lifecycle == .active && (isEntitled || activeCylinders.count <= Self.freeActiveCylinderLimit || freeManagedCylinderIDs.contains(id))
    }

    func requiresFreeCylinderSelection(isEntitled: Bool) -> Bool {
        guard !isEntitled, activeCylinders.count > Self.freeActiveCylinderLimit else { return false }
        let activeIDs = Set(activeCylinders.map(\.id))
        return freeManagedCylinderIDs.intersection(activeIDs).count < Self.freeActiveCylinderLimit
    }

    func reconcileAccess(isEntitled: Bool) {
        let previous = freeManagedCylinderIDs
        let activeIDs = Set(activeCylinders.map(\.id))
        if isEntitled {
            freeManagedCylinderIDs = []
        } else if activeIDs.count <= Self.freeActiveCylinderLimit {
            freeManagedCylinderIDs = activeIDs
        } else {
            freeManagedCylinderIDs.formIntersection(activeIDs)
            if freeManagedCylinderIDs.count > Self.freeActiveCylinderLimit {
                freeManagedCylinderIDs = Set(activeCylinders.lazy.map(\.id).filter(freeManagedCylinderIDs.contains).prefix(Self.freeActiveCylinderLimit))
            }
        }
        if previous != freeManagedCylinderIDs, !persistCurrentState() { freeManagedCylinderIDs = previous }
    }

    @discardableResult
    func selectFreeManagedCylinders(_ ids: Set<UUID>, isEntitled: Bool) -> Bool {
        guard !isEntitled else { return false }
        let activeIDs = Set(activeCylinders.map(\.id))
        let requiredCount = min(Self.freeActiveCylinderLimit, activeIDs.count)
        guard ids.count == requiredCount,
              ids.isSubset(of: activeIDs),
              freeManagedCylinderIDs.isSubset(of: ids) else { return false }
        return commit { freeManagedCylinderIDs = ids }
    }

    @discardableResult
    func addCylinder(gas: String, capacity: Double, unit: String, supplierID: UUID?, relationship: Relationship, serial: String, notes: String = "", isEntitled: Bool) -> CylinderRecord? {
        guard canAddCylinder(isEntitled: isEntitled) else { return nil }
        let cleanGas = gas.trimmed
        let cleanSerial = serial.trimmed
        guard !cleanGas.isEmpty, capacity.isFinite, capacity > 0, Self.validUnit(unit), supplierID == nil || suppliers.contains(where: { $0.id == supplierID }) else { return nil }
        guard cleanSerial.isEmpty || !cylinders.contains(where: { $0.serial.localizedCaseInsensitiveCompare(cleanSerial) == .orderedSame }) else { return nil }
        let cylinder = CylinderRecord(gas: cleanGas, capacityValue: capacity, capacityUnit: unit, supplierID: supplierID, relationship: relationship, serial: cleanSerial, notes: notes.trimmed)
        return commit({
            cylinders.append(cylinder)
            defaults = CylinderDefaults(supplierID: supplierID, relationship: relationship, capacityUnit: unit)
            activity.insert(ActivityRecord(cylinderID: cylinder.id, kind: .created, title: "\(cleanGas) added", detail: "\(supplierName(supplierID)) · \(cylinder.capacityLabel)"), at: 0)
        }) ? cylinder : nil
    }

    func duplicate(_ source: CylinderRecord, serial: String = "", isEntitled: Bool) -> CylinderRecord? {
        guard canManageCylinder(source.id, isEntitled: isEntitled) else { return nil }
        return addCylinder(gas: source.gas, capacity: source.capacityValue, unit: source.capacityUnit, supplierID: source.supplierID, relationship: source.relationship, serial: serial, notes: source.notes, isEntitled: isEntitled)
    }

    func update(_ cylinder: CylinderRecord, isEntitled: Bool) -> Bool {
        guard let index = cylinders.firstIndex(where: { $0.id == cylinder.id }) else { return false }
        guard canManageCylinder(cylinder.id, isEntitled: isEntitled),
              cylinder.lifecycle == cylinders[index].lifecycle else { return false }
        guard !cylinder.gas.trimmed.isEmpty, cylinder.capacityValue.isFinite, cylinder.capacityValue > 0,
              Self.validUnit(cylinder.capacityUnit), cylinder.supplierID == nil || suppliers.contains(where: { $0.id == cylinder.supplierID }) else { return false }
        let serial = cylinder.serial.trimmed
        guard serial.isEmpty || !cylinders.contains(where: { $0.id != cylinder.id && $0.serial.localizedCaseInsensitiveCompare(serial) == .orderedSame }) else { return false }
        let updated = cylinder
        let saved = commit {
            cylinders[index] = updated
            cylinders[index].gas = updated.gas.trimmed
            cylinders[index].serial = serial
        }
        if saved, cylinders[index].reminderAt != nil {
            let refreshed = cylinders[index]
            Task { await LocalReminderScheduler.schedule(cylinder: refreshed, at: refreshed.reminderAt, locale: Self.selectedLocale) }
        }
        return saved
    }

    @discardableResult
    func setStatus(_ status: CylinderStatus, for id: UUID, isEntitled: Bool) -> Bool {
        guard canManageCylinder(id, isEntitled: isEntitled),
              let index = cylinders.firstIndex(where: { $0.id == id }),
              cylinders[index].status != status else { return false }
        let cylinder = cylinders[index]
        return commit {
            cylinders[index].status = status
            activity.insert(ActivityRecord(cylinderID: id, kind: .status, title: "\(cylinder.gas) marked \(status.rawValue)", detail: "\(supplierName(cylinder.supplierID)) · \(cylinder.capacityLabel)"), at: 0)
        }
    }

    func recordService(for id: UUID, kind: ActivityKind, amount: Decimal?, currency: String, date: Date, replacementSerial: String? = nil, replacementCapacity: Double? = nil, replacementUnit: String? = nil, isEntitled: Bool) -> Bool {
        guard canManageCylinder(id, isEntitled: isEntitled),
              let index = cylinders.firstIndex(where: { $0.id == id }) else { return false }
        if let amount, amount <= 0 { return false }
        let minor: Int64?
        if let amount {
            guard let converted = Self.minorUnits(amount) else { return false }
            guard Locale.Currency.isoCurrencies.contains(where: { $0.identifier == currency }) else { return false }
            minor = converted
        } else { minor = nil }
        if let replacementCapacity, (!replacementCapacity.isFinite || replacementCapacity <= 0) { return false }
        if replacementCapacity == nil, replacementUnit != nil { return false }
        if let replacementUnit, !Self.validUnit(replacementUnit) { return false }
        if let serial = replacementSerial?.trimmed, !serial.isEmpty {
            guard !cylinders.contains(where: { $0.id != id && $0.serial.localizedCaseInsensitiveCompare(serial) == .orderedSame }) else { return false }
        }
        return commit {
            if let serial = replacementSerial?.trimmed, !serial.isEmpty { cylinders[index].serial = serial }
            if let replacementCapacity { cylinders[index].capacityValue = replacementCapacity }
            if let replacementUnit { cylinders[index].capacityUnit = replacementUnit }
            if kind == .refill || kind == .exchange { cylinders[index].status = .ready }
            let cylinder = cylinders[index]
            activity.insert(ActivityRecord(
                cylinderID: id, kind: kind, occurredAt: date,
                title: "\(cylinder.gas) \(kind.rawValue)",
                detail: replacementSerial?.trimmed.isEmpty == false ? "Replacement \(replacementSerial!.trimmed)" : supplierName(cylinder.supplierID),
                amountMinor: minor, currencyCode: minor == nil ? nil : currency
            ), at: 0)
        }
    }

    @discardableResult func archive(_ id: UUID, as lifecycle: CylinderLifecycle) -> Bool {
        guard lifecycle != .active, let index = cylinders.firstIndex(where: { $0.id == id }), cylinders[index].lifecycle == .active else { return false }
        let cylinder = cylinders[index]
        let kind: ActivityKind = lifecycle == .returned ? .returned : .archived
        let saved = commit {
            cylinders[index].lifecycle = lifecycle
            cylinders[index].reminderAt = nil
            activity.insert(ActivityRecord(cylinderID: id, kind: kind, title: "\(cylinder.gas) \(lifecycle.rawValue)", detail: "History retained"), at: 0)
            freeManagedCylinderIDs.remove(id)
        }
        if saved { Task { await LocalReminderScheduler.schedule(cylinder: cylinder, at: nil) } }
        return saved
    }

    @discardableResult func delete(_ id: UUID) -> Bool {
        guard let index = cylinders.firstIndex(where: { $0.id == id }) else { return false }
        let linked = activity.filter { $0.cylinderID == id }
        let removed = cylinders[index]
        guard commit({
            lastDeleted = DeletedCylinderSnapshot(cylinder: cylinders.remove(at: index), activity: linked)
            activity.removeAll { $0.cylinderID == id }
            freeManagedCylinderIDs.remove(id)
        }) else { return false }
        Task { await LocalReminderScheduler.schedule(cylinder: removed, at: nil) }
        undoTask?.cancel()
        undoTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled else { return }
            self?.lastDeleted = nil
        }
        return true
    }

    @discardableResult func undoDelete() -> Bool {
        guard let deleted = lastDeleted else { return false }
        guard commit({
            cylinders.append(deleted.cylinder)
            activity.append(contentsOf: deleted.activity)
            activity.sort { $0.occurredAt > $1.occurredAt }
            lastDeleted = nil
        }) else { return false }
        undoTask?.cancel()
        Task { await LocalReminderScheduler.schedule(cylinder: deleted.cylinder, at: deleted.cylinder.reminderAt) }
        return true
    }

    @discardableResult
    func setReminder(_ date: Date?, for id: UUID, isEntitled: Bool) -> Bool {
        guard canManageCylinder(id, isEntitled: isEntitled),
              let index = cylinders.firstIndex(where: { $0.id == id }) else { return false }
        guard date == nil || date! > Date() else { return false }
        return commit { cylinders[index].reminderAt = date }
    }

    @discardableResult func setCurrency(_ code: String?) -> Bool {
        guard code == nil || Locale.Currency.isoCurrencies.contains(where: { $0.identifier == code }) else { return false }
        return commit { currencyOverride = code }
    }

    @discardableResult func deleteAllData() -> Bool {
        let removed = cylinders
        guard commit({
            cylinders = []; suppliers = []; activity = []; lastDeleted = nil; freeManagedCylinderIDs = []; currencyOverride = nil
            defaults = CylinderDefaults(capacityUnit: Locale.current.region?.identifier == "US" ? "ft3" : "L")
        }) else { return false }
        undoTask?.cancel()
        for cylinder in removed { Task { await LocalReminderScheduler.schedule(cylinder: cylinder, at: nil) } }
        return true
    }

    func exportData() throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot())
    }

    func restore(from data: Data, isEntitled: Bool, locale: Locale? = nil) throws {
        guard data.count <= 5 * 1024 * 1024 else { throw WalletError.backupTooLarge }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WalletSnapshot.self, from: data)
        guard decoded.format == "welding-gas-wallet", decoded.version == 2 else { throw WalletError.unsupportedBackup }
        guard Self.isValid(decoded) else { throw WalletError.invalidBackup }
        let previous = captureState()
        let removed = cylinders
        cylinders = decoded.cylinders; suppliers = decoded.suppliers; activity = decoded.activity.sorted { $0.occurredAt > $1.occurredAt }
        currencyOverride = decoded.currencyOverride; defaults = decoded.defaults; lastDeleted = nil
        freeManagedCylinderIDs = reconciledManagedIDs(isEntitled: isEntitled, proposed: [])
        guard persistCurrentState() else { apply(previous); throw WalletError.persistenceFailure }
        let reminderLocale = locale ?? Self.selectedLocale
        let restoredActive = activeCylinders
        Task {
            for cylinder in removed { await LocalReminderScheduler.schedule(cylinder: cylinder, at: nil) }
            for cylinder in restoredActive { await LocalReminderScheduler.schedule(cylinder: cylinder, at: cylinder.reminderAt, locale: reminderLocale) }
        }
    }

    func totals(for cylinderID: UUID? = nil) -> [(String, Decimal)] {
        let relevant = activity.filter { cylinderID == nil || $0.cylinderID == cylinderID }
        let grouped = Dictionary(grouping: relevant.compactMap { event -> (String, Int64)? in
            guard let minor = event.amountMinor, let code = event.currencyCode else { return nil }
            return (code, minor)
        }, by: { $0.0 })
        return grouped.map { code, values in (code, Decimal(values.reduce(0) { $0 + $1.1 }) / 100) }.sorted { $0.0 < $1.0 }
    }

    var refillCount: Int { activity.filter { $0.kind == .refill }.count }
    var averageRefillIntervalDays: Int? {
        let grouped = Dictionary(grouping: activity.filter { $0.kind == .refill }, by: \.cylinderID)
        let intervals = grouped.values.flatMap { events -> [Double] in
            let dates = events.map(\.occurredAt).sorted()
            return zip(dates, dates.dropFirst()).map { $1.timeIntervalSince($0) / 86_400 }
        }
        guard !intervals.isEmpty else { return nil }
        return Int((intervals.reduce(0, +) / Double(intervals.count)).rounded())
    }

    private func snapshot() -> WalletSnapshot {
        WalletSnapshot(cylinders: cylinders, suppliers: suppliers, activity: activity, currencyOverride: currencyOverride, defaults: defaults, freeManagedCylinderIDs: freeManagedCylinderIDs)
    }

    private func save() {
        _ = persistCurrentState()
    }

    @discardableResult private func persistCurrentState() -> Bool {
        do {
            let data = try exportData()
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
            persistenceError = nil
            return true
        } catch {
            persistenceError = error.localizedDescription
            return false
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode(WalletSnapshot.self, from: data),
              decoded.format == "welding-gas-wallet", decoded.version == 2,
              Self.isValid(decoded) else {
            let recovery = fileURL.deletingPathExtension().appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.copyItem(at: fileURL, to: recovery)
            persistenceError = WalletError.corruptStoreRecovered.localizedDescription
            return
        }
        cylinders = decoded.cylinders; suppliers = decoded.suppliers; activity = decoded.activity.sorted { $0.occurredAt > $1.occurredAt }
        currencyOverride = decoded.currencyOverride; defaults = decoded.defaults
        let activeIDs = Set(activeCylinders.map(\.id))
        let restoredManagedIDs = decoded.freeManagedCylinderIDs ?? []
        freeManagedCylinderIDs = Set(activeCylinders.lazy.map(\.id).filter { activeIDs.contains($0) && restoredManagedIDs.contains($0) }.prefix(Self.freeActiveCylinderLimit))
        let reminderLocale = Self.selectedLocale
        for cylinder in cylinders {
            Task { await LocalReminderScheduler.schedule(cylinder: cylinder, at: cylinder.lifecycle == .active ? cylinder.reminderAt : nil, locale: reminderLocale) }
        }
    }

    private static var selectedLocale: Locale {
        Locale(identifier: UserDefaults.standard.string(forKey: "wallet.language") ?? Locale.preferredLanguages.first ?? "en")
    }

    private static func isValid(_ snapshot: WalletSnapshot) -> Bool {
        let cylinderIDs = snapshot.cylinders.map(\.id)
        let supplierIDs = snapshot.suppliers.map(\.id)
        let activityIDs = snapshot.activity.map(\.id)
        guard Set(cylinderIDs).count == cylinderIDs.count,
              Set(supplierIDs).count == supplierIDs.count,
              Set(activityIDs).count == activityIDs.count else { return false }

        let knownCylinders = Set(cylinderIDs)
        let knownSuppliers = Set(supplierIDs)
        let supplierNames = snapshot.suppliers.map { $0.name.trimmed.lowercased() }
        guard supplierNames.allSatisfy({ !$0.isEmpty }), Set(supplierNames).count == supplierNames.count else { return false }
        let serials = snapshot.cylinders.map { $0.serial.trimmed.lowercased() }.filter { !$0.isEmpty }
        guard Set(serials).count == serials.count else { return false }
        guard snapshot.cylinders.allSatisfy({ cylinder in
            !cylinder.gas.trimmed.isEmpty && cylinder.capacityValue.isFinite && cylinder.capacityValue > 0 && validUnit(cylinder.capacityUnit) &&
            (cylinder.supplierID == nil || knownSuppliers.contains(cylinder.supplierID!))
        }) else { return false }
        guard snapshot.activity.allSatisfy({ event in
            guard knownCylinders.contains(event.cylinderID), event.amountMinor == nil || event.amountMinor! >= 0 else { return false }
            if let code = event.currencyCode { return event.amountMinor != nil && Locale.Currency.isoCurrencies.contains(where: { $0.identifier == code }) }
            return event.amountMinor == nil
        }) else { return false }
        if let currency = snapshot.currencyOverride,
           !Locale.Currency.isoCurrencies.contains(where: { $0.identifier == currency }) { return false }
        guard validUnit(snapshot.defaults.capacityUnit), snapshot.defaults.supplierID == nil || knownSuppliers.contains(snapshot.defaults.supplierID!) else { return false }
        return true
    }

    private func captureState() -> StoreState {
        StoreState(cylinders: cylinders, suppliers: suppliers, activity: activity, lastDeleted: lastDeleted, freeManagedCylinderIDs: freeManagedCylinderIDs, currencyOverride: currencyOverride, defaults: defaults)
    }

    private func apply(_ state: StoreState) {
        cylinders = state.cylinders; suppliers = state.suppliers; activity = state.activity
        lastDeleted = state.lastDeleted; freeManagedCylinderIDs = state.freeManagedCylinderIDs
        currencyOverride = state.currencyOverride; defaults = state.defaults
    }

    @discardableResult private func commit(_ mutation: () -> Void) -> Bool {
        let previous = captureState()
        mutation()
        guard persistCurrentState() else { apply(previous); return false }
        return true
    }

    private func reconciledManagedIDs(isEntitled: Bool, proposed: Set<UUID>) -> Set<UUID> {
        guard !isEntitled else { return [] }
        let activeIDs = Set(activeCylinders.map(\.id))
        if activeIDs.count <= Self.freeActiveCylinderLimit { return activeIDs }
        return Set(activeCylinders.lazy.map(\.id).filter(proposed.contains).prefix(Self.freeActiveCylinderLimit))
    }

    private static func validUnit(_ unit: String) -> Bool { ["L", "ft3", "m3", "kg", "lb"].contains(unit) }

    private static func minorUnits(_ amount: Decimal) -> Int64? {
        let number = NSDecimalNumber(decimal: amount * 100)
        guard number != .notANumber,
              number.compare(NSDecimalNumber(value: Int64.max)) != .orderedDescending else { return nil }
        return number.rounding(accordingToBehavior: NSDecimalNumberHandler(roundingMode: .plain, scale: 0, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false)).int64Value
    }

    private static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appending(path: "WeldingGasWallet/wallet-v2.json")
    }

    static func preview() -> WalletStore {
        let store = WalletStore(fileURL: FileManager.default.temporaryDirectory.appending(path: "welding-wallet-preview-\(UUID().uuidString).json"), loadExisting: false)
        let airgas = store.addSupplier(name: "Airgas")!
        let praxair = store.addSupplier(name: "Praxair")!
        _ = store.addCylinder(gas: "Argon", capacity: 80, unit: "ft3", supplierID: airgas.id, relationship: .rental, serial: "AR-8084", isEntitled: true)
        _ = store.addCylinder(gas: "C25 Mix", capacity: 75, unit: "ft3", supplierID: airgas.id, relationship: .rental, serial: "C25-4419", isEntitled: true)
        _ = store.addCylinder(gas: "Oxygen", capacity: 40, unit: "ft3", supplierID: praxair.id, relationship: .owned, serial: "OX-2037", isEntitled: true)
        if store.cylinders.count > 1 { store.setStatus(.low, for: store.cylinders[1].id, isEntitled: true) }
        if store.cylinders.count > 2 { store.setStatus(.away, for: store.cylinders[2].id, isEntitled: true) }
        return store
    }

#if DEBUG || SCREENSHOT_BUILD
    /// Deterministic, screenshot-only fixture spanning September 2025 through
    /// August 2026. It is activated exclusively by the UI-test launch flag and
    /// never enters a normal user's on-device wallet.
    static func screenshotYear(openSlot: Bool = false) -> WalletStore {
        let store = WalletStore(
            fileURL: FileManager.default.temporaryDirectory.appending(path: "welding-wallet-screenshots-\(UUID().uuidString).json"),
            loadExisting: false
        )
        let calendar = Calendar(identifier: .gregorian)
        func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 9) -> Date {
            calendar.date(from: DateComponents(timeZone: TimeZone(secondsFromGMT: 0), year: year, month: month, day: day, hour: hour))!
        }

        let lindeID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let airLiquideID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
        let localID = UUID(uuidString: "10000000-0000-0000-0000-000000000003")!
        let argonID = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
        let c25ID = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
        let oxygenID = UUID(uuidString: "20000000-0000-0000-0000-000000000003")!
        let acetyleneID = UUID(uuidString: "20000000-0000-0000-0000-000000000004")!

        store.suppliers = [
            SupplierRecord(id: lindeID, name: "Linde Canada", phone: "905-555-0142", notes: "Argon and C25 exchanges"),
            SupplierRecord(id: airLiquideID, name: "Air Liquide", phone: "905-555-0186", notes: "Oxygen refills"),
            SupplierRecord(id: localID, name: "Brampton Welding Supply", phone: "905-555-0118", notes: "Backup supplier"),
        ]
        store.cylinders = [
            CylinderRecord(id: argonID, gas: "Argon", capacityValue: 80, capacityUnit: "ft3", supplierID: lindeID, relationship: .owned, serial: "AR-8084", status: .ready, acquiredAt: date(2025, 9, 3), reminderAt: date(2026, 9, 17), notes: "TIG bench"),
            CylinderRecord(id: c25ID, gas: "C25 Mix", capacityValue: 125, capacityUnit: "ft3", supplierID: lindeID, relationship: .rental, serial: "C25-4419", status: .low, acquiredAt: date(2025, 10, 6), notes: "MIG cart"),
            CylinderRecord(id: oxygenID, gas: "Oxygen", capacityValue: 40, capacityUnit: "ft3", supplierID: airLiquideID, relationship: .owned, serial: "OX-2037", status: .away, acquiredAt: date(2026, 1, 12), notes: "With mobile repair kit"),
            CylinderRecord(id: acetyleneID, gas: "Acetylene", capacityValue: 75, capacityUnit: "ft3", supplierID: localID, relationship: .deposit, serial: "AC-7315", status: .empty, lifecycle: .archived, acquiredAt: date(2025, 9, 18), notes: "Returned after torch upgrade"),
        ]
        if openSlot, let index = store.cylinders.firstIndex(where: { $0.id == oxygenID }) {
            store.cylinders[index].lifecycle = .archived
        }
        store.activity = [
            ActivityRecord(cylinderID: c25ID, kind: .status, occurredAt: date(2026, 8, 28), title: "C25 Mix marked Low", detail: "Linde Canada · 125 ft³"),
            ActivityRecord(cylinderID: oxygenID, kind: .status, occurredAt: date(2026, 8, 12), title: "Oxygen marked Away", detail: "Mobile repair job"),
            ActivityRecord(cylinderID: argonID, kind: .refill, occurredAt: date(2026, 6, 29), title: "Argon refill", detail: "Linde Canada", amountMinor: 6375, currencyCode: "CAD"),
            ActivityRecord(cylinderID: acetyleneID, kind: .archived, occurredAt: date(2026, 6, 3), title: "Acetylene archived", detail: "History retained"),
            ActivityRecord(cylinderID: c25ID, kind: .exchange, occurredAt: date(2026, 5, 17), title: "C25 Mix exchange", detail: "Replacement C25-6721", amountMinor: 7950, currencyCode: "CAD"),
            ActivityRecord(cylinderID: c25ID, kind: .status, occurredAt: date(2026, 4, 18), title: "C25 Mix marked Low", detail: "Linde Canada · 125 ft³"),
            ActivityRecord(cylinderID: oxygenID, kind: .refill, occurredAt: date(2026, 3, 2), title: "Oxygen refill", detail: "Air Liquide", amountMinor: 4400, currencyCode: "CAD"),
            ActivityRecord(cylinderID: argonID, kind: .refill, occurredAt: date(2026, 2, 21), title: "Argon refill", detail: "Linde Canada", amountMinor: 6110, currencyCode: "CAD"),
            ActivityRecord(cylinderID: oxygenID, kind: .created, occurredAt: date(2026, 1, 12), title: "Oxygen added", detail: "Air Liquide · 40 ft³"),
            ActivityRecord(cylinderID: c25ID, kind: .exchange, occurredAt: date(2025, 12, 5), title: "C25 Mix exchange", detail: "Replacement C25-4419", amountMinor: 7425, currencyCode: "CAD"),
            ActivityRecord(cylinderID: c25ID, kind: .status, occurredAt: date(2025, 12, 2), title: "C25 Mix marked Empty", detail: "Linde Canada · 125 ft³"),
            ActivityRecord(cylinderID: argonID, kind: .refill, occurredAt: date(2025, 11, 14), title: "Argon refill", detail: "Linde Canada", amountMinor: 5840, currencyCode: "CAD"),
            ActivityRecord(cylinderID: c25ID, kind: .cost, occurredAt: date(2025, 10, 6), title: "C25 Mix cost", detail: "Rental deposit", amountMinor: 12000, currencyCode: "CAD"),
            ActivityRecord(cylinderID: c25ID, kind: .created, occurredAt: date(2025, 10, 6), title: "C25 Mix added", detail: "Linde Canada · 125 ft³"),
            ActivityRecord(cylinderID: acetyleneID, kind: .created, occurredAt: date(2025, 9, 18), title: "Acetylene added", detail: "Brampton Welding Supply · 75 ft³"),
            ActivityRecord(cylinderID: argonID, kind: .created, occurredAt: date(2025, 9, 3), title: "Argon added", detail: "Linde Canada · 80 ft³"),
        ]
        store.currencyOverride = "CAD"
        store.defaults = CylinderDefaults(supplierID: lindeID, relationship: .owned, capacityUnit: "ft3")
        store.save()
        return store
    }
#endif
}

enum WalletError: LocalizedError {
    case backupTooLarge, unsupportedBackup, invalidBackup, persistenceFailure, corruptStoreRecovered, activeCylinderLimit(Int)
    var errorDescription: String? {
        switch self {
        case .backupTooLarge: "The backup is larger than 5 MB."
        case .unsupportedBackup: "This backup format is not supported."
        case .invalidBackup: "The backup contains invalid or inconsistent records."
        case .persistenceFailure: "The wallet could not be saved. No changes were applied."
        case .corruptStoreRecovered: "The saved wallet was damaged. A recovery copy was preserved."
        case .activeCylinderLimit(let limit): "This backup contains more than \(limit) active cylinders."
        }
    }
}

struct WalletBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
