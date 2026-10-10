//
//  SelectionMark.swift
//  Inkwell Keeper
//
//  Marks a card as chosen while selecting in a binder or box: a gold ring around
//  it and a check in the corner (an empty circle when not chosen).
//

import SwiftUI

struct SelectionMark: ViewModifier {
    /// nil when not selecting, so nothing is drawn.
    let isSelected: Bool?
    var cornerRadius: CGFloat = 6

    func body(content: Content) -> some View {
        content
            .overlay {
                if isSelected == true {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(Color.lorcanaGold, lineWidth: 3)
                }
            }
            .overlay(alignment: .topLeading) {
                if let isSelected {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(isSelected ? Color.lorcanaDark : .white, isSelected ? Color.lorcanaGold : .black.opacity(0.35))
                        .background(Circle().fill(.black.opacity(isSelected ? 0 : 0.25)))
                        .padding(4)
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityHidden(true)
                }
            }
            .animation(.snappy(duration: 0.2), value: isSelected)
    }
}

extension View {
    /// Shows whether this card is chosen while selecting; pass nil when not selecting.
    func selectionMark(_ isSelected: Bool?, cornerRadius: CGFloat = 6) -> some View {
        modifier(SelectionMark(isSelected: isSelected, cornerRadius: cornerRadius))
    }
}
