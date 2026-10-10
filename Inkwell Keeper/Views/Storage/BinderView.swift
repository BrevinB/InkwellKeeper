//
//  BinderView.swift
//  Inkwell Keeper
//
//  An open binder. The cover swings open on arrival, pages turn under your finger,
//  and in Arrange mode cards can be picked up and moved between pockets — by tap
//  (pick up, turn pages, put down) or by drag and drop.
//

import SwiftUI

struct BinderView: View {
    let container: StorageContainer
    /// Pocket to open to and highlight, e.g. from a card's "Stored in" row.
    var focusSlot: Int?

    @Environment(StorageManager.self) private var storageManager
    @Environment(CollectionManager.self) private var collectionManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    @State private var model: BinderViewModel
    @State private var coverAngle: Double?
    @State private var ghostsBySlot: [Int: LorcanaCard] = [:]
    @State private var detailCard: LorcanaCard?
    @State private var fillSlot: FillTarget?
    @State private var showingAddCards = false
    @State private var showingAutoFill = false
    @State private var showingEditor = false
    @State private var showingDeleteConfirmation = false
    @State private var moveFeedback = 0
    @State private var showingMove = false
    /// "Not Now" on the empty-binder prompt, for this visit.
    @State private var fillPromptDismissed = false
    @State private var bulkMoveResult: StorageManager.BulkMoveResult?
    @Namespace private var pocketNamespace

    private struct FillTarget: Identifiable {
        let slot: Int
        var id: Int { slot }
    }

    init(container: StorageContainer, focusSlot: Int? = nil, playsIntro: Bool = true) {
        self.container = container
        self.focusSlot = focusSlot
        _model = State(initialValue: BinderViewModel(layout: container.binderLayout, isTwoUp: false, focusSlot: focusSlot))
        // Open with the cover closed, unless we're jumping straight to a card or
        // the binder has already been opened on the way in.
        _coverAngle = State(initialValue: focusSlot == nil && playsIntro ? 0 : nil)
    }

    private var wantsTwoUp: Bool {
        horizontalSizeClass == .regular || verticalSizeClass == .compact
    }

    var body: some View {
        let itemsBySlot = Self.itemsBySlot(container.items ?? [])

        VStack(spacing: 12) {
            if model.isEditing {
                ArrangeHint(hasPickedUp: model.pickedUpItemId != nil)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer(minLength: 0)

            PageFlipView(
                model: model,
                pageAspectRatio: BinderPageView.aspectRatio(for: model.layout),
                allowsSwipe: !model.isEditing || model.pickedUpItemId != nil,
                page: { page in
                    if let page {
                        BinderPageView(
                            page: page,
                            layout: model.layout,
                            itemsBySlot: itemsBySlot,
                            ghostsBySlot: ghostsBySlot,
                            model: model,
                            namespace: pocketNamespace,
                            onTap: handleTap,
                            onDrop: moveItem,
                            onRemove: remove,
                            upgradeableFoil: upgradeableFoil,
                            onUpgrade: upgrade
                        )
                    } else {
                        BinderInsideCover(
                            container: container,
                            value: storageManager.value(of: container),
                            setProgress: setProgress(itemsBySlot: itemsBySlot)
                        )
                    }
                },
                sheetBack: { PageSheetBackground() },
                coverAngle: coverAngle,
                cover: {
                    Button {
                        openCover(animated: false)
                    } label: {
                        ClosedBinderCover(container: container)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open \(container.name)")
                }
            )
            .padding(.horizontal)

            Spacer(minLength: 0)

            BinderPageScrubber(model: model)
        }
        .overlay(alignment: .bottom) {
            if showsFillPrompt {
                BinderFillPrompt(
                    setName: container.linkedSetName,
                    onAutoFill: { showingAutoFill = true },
                    onAddCards: { showingAddCards = true },
                    onDismiss: { withAnimation(.snappy) { fillPromptDismissed = true } }
                )
                // Sit above the page scrubber.
                .padding(.bottom, 64)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: showsFillPrompt)
        .background(LorcanaBackground())
        .navigationTitle(container.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .safeAreaInset(edge: .bottom) {
            if model.isSelecting {
                BulkSelectionBar(
                    selectedCopies: model.selectedItemIds.count,
                    allSelected: !(container.items ?? []).isEmpty && model.selectedItemIds.count == (container.items ?? []).count,
                    onToggleAll: toggleSelectAll,
                    onMove: { showingMove = true }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: model.isEditing)
        .animation(.snappy, value: model.isSelecting)
        .sensoryFeedback(.impact(weight: .medium), trigger: moveFeedback)
        .sensoryFeedback(.selection, trigger: model.pickedUpItemId)
        .sensoryFeedback(.selection, trigger: model.selectedItemIds)
        .onAppear {
            model.setTwoUp(wantsTwoUp)
            if let focusSlot { model.show(slot: focusSlot) }
            openCover(animated: !reduceMotion)
        }
        .onChange(of: wantsTwoUp) { _, twoUp in
            withAnimation(.snappy) { model.setTwoUp(twoUp) }
        }
        .onChange(of: container.binderLayout) { _, layout in
            model.updateLayout(layout)
        }
        .task(id: "\(container.linkedSetName ?? "")|\(container.hasFoilPockets)|\(container.sheetCount)|\(container.pocketsPerPage)") {
            ghostsBySlot = storageManager.checklistGhosts(for: container)
        }
        .sheet(item: $detailCard) { card in
            CollectionCardDetailView(
                card: card,
                isPresented: Binding(get: { detailCard != nil }, set: { if !$0 { detailCard = nil } })
            )
            .presentationSizing(.page)
        }
        .sheet(item: $fillSlot) { target in
            AddToContainerSheet(container: container, targetSlot: target.slot, suggestedCard: ghostsBySlot[target.slot])
        }
        .sheet(isPresented: $showingAddCards) {
            AddToContainerSheet(container: container, targetSlot: nil, suggestedCard: nil)
        }
        .sheet(isPresented: $showingAutoFill) {
            BinderAutoFillSheet(container: container) { firstSlot in
                if let firstSlot {
                    withAnimation(.snappy) { model.show(slot: firstSlot) }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingMove) {
            MoveCardsSheet(
                items: (container.items ?? []).filter { model.selectedItemIds.contains($0.id) },
                source: container
            ) { result in
                model.isSelecting = false
                if result.leftBehind > 0 { bulkMoveResult = result }
            }
        }
        .alert(
            "Some Cards Stayed",
            isPresented: Binding(get: { bulkMoveResult != nil }, set: { if !$0 { bulkMoveResult = nil } }),
            presenting: bulkMoveResult
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { result in
            Text("Moved \(result.moved). ^[\(result.leftBehind) card](inflect: true) didn't fit there and stayed in this binder.")
        }
        .sheet(isPresented: $showingEditor) {
            ContainerEditorSheet(container: container)
        }
        .confirmationDialog("Delete \(container.name)?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Binder", role: .destructive) {
                storageManager.delete(container)
                dismiss()
            }
        } message: {
            Text("Its cards stay in your collection and move back to Unsorted.")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if model.isSelecting {
                Button("Done") { model.isSelecting = false }
                    .bold()
            } else {
                Button(model.isEditing ? "Done" : "Arrange") {
                    model.isEditing.toggle()
                }
                .bold(model.isEditing)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu("More", systemImage: "ellipsis.circle") {
                Button("Select Cards", systemImage: "checkmark.circle") { model.isSelecting = true }
                    .disabled((container.items ?? []).isEmpty)
                Button("Auto-Fill…", systemImage: "wand.and.stars") { showingAutoFill = true }
                Button("Add Cards…", systemImage: "plus.rectangle.on.rectangle") { showingAddCards = true }
                    .disabled(storageManager.isFull(container))
                Button("Close Gaps", systemImage: "arrow.left.to.line.compact") {
                    withAnimation(.spring(duration: 0.5)) { storageManager.compact(container) }
                }
                Button("Add 5 Sheets", systemImage: "doc.badge.plus") {
                    storageManager.addSheets(5, to: container)
                }
                Divider()
                Button("Edit Binder", systemImage: "pencil") { showingEditor = true }
                Button("Delete Binder", systemImage: "trash", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            }
        }
    }

    // MARK: - Actions

    private func openCover(animated: Bool) {
        guard coverAngle != nil else { return }
        guard animated else {
            coverAngle = nil
            return
        }
        // Wait for the zoom in to land, so the two never compete for frames.
        withAnimation(.easeInOut(duration: 0.9).delay(0.55)) {
            coverAngle = -180
        } completion: {
            coverAngle = nil
        }
    }

    /// An empty binder, open and not being arranged, suggests how to fill it.
    private var showsFillPrompt: Bool {
        (container.items ?? []).isEmpty && coverAngle == nil && !model.isEditing && !model.isSelecting && !fillPromptDismissed
    }

    private func toggleSelectAll() {
        let all = Set((container.items ?? []).map(\.id))
        model.selectedItemIds = model.selectedItemIds == all ? [] : all
    }

    private func handleTap(slot: Int, occupant: StoredCard?) {
        model.focusedSlot = nil
        switch model.action(forTapOnSlot: slot, occupant: occupant?.id) {
        case .open:
            detailCard = occupant?.toLorcanaCard
        case .fill(let slot):
            fillSlot = FillTarget(slot: slot)
        case .pickUp(let id):
            model.pickedUpItemId = id
        case .putDown:
            model.pickedUpItemId = nil
        case .move(let id, let slot):
            moveItem(id, toSlot: slot)
        case .toggleSelection(let id):
            model.toggleSelection(id)
        case .none:
            break
        }
    }

    private func moveItem(_ id: UUID, toSlot slot: Int) {
        guard let item = (container.items ?? []).first(where: { $0.id == id }) else { return }
        withAnimation(.spring(duration: 0.45, bounce: 0.25)) {
            storageManager.moveItem(item, toSlot: slot)
            model.pickedUpItemId = nil
        }
        moveFeedback += 1
    }

    /// The unsorted foil that could replace this normal copy, if any.
    private func upgradeableFoil(for item: StoredCard) -> LorcanaCard? {
        guard item.cardVariant == .normal else { return nil }
        let foil = item.toLorcanaCard.withVariant(.foil)
        return storageManager.upgradeTarget(for: foil, in: container) == nil ? nil : foil
    }

    private func upgrade(_ item: StoredCard) {
        guard let foil = upgradeableFoil(for: item) else { return }
        withAnimation(.spring(duration: 0.45, bounce: 0.3)) {
            _ = storageManager.upgradeToFoil(foil, in: container)
        }
        moveFeedback += 1
    }

    private func remove(_ item: StoredCard) {
        withAnimation(.snappy) {
            storageManager.remove(item)
        }
    }

    // MARK: - Derived data

    static func itemsBySlot(_ items: [StoredCard]) -> [Int: StoredCard] {
        var bySlot: [Int: StoredCard] = [:]
        for item in items {
            if let slot = item.slotIndex, bySlot[slot] == nil {
                bySlot[slot] = item
            }
        }
        return bySlot
    }

    private func setProgress(itemsBySlot: [Int: StoredCard]) -> (filled: Int, total: Int)? {
        guard container.linkedSetName != nil, !ghostsBySlot.isEmpty else { return nil }
        let filled = ghostsBySlot.keys.filter { itemsBySlot[$0] != nil }.count
        return (filled, ghostsBySlot.count)
    }
}
