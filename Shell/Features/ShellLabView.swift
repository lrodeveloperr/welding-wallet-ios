import SwiftUI

#if DEBUG
struct ShellLabView: View {
    @Environment(ShellModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = model
        Form {
            Section("Monetization") {
                LabeledContent("Mode", value: model.access.configuration.mode.title)
                LabeledContent("Access", value: String(describing: model.access.decision))
                if let remaining = model.access.remainingFreeActions {
                    LabeledContent("Free actions remaining", value: "\(remaining)")
                }
            }
            Section("Feature state") {
                Picker("State", selection: $model.contentState) {
                    ForEach(SampleContentState.allCases) { state in Text(state.title).tag(state) }
                }
                .pickerStyle(.segmented)
            }
            Section("Responsive checks") {
                LabeledContent("Compact", value: "Tab bar")
                LabeledContent("Regular", value: "Sidebar-adaptable tabs")
                LabeledContent("Detail", value: "Split at 700 pt")
            }
        }
        .navigationTitle("Shell Lab")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
}
#endif
