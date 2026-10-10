//
//  ContainerPreview.swift
//  Inkwell Keeper
//
//  The live object at the top of the editor. It sways gently, pops when you change
//  its color or finish, and morphs between kinds.
//

import SwiftUI

struct ContainerPreview: View {
    let draft: ContainerDraft

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ContainerArtwork(kind: draft.kind, color: draft.color, style: draft.style)
            .frame(height: 150)
            .id(draft.kind)
            .transition(.scale(scale: 0.7).combined(with: .opacity))
            .shadow(color: draft.color.highlight.opacity(0.45), radius: 18, y: 8)
            .modifier(SwayEffect(isEnabled: !reduceMotion))
            .modifier(PopEffect(trigger: "\(draft.color.rawValue)-\(draft.style.rawValue)", isEnabled: !reduceMotion))
            .animation(reduceMotion ? nil : .bouncy, value: draft.kind)
            .padding(.vertical, 12)
            .accessibilityElement()
            .accessibilityLabel("\(draft.color.displayName) \(draft.style.displayName) \(draft.kind.displayName)")
    }
}
