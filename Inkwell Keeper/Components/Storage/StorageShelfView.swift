//
//  StorageShelfView.swift
//  Inkwell Keeper
//
//  The shelf at the top of the Collection tab: the Unsorted pile, then every binder
//  and box as an object you can open, then a slot to add another. Items tilt away
//  like a carousel as they scroll off the edge.
//

import SwiftUI

struct StorageShelfView: View {
    let unsortedCount: Int
    @Binding var showUnsortedOnly: Bool
    let transitionNamespace: Namespace.ID

    @Environment(StorageManager.self) private var storageManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("storageShelfCollapsed") private var isCollapsed = false

    @State private var showingCreate = false
    @State private var showingPaywall = false
    @State private var editingContainer: StorageContainer?
    @State private var containerPendingDelete: StorageContainer?
    /// Just created here; opened as soon as the create sheet has gone.
    @State private var justCreated: StorageContainer?
    @State private var openedNew: StorageRoute?

    private let subscriptionManager = SubscriptionManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if !isCollapsed {
                if storageManager.containers.isEmpty {
                    StorageShelfEmptyPrompt(onCreate: addContainer)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    shelf
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .sheet(isPresented: $showingCreate, onDismiss: openJustCreated) {
            ContainerEditorSheet(container: nil) { justCreated = $0 }
        }
        // A new binder or box opens straight away, ready to fill. It's already been
        // seen being made, so it skips its own cover/lid intro.
        .navigationDestination(item: $openedNew) { route in
            StorageContainerScreen(route: route)
                .navigationTransition(.zoom(sourceID: route.container.id, in: transitionNamespace))
        }
        .sheet(item: $editingContainer) { container in
            ContainerEditorSheet(container: container)
        }
        .sheet(isPresented: $showingPaywall) {
            RulesPaywallView(source: "storageLimit")
        }
        .confirmationDialog(
            "Delete \(containerPendingDelete?.name ?? "")?",
            isPresented: Binding(
                get: { containerPendingDelete != nil },
                set: { if !$0 { containerPendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: containerPendingDelete
        ) { container in
            Button("Delete \(container.kind.displayName)", role: .destructive) {
                withAnimation(.snappy) {
                    storageManager.delete(container)
                }
            }
        } message: { _ in
            Text("Its cards stay in your collection and move back to Unsorted.")
        }
    }

    private var header: some View {
        HStack {
            Button {
                withAnimation(reduceMotion ? nil : .snappy) {
                    isCollapsed.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text("Storage")
                        .font(.headline)
                        .foregroundStyle(.lorcanaGold)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(.gray)
                        .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Storage")
            .accessibilityValue(isCollapsed ? "Collapsed" : "Expanded")
            .accessibilityHint("Shows or hides your binders and boxes")

            if showUnsortedOnly {
                Button("Unsorted", systemImage: "xmark.circle.fill") {
                    withAnimation(.snappy) { showUnsortedOnly = false }
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .tint(.lorcanaGold)
                .accessibilityLabel("Clear Unsorted filter")
            }

            Spacer()

            Button("Add Binder or Box", systemImage: "plus", action: addContainer)
                .labelStyle(.iconOnly)
                .foregroundStyle(.lorcanaGold)
        }
    }

    private var shelf: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 8) {
                Button {
                    withAnimation(.snappy) { showUnsortedOnly.toggle() }
                } label: {
                    UnsortedPileView(count: unsortedCount, isSelected: showUnsortedOnly)
                }
                .buttonStyle(.plain)
                .shelfTilt(enabled: !reduceMotion)

                ForEach(storageManager.containers) { container in
                    NavigationLink(value: StorageRoute(container: container)) {
                        ShelfItemView(container: container, isFull: storageManager.isFull(container))
                            .matchedTransitionSource(id: container.id, in: transitionNamespace)
                    }
                    .buttonStyle(.plain)
                    .shelfTilt(enabled: !reduceMotion)
                    .contextMenu {
                        Button("Edit", systemImage: "pencil") { editingContainer = container }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            containerPendingDelete = container
                        }
                    }
                }

                Button(action: addContainer) {
                    AddContainerTile()
                }
                .buttonStyle(.plain)
            }
            .scrollTargetLayout()
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .background(alignment: .top) {
            // The plank the objects stand on, running edge to edge under the row.
            ShelfPlank()
                .padding(.top, 4 + ShelfMetrics.objectZone)
                .padding(.horizontal, -16)
        }
    }

    private func openJustCreated() {
        guard let container = justCreated else { return }
        justCreated = nil
        openedNew = StorageRoute(container: container, playsIntro: container.kind != .binder)
    }

    private func addContainer() {
        if storageManager.canCreateContainer(isSubscribed: subscriptionManager.isSubscribed) {
            showingCreate = true
        } else {
            showingPaywall = true
        }
    }
}

private extension View {
    /// Items rotate away and shrink slightly as they scroll off either edge.
    func shelfTilt(enabled: Bool) -> some View {
        scrollTransition(.interactive, axis: .horizontal) { content, phase in
            content
                .rotation3DEffect(.degrees(enabled ? phase.value * -28 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                .scaleEffect(enabled ? 1 - abs(phase.value) * 0.1 : 1)
                .opacity(1 - abs(phase.value) * 0.3)
        }
    }
}
