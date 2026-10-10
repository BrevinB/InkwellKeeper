//
//  BoxView.swift
//  Inkwell Keeper
//
//  An open trove, deck box, storage box or bin. The lid lifts on arrival, then the
//  cards inside are laid out by set.
//

import SwiftUI
import SwiftData

struct BoxView: View {
    let container: StorageContainer
    /// False when the box arrives already open (from the bookshelf): the lid starts
    /// up and just settles, instead of closing and lifting again.
    var playsIntro = true

    @Environment(StorageManager.self) private var storageManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Query private var decks: [Deck]

    @State private var lidLift = 0.0
    @State private var detailCard: LorcanaCard?
    @State private var showingAddCards = false
    @State private var showingEditor = false
    @State private var showingDeleteConfirmation = false
    @State private var showingPullList = false
    /// Select mode: tap cards to choose several, then move them together.
    @State private var isSelecting = false
    @State private var selection: Set<UUID> = []
    @State private var showingMove = false
    @State private var bulkMoveResult: StorageManager.BulkMoveResult?

    private struct BoxSection: Identifiable {
        let setName: String
        let items: [StoredCard]
        var id: String { setName }
    }

    /// Cards grouped by set, sets in release order, cards by number within each.
    private var sections: [BoxSection] {
        let setOrder = BinderSortOrder.catalogSetOrder()
        let grouped: [String: [StoredCard]] = Dictionary(grouping: container.items ?? [], by: \.setName)
        let unsorted: [BoxSection] = grouped.map { setName, items in
            let sortedItems = items.sorted { lhs, rhs in
                let lhsNumber = lhs.cardNumber ?? Int.max
                let rhsNumber = rhs.cardNumber ?? Int.max
                return lhsNumber == rhsNumber ? lhs.variant < rhs.variant : lhsNumber < rhsNumber
            }
            return BoxSection(setName: setName, items: sortedItems)
        }
        return unsorted.sorted { lhs, rhs in
            let lhsRank = setOrder[lhs.setName] ?? Int.max
            let rhsRank = setOrder[rhs.setName] ?? Int.max
            return lhsRank == rhsRank ? lhs.setName < rhs.setName : lhsRank < rhsRank
        }
    }

    private var linkedDeck: Deck? {
        guard let id = container.linkedDeckId else { return nil }
        return decks.first { $0.id == id }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                BoxHeader(container: container, lidLift: lidLift, value: storageManager.value(of: container))

                if let linkedDeck {
                    DeckBoxChecklist(deck: linkedDeck, container: container) { showingPullList = true }
                        .padding(.horizontal)
                }

                if (container.items ?? []).isEmpty {
                    ContentUnavailableView {
                        Label("Nothing Inside Yet", systemImage: container.kind.systemImage)
                    } description: {
                        Text("Put unsorted cards in this \(container.kind.displayName.lowercased()) to find them later.")
                    } actions: {
                        Button("Add Cards") { showingAddCards = true }
                            .buttonStyle(.borderedProminent)
                            .foregroundStyle(Color.lorcanaDark)
                    }
                } else {
                    LazyVStack(alignment: .leading, spacing: 18, pinnedViews: .sectionHeaders) {
                        ForEach(sections) { section in
                            Section {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 10)], spacing: 12) {
                                    ForEach(section.items) { item in
                                        BoxCardCell(item: item, isSelected: isSelecting ? selection.contains(item.id) : nil) {
                                            if isSelecting {
                                                selection.formSymmetricDifference([item.id])
                                            } else {
                                                detailCard = item.toLorcanaCard
                                            }
                                        }
                                        .contextMenu { if !isSelecting { cellMenu(for: item) } }
                                        .transition(.scale.combined(with: .opacity))
                                    }
                                }
                            } header: {
                                BoxSectionHeader(setName: section.setName, count: section.items.reduce(0) { $0 + $1.quantity })
                            }
                        }
                    }
                    .padding(.horizontal)
                    .animation(.snappy, value: container.cardCount)
                }
            }
            .padding(.bottom)
        }
        .background(LorcanaBackground())
        .navigationTitle(container.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if isSelecting {
                BulkSelectionBar(
                    selectedCopies: selectedItems.reduce(0) { $0 + $1.quantity },
                    allSelected: !(container.items ?? []).isEmpty && selection.count == (container.items ?? []).count,
                    onToggleAll: toggleSelectAll,
                    onMove: { showingMove = true }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: isSelecting)
        .sensoryFeedback(.selection, trigger: selection)
        .toolbar {
            if !(container.items ?? []).isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSelecting ? "Done" : "Select") {
                        isSelecting.toggle()
                        selection = []
                    }
                    .bold(isSelecting)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add Cards", systemImage: "plus") { showingAddCards = true }
                    .disabled(storageManager.isFull(container) || isSelecting)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu("More", systemImage: "ellipsis.circle") {
                    Button("Edit \(container.kind.displayName)", systemImage: "pencil") { showingEditor = true }
                    Button("Delete \(container.kind.displayName)", systemImage: "trash", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }
            }
        }
        .onAppear(perform: liftLid)
        .sheet(item: $detailCard) { card in
            CollectionCardDetailView(
                card: card,
                isPresented: Binding(get: { detailCard != nil }, set: { if !$0 { detailCard = nil } })
            )
            .presentationSizing(.page)
        }
        .sheet(isPresented: $showingAddCards) {
            AddToContainerSheet(container: container, targetSlot: nil, suggestedCard: nil)
        }
        .sheet(isPresented: $showingEditor) {
            ContainerEditorSheet(container: container)
        }
        .sheet(isPresented: $showingMove) {
            MoveCardsSheet(items: selectedItems, source: container) { result in
                selection = []
                isSelecting = false
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
            Text("Moved \(result.moved). ^[\(result.leftBehind) card](inflect: true) didn't fit there and stayed in this \(container.kind.displayName.lowercased()).")
        }
        .sheet(isPresented: $showingPullList) {
            if let linkedDeck {
                BuildDeckSheet(deck: linkedDeck)
            }
        }
        .confirmationDialog("Delete \(container.name)?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete \(container.kind.displayName)", role: .destructive) {
                storageManager.delete(container)
                dismiss()
            }
        } message: {
            Text("Its cards stay in your collection and move back to Unsorted.")
        }
    }

    private var selectedItems: [StoredCard] {
        (container.items ?? []).filter { selection.contains($0.id) }
    }

    private func toggleSelectAll() {
        let all = Set((container.items ?? []).map(\.id))
        selection = selection == all ? [] : all
    }

    @ViewBuilder
    private func cellMenu(for item: StoredCard) -> some View {
        let card = item.toLorcanaCard
        Button("Card Details", systemImage: "info.circle") { detailCard = card }
        if item.quantity > 1 {
            Button("Take Out One", systemImage: "minus.circle") {
                storageManager.unstore(card, quantity: 1, from: container)
            }
        }
        Button("Take Out All", systemImage: "tray.and.arrow.up", role: .destructive) {
            storageManager.unstore(card, quantity: item.quantity, from: container)
        }
        let others = storageManager.containers.filter { $0.id != container.id }
        if !others.isEmpty {
            Menu("Move To", systemImage: "arrow.right.square") {
                ForEach(others) { destination in
                    let refusal = storageManager.refusal(for: card, in: destination)
                    Button(
                        refusal.map { String(localized: "\(destination.name) (\($0))") } ?? destination.name,
                        systemImage: destination.kind.systemImage
                    ) {
                        storageManager.move(card, quantity: item.quantity, from: container, to: destination)
                    }
                    .disabled(refusal != nil)
                }
            }
        }
    }

    private func liftLid() {
        guard playsIntro else {
            lidLift = 1
            withAnimation(.easeOut(duration: 0.5).delay(0.45)) { lidLift = 0.35 }
            return
        }
        guard !reduceMotion else {
            lidLift = 0.35
            return
        }
        lidLift = 0
        // Wait for the zoom in to land, so the two never compete for frames.
        withAnimation(.spring(duration: 0.7, bounce: 0.4).delay(0.5)) {
            lidLift = 1
        } completion: {
            withAnimation(.easeOut(duration: 0.5)) { lidLift = 0.35 }
        }
    }
}
