//
//  ScanDestinationPicker.swift
//  Inkwell Keeper
//
//  "Put into…" above the multi-scan Add button: scanned cards can go straight into a
//  binder or box instead of Unsorted. Pro; free users see the PRO pill and the paywall.
//

import SwiftUI

struct ScanDestinationPicker: View {
    /// The chosen container, or nil for Unsorted.
    let selection: StorageContainer?
    let containers: [StorageContainer]
    /// Containers with no room left; they can't be chosen.
    let fullContainerIds: Set<UUID>
    let isSubscribed: Bool
    let onSelect: (StorageContainer?) -> Void
    let onLocked: () -> Void

    var body: some View {
        Group {
            if isSubscribed {
                Menu {
                    Button("Unsorted", systemImage: "square.stack.3d.down.right") { onSelect(nil) }
                    if !containers.isEmpty {
                        Divider()
                        ForEach(containers) { container in
                            let isFull = fullContainerIds.contains(container.id)
                            Button(
                                isFull ? String(localized: "\(container.name) (Full)") : container.name,
                                systemImage: container.kind.systemImage
                            ) { onSelect(container) }
                            .disabled(isFull)
                        }
                    }
                } label: {
                    label
                }
            } else {
                Button(action: onLocked) {
                    label
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Put scanned cards into")
        .accessibilityValue(selection?.name ?? "Unsorted")
        .accessibilityHint(isSubscribed ? "Choose a binder or box" : "Requires Inkwell Pro")
    }

    private var label: some View {
        HStack(spacing: 10) {
            Group {
                if let selection {
                    ContainerArtwork(kind: selection.kind, color: selection.coverColor, style: .classic)
                } else {
                    Image(systemName: "square.stack.3d.down.right")
                        .foregroundStyle(.gray)
                }
            }
            .frame(width: 26, height: 26)

            Text("Put into")
                .font(.subheadline)
                .foregroundStyle(.gray)
            Text(selection?.name ?? String(localized: "Unsorted"))
                .font(.subheadline)
                .bold()
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 0)

            if let selection, fullContainerIds.contains(selection.id) {
                FullBadge()
            }

            if isSubscribed {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.lorcanaGold)
            } else {
                ProPill()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
        .contentShape(.rect)
    }
}
