import SwiftUI

struct SimpleCardSearchRow: View {
    let card: LorcanaCard
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                AsyncImage(url: card.bestImageUrl()) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 50, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 4) {
                    Text(card.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(card.setName)
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .lineLimit(1)

                    HStack {
                        RarityBadge(rarity: card.rarity)
                        Spacer()
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.gray)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
