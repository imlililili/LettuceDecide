import SwiftUI

/// Add / Edit Ingredient sheet. Its fields map onto a `ManagePantryIngredientUseCase.Action`; on save it
/// calls back into the caller, and surfaces any `PantryIngredientError` in the form using the
/// domain's own wording rather than a raw system error.
struct AddEditIngredientView: View {
    enum Mode: Equatable {
        case add
        case edit(PantryIngredient)

        var isEditing: Bool {
            if case .edit = self { return true }
            return false
        }
    }

    let mode: Mode
    /// Throws `PantryIngredientError` (or another error) which the sheet displays inline.
    let onSubmit: (IngredientDraft) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: IngredientDraft
    @State private var errorMessage: String?

    init(mode: Mode, onSubmit: @escaping (IngredientDraft) throws -> Void) {
        self.mode = mode
        self.onSubmit = onSubmit
        switch mode {
        case .add:
            _draft = State(initialValue: IngredientDraft())
        case .edit(let ingredient):
            _draft = State(initialValue: IngredientDraft(from: ingredient))
        }
    }

    private var trimmedName: String {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if mode.isEditing {
                        LabeledContent("Ingredient", value: draft.name)
                    } else {
                        TextField("Ingredient", text: $draft.name)
                            .textInputAutocapitalization(.words)
                    }
                }

                Section("Amount") {
                    HStack {
                        TextField("Quantity", value: $draft.quantity, format: .number)
                            .keyboardType(.decimalPad)
                        Picker("Unit", selection: $draft.unit) {
                            ForEach(IngredientUnit.allCases) { Text($0.displayName).tag($0) }
                        }
                        .labelsHidden()
                    }
                    Picker("Storage", selection: $draft.storageLocation) {
                        ForEach(StorageLocation.allCases) { Text($0.displayName).tag($0) }
                    }
                }

                Section("Expiry") {
                    Toggle("Track an expiry date", isOn: $draft.includesExpiryDate)
                    if draft.includesExpiryDate {
                        DatePicker("Expiry date", selection: $draft.expiryDate, displayedComponents: .date)
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }
            }
            .navigationTitle(mode.isEditing ? "Edit Ingredient" : "Add Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: submit)
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private func submit() {
        errorMessage = nil
        do {
            try onSubmit(draft)
            dismiss()
        } catch let error as PantryIngredientError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    AddEditIngredientView(mode: .add) { _ in }
}
