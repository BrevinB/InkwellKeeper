//
//  BinderPageView.swift
//  Inkwell Keeper
//
//  One page of pockets. Taps, drags and context-menu actions are reported to the
//  binder, which owns the decisions.
//

import SwiftUI

struct BinderPageView: View {
    let page: Int
    let layout: BinderLayout
    /// Every pocket's copies, top card first.
    let stacksBySlot: [Int: [StoredCard]]
    let ghostsBySlot: [Int: LorcanaCard]
    let model: BinderViewModel
    let namespace: Namespace.ID
    let onTap: (_ slot: Int, _ occupant: StoredCard?) -> Void
    let onDrop: (_ itemId: UUID, _ slot: Int) -> Void
    let onRemove: (StoredCard) -> Void
    var onEditPocket: (_ slot: Int) -> Void = { _ in }
    var onShowDetails: (StoredCard) -> Void = { _ in }
    /// The foil that could replace a normal copy in a checklist pocket, if one is unsorted.
    var upgradeableFoil: (StoredCard) -> LorcanaCard? = { _ in nil }
    var onUpgrade: (StoredCard) -> Void = { _ in }

    /// Gap between pockets and around the page edge, in points.
    static let gap: CGFloat = 6

    /// Width ÷ height of a page for this layout.
    static func aspectRatio(for layout: BinderLayout) -> CGFloat {
        let width = CGFloat(layout.columns) * 63 + CGFloat(layout.columns + 1) * 5
        let height = CGFloat(layout.rows) * 88 + CGFloat(layout.rows + 1) * 5 + 12
        return width / height
    }

    var body: some View {
        VStack(spacing: 2) {
            Grid(horizontalSpacing: Self.gap, verticalSpacing: Self.gap) {
                ForEach(0..<layout.rows, id: \.self) { row in
                    GridRow {
                        ForEach(0..<layout.columns, id: \.self) { column in
                            let pocket = row * layout.columns + column
                            if pocket < layout.pocketsPerPage {
                                pocketButton(pocket: pocket)
                            }
                        }
                    }
                }
            }

            Text("\(page + 1)")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.4))
                .accessibilityHidden(true)
        }
        .padding(Self.gap)
        .background(PageSheetBackground())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Page \(page + 1)")
    }

    private func pocketButton(pocket: Int) -> some View {
        let slot = layout.slot(page: page, pocket: pocket)
        let stack = stacksBySlot[slot] ?? []
        let item = stack.first
        let ghost = item == nil ? ghostsBySlot[slot] : nil

        return Button {
            onTap(slot, item)
        } label: {
            PocketView(
                stack: stack,
                ghost: ghost,
                pocketIndex: pocket,
                isPickedUp: item != nil && item?.id == model.pickedUpItemId,
                isFocused: model.focusedSlot == slot,
                namespace: namespace,
                canUpgrade: item.map { upgradeableFoil($0) != nil } ?? false,
                isSelected: model.isSelecting && item != nil ? stack.allSatisfy { model.selectedItemIds.contains($0.id) } : nil
            )
        }
        .buttonStyle(.plain)
        .draggable(item?.id.uuidString ?? "") {
            if let item {
                StorageCardThumbnail(card: item.toLorcanaCard)
                    .frame(width: 70)
            }
        }
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first.flatMap(UUID.init(uuidString:)) else { return false }
            onDrop(id, slot)
            return true
        }
        .contextMenu {
            if let item {
                Button("Edit Pocket", systemImage: "square.stack") {
                    onEditPocket(slot)
                }
                Button("Card Details", systemImage: "info.circle") {
                    onShowDetails(item)
                }
                if upgradeableFoil(item) != nil {
                    Button("Upgrade to Foil", systemImage: "sparkles") {
                        onUpgrade(item)
                    }
                }
                Button(stack.count > 1 ? "Take All Out of Binder" : "Take Out of Binder", systemImage: "tray.and.arrow.up", role: .destructive) {
                    onRemove(item)
                }
            } else {
                Button("Fill This Pocket", systemImage: "plus.rectangle.portrait") {
                    onTap(slot, nil)
                }
            }
        }
        .accessibilityLabel(pocketLabel(pocket: pocket, stack: stack, ghost: ghost))
        .accessibilityActions {
            if let item, upgradeableFoil(item) != nil {
                Button("Upgrade to Foil") { onUpgrade(item) }
            }
        }
        .accessibilityHint(pocketHint(item: item))
    }

    private func pocketLabel(pocket: Int, stack: [StoredCard], ghost: LorcanaCard?) -> String {
        let position = "Page \(page + 1), pocket \(pocket + 1)"
        if let item = stack.first {
            guard stack.count > 1 else {
                let variant = item.cardVariant == .normal ? "" : ", \(item.variant)"
                return "\(position), \(item.name)\(variant)"
            }
            let counts = Dictionary(grouping: stack, by: \.variant)
                .sorted { $0.key == CardVariant.normal.rawValue || ($1.key != CardVariant.normal.rawValue && $0.key < $1.key) }
                .map { "\($0.value.count) \($0.key.lowercased())" }
                .joined(separator: ", ")
            return "\(position), \(item.name), \(counts)"
        }
        if let ghost {
            return "\(position), empty, missing \(ghost.name)"
        }
        return "\(position), empty"
    }

    private func pocketHint(item: StoredCard?) -> String {
        if model.isEditing {
            if model.pickedUpItemId != nil { return "Moves the picked-up card here" }
            return item == nil ? "Choose a card for this pocket" : "Picks up this card to move it"
        }
        return item == nil ? "Choose a card for this pocket" : "Shows the copies in this pocket"
    }
}
