//
//  BookshelfView.swift
//  Inkwell Keeper
//
//  The Bookshelf tab: every binder and box standing in a wooden bookcase, for
//  showing a collection off. (The shelf on the Collection tab is the quick-access
//  version.) Tap a binder and it's pulled from the shelf, turned to face you and
//  opened; tap a box and it's lifted down and its lid comes off.
//

import SwiftUI

struct BookshelfView: View {
    static let coordinateSpace = "bookshelf"

    @Environment(StorageManager.self) private var storageManager
    @Environment(CollectionManager.self) private var collectionManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var model = BookshelfViewModel()
    @State private var shelfWidth: CGFloat = 0
    @State private var showingCreate = false
    @State private var showingPaywall = false
    @State private var showingShare = false
    /// Just created here; pulled off the shelf and opened once the create sheet has gone.
    @State private var justCreated: StorageContainer?
    /// Bumped when scrolling settles, so faces are pre-drawn for what's now on screen.
    @State private var scrollSettledCount = 0
    @State private var editingContainer: StorageContainer?
    @State private var containerPendingDelete: StorageContainer?
    @Namespace private var zoom

    private let subscriptionManager = SubscriptionManager.shared

    var body: some View {
        let containers = BookcaseLayout.ordered(storageManager.containers)
        let slots = containers.map(BookcaseLayout.slot(for:))
        let rows = BookcaseLayout.rows(for: slots, availableWidth: max(shelfWidth - BookcaseShelf<EmptyView>.inset * 2, 120))

        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 0) {
                        BookshelfSummary(
                            containerCount: containers.count,
                            cardCount: containers.reduce(0) { $0 + $1.cardCount },
                            value: containers.reduce(0) { $0 + storageManager.value(of: $1) }
                        )
                        .padding(.horizontal, BookcaseShelf<EmptyView>.inset)
                        .padding(.top, 12)

                        if containers.isEmpty {
                            BookshelfEmptyState(onCreate: addContainer)
                        } else {
                            ForEach(rows, id: \.self) { row in
                                BookcaseShelf {
                                    ForEach(row, id: \.self) { index in
                                        BookcaseShelfItem(
                                            container: containers[index],
                                            model: model,
                                            isFull: storageManager.isFull(containers[index]),
                                            onOpen: { open(containers[index]) },
                                            onEdit: { editingContainer = containers[index] },
                                            onDelete: { containerPendingDelete = containers[index] }
                                        )
                                        .padding(.leading, index == row.first ? 0 : BookcaseLayout.gap(between: slots[index - 1], and: slots[index]))
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
                .onScrollPhaseChange { _, phase in
                    if phase == .idle { scrollSettledCount += 1 }
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { shelfWidth = $0 }
                .background { BookcaseBackdrop().ignoresSafeArea() }

                if let pull = model.pull {
                    // The room dims while something's off the shelf; it also stops taps
                    // landing on the bookcase mid-animation.
                    Color.black
                        .opacity(0.6 * model.travel)
                        .ignoresSafeArea()
                        .contentShape(.rect)
                        .accessibilityHidden(true)

                    PulledContainerView(
                        container: pull.container,
                        source: pull.source,
                        stage: pull.stage,
                        snapshot: pull.snapshot,
                        spreadWidth: pull.spreadWidth,
                        zoomNamespace: zoom,
                        travel: model.travel,
                        opened: model.opened
                    )
                    .accessibilityHidden(true)
                    .onAppear(perform: model.pulledObjectAppeared)
                }
            }
            .coordinateSpace(.named(Self.coordinateSpace))
            .onGeometryChange(for: CGSize.self) { $0.size } action: { model.viewSize = $0 }
            // Same rule as the binder screen, so the pull opens to the spread it'll show.
            .onChange(of: horizontalSizeClass == .regular || verticalSizeClass == .compact, initial: true) { _, spreads in
                model.usesSpreads = spreads
            }
            .navigationTitle("Bookshelf")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Binder or Box", systemImage: "plus", action: addContainer)
                }
                if !containers.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Share Bookshelf", systemImage: "square.and.arrow.up") { showingShare = true }
                    }
                }
            }
            .fullScreenCover(item: $model.presented, onDismiss: model.returnToShelf) { container in
                Group {
                    if reduceMotion {
                        BookshelfOpenContainer(container: container, playsIntro: true)
                    } else {
                        // Already opened by the pull, so the screen skips its own intro.
                        BookshelfOpenContainer(container: container, playsIntro: false)
                            .navigationTransition(.zoom(sourceID: container.id, in: zoom))
                    }
                }
                .environment(storageManager)
                .environment(collectionManager)
            }
            // Draw every container's pull faces while the bookcase sits idle, so a
            // tap never has to stop and render before the pull can start.
            .task(id: prewarmKey(for: containers)) {
                await model.prewarmSnapshots(for: containers, renderer: snapshotRenderer)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: model.pullCount)
            .sensoryFeedback(.impact(weight: .medium), trigger: model.openCount)
        }
        .sheet(isPresented: $showingCreate, onDismiss: openJustCreated) {
            ContainerEditorSheet(container: nil) { justCreated = $0 }
        }
        .sheet(item: $editingContainer) { container in
            ContainerEditorSheet(container: container)
        }
        .sheet(isPresented: $showingShare) {
            ShareCardPresenter(
                analyticsType: "bookshelf",
                qrPayload: AppLinks.appStoreURLString,
                tagline: "Organize your Lorcana collection",
                fileName: "InkwellKeeper-Bookshelf",
                canvasHeight: nil
            ) { _ in
                BookshelfShareCardView(summary: BookshelfShareSummary(
                    containers: storageManager.containers,
                    value: storageManager.value(of:)
                ))
            }
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

    private var snapshotRenderer: PullSnapshot.Renderer {
        PullSnapshot.Renderer(scale: displayScale, dynamicTypeSize: dynamicTypeSize)
    }

    private func open(_ container: StorageContainer) {
        model.open(container, animated: !reduceMotion, renderer: snapshotRenderer)
    }

    /// Changes whenever the pull faces would need drawing again.
    private func prewarmKey(for containers: [StorageContainer]) -> String {
        let looks = containers.map { "\($0.id)\($0.name)\($0.colorName)\($0.coverStyle)\($0.sheetCount)" }
        return looks.joined() + "\(model.viewSize)\(displayScale)\(dynamicTypeSize)\(scrollSettledCount)"
    }

    /// The new binder or box has just landed on the shelf: take it straight back off
    /// and open it, so filling it is the next thing that happens.
    private func openJustCreated() {
        guard let container = justCreated else { return }
        justCreated = nil
        Task {
            // Give the shelf a moment to lay out the new arrival so the pull starts from it.
            try? await Task.sleep(for: .milliseconds(250))
            open(container)
        }
    }

    private func addContainer() {
        if storageManager.canCreateContainer(isSubscribed: subscriptionManager.isSubscribed) {
            showingCreate = true
        } else {
            showingPaywall = true
        }
    }
}
