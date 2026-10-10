//
//  BinderAutoFillSheet.swift
//  Inkwell Keeper
//
//  Fill a binder's free pockets with unsorted cards in a chosen order.
//

import SwiftUI

struct BinderAutoFillSheet: View {
    let container: StorageContainer
    /// Called with the first free pocket, so the binder can turn to it before filling.
    let onFilled: (Int?) -> Void

    @Environment(StorageManager.self) private var storageManager
    @Environment(CollectionManager.self) private var collectionManager
    @Environment(\.dismiss) private var dismiss

    @State private var order: BinderSortOrder = .setNumber
    @State private var setFilter: String?
    /// Off by default: filling never makes the binder bigger unless asked to.
    @State private var growToFit = false
    @State private var unsortedByIdentity: [String: Int] = [:]

    /// Set checklist binders are locked to their set.
    private var lockedSet: String? { container.linkedSetName }

    private var sourceCards: [LorcanaCard] {
        let set = lockedSet ?? setFilter
        return collectionManager.collectedCards.filter { card in
            (unsortedByIdentity[CollectionManager.identityKey(for: card)] ?? 0) > 0
                && (set == nil || card.setName == set)
        }
    }

    private var copiesToPlace: Int {
        if lockedSet != nil {
            // One card per empty numbered pocket; extra copies and variants share it.
            let occupied = storageManager.occupiedSlots(in: container)
            let slots = sourceCards.compactMap { storageManager.setPocket(for: $0, in: container) }
            return Set(slots).subtracting(occupied).count
        }
        return sourceCards.reduce(0) { $0 + (unsortedByIdentity[CollectionManager.identityKey(for: $1)] ?? 0) }
    }

    private var freePockets: Int {
        container.binderLayout.totalSlots - storageManager.occupiedSlots(in: container).count
    }

    private var availableSets: [String] {
        let names = Set(collectionManager.collectedCards
            .filter { (unsortedByIdentity[CollectionManager.identityKey(for: $0)] ?? 0) > 0 }
            .map(\.setName))
        let setOrder = BinderSortOrder.catalogSetOrder()
        return names.sorted { (setOrder[$0] ?? .max, $0) < (setOrder[$1] ?? .max, $1) }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let lockedSet {
                    Section {
                        LabeledContent("From", value: lockedSet)
                        LabeledContent("Cards to place", value: "\(copiesToPlace)")
                    } header: {
                        Text("Cards")
                    } footer: {
                        Text("This is a \(lockedSet) checklist, so each card goes in its own numbered pocket. Extra copies and cards from other sets stay unsorted.")
                    }
                } else {
                    Section("Cards") {
                        Picker("From", selection: $setFilter) {
                            Text("All unsorted cards").tag(String?.none)
                            ForEach(availableSets, id: \.self) { name in
                                Text(name).tag(Optional(name))
                            }
                        }
                    }

                    Section("Order") {
                        Picker("Arrange by", selection: $order) {
                            ForEach(BinderSortOrder.allCases) { order in
                                Label(order.displayName, systemImage: order.systemImage).tag(order)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }

                    Section {
                        LabeledContent("Cards to place", value: "\(copiesToPlace)")
                        LabeledContent("Free pockets", value: "\(freePockets)")
                        if copiesToPlace > freePockets {
                            Toggle("Add sheets so everything fits", isOn: $growToFit)
                        }
                    } footer: {
                        if copiesToPlace > freePockets && !growToFit {
                            Text("\(copiesToPlace - freePockets) cards won't fit and will stay unsorted.")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(LorcanaBackground())
            .navigationTitle("Auto-Fill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fill", action: fill)
                        .bold()
                        .disabled(copiesToPlace == 0 || (lockedSet == nil && freePockets == 0 && !growToFit))
                }
            }
            .onAppear {
                unsortedByIdentity = storageManager.unsortedQuantitiesByIdentity()
            }
        }
        .tint(.lorcanaGold)
    }

    private func fill() {
        if lockedSet == nil, growToFit, copiesToPlace > freePockets {
            let layout = container.binderLayout
            let neededSlots = copiesToPlace - freePockets
            let perSheet = layout.pocketsPerPage * layout.pagesPerSheet
            storageManager.addSheets((neededSlots + perSheet - 1) / perSheet, to: container)
        }
        let cards = sourceCards
        let order = order
        let occupied = storageManager.occupiedSlots(in: container)
        let firstFree = lockedSet == nil
            ? container.binderLayout.firstEmptySlot(occupied: occupied)
            : cards.compactMap { storageManager.setPocket(for: $0, in: container) }.filter { !occupied.contains($0) }.min()

        // Turn to the first free pocket while the sheet slides away, then drop the
        // cards in so the cascade happens in view.
        onFilled(firstFree)
        dismiss()
        Task { [storageManager, container] in
            try? await Task.sleep(for: .milliseconds(450))
            storageManager.autoFill(container, with: cards, order: order, setOrder: BinderSortOrder.catalogSetOrder())
        }
    }
}
