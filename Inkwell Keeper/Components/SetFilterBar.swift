//
//  SetFilterBar.swift
//  Inkwell Keeper
//
//  Collapsible filter/sort bar for a set's card grid: ownership, ink color,
//  rarity, variant, and market-price bucket. Mirrors the collection FilterBar.
//

import SwiftUI

struct SetFilterBar: View {
    @Binding var ownership: SetOwnershipFilter
    @Binding var inkColor: InkColorFilter
    @Binding var rarity: CardRarity?
    @Binding var variant: VariantFilter
    @Binding var price: PriceFilter
    @Binding var sortOption: SetSortOption

    @State private var isExpanded = false

    private var activeFilterCount: Int {
        var count = 0
        if ownership != .all { count += 1 }
        if inkColor != .all { count += 1 }
        if rarity != nil { count += 1 }
        if variant != .all { count += 1 }
        if price != .all { count += 1 }
        return count
    }

    private var hasActiveFilters: Bool { activeFilterCount > 0 }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.body)
                        Text("Filters")
                            .font(.subheadline)

                        if hasActiveFilters {
                            Text("\(activeFilterCount)")
                                .font(.caption2)
                                .bold()
                                .foregroundStyle(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.lorcanaGold))
                        }

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .foregroundStyle(hasActiveFilters ? Color.lorcanaGold : .gray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.lorcanaDark.opacity(0.6))
                    )
                }

                if !isExpanded && hasActiveFilters {
                    activePills
                }

                Spacer()

                Menu {
                    ForEach(SetSortOption.allCases, id: \.self) { option in
                        Button {
                            sortOption = option
                        } label: {
                            HStack {
                                Text(option.displayName)
                                if sortOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text(sortOption == .cardNumber ? "Sort" : sortOption.displayName)
                            .font(.caption)
                    }
                    .foregroundStyle(Color.lorcanaGold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.lorcanaDark.opacity(0.6))
                    )
                }
            }

            if isExpanded {
                expandedRows
            }
        }
    }

    private var activePills: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                if ownership != .all {
                    pill(ownership.rawValue, color: .blue) { ownership = .all }
                }
                if inkColor != .all {
                    pill(inkColor.displayName, color: inkColor.color) { inkColor = .all }
                }
                if let selectedRarity = rarity {
                    pill(selectedRarity.displayName, color: selectedRarity.color) { rarity = nil }
                }
                if variant != .all {
                    pill(variant.displayName, color: .cyan) { variant = .all }
                }
                if price != .all {
                    pill(price.rawValue, color: .green) { price = .all }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var expandedRows: some View {
        VStack(spacing: 8) {
            filterRow(label: "Show") {
                ForEach(SetOwnershipFilter.allCases, id: \.self) { option in
                    FilterChip(title: option.rawValue, isSelected: ownership == option) {
                        ownership = option
                    }
                }
            }

            filterRow(label: "Color") {
                ForEach(InkColorFilter.allCases, id: \.self) { color in
                    ColorFilterChip(inkColor: color, isSelected: inkColor == color) {
                        inkColor = color
                    }
                }
            }

            filterRow(label: "Rarity") {
                FilterChip(title: "All", isSelected: rarity == nil) {
                    rarity = nil
                }
                ForEach(CardRarity.allCases, id: \.self) { option in
                    FilterChip(title: option.displayName, isSelected: rarity == option) {
                        rarity = option
                    }
                }
            }

            filterRow(label: "Variant") {
                ForEach(VariantFilter.allCases, id: \.self) { option in
                    VariantFilterChip(variant: option, isSelected: variant == option) {
                        variant = option
                    }
                }
            }

            filterRow(label: "Price") {
                ForEach(PriceFilter.allCases, id: \.self) { option in
                    FilterChip(title: option.rawValue, isSelected: price == option) {
                        price = option
                    }
                }
            }

            if hasActiveFilters {
                Button {
                    clearAll()
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Clear All Filters")
                    }
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.8))
                }
                .padding(.top, 4)
            }
        }
        .padding(.top, 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func filterRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text("\(label):")
                .font(.caption)
                .foregroundStyle(.gray)
                .frame(width: 45, alignment: .leading)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    content()
                }
                .padding(.horizontal, 4)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func pill(_ text: String, color: Color, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
                .fontWeight(.medium)

            Button("Remove", systemImage: "xmark.circle.fill", action: onRemove)
                .labelStyle(.iconOnly)
                .font(.caption)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color.opacity(0.2))
                .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 1))
        )
    }

    private func clearAll() {
        withAnimation(.easeInOut(duration: 0.2)) {
            ownership = .all
            inkColor = .all
            rarity = nil
            variant = .all
            price = .all
        }
    }
}
