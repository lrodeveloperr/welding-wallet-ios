import SwiftUI
import UserNotifications

@MainActor
final class WeldingWalletFeatureProvider: FeatureCanvasProviding {
    let store: WalletStore
    init(store: WalletStore) { self.store = store }

    func makeCanvas(for destination: ShellDestination, context: FeatureCanvasContext) -> AnyView {
        AnyView(Group {
            switch destination.id {
            case "activity": ActivityHome(store: store)
            case "suppliers": SupplierHome(store: store, isEntitled: context.isEntitled, requestUpgrade: context.requestUpgrade)
            default: CylinderHome(store: store, context: context)
            }
        })
    }
}

struct CylinderSymbol: View {
    var body: some View {
        Canvas { context, size in
            let line = StrokeStyle(lineWidth: max(1.5, size.width * 0.085), lineCap: .round, lineJoin: .round)
            var path = Path()
            path.addRoundedRect(in: CGRect(x: size.width * 0.25, y: size.height * 0.25, width: size.width * 0.5, height: size.height * 0.68), cornerSize: CGSize(width: size.width * 0.12, height: size.width * 0.12))
            path.move(to: CGPoint(x: size.width * 0.38, y: size.height * 0.25))
            path.addLine(to: CGPoint(x: size.width * 0.38, y: size.height * 0.11))
            path.addLine(to: CGPoint(x: size.width * 0.62, y: size.height * 0.11))
            path.addLine(to: CGPoint(x: size.width * 0.62, y: size.height * 0.25))
            context.stroke(path, with: .foreground, style: line)
        }
        .accessibilityHidden(true)
    }
}

private enum StatusFilter: String, CaseIterable, Identifiable {
    case all = "All", ready = "Ready", low = "Low", empty = "Empty", away = "Away"
    var id: String { rawValue }
    var localizationKey: String { self == .all ? "common.all" : "status.\(rawValue.lowercased())" }
}

struct CylinderHome: View {
    @Bindable var store: WalletStore
    let context: FeatureCanvasContext
    @Environment(\.locale) private var locale
    @State private var query = ""
    @State private var filter = StatusFilter.all
    @State private var expandedStatusID: UUID?
    @State private var showingAdd = false
    @State private var showingFreeSelection = false

    private var visible: [CylinderRecord] {
        store.activeCylinders.filter { cylinder in
            let statusMatches = filter == .all || cylinder.status.rawValue == filter.rawValue
            let supplier = store.supplierName(cylinder.supplierID)
            let haystack = [
                AppLocalization.gas(cylinder.gas, locale: locale),
                cylinder.capacityLabel(locale: locale),
                AppLocalization.supplier(supplier, locale: locale),
                AppLocalization.string(cylinder.relationship.localizationKey, locale: locale),
                AppLocalization.string(cylinder.status.localizationKey, locale: locale),
                cylinder.serial,
            ].joined(separator: " ")
            return statusMatches && (query.isEmpty || haystack.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 14) {
                    summaryCard
                    searchAndFilters
                    if visible.isEmpty { emptyState }
                    else {
                        LazyVGrid(columns: geometry.size.width >= 700 ? [GridItem(.flexible()), GridItem(.flexible())] : [GridItem(.flexible())], spacing: 12) {
                            ForEach(visible) { cylinder in
                                CylinderCard(store: store, cylinder: cylinder, expanded: expandedStatusID == cylinder.id, isEntitled: context.isEntitled, requestUpgrade: context.requestUpgrade) {
                                    withAnimation(.snappy) { expandedStatusID = expandedStatusID == cylinder.id ? nil : cylinder.id }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: 980)
                .padding(16)
                .frame(maxWidth: .infinity)
            }
            .overlay(alignment: .bottomTrailing) {
                Button { addTapped() } label: { Image(systemName: "plus").font(.title2.bold()).frame(width: 58, height: 58) }
                    .buttonStyle(.borderedProminent).buttonBorderShape(.circle).padding(20)
                    .accessibilityLabel("Add cylinder")
                    .accessibilityIdentifier("wallet.addCylinder")
            }
            .sheet(isPresented: $showingAdd) { NavigationStack { CylinderForm(store: store, mode: .new, isEntitled: context.isEntitled) } }
            .sheet(isPresented: $showingFreeSelection) {
                NavigationStack { FreeCylinderSelectionView(store: store, isEntitled: context.isEntitled) }
            }
            .safeAreaInset(edge: .bottom) {
                if let deleted = store.lastDeleted {
                    HStack { Text(AppLocalization.string("cylinder.deleted %@", locale: locale, AppLocalization.gas(deleted.cylinder.gas, locale: locale))); Spacer(); Button("Undo") { store.undoDelete() } }
                        .padding().background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 14)).padding(.horizontal)
                }
            }
            .onAppear(perform: synchronizeAccess)
            .onChange(of: context.isEntitled()) { _, _ in synchronizeAccess() }
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 16) {
            CylinderSymbol().frame(width: 30, height: 44).foregroundStyle(.tint).padding(12).background(Color.blue.opacity(0.08), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(AppLocalization.string(store.activeCylinders.count == 1 ? "cylinders.active.one" : "cylinders.active.other", locale: locale, store.activeCylinders.count)).font(.headline)
                if !context.isEntitled() { Text(freeSummary).foregroundStyle(.secondary) }
            }
            Spacer()
            if !context.isEntitled() {
                if store.requiresFreeCylinderSelection(isEntitled: false) {
                    Button("freeSelection.choose") { showingFreeSelection = true }
                } else {
                    Button("Upgrade", action: context.requestUpgrade)
                }
            }
        }
        .padding(18).background(.background).clipShape(RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(.separator))
    }

    private var searchAndFilters: some View {
        VStack(spacing: 10) {
            HStack { Image(systemName: "magnifyingglass").foregroundStyle(.secondary); TextField("Search cylinders", text: $query).textInputAutocapitalization(.never); if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain) } }
                .padding(.horizontal, 12).frame(minHeight: 44).background(Color.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack { ForEach(StatusFilter.allCases) { item in Button { filter = item } label: { Text(LocalizedStringKey(item.localizationKey)) }.buttonStyle(.bordered).buttonBorderShape(.capsule).tint(filter == item ? .accentColor : .secondary) } }
            }
        }
    }

    private var emptyState: some View {
        Group {
            if query.isEmpty && filter == .all {
                ContentUnavailableView("No cylinders yet", systemImage: "shippingbox", description: Text("Add a gas and capacity to start your wallet."))
            } else {
                ContentUnavailableView("No matching cylinders", systemImage: "shippingbox", description: Text("Try another search or filter."))
            }
        }.frame(minHeight: 280)
    }

    private func addTapped() {
        if !store.canAddCylinder(isEntitled: context.isEntitled()) { context.requestUpgrade() }
        else { showingAdd = true }
    }

    private func synchronizeAccess() {
        let entitled = context.isEntitled()
        store.reconcileAccess(isEntitled: entitled)
        if !entitled && store.requiresFreeCylinderSelection(isEntitled: false) {
            expandedStatusID = nil
            showingFreeSelection = true
        }
    }

    private var freeSummary: String {
        let activeCount = store.activeCylinders.count
        guard activeCount > WalletStore.freeActiveCylinderLimit else {
            return AppLocalization.string("cylinders.free.count", locale: locale, activeCount)
        }
        if store.requiresFreeCylinderSelection(isEntitled: false) {
            return AppLocalization.string("cylinders.free.selection", locale: locale)
        }
        let readOnlyCount = activeCount - store.freeManagedCylinderIDs.count
        return AppLocalization.string("cylinders.free.managed %lld", locale: locale, readOnlyCount)
    }
}

private struct FreeCylinderSelectionView: View {
    @Bindable var store: WalletStore
    let isEntitled: () -> Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var selection: Set<UUID>

    init(store: WalletStore, isEntitled: @escaping () -> Bool) {
        self.store = store
        self.isEntitled = isEntitled
        _selection = State(initialValue: store.freeManagedCylinderIDs)
    }

    var body: some View {
        List {
            Section {
                Text("freeSelection.message")
                    .foregroundStyle(.secondary)
            }
            Section("freeSelection.section") {
                ForEach(store.activeCylinders) { cylinder in
                    Button { toggle(cylinder.id) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(AppLocalization.gas(cylinder.gas, locale: locale)).foregroundStyle(.primary)
                                Text("\(cylinder.capacityLabel(locale: locale)) · \(AppLocalization.supplier(store.supplierName(cylinder.supplierID), locale: locale))").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selection.contains(cylinder.id) { Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint) }
                        }
                    }
                    .disabled(store.freeManagedCylinderIDs.contains(cylinder.id))
                    .accessibilityAddTraits(selection.contains(cylinder.id) ? .isSelected : [])
                }
            }
            Section { Text("freeSelection.dataNotice").font(.footnote).foregroundStyle(.secondary) }
        }
        .navigationTitle("freeSelection.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Not now") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("freeSelection.confirm") {
                    if store.selectFreeManagedCylinders(selection, isEntitled: isEntitled()) { dismiss() }
                }
                .disabled(selection.count != min(WalletStore.freeActiveCylinderLimit, store.activeCylinders.count))
            }
        }
        .onChange(of: isEntitled()) { _, entitled in if entitled { dismiss() } }
    }

    private func toggle(_ id: UUID) {
        guard !store.freeManagedCylinderIDs.contains(id) else { return }
        if selection.contains(id) { selection.remove(id) }
        else if selection.count < WalletStore.freeActiveCylinderLimit { selection.insert(id) }
    }
}

private struct CylinderCard: View {
    @Bindable var store: WalletStore
    let cylinder: CylinderRecord
    let expanded: Bool
    let isEntitled: () -> Bool
    let requestUpgrade: () -> Void
    let toggle: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        let entitled = isEntitled()
        let canManage = store.canManageCylinder(cylinder.id, isEntitled: entitled)
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Text(String((store.activeCylinders.firstIndex(where: { $0.id == cylinder.id }) ?? 0) + 1)).font(.headline).foregroundStyle(.tint).frame(width: 38, height: 44).background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                NavigationLink { CylinderDetail(store: store, cylinderID: cylinder.id, isEntitled: isEntitled, requestUpgrade: requestUpgrade) } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(AppLocalization.gas(cylinder.gas, locale: locale)).font(.title3.bold()).foregroundStyle(.primary)
                        Text(cylinder.capacityLabel(locale: locale)).foregroundStyle(.primary)
                        Text("\(AppLocalization.supplier(store.supplierName(cylinder.supplierID), locale: locale)) · \(AppLocalization.string(cylinder.relationship.localizationKey, locale: locale))").font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain)
                if canManage { StatusBadge(status: cylinder.status) }
                else { Image(systemName: "lock.fill").foregroundStyle(.secondary).accessibilityLabel(Text("cylinder.readOnly")) }
                Button(action: canManage ? toggle : requestUpgrade) { Image(systemName: canManage && expanded ? "chevron.up" : "chevron.forward") }.buttonStyle(.plain).frame(minWidth: 44, minHeight: 44).accessibilityLabel(Text(canManage ? AppLocalization.string("cylinder.changeStatus %@", locale: locale, AppLocalization.gas(cylinder.gas, locale: locale)) : AppLocalization.string("cylinder.readOnly", locale: locale))).accessibilityIdentifier("wallet.status.\(cylinder.id.uuidString)")
            }.padding(14)
            if expanded {
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    Text("Update status").foregroundStyle(.secondary)
                    HStack(spacing: 8) { ForEach(CylinderStatus.allCases) { status in StatusButton(status: status, selected: cylinder.status == status) { store.setStatus(status, for: cylinder.id, isEntitled: isEntitled()) } } }
                }.padding(14)
            }
        }
        .background(.background).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(.separator))
    }
}

private struct StatusBadge: View {
    let status: CylinderStatus
    var color: Color { switch status { case .ready: .green; case .low: .orange; case .empty: .red; case .away: .blue } }
    var body: some View { Label { Text(LocalizedStringKey(status.localizationKey)) } icon: { Image(systemName: status.symbol) }.font(.subheadline.weight(.semibold)).foregroundStyle(color).padding(.horizontal, 10).padding(.vertical, 7).background(color.opacity(0.08), in: Capsule()).overlay(Capsule().stroke(color.opacity(0.35))) }
}

private struct StatusButton: View {
    let status: CylinderStatus; let selected: Bool; let action: () -> Void
    var color: Color { switch status { case .ready: .green; case .low: .orange; case .empty: .red; case .away: .blue } }
    var body: some View { Button(action: action) { VStack(spacing: 6) { Image(systemName: status.symbol).font(.title2); Text(LocalizedStringKey(status.localizationKey)).font(.caption.weight(.semibold)) }.frame(maxWidth: .infinity, minHeight: 70) }.buttonStyle(.plain).foregroundStyle(color).background(color.opacity(selected ? 0.12 : 0.04), in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(selected ? 0.8 : 0.35))) }
}

struct CylinderDetail: View {
    @Bindable var store: WalletStore
    let cylinderID: UUID
    var isEntitled: () -> Bool = { false }
    var requestUpgrade: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var sheet: DetailSheet?
    @State private var confirmLifecycle: CylinderLifecycle?
    @State private var showDelete = false

    private var cylinder: CylinderRecord? { store.cylinders.first { $0.id == cylinderID } }
    var body: some View {
        Group {
            if let cylinder {
                let canManage = store.canManageCylinder(cylinderID, isEntitled: isEntitled())
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(AppLocalization.gas(cylinder.gas, locale: locale).uppercased(with: locale)).font(.caption.bold()).foregroundStyle(.tint)
                            Text(cylinder.capacityLabel(locale: locale)).font(.largeTitle.bold())
                            StatusBadge(status: cylinder.status)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(20).background(Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            Fact(titleKey: "Supplier", value: AppLocalization.supplier(store.supplierName(cylinder.supplierID), locale: locale)); Fact(titleKey: "Relationship", value: AppLocalization.string(cylinder.relationship.localizationKey, locale: locale)); Fact(titleKey: "Serial", value: cylinder.serial.isEmpty ? AppLocalization.string("common.notSet", locale: locale) : cylinder.serial); Fact(titleKey: "Acquired", value: cylinder.acquiredAt.formatted(.dateTime.locale(locale).day().month(.abbreviated).year()))
                        }
                        if canManage {
                            HStack { Button("Refill") { sheet = .service(.refill) }.buttonStyle(.borderedProminent); Button("Exchange") { sheet = .service(.exchange) }.buttonStyle(.bordered); Button("Add cost") { sheet = .service(.cost) }.buttonStyle(.bordered) }
                            Button { sheet = .reminder } label: { Label(cylinder.reminderAt.map { AppLocalization.string("reminder.label %@", locale: locale, $0.formatted(.dateTime.locale(locale).day().month(.abbreviated).hour().minute())) } ?? AppLocalization.string("Add reminder", locale: locale), systemImage: "bell") }.buttonStyle(.bordered).frame(maxWidth: .infinity)
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("cylinder.readOnly", systemImage: "lock.fill").font(.headline)
                                Text("cylinder.readOnly.message").foregroundStyle(.secondary)
                                Button("cylinder.unlock", action: requestUpgrade).buttonStyle(.borderedProminent)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Recent activity").font(.headline)
                            ForEach(store.activity.filter { $0.cylinderID == cylinderID }.prefix(5)) { ActivityRow(store: store, item: $0) }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Menu("Return or archive") { Button("Return cylinder") { confirmLifecycle = .returned }; Button("Archive cylinder") { confirmLifecycle = .archived } }.buttonStyle(.bordered).frame(maxWidth: .infinity)
                        if !canManage { Button("Delete cylinder", role: .destructive) { showDelete = true }.buttonStyle(.bordered).frame(maxWidth: .infinity) }
                    }.frame(maxWidth: 720).padding(16).frame(maxWidth: .infinity)
                }
                .toolbar { if canManage { ToolbarItem(placement: .topBarTrailing) { Button("Edit") { sheet = .edit } } } }
                .sheet(item: $sheet) { value in NavigationStack { detailSheet(value, cylinder: cylinder) } }
                .confirmationDialog(AppLocalization.string(confirmLifecycle == .returned ? "Return this cylinder?" : "Archive this cylinder?", locale: locale), isPresented: Binding(get: { confirmLifecycle != nil }, set: { if !$0 { confirmLifecycle = nil } })) {
                    if let lifecycle = confirmLifecycle { Button(AppLocalization.string(lifecycle == .returned ? "Return cylinder" : "Archive cylinder", locale: locale)) { store.archive(cylinderID, as: lifecycle); dismiss() } }
                    Button("Cancel", role: .cancel) { confirmLifecycle = nil }
                }
                .alert("Delete cylinder?", isPresented: $showDelete) {
                    Button("Delete cylinder and history", role: .destructive) { store.delete(cylinderID); dismiss() }
                    Button("Cancel", role: .cancel) {}
                } message: { Text("You can undo for 15 seconds.") }
            } else { ContentUnavailableView("Cylinder not found", systemImage: "questionmark.square") }
        }.navigationTitle(cylinder.map { AppLocalization.gas($0.gas, locale: locale) } ?? AppLocalization.string("Cylinder", locale: locale)).navigationBarTitleDisplayMode(.inline).accessibilityIdentifier("screen.cylinderDetail")
    }

    @ViewBuilder private func detailSheet(_ sheet: DetailSheet, cylinder: CylinderRecord) -> some View {
        switch sheet { case .edit: CylinderForm(store: store, mode: .edit(cylinder), isEntitled: isEntitled); case .service(let kind): ServiceForm(store: store, cylinder: cylinder, kind: kind, isEntitled: isEntitled); case .reminder: ReminderForm(store: store, cylinder: cylinder, isEntitled: isEntitled) }
    }
}

private enum DetailSheet: Identifiable { case edit, service(ActivityKind), reminder; var id: String { switch self { case .edit: "edit"; case .service(let k): k.rawValue; case .reminder: "reminder" } } }

private struct Fact: View { let titleKey: LocalizedStringKey; let value: String; var body: some View { VStack(alignment: .leading, spacing: 4) { Text(titleKey).textCase(.uppercase).font(.caption2.bold()).foregroundStyle(.secondary); Text(value).font(.subheadline.weight(.semibold)).lineLimit(2) }.frame(maxWidth: .infinity, minHeight: 58, alignment: .leading).padding(12).background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12)) } }

private enum CylinderFormMode { case new, edit(CylinderRecord), duplicate(CylinderRecord) }

private struct CylinderForm: View {
    @Bindable var store: WalletStore
    let mode: CylinderFormMode
    let isEntitled: () -> Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var gas = ""
    @State private var customGas = ""
    @State private var capacity = ""
    @State private var unit = "ft3"
    @State private var supplierID: UUID?
    @State private var relationship: Relationship = .notSet
    @State private var serial = ""
    @State private var notes = ""
    @State private var showOptional = false
    @State private var showSupplier = false
    @State private var showDelete = false
    @State private var errorKey = ""

    var body: some View {
        Form {
            if !errorKey.isEmpty { Text(LocalizedStringKey(errorKey)).foregroundStyle(.red) }
            if case .new = mode, !store.activeCylinders.isEmpty {
                Section("Copy an existing cylinder") {
                    ForEach(store.activeCylinders) { cylinder in
                        Button { copy(cylinder) } label: {
                            VStack(alignment: .leading) {
                                Text(AppLocalization.gas(cylinder.gas, locale: locale))
                                Text("\(cylinder.capacityLabel(locale: locale)) · \(AppLocalization.supplier(store.supplierName(cylinder.supplierID), locale: locale))").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            Section {
                Picker("Gas", selection: $gas) { ForEach(["", "Argon", "C25 Mix", "Oxygen", "Acetylene", "Nitrogen", "CO₂", "Helium", "Other"], id: \.self) { value in Text(LocalizedStringKey(value.isEmpty ? "Choose gas" : value)).tag(value) } }
                if gas == "Other" { TextField("Custom gas", text: $customGas) }
                HStack { TextField("Capacity", text: $capacity).keyboardType(.decimalPad); Picker("Unit", selection: $unit) { ForEach(["ft3", "L", "m3", "kg", "lb"], id: \.self) { Text($0.replacingOccurrences(of: "3", with: "³")) } }.labelsHidden() }
            }
            Section {
                DisclosureGroup("Add supplier, relationship or serial", isExpanded: $showOptional) {
                    Picker("Supplier", selection: $supplierID) { Text("Not set").tag(UUID?.none); ForEach(store.suppliers) { Text($0.name).tag(Optional($0.id)) } }
                    Button("Add supplier") { showSupplier = true }
                    Picker("Relationship", selection: $relationship) { ForEach(Relationship.allCases) { Text(LocalizedStringKey($0.localizationKey)).tag($0) } }
                    TextField("Serial number", text: $serial).textInputAutocapitalization(.characters)
                    TextField("Notes", text: $notes, axis: .vertical)
                }
            }
            if case .edit(let cylinder) = mode {
                Section { Button("Duplicate cylinder") { let entitled = isEntitled(); if !store.canAddCylinder(isEntitled: entitled) { errorKey = "error.upgradeRequired" } else if store.duplicate(cylinder, isEntitled: entitled) != nil { dismiss() } }.foregroundStyle(.tint); Button("Delete cylinder", role: .destructive) { showDelete = true } }
            }
        }
        .navigationTitle(LocalizedStringKey(titleKey)).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(resolvedGas.isEmpty || (AppLocalization.double(from: capacity, locale: locale) ?? 0) <= 0) } }
        .sheet(isPresented: $showSupplier) { NavigationStack { SupplierForm(store: store) { supplier in supplierID = supplier.id } } }
        .confirmationDialog("Delete \(gas)?", isPresented: $showDelete, titleVisibility: .visible) { Button("Delete cylinder and history", role: .destructive) { if case .edit(let cylinder) = mode { store.delete(cylinder.id); dismiss() } }; Button("Cancel", role: .cancel) {} } message: { Text("You can undo for 15 seconds.") }
        .onAppear(perform: seed)
    }

    private var titleKey: String { switch mode { case .new: "Add cylinder"; case .edit: "Edit cylinder"; case .duplicate: "Duplicate cylinder" } }
    private func seed() {
        switch mode {
        case .new: unit = store.defaults.capacityUnit; supplierID = store.defaults.supplierID; relationship = store.defaults.relationship
        case .edit(let c): copy(c); serial = c.serial; notes = c.notes
        case .duplicate(let c): copy(c); notes = c.notes
        }
    }
    private var resolvedGas: String { (gas == "Other" ? customGas : gas).trimmed }
    private func copy(_ cylinder: CylinderRecord) {
        let presets = ["Argon", "C25 Mix", "Oxygen", "Acetylene", "Nitrogen", "CO₂", "Helium"]
        if presets.contains(cylinder.gas) { gas = cylinder.gas; customGas = "" } else { gas = "Other"; customGas = cylinder.gas }
        capacity = AppLocalization.number(cylinder.capacityValue, locale: locale); unit = cylinder.capacityUnit; supplierID = cylinder.supplierID; relationship = cylinder.relationship
    }
    private func save() {
        guard let value = AppLocalization.double(from: capacity, locale: locale), value > 0 else { errorKey = "error.validCapacity"; return }
        let success: Bool
        let entitled = isEntitled()
        switch mode {
        case .new, .duplicate:
            guard store.canAddCylinder(isEntitled: entitled) else { errorKey = "error.upgradeRequired"; return }
            success = store.addCylinder(gas: resolvedGas, capacity: value, unit: unit, supplierID: supplierID, relationship: relationship, serial: serial, notes: notes, isEntitled: entitled) != nil
        case .edit(var c):
            guard store.canManageCylinder(c.id, isEntitled: entitled) else { errorKey = "error.readOnly"; return }
            c.gas = resolvedGas; c.capacityValue = value; c.capacityUnit = unit; c.supplierID = supplierID; c.relationship = relationship; c.serial = serial; c.notes = notes; success = store.update(c, isEntitled: entitled)
        }
        if success { dismiss() } else { errorKey = "error.requiredUniqueSerial" }
    }
}

private struct ServiceForm: View {
    @Bindable var store: WalletStore
    let cylinder: CylinderRecord
    let kind: ActivityKind
    let isEntitled: () -> Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var amount = ""
    @State private var date = Date.now
    @State private var replacementSerial = ""
    @State private var sameCapacity = true
    @State private var capacity = ""
    @State private var unit = "ft3"
    @State private var errorKey = ""

    private var lastAmount: Decimal? { store.activity.first { $0.cylinderID == cylinder.id && $0.amountMinor != nil && $0.currencyCode == store.defaultCurrency }.flatMap { $0.amountMinor.map { Decimal($0) / 100 } } }
    var body: some View {
        Form {
            Text(AppLocalization.string("service.todayCurrency %@", locale: locale, store.currencySign(for: store.defaultCurrency))).font(.subheadline).foregroundStyle(.secondary)
            if !errorKey.isEmpty { Text(LocalizedStringKey(errorKey)).foregroundStyle(.red) }
            Section {
                HStack { Text(store.currencySign(for: store.defaultCurrency)); TextField("0.00", text: $amount).keyboardType(.decimalPad) }
                if let lastAmount { Button(AppLocalization.string("service.useLastCost %@%@", locale: locale, store.currencySign(for: store.defaultCurrency), AppLocalization.number(lastAmount, locale: locale))) { amount = AppLocalization.number(lastAmount, locale: locale) } }
                DatePicker("Date", selection: $date, displayedComponents: .date)
            }
            if kind == .exchange {
                Section("Replacement") {
                    TextField("Serial number (optional)", text: $replacementSerial).textInputAutocapitalization(.characters)
                    Toggle("Same capacity", isOn: $sameCapacity)
                    if !sameCapacity { HStack { TextField("Capacity", text: $capacity).keyboardType(.decimalPad); Picker("Unit", selection: $unit) { ForEach(["ft3", "L", "m3", "kg", "lb"], id: \.self, content: Text.init) }.labelsHidden() } }
                }
            }
        }
        .navigationTitle(LocalizedStringKey(kind.localizationKey)).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled((AppLocalization.decimal(from: amount, locale: locale) ?? 0) <= 0) } }
        .onAppear { unit = cylinder.capacityUnit }
    }
    private func save() {
        let value = AppLocalization.decimal(from: amount, locale: locale)
        let replacementCapacity = sameCapacity ? nil : AppLocalization.double(from: capacity, locale: locale)
        let entitled = isEntitled()
        guard store.canManageCylinder(cylinder.id, isEntitled: entitled) else { errorKey = "error.readOnly"; return }
        if !store.recordService(for: cylinder.id, kind: kind, amount: value, currency: store.defaultCurrency, date: date, replacementSerial: replacementSerial, replacementCapacity: replacementCapacity, replacementUnit: sameCapacity ? nil : unit, isEntitled: entitled) { errorKey = "error.positiveAmountUniqueSerial" } else { dismiss() }
    }
}

private struct ReminderForm: View {
    @Bindable var store: WalletStore; let cylinder: CylinderRecord; let isEntitled: () -> Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var enabled = true; @State private var days = 7; @State private var custom = false; @State private var date = Calendar.current.date(byAdding: .day, value: 7, to: .now)!
    var body: some View {
        Form {
            Toggle("Refill reminder", isOn: $enabled)
            if enabled {
                Section("Remind me") {
                    HStack {
                        ForEach([3, 7, 14], id: \.self) { value in
                            Button(AppLocalization.string("days.other", locale: locale, value)) {
                                days = value; custom = false
                                date = Calendar.current.date(byAdding: .day, value: value, to: .now)!
                            }.buttonStyle(.bordered).tint(days == value && !custom ? .accentColor : .secondary)
                        }
                        Button("Custom") { custom = true }.buttonStyle(.bordered)
                    }
                    if custom { DatePicker("Date and time", selection: $date, in: Date.now...) }
                    else { Text(AppLocalization.string("reminder.scheduled %@", locale: locale, date.formatted(.dateTime.locale(locale).day().month(.abbreviated).hour().minute()))) }
                }
            }
            Section { Text("The reminder is scheduled locally on this device.").font(.footnote).foregroundStyle(.secondary) }
        }
        .navigationTitle("Reminder")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { if store.setReminder(enabled ? date : nil, for: cylinder.id, isEntitled: isEntitled()) { Task { await LocalReminderScheduler.schedule(cylinder: cylinder, at: enabled ? date : nil, locale: locale) }; dismiss() } } }
        }
        .onAppear { if let existing = cylinder.reminderAt { date = existing; enabled = true } }
    }
}

enum LocalReminderScheduler {
    static func schedule(cylinder: CylinderRecord, at date: Date?, locale: Locale = .current) async {
        let center = UNUserNotificationCenter.current(); center.removePendingNotificationRequests(withIdentifiers: ["cylinder-\(cylinder.id.uuidString)"])
        guard let date else { return }
        let granted = try? await center.requestAuthorization(options: [.alert, .sound]); guard granted == true else { return }
        let content = UNMutableNotificationContent(); content.title = AppLocalization.string("notification.check %@", locale: locale, AppLocalization.gas(cylinder.gas, locale: locale)); content.body = AppLocalization.string("notification.review", locale: locale); content.sound = .default
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        try? await center.add(UNNotificationRequest(identifier: "cylinder-\(cylinder.id.uuidString)", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)))
    }
}

struct ActivityHome: View {
    @Bindable var store: WalletStore
    @Environment(\.locale) private var locale
    @State private var filter: ActivityKind?
    var filtered: [ActivityRecord] { filter.map { selected in store.activity.filter { $0.kind == selected } } ?? store.activity }
    var body: some View { GeometryReader { geometry in ScrollView { VStack(spacing: 14) { LazyVGrid(columns: geometry.size.width >= 700 ? [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())] : [GridItem(.flexible())], spacing: 10) { Metric(titleKey: "Total spent", value: store.totals().map { "\(store.currencySign(for: $0.0))\(AppLocalization.number($0.1, locale: locale))" }.joined(separator: " · ").nilIfEmpty ?? "—", noteKey: "Currencies stay separate"); Metric(titleKey: "Refill count", value: "\(store.refillCount)", noteKey: "Recorded refills"); Metric(titleKey: "Average refill interval", value: store.averageRefillIntervalDays.map { AppLocalization.string($0 == 1 ? "days.one" : "days.other", locale: locale, $0) } ?? "—", noteKey: "Across repeat refills") }; ScrollView(.horizontal, showsIndicators: false) { HStack { Button("All") { filter = nil }.buttonStyle(.bordered); Button("Refills") { filter = .refill }.buttonStyle(.bordered); Button("Status") { filter = .status }.buttonStyle(.bordered) } }; LazyVGrid(columns: geometry.size.width >= 700 ? [GridItem(.flexible()), GridItem(.flexible())] : [GridItem(.flexible())], spacing: 10) { ForEach(filtered) { ActivityRow(store: store, item: $0) } } }.frame(maxWidth: 980).padding(16).frame(maxWidth: .infinity) } } }
}

private struct Metric: View { let titleKey: LocalizedStringKey; let value: String; let noteKey: LocalizedStringKey; var body: some View { VStack(alignment: .leading, spacing: 5) { Text(titleKey).font(.caption).foregroundStyle(.secondary); Text(value).font(.title3.bold()); Text(noteKey).font(.caption2).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, minHeight: 82, alignment: .leading).padding(14).background(.background, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(.separator)) } }
private struct ActivityRow: View {
    let store: WalletStore; let item: ActivityRecord
    @Environment(\.locale) private var locale
    private var cylinderGas: String { store.cylinders.first { $0.id == item.cylinderID }.map { AppLocalization.gas($0.gas, locale: locale) } ?? item.title }
    private var localizedTitle: String { AppLocalization.string("activity.title.\(item.kind.rawValue) %@", locale: locale, cylinderGas) }
    private var localizedDetail: String {
        if item.detail == "History retained" { return AppLocalization.string("activity.historyRetained", locale: locale) }
        if item.detail.hasPrefix("Replacement ") { return AppLocalization.string("activity.replacement %@", locale: locale, String(item.detail.dropFirst("Replacement ".count))) }
        return AppLocalization.supplier(item.detail, locale: locale)
    }
    var body: some View { HStack(spacing: 12) { Image(systemName: item.kind == .refill ? "arrow.clockwise" : item.kind == .status ? "checkmark.circle" : "doc.text").foregroundStyle(.tint).frame(width: 34, height: 34).background(Color.blue.opacity(0.08), in: Circle()); VStack(alignment: .leading, spacing: 3) { Text(localizedTitle).font(.subheadline.weight(.semibold)); Text(localizedDetail).font(.caption).foregroundStyle(.secondary) }; Spacer(); VStack(alignment: .trailing) { if let minor = item.amountMinor, let code = item.currencyCode { Text("\(store.currencySign(for: code))\(AppLocalization.number(Decimal(minor) / 100, locale: locale))").font(.caption.bold()) }; Text(item.occurredAt.formatted(.dateTime.locale(locale).day().month(.abbreviated).year())).font(.caption2).foregroundStyle(.secondary) } }.padding(12).background(.background, in: RoundedRectangle(cornerRadius: 13)).overlay(RoundedRectangle(cornerRadius: 13).stroke(.separator)) }
}

struct SupplierHome: View {
    @Bindable var store: WalletStore
    let isEntitled: () -> Bool
    let requestUpgrade: () -> Void
    @Environment(\.locale) private var locale
    @State private var query = ""; @State private var showingAdd = false
    var visible: [SupplierRecord] { store.suppliers.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) } }
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 12) {
                    HStack { Image(systemName: "magnifyingglass"); TextField("Search suppliers", text: $query) }
                        .padding(.horizontal, 12).frame(minHeight: 44).background(Color.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
                    if visible.isEmpty {
                        ContentUnavailableView("No suppliers yet", systemImage: "person.2", description: Text("Add a supplier here or directly from a cylinder."))
                    } else {
                        LazyVGrid(columns: geometry.size.width >= 700 ? [GridItem(.flexible()), GridItem(.flexible())] : [GridItem(.flexible())], spacing: 10) {
                            ForEach(visible) { supplier in
                                NavigationLink { SupplierDetail(store: store, supplier: supplier, isEntitled: isEntitled, requestUpgrade: requestUpgrade) } label: {
                                    HStack {
                                        Text(initials(supplier.name)).font(.headline).foregroundStyle(.tint).frame(width: 46, height: 46).background(Color.blue.opacity(0.08), in: Circle())
                                        VStack(alignment: .leading) {
                                            Text(supplier.name).font(.headline).foregroundStyle(.primary)
                                            let count = store.activeCylinders.filter { $0.supplierID == supplier.id }.count
                                            Text(AppLocalization.string(count == 1 ? "cylinders.current.one" : "cylinders.current.other", locale: locale, count)).font(.subheadline).foregroundStyle(.secondary)
                                        }
                                        Spacer(); Image(systemName: "chevron.forward").foregroundStyle(.secondary)
                                    }
                                    .padding(14).background(.background, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(.separator))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }.frame(maxWidth: 980).padding(16).frame(maxWidth: .infinity)
            }
            .overlay(alignment: .bottomTrailing) { Button { showingAdd = true } label: { Image(systemName: "plus").font(.title2.bold()).frame(width: 58, height: 58) }.buttonStyle(.borderedProminent).buttonBorderShape(.circle).padding(20).accessibilityLabel("Add supplier").accessibilityIdentifier("wallet.addSupplier") }
            .sheet(isPresented: $showingAdd) { NavigationStack { SupplierForm(store: store) { _ in } } }
        }
    }
    private func initials(_ name: String) -> String { name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased() }
}

private struct SupplierDetail: View {
    @Bindable var store: WalletStore; let supplier: SupplierRecord; let isEntitled: () -> Bool; let requestUpgrade: () -> Void
    @Environment(\.locale) private var locale
    var body: some View { List { Section { HStack { Text(supplier.name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()).font(.title2.bold()).foregroundStyle(.tint).frame(width: 60, height: 60).background(Color.blue.opacity(0.08), in: Circle()); VStack(alignment: .leading) { Text(supplier.name).font(.title2.bold()); let count = store.activeCylinders.filter { $0.supplierID == supplier.id }.count; Text(AppLocalization.string(count == 1 ? "cylinders.current.one" : "cylinders.current.other", locale: locale, count)).foregroundStyle(.secondary) } } }; if !supplier.phone.isEmpty || !supplier.notes.isEmpty { Section { if !supplier.phone.isEmpty { LabeledContent("Phone", value: supplier.phone) }; if !supplier.notes.isEmpty { LabeledContent("Notes", value: supplier.notes) } } }; Section("Cylinders") { let linked = store.cylinders.filter { $0.supplierID == supplier.id }; if linked.isEmpty { Text("No linked cylinders").foregroundStyle(.secondary) } else { ForEach(linked) { cylinder in NavigationLink { CylinderDetail(store: store, cylinderID: cylinder.id, isEntitled: isEntitled, requestUpgrade: requestUpgrade) } label: { VStack(alignment: .leading) { Text(AppLocalization.gas(cylinder.gas, locale: locale)); Text("\(cylinder.capacityLabel(locale: locale)) · \(AppLocalization.string(cylinder.lifecycle.localizationKey, locale: locale))").font(.caption).foregroundStyle(.secondary) } } } } } }.navigationTitle(supplier.name).navigationBarTitleDisplayMode(.inline) }
}

private struct SupplierForm: View { @Bindable var store: WalletStore; let onSave: (SupplierRecord) -> Void; @Environment(\.dismiss) private var dismiss; @State private var name = ""; @State private var phone = ""; @State private var notes = ""; @State private var errorKey = ""; var body: some View { Form { if !errorKey.isEmpty { Text(LocalizedStringKey(errorKey)).foregroundStyle(.red) }; Section { TextField("Supplier name", text: $name); TextField("Phone (optional)", text: $phone).keyboardType(.phonePad); TextField("Notes (optional)", text: $notes) } }.navigationTitle("Add supplier").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { if let supplier = store.addSupplier(name: name, phone: phone, notes: notes) { onSave(supplier); dismiss() } else { errorKey = name.trimmed.isEmpty ? "error.supplierName" : "error.supplierDuplicate" } }.disabled(name.trimmed.isEmpty) } } } }

private extension String { var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }; var nilIfEmpty: String? { isEmpty ? nil : self } }

#Preview("Phone") { NavigationStack { CylinderHome(store: .preview(), context: FeatureCanvasContext(remainingFreeActions: { nil }, isEntitled: { false }, recordSuccessfulAction: { _ in .notMetered }, requestUpgrade: {})) }.tint(ShellConfiguration.tint) }
