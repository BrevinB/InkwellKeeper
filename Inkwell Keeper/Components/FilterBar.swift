//
//  FilterBar.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

import SwiftUI

struct FilterBar: View {
    @Binding var selectedFilter: CardFilter
    @Binding var selectedInkColor: InkColorFilter
    @Binding var selectedVariant: VariantFilter
    @Binding var sortOption: SortOption

    @State private var isExpanded = false

    /// Whether any filters are active (not set to "All")
    private var hasActiveFilters: Bool {
        selectedFilter != .all || selectedInkColor != .all || selectedVariant != .all
    }

    /// Count of active filters
    private var activeFilterCount: Int {
        var count = 0
        if selectedFilter != .all { count += 1 }
        if selectedInkColor != .all { count += 1 }
        if selectedVariant != .all { count += 1 }
        return count
    }

    var body: some View {
        VStack(spacing: 8) {
            // Collapsed header row - always visible
            HStack(spacing: 12) {
                // Filter toggle button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.body)

                        Text("Filters")
                            .font(.subheadline)

                        if hasActiveFilters {
                            Text("\(activeFilterCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.lorcanaGold))
                        }

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(hasActiveFilters ? .lorcanaGold : .gray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.lorcanaDark.opacity(0.6))
                    )
                }

                // Active filter pills (when collapsed)
                if !isExpanded && hasActiveFilters {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            if selectedFilter != .all {
                                activeFilterPill(selectedFilter.displayName, color: .blue) {
                                    selectedFilter = .all
                                }
                            }
                            if selectedInkColor != .all {
                                activeFilterPill(selectedInkColor.displayName, color: selectedInkColor.color) {
                                    selectedInkColor = .all
                                }
                            }
                            if selectedVariant != .all {
                                activeFilterPill(selectedVariant.displayName, color: variantColor(selectedVariant)) {
                                    selectedVariant = .all
                                }
                            }
                        }
                    }
                }

                Spacer()

                // Sort menu - always visible
                Menu {
                    ForEach(SortOption.allCases, id: \.self) { option in
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
                        Text(sortOption.displayName)
                            .font(.caption)
                    }
                    .foregroundColor(.lorcanaGold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.lorcanaDark.opacity(0.6))
                    )
                }
            }

            // Expanded filter rows
            if isExpanded {
                VStack(spacing: 8) {
                    // Type filter row
                    filterRow(label: "Type") {
                        ForEach(CardFilter.allCases, id: \.self) { filter in
                            FilterChip(
                                title: filter.displayName,
                                isSelected: selectedFilter == filter
                            ) {
                                selectedFilter = filter
                            }
                        }
                    }

                    // Color filter row
                    filterRow(label: "Color") {
                        ForEach(InkColorFilter.allCases, id: \.self) { color in
                            ColorFilterChip(
                                inkColor: color,
                                isSelected: selectedInkColor == color
                            ) {
                                selectedInkColor = color
                            }
                        }
                    }

                    // Variant filter row
                    filterRow(label: "Variant") {
                        ForEach(VariantFilter.allCases, id: \.self) { variant in
                            VariantFilterChip(
                                variant: variant,
                                isSelected: selectedVariant == variant
                            ) {
                                selectedVariant = variant
                            }
                        }
                    }

                    // Clear all button (when filters are active)
                    if hasActiveFilters {
                        Button(action: clearAllFilters) {
                            HStack {
                                Image(systemName: "xmark.circle")
                                Text("Clear All Filters")
                            }
                            .font(.caption)
                            .foregroundColor(.red.opacity(0.8))
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Helper Views

    private func filterRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text("\(label):")
                .font(.caption)
                .foregroundColor(.gray)
                .frame(width: 45, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    content()
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private func activeFilterPill(_ text: String, color: Color, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
                .fontWeight(.medium)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color.opacity(0.2))
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.5), lineWidth: 1)
                )
        )
    }

    private func variantColor(_ variant: VariantFilter) -> Color {
        switch variant {
        case .all: return .gray
        case .normal: return .white
        case .foil: return .lorcanaGold
        case .enchanted: return .purple
        case .promo: return .orange
        case .special: return .cyan
        }
    }

    // MARK: - Actions

    private func clearAllFilters() {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedFilter = .all
            selectedInkColor = .all
            selectedVariant = .all
        }
    }
}

struct ColorFilterChip: View {
    let inkColor: InkColorFilter
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: inkColor.icon)
                    .font(.caption)

                if inkColor != .all {
                    Text(inkColor.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? inkColor.color.opacity(0.3) : Color.lorcanaDark.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? inkColor.color : Color.clear, lineWidth: 2)
                    )
            )
            .foregroundColor(isSelected ? inkColor.color : .gray)
        }
        .buttonStyle(.plain)
    }
}

struct VariantFilterChip: View {
    let variant: VariantFilter
    let isSelected: Bool
    let action: () -> Void

    private var chipColor: Color {
        switch variant {
        case .all: return .gray
        case .normal: return .white
        case .foil: return .lorcanaGold
        case .enchanted: return .purple
        case .promo: return .orange
        case .special: return .cyan
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: variant.icon)
                    .font(.caption)

                if variant != .all {
                    Text(variant.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? chipColor.opacity(0.3) : Color.lorcanaDark.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? chipColor : Color.clear, lineWidth: 2)
                    )
            )
            .foregroundColor(isSelected ? chipColor : .gray)
        }
        .buttonStyle(.plain)
    }
}
