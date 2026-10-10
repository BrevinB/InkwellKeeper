//
//  BinderFillPrompt.swift
//  Inkwell Keeper
//
//  Floats over an empty binder's pages with the obvious next step: fill it from
//  Unsorted in one go, or pick cards by hand. Set checklist binders say which set.
//

import SwiftUI

struct BinderFillPrompt: View {
    /// The set a checklist binder is for, if it is one.
    let setName: String?
    let onAutoFill: () -> Void
    let onAddCards: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Group {
                        if let setName {
                            Text("Ready for \(setName)")
                        } else {
                            Text("Your binder is ready")
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    Group {
                        if let setName {
                            Text("Fill each numbered pocket from the \(setName) cards in Unsorted, or pick them yourself.")
                        } else {
                            Text("Fill it from your unsorted cards in one go, or pick them yourself.")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button("Not Now", systemImage: "xmark", action: onDismiss)
                    .labelStyle(.iconOnly)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button(action: onAutoFill) {
                    Label("Auto-Fill", systemImage: "wand.and.stars")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(Color.lorcanaDark)
                Button(action: onAddCards) {
                    Label("Add Cards", systemImage: "plus.rectangle.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .tint(.lorcanaGold)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.lorcanaGold.opacity(0.4), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
        }
        .padding(.horizontal)
    }
}

#Preview {
    VStack(spacing: 24) {
        BinderFillPrompt(setName: nil, onAutoFill: {}, onAddCards: {}, onDismiss: {})
        BinderFillPrompt(setName: "Winterspell", onAutoFill: {}, onAddCards: {}, onDismiss: {})
    }
    .frame(maxHeight: .infinity)
    .background(LorcanaBackground())
    .preferredColorScheme(.dark)
}
