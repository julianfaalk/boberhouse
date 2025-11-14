import SwiftUI

struct TaskTemplateEditorView: View {
    @EnvironmentObject private var store: HouseholdStore
    @Environment(\.dismiss) private var dismiss

    private let template: TaskTemplate?

    @State private var title: String
    @State private var details: String
    @State private var cadenceValue: Int
    @State private var cadenceUnit: CadenceUnit
    @State private var leadTimeHours: Int
    @State private var isActive: Bool
    @State private var startDate: Date

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && cadenceValue > 0
    }

    init(template: TaskTemplate? = nil) {
        self.template = template
        _title = State(initialValue: template?.title ?? "")
        _details = State(initialValue: template?.details ?? "")
        _cadenceValue = State(initialValue: template?.cadenceValue ?? 1)
        _cadenceUnit = State(initialValue: template?.cadenceUnit ?? .weeks)
        _leadTimeHours = State(initialValue: template?.leadTimeHours ?? 12)
        _isActive = State(initialValue: template?.isActive ?? true)
        _startDate = State(initialValue: template?.startDate ?? template?.createdAt ?? .now)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $title)
                    TextField("Details", text: $details, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                Section("Cadence") {
                    Stepper(value: $cadenceValue, in: 1...365) {
                        Text("\(cadenceValue) \(cadenceUnit.localizedLabel.lowercased())")
                    }

                    Picker("Unit", selection: $cadenceUnit) {
                        ForEach(CadenceUnit.allCases, id: \.self) { unit in
                            Text(unit.localizedLabel).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Reminder") {
                    Stepper(value: $leadTimeHours, in: 0...168) {
                        if leadTimeHours == 0 {
                            Text("No lead time reminder")
                        } else {
                            Text("Notify \(leadTimeHours)h before due")
                        }
                    }
                }

                Section("Schedule") {
                    DatePicker(
                        "Starts on",
                        selection: $startDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .disabled(template != nil)
                    if template != nil {
                        Text("Start date can be changed by creating a new copy of the task.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if template != nil {
                    Section("Status") {
                        Toggle("Template Active", isOn: $isActive)
                    }
                }
            }
            .navigationTitle(template == nil ? "New Task" : "Edit Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if let template {
                                await store.updateTemplate(
                                    template,
                                    title: title,
                                    details: details.isEmpty ? nil : details,
                                    cadenceValue: cadenceValue,
                                    cadenceUnit: cadenceUnit,
                                    leadTimeHours: leadTimeHours,
                                    isActive: isActive,
                                    startDate: startDate
                                )
                            } else {
                                await store.addTemplate(
                                    title: title,
                                    cadenceValue: cadenceValue,
                                    cadenceUnit: cadenceUnit,
                                    details: details.isEmpty ? nil : details,
                                    leadTimeHours: leadTimeHours,
                                    startDate: startDate
                                )
                            }
                            dismiss()
                        }
                    }
                    .disabled(!canSave)
                }

                if let template {
                    ToolbarItem(placement: .bottomBar) {
                        Button(role: .destructive) {
                            Task {
                                await store.deleteTemplate(template)
                                dismiss()
                            }
                        } label: {
                            Text("Delete Template")
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct TaskTemplateEditorPreview: View {
    @StateObject private var store = HouseholdStore()

    var body: some View {
        TaskTemplateEditorView()
            .environmentObject(store)
            .modelContainer(previewContainer)
            .task {
                await store.attachIfNeeded(modelContext: previewContainer.mainContext)
            }
    }
}

#Preview {
    TaskTemplateEditorPreview()
}
