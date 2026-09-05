import SwiftUI

/// The full recipe: an honest have/short/missing ingredient checklist, the method rendered
/// in-app, a small source-attribution line, and "Mark as Cooked" which deducts what was
/// used from the pantry.
struct RecipeDetailView: View {
    @StateObject private var viewModel: RecipeDetailViewModel
    let onCooked: () -> Void

    @Environment(\.dismiss) private var dismiss

    init(viewModel: @autoclosure @escaping () -> RecipeDetailViewModel, onCooked: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.onCooked = onCooked
    }

    private var recipe: Recipe { viewModel.recipe }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                ingredients
                method
                attribution
            }
            .padding()
        }
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                viewModel.markAsCooked()
            } label: {
                Text("Mark as Cooked")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding()
            .background(.bar)
        }
        .alert(
            viewModel.cookAlert?.title ?? "",
            isPresented: Binding(
                get: { viewModel.cookAlert != nil },
                set: { if !$0 { viewModel.cookAlert = nil } }
            ),
            presenting: viewModel.cookAlert
        ) { alert in
            Button("OK") {
                if alert.didCook {
                    onCooked()
                    dismiss()
                }
            }
        } message: { alert in
            Text(alert.message)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            AsyncImage(url: recipe.imageURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .empty:
                    imagePlaceholder.overlay(ProgressView())
                default:
                    imagePlaceholder
                }
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack(spacing: 16) {
                if let minutes = recipe.readyInMinutes {
                    Label("\(minutes) min", systemImage: "clock")
                }
                if let servings = recipe.servings {
                    Label("\(servings) servings", systemImage: "person.2")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if let summary = recipe.plainSummary {
                Text(summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var ingredients: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ingredients").font(.title3.bold())
            if viewModel.ingredientStatuses.isEmpty {
                Text("This recipe didn't come with an ingredient list.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.ingredientStatuses) { status in
                    IngredientStatusRow(status: status)
                }
            }
        }
    }

    @ViewBuilder
    private var method: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Method").font(.title3.bold())
            if !recipe.analyzedSteps.isEmpty {
                ForEach(recipe.analyzedSteps) { step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(step.id)")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 22, alignment: .trailing)
                        Text(step.stepText)
                    }
                }
            } else if let instructions = recipe.plainInstructions {
                Text(instructions)
            } else {
                Text("No instructions available for this recipe.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var attribution: some View {
        if let name = recipe.sourceName, let url = recipe.sourceURL {
            Link("Recipe from \(name)", destination: url)
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if let name = recipe.sourceName {
            Text("Recipe from \(name)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if let url = recipe.sourceURL {
            Link("View the original recipe", destination: url)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var imagePlaceholder: some View {
        Rectangle()
            .fill(.green.opacity(0.15))
            .overlay(Image(systemName: "fork.knife").font(.largeTitle).foregroundStyle(.green))
    }
}

private struct IngredientStatusRow: View {
    let status: IngredientStatus

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(status.name)
                    Text(status.requiredAmount)
                        .foregroundStyle(.secondary)
                }
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(tint)
                }
            }
            Spacer()
        }
    }

    private var icon: String {
        switch status.kind {
        case .have: return "checkmark.circle.fill"
        case .shortBy: return "exclamationmark.triangle.fill"
        case .missing: return "circle"
        }
    }

    private var tint: Color {
        switch status.kind {
        case .have: return .green
        case .shortBy: return .orange
        case .missing: return .secondary
        }
    }

    private var detail: String? {
        switch status.kind {
        case .have:
            return nil
        case .shortBy(let have, let unit):
            return "Only \(number(have)) \(unit.displayName) in your pantry"
        case .missing:
            return "Not in your pantry"
        }
    }

    private func number(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}

#Preview {
    NavigationStack {
        RecipeDetailView(
            viewModel: RecipeDetailViewModel(
                recipe: MockRecipeRepository.sampleRecipes[1],
                pantryStore: InMemoryPantryStore(initial: [
                    PantryIngredient(ingredientName: "chickpeas", quantity: 200, unit: .grams, storageLocation: .pantry),
                    PantryIngredient(ingredientName: "spinach", quantity: 200, unit: .grams, storageLocation: .fridge),
                ])
            ),
            onCooked: {}
        )
    }
}
