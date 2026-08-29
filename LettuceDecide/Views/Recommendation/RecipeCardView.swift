import SwiftUI

struct RecipeCardView: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AsyncImage(url: recipe.imageURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    placeholder
                case .empty:
                    placeholder.overlay(ProgressView())
                @unknown default:
                    placeholder
                }
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text(recipe.title)
                .font(.title2.bold())

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

            if !recipe.diets.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(recipe.diets, id: \.self) { diet in
                            Text(diet.capitalized)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.green.opacity(0.15), in: Capsule())
                                .foregroundStyle(.green)
                        }
                    }
                }
            }

            if let summary = recipe.plainSummary {
                Text(summary)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }

            if let sourceURL = recipe.sourceURL {
                Link("View full recipe", destination: sourceURL)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }

    private var placeholder: some View {
        Rectangle()
            .fill(.green.opacity(0.15))
            .overlay(Image(systemName: "leaf.fill").font(.largeTitle).foregroundStyle(.green))
    }
}

#Preview {
    RecipeCardView(recipe: MockRecipeRepository.sampleRecipes[0])
        .padding()
}
