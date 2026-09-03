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
            case "suppliers": SupplierHome(store: store, isEntitled: context.isEntitled())
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

private enum StatusFilter: String, CaseIterable, Identifiable { case all = "All", ready = "Ready", low = "Low", empty = "Empty", away = "Away"; var id: String { rawValue } }

struct CylinderHome: View {
    @Bindable var store: WalletStore
    let context: FeatureCanvasContext
    @State private var query = ""
    @State private var filter = StatusFilter.all
    @State private var expandedStatusID: UUID?
    @State private var showingAdd = false

    private var visible: [CylinderRecord] {
        store.activeCylinders.filter { cylinder in
            let statusMatches = filter == .all || cylinder.status.rawValue == filter.rawValue
            let supplier = store.supplierName(cylinder.supplierID)
            let haystack = [cylinder.gas, cylinder.capacityLabel, supplier, cylinder.relationship.rawValue, cylinder.serial].joined(separator: " ")
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
                                CylinderCard(store: store, cylinder: cylinder, expanded: expandedStatusID == cylinder.id, isEntitled: context.isEntitled()) {
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
            .sheet(isPresented: $showingAdd) { NavigationStack { CylinderForm(store: store, mode: .new) } }
            .safeAreaInset(edge: .bottom) {
                if let deleted = store.lastDeleted {
                    HStack { Text("\(deleted.cylinder.gas) deleted"); Spacer(); Button("Undo") { store.undoDelete() } }
                        .padding().background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 14)).padding(.horizontal)
                }
            }
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 16) {
            CylinderSymbol().frame(width: 30, height: 44).foregroundStyle(.tint).padding(12).background(Color.blue.opacity(0.08), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text("\(store.activeCylinders.count) active \(store.activeCylinders.count == 1 ? "cylinder" : "cylinders")").font(.headline)
                if !context.isEntitled() { Text("\(store.activeCylinders.count) of 3 free").foregroundStyle(.secondary) }
            }
            Spacer()
            if !context.isEntitled() { Button("Upgrade", action: context.requestUpgrade) }
        }
        .padding(18).background(.background).clipShape(RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(.separator))
    }

    private var searchAndFilters: some View {
        VStack(spacing: 10) {
            HStack { Image(systemName: "magnifyingglass").foregroundStyle(.secondary); TextField("Search cylinders", text: $query).textInputAutocapitalization(.never); if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain) } }
                .padding(.horizontal, 12).frame(minHeight: 44).background(Color.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack { ForEach(StatusFilter.allCases) { item in Button(item.rawValue) { filter = item }.buttonStyle(.bordered).buttonBorderShape(.capsule).tint(filter == item ? .accentColor : .secondary) } }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(query.isEmpty && filter == .all ? "No cylinders yet" : "No matching cylinders", systemImage: "shippingbox", description: Text(query.isEmpty && filter == .all ? "Add a gas and capacity to start your wallet." : "Try another search or filter."))
            .frame(minHeight: 280)
    }

    private func addTapped() {
        if store.activeCylinders.count >= 3 && !context.isEntitled() { context.requestUpgrade() }
        else { showingAdd = true }
    }
}

private struct CylinderCard: View {
    @Bindable var store: WalletStore
    let cylinder: CylinderRecord
    let expanded: Bool
    let isEntitled: Bool
    let toggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Text(String((store.activeCylinders.firstIndex(where: { $0.id == cylinder.id }) ?? 0) + 1)).font(.headline).foregroundStyle(.tint).frame(width: 38, height: 44).background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                NavigationLink { CylinderDetail(store: store, cylinderID: cylinder.id, isEntitled: isEntitled) } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(cylinder.gas).font(.title3.bold()).foregroundStyle(.primary)
                        Text(cylinder.capacityLabel).foregroundStyle(.primary)
                        Text("\(store.supplierName(cylinder.supplierID)) · \(cylinder.relationship.rawValue)").font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain)
                StatusBadge(status: cylinder.status)
                Button(action: toggle) { Image(systemName: expanded ? "chevron.up" : "chevron.right") }.buttonStyle(.plain).frame(minWidth: 44, minHeight: 44).accessibilityLabel("Change \(cylinder.gas) status").accessibilityIdentifier("wallet.status.\(cylinder.id.uuidString)")
            }.padding(14)
            if expanded {
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    Text("Update status").foregroundStyle(.secondary)
                    HStack(spacing: 8) { ForEach(CylinderStatus.allCases) { status in StatusButton(status: status, selected: cylinder.status == status) { store.setStatus(status, for: cylinder.id) } } }
                }.padding(14)
            }
        }
        .background(.background).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(.separator))
    }
}

private struct StatusBadge: View {
    let status: CylinderStatus
    var color: Color { switch status { case .ready: .green; case .low: .orange; case .empty: .red; case .away: .blue } }
    var body: some View { Label(status.rawValue, systemImage: status.symbol).font(.subheadline.weight(.semibold)).foregroundStyle(color).padding(.horizontal, 10).padding(.vertical, 7).background(color.opacity(0.08), in: Capsule()).overlay(Capsule().stroke(color.opacity(0.35))) }
}

private struct StatusButton: View {
    let status: CylinderStatus; let selected: Bool; let action: () -> Void
    var color: Color { switch status { case .ready: .green; case .low: .orange; case .empty: .red; case .away: .blue } }
    var body: some View { Button(action: action) { VStack(spacing: 6) { Image(systemName: status.symbol).font(.title2); Text(status.rawValue).font(.caption.weight(.semibold)) }.frame(maxWidth: .infinity, minHeight: 70) }.buttonStyle(.plain).foregroundStyle(color).background(color.opacity(selected ? 0.12 : 0.04), in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(selected ? 0.8 : 0.35))) }
}

struct CylinderDetail: View {
    @Bindable var store: WalletStore
    let cylinderID: UUID
    var isEntitled = false
    @Environment(\.dismiss) private var dismiss
    @State private var sheet: DetailSheet?
    @State private var confirmLifecycle: CylinderLifecycle?

    private var cylinder: CylinderRecord? { store.cylinders.first { $0.id == cylinderID } }
    var body: some View {
        Group {
            if let cylinder {
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(cylinder.gas.uppercased()).font(.caption.bold()).foregroundStyle(.tint)
                            Text(cylinder.capacityLabel).font(.largeTitle.bold())
                            StatusBadge(status: cylinder.status)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(20).background(Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            Fact(title: "Supplier", value: store.supplierName(cylinder.supplierID)); Fact(title: "Relationship", value: cylinder.relationship.rawValue); Fact(title: "Serial", value: cylinder.serial.isEmpty ? "Not set" : cylinder.serial); Fact(title: "Acquired", value: cylinder.acquiredAt.formatted(date: .abbreviated, time: .omitted))
                        }
                        HStack { Button("Refill") { sheet = .service(.refill) }.buttonStyle(.borderedProminent); Button("Exchange") { sheet = .service(.exchange) }.buttonStyle(.bordered); Button("Add cost") { sheet = .service(.cost) }.buttonStyle(.bordered) }
                        Button { sheet = .reminder } label: { Label(cylinder.reminderAt.map { "Reminder · \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "Add reminder", systemImage: "bell") }.buttonStyle(.bordered).frame(maxWidth: .infinity)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Recent activity").font(.headline)
                            ForEach(store.activity.filter { $0.cylinderID == cylinderID }.prefix(5)) { ActivityRow(store: store, item: $0) }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Menu("Return or archive") { Button("Return cylinder") { confirmLifecycle = .returned }; Button("Archive cylinder") { confirmLifecycle = .archived } }.buttonStyle(.bordered).frame(maxWidth: .infinity)
                    }.frame(maxWidth: 720).padding(16).frame(maxWidth: .infinity)
                }
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Edit") { sheet = .edit } } }
                .sheet(item: $sheet) { value in NavigationStack { detailSheet(value, cylinder: cylinder) } }
                .confirmationDialog(confirmLifecycle == .returned ? "Return this cylinder?" : "Archive this cylinder?", isPresented: Binding(get: { confirmLifecycle != nil }, set: { if !$0 { confirmLifecycle = nil } })) {
                    if let lifecycle = confirmLifecycle { Button(lifecycle == .returned ? "Return cylinder" : "Archive cylinder") { store.archive(cylinderID, as: lifecycle); dismiss() } }
                    Button("Cancel", role: .cancel) { confirmLifecycle = nil }
                }
            } else { ContentUnavailableView("Cylinder not found", systemImage: "questionmark.square") }
        }.navigationTitle(cylinder?.gas ?? "Cylinder").navigationBarTitleDisplayMode(.inline).accessibilityIdentifier("screen.cylinderDetail")
    }

    @ViewBuilder private func detailSheet(_ sheet: DetailSheet, cylinder: CylinderRecord) -> some View {
        switch sheet { case .edit: CylinderForm(store: store, mode: .edit(cylinder), canAddAnother: isEntitled || store.activeCylinders.count < 3); case .service(let kind): ServiceForm(store: store, cylinder: cylinder, kind: kind); case .reminder: ReminderForm(store: store, cylinder: cylinder) }
    }
}

private enum DetailSheet: Identifiable { case edit, service(ActivityKind), reminder; var id: String { switch self { case .edit: "edit"; case .service(let k): k.rawValue; case .reminder: "reminder" } } }

private struct Fact: View { let title: String; let value: String; var body: some View { VStack(alignment: .leading, spacing: 4) { Text(title.uppercased()).font(.caption2.bold()).foregroundStyle(.secondary); Text(value).font(.subheadline.weight(.semibold)).lineLimit(2) }.frame(maxWidth: .infinity, minHeight: 58, alignment: .leading).padding(12).background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12)) } }

private enum CylinderFormMode { case new, edit(CylinderRecord), duplicate(CylinderRecord) }

private struct CylinderForm: View {
    @Bindable var store: WalletStore
    let mode: CylinderFormMode
    var canAddAnother = true
    @Environment(\.dismiss) private var dismiss
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
    @State private var error = ""

    var body: some View {
        Form {
            if !error.isEmpty { Text(error).foregroundStyle(.red) }
            if case .new = mode, !store.activeCylinders.isEmpty {
                Section("Copy an existing cylinder") {
                    ForEach(store.activeCylinders) { cylinder in
                        Button { copy(cylinder) } label: {
                            VStack(alignment: .leading) {
                                Text(cylinder.gas)
                                Text("\(cylinder.capacityLabel) · \(store.supplierName(cylinder.supplierID))").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            Section {
                Picker("Gas", selection: $gas) { ForEach(["", "Argon", "C25 Mix", "Oxygen", "Acetylene", "Nitrogen", "CO₂", "Helium", "Other"], id: \.self) { Text($0.isEmpty ? "Choose gas" : $0) } }
                if gas == "Other" { TextField("Custom gas", text: $customGas) }
                HStack { TextField("Capacity", text: $capacity).keyboardType(.decimalPad); Picker("Unit", selection: $unit) { ForEach(["ft3", "L", "m3", "kg", "lb"], id: \.self) { Text($0.replacingOccurrences(of: "3", with: "³")) } }.labelsHidden() }
            }
            Section {
                DisclosureGroup("Add supplier, relationship or serial", isExpanded: $showOptional) {
                    Picker("Supplier", selection: $supplierID) { Text("Not set").tag(UUID?.none); ForEach(store.suppliers) { Text($0.name).tag(Optional($0.id)) } }
                    Button("Add supplier") { showSupplier = true }
                    Picker("Relationship", selection: $relationship) { ForEach(Relationship.allCases) { Text($0.rawValue).tag($0) } }
                    TextField("Serial number", text: $serial).textInputAutocapitalization(.characters)
                    TextField("Notes", text: $notes, axis: .vertical)
                }
            }
            if case .edit(let cylinder) = mode {
                Section { Button("Duplicate cylinder") { if !canAddAnother { error = "Upgrade is required before adding another active cylinder." } else if store.duplicate(cylinder) != nil { dismiss() } }.foregroundStyle(.tint); Button("Delete cylinder", role: .destructive) { showDelete = true } }
            }
        }
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(resolvedGas.isEmpty || (Double(capacity) ?? 0) <= 0) } }
        .sheet(isPresented: $showSupplier) { NavigationStack { SupplierForm(store: store) { supplier in supplierID = supplier.id } } }
        .confirmationDialog("Delete \(gas)?", isPresented: $showDelete, titleVisibility: .visible) { Button("Delete cylinder and history", role: .destructive) { if case .edit(let cylinder) = mode { store.delete(cylinder.id); dismiss() } }; Button("Cancel", role: .cancel) {} } message: { Text("You can undo for 15 seconds.") }
        .onAppear(perform: seed)
    }

    private var title: String { switch mode { case .new: "Add cylinder"; case .edit: "Edit cylinder"; case .duplicate: "Duplicate cylinder" } }
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
        capacity = String(cylinder.capacityValue); unit = cylinder.capacityUnit; supplierID = cylinder.supplierID; relationship = cylinder.relationship
    }
    private func save() {
        guard let value = Double(capacity), value > 0 else { error = "Enter a valid capacity."; return }
        let success: Bool
        switch mode {
        case .new, .duplicate: success = store.addCylinder(gas: resolvedGas, capacity: value, unit: unit, supplierID: supplierID, relationship: relationship, serial: serial, notes: notes) != nil
        case .edit(var c): c.gas = resolvedGas; c.capacityValue = value; c.capacityUnit = unit; c.supplierID = supplierID; c.relationship = relationship; c.serial = serial; c.notes = notes; success = store.update(c)
        }
        if success { dismiss() } else { error = "Check the required fields. Serial numbers must be unique." }
    }
}

private struct ServiceForm: View {
    @Bindable var store: WalletStore
    let cylinder: CylinderRecord
    let kind: ActivityKind
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var date = Date.now
    @State private var replacementSerial = ""
    @State private var sameCapacity = true
    @State private var capacity = ""
    @State private var unit = "ft3"
    @State private var error = ""

    private var lastAmount: Decimal? { store.activity.first { $0.cylinderID == cylinder.id && $0.amountMinor != nil && $0.currencyCode == store.defaultCurrency }.flatMap { $0.amountMinor.map { Decimal($0) / 100 } } }
    var body: some View {
        Form {
            Text("Today · \(store.currencySign(for: store.defaultCurrency))").font(.subheadline).foregroundStyle(.secondary)
            if !error.isEmpty { Text(error).foregroundStyle(.red) }
            Section {
                HStack { Text(store.currencySign(for: store.defaultCurrency)); TextField("0.00", text: $amount).keyboardType(.decimalPad) }
                if let lastAmount { Button("Use last cost · \(store.currencySign(for: store.defaultCurrency))\(lastAmount)") { amount = "\(lastAmount)" } }
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
        .navigationTitle(kind.rawValue.capitalized).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled((Decimal(string: amount) ?? 0) <= 0) } }
        .onAppear { unit = cylinder.capacityUnit }
    }
    private func save() {
        let value = Decimal(string: amount)
        let replacementCapacity = sameCapacity ? nil : Double(capacity)
        if !store.recordService(for: cylinder.id, kind: kind, amount: value, currency: store.defaultCurrency, date: date, replacementSerial: replacementSerial, replacementCapacity: replacementCapacity, replacementUnit: sameCapacity ? nil : unit) { error = "Enter a positive amount and a unique replacement serial." } else { dismiss() }
    }
}

private struct ReminderForm: View {
    @Bindable var store: WalletStore; let cylinder: CylinderRecord
    @Environment(\.dismiss) private var dismiss
    @State private var enabled = true; @State private var days = 7; @State private var custom = false; @State private var date = Calendar.current.date(byAdding: .day, value: 7, to: .now)!
    var body: some View { Form { Toggle("Refill reminder", isOn: $enabled); if enabled { Section("Remind me") { HStack { ForEach([3, 7, 14], id: \.self) { value in Button("\(value) days") { days = value; custom = false; date = Calendar.current.date(byAdding: .day, value: value, to: .now)! }.buttonStyle(.bordered).tint(days == value && !custom ? .accentColor : .secondary) }; Button("Custom") { custom = true }.buttonStyle(.bordered) }; if custom { DatePicker("Date and time", selection: $date, in: Date.now...) } else { Text("Scheduled for \(date.formatted(date: .abbreviated, time: .shortened)).") } } }; Section { Text("The reminder is scheduled locally on this device.").font(.footnote).foregroundStyle(.secondary) } }.navigationTitle("Reminder").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { store.setReminder(enabled ? date : nil, for: cylinder.id); Task { await LocalReminderScheduler.schedule(cylinder: cylinder, at: enabled ? date : nil) }; dismiss() } } }.onAppear { if let existing = cylinder.reminderAt { date = existing; enabled = true } } }
}

enum LocalReminderScheduler {
    static func schedule(cylinder: CylinderRecord, at date: Date?) async {
        let center = UNUserNotificationCenter.current(); center.removePendingNotificationRequests(withIdentifiers: ["cylinder-\(cylinder.id.uuidString)"])
        guard let date else { return }
        let granted = try? await center.requestAuthorization(options: [.alert, .sound]); guard granted == true else { return }
        let content = UNMutableNotificationContent(); content.title = "Check \(cylinder.gas)"; content.body = "Open Welding Gas Wallet to review this cylinder."; content.sound = .default
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        try? await center.add(UNNotificationRequest(identifier: "cylinder-\(cylinder.id.uuidString)", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)))
    }
}

struct ActivityHome: View {
    @Bindable var store: WalletStore
    @State private var filter: ActivityKind?
    var filtered: [ActivityRecord] { filter.map { selected in store.activity.filter { $0.kind == selected } } ?? store.activity }
    var body: some View { GeometryReader { geometry in ScrollView { VStack(spacing: 14) { LazyVGrid(columns: geometry.size.width >= 700 ? [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())] : [GridItem(.flexible())], spacing: 10) { Metric(title: "Total spent", value: store.totals().map { "\(store.currencySign(for: $0.0))\(NSDecimalNumber(decimal: $0.1).stringValue)" }.joined(separator: " · ").nilIfEmpty ?? "—", note: "Currencies stay separate"); Metric(title: "Refill count", value: "\(store.refillCount)", note: "Recorded refills"); Metric(title: "Average refill interval", value: store.averageRefillIntervalDays.map { "\($0) days" } ?? "—", note: "Across repeat refills") }; ScrollView(.horizontal, showsIndicators: false) { HStack { Button("All") { filter = nil }.buttonStyle(.bordered); Button("Refills") { filter = .refill }.buttonStyle(.bordered); Button("Status") { filter = .status }.buttonStyle(.bordered) } }; LazyVGrid(columns: geometry.size.width >= 700 ? [GridItem(.flexible()), GridItem(.flexible())] : [GridItem(.flexible())], spacing: 10) { ForEach(filtered) { ActivityRow(store: store, item: $0) } } }.frame(maxWidth: 980).padding(16).frame(maxWidth: .infinity) } } }
}

private struct Metric: View { let title: String; let value: String; let note: String; var body: some View { VStack(alignment: .leading, spacing: 5) { Text(title).font(.caption).foregroundStyle(.secondary); Text(value).font(.title3.bold()); Text(note).font(.caption2).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, minHeight: 82, alignment: .leading).padding(14).background(.background, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(.separator)) } }
private struct ActivityRow: View { let store: WalletStore; let item: ActivityRecord; var body: some View { HStack(spacing: 12) { Image(systemName: item.kind == .refill ? "arrow.clockwise" : item.kind == .status ? "checkmark.circle" : "doc.text").foregroundStyle(.tint).frame(width: 34, height: 34).background(Color.blue.opacity(0.08), in: Circle()); VStack(alignment: .leading, spacing: 3) { Text(item.title).font(.subheadline.weight(.semibold)); Text(item.detail).font(.caption).foregroundStyle(.secondary) }; Spacer(); VStack(alignment: .trailing) { if let minor = item.amountMinor, let code = item.currencyCode { Text("\(store.currencySign(for: code))\(NSDecimalNumber(value: Double(minor) / 100).stringValue)").font(.caption.bold()) }; Text(item.occurredAt.formatted(date: .abbreviated, time: .omitted)).font(.caption2).foregroundStyle(.secondary) } }.padding(12).background(.background, in: RoundedRectangle(cornerRadius: 13)).overlay(RoundedRectangle(cornerRadius: 13).stroke(.separator)) } }

struct SupplierHome: View {
    @Bindable var store: WalletStore
    let isEntitled: Bool
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
                                NavigationLink { SupplierDetail(store: store, supplier: supplier, isEntitled: isEntitled) } label: {
                                    HStack {
                                        Text(initials(supplier.name)).font(.headline).foregroundStyle(.tint).frame(width: 46, height: 46).background(Color.blue.opacity(0.08), in: Circle())
                                        VStack(alignment: .leading) {
                                            Text(supplier.name).font(.headline).foregroundStyle(.primary)
                                            let count = store.activeCylinders.filter { $0.supplierID == supplier.id }.count
                                            Text("\(count) current \(count == 1 ? "cylinder" : "cylinders")").font(.subheadline).foregroundStyle(.secondary)
                                        }
                                        Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary)
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

private struct SupplierDetail: View { @Bindable var store: WalletStore; let supplier: SupplierRecord; let isEntitled: Bool; var body: some View { List { Section { HStack { Text(supplier.name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()).font(.title2.bold()).foregroundStyle(.tint).frame(width: 60, height: 60).background(Color.blue.opacity(0.08), in: Circle()); VStack(alignment: .leading) { Text(supplier.name).font(.title2.bold()); let count = store.activeCylinders.filter { $0.supplierID == supplier.id }.count; Text("\(count) current \(count == 1 ? "cylinder" : "cylinders")").foregroundStyle(.secondary) } } }; if !supplier.phone.isEmpty || !supplier.notes.isEmpty { Section { if !supplier.phone.isEmpty { LabeledContent("Phone", value: supplier.phone) }; if !supplier.notes.isEmpty { LabeledContent("Notes", value: supplier.notes) } } }; Section("Cylinders") { let linked = store.cylinders.filter { $0.supplierID == supplier.id }; if linked.isEmpty { Text("No linked cylinders").foregroundStyle(.secondary) } else { ForEach(linked) { cylinder in NavigationLink { CylinderDetail(store: store, cylinderID: cylinder.id, isEntitled: isEntitled) } label: { VStack(alignment: .leading) { Text(cylinder.gas); Text("\(cylinder.capacityLabel) · \(cylinder.lifecycle.rawValue)").font(.caption).foregroundStyle(.secondary) } } } } } }.navigationTitle(supplier.name).navigationBarTitleDisplayMode(.inline) } }

private struct SupplierForm: View { @Bindable var store: WalletStore; let onSave: (SupplierRecord) -> Void; @Environment(\.dismiss) private var dismiss; @State private var name = ""; @State private var phone = ""; @State private var notes = ""; @State private var error = ""; var body: some View { Form { if !error.isEmpty { Text(error).foregroundStyle(.red) }; Section { TextField("Supplier name", text: $name); TextField("Phone (optional)", text: $phone).keyboardType(.phonePad); TextField("Notes (optional)", text: $notes) } }.navigationTitle("Add supplier").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { if let supplier = store.addSupplier(name: name, phone: phone, notes: notes) { onSave(supplier); dismiss() } else { error = name.trimmed.isEmpty ? "Enter a supplier name." : "That supplier is already saved." } }.disabled(name.trimmed.isEmpty) } } } }

private extension String { var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }; var nilIfEmpty: String? { isEmpty ? nil : self } }

#Preview("Phone") { NavigationStack { CylinderHome(store: .preview(), context: FeatureCanvasContext(remainingFreeActions: { nil }, isEntitled: { false }, recordSuccessfulAction: { _ in .notMetered }, requestUpgrade: {})) }.tint(ShellConfiguration.tint) }
