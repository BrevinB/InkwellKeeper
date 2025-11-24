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
    @Binding var sortOption: SortOption

    var body: some View {
        VStack(spacing: 8) {
            // Type filter row
            HStack {
                Text("Type:")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(width: 40, alignment: .leading)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(CardFilter.allCases, id: \.self) { filter in
                            FilterChip(
                                title: filter.displayName,
                                isSelected: selectedFilter == filter
                            ) {
                                selectedFilter = filter
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }

                Menu {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button(option.displayName) {
                            sortOption = option
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundColor(.lorcanaGold)
                        .padding(8)
                        .background(Circle().fill(Color.lorcanaDark))
                }
            }

            // Color filter row
            HStack {
                Text("Color:")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(width: 40, alignment: .leading)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(InkColorFilter.allCases, id: \.self) { color in
                            ColorFilterChip(
                                inkColor: color,
                                isSelected: selectedInkColor == color
                            ) {
                                selectedInkColor = color
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
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
