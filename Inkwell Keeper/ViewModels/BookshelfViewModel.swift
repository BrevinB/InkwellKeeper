//
//  BookshelfViewModel.swift
//  Inkwell Keeper
//
//  Drives the Bookshelf tab's showpiece: tapping a binder or box pulls it off the
//  shelf, brings it to the middle of the room (turning a binder from its spine to
//  its cover), opens a box's lid, then zooms into it full screen. Closing runs it
//  in reverse and slides the object back into its gap.
//
//  The container opens full screen rather than being pushed: on iPhone this tab
//  lives under More, which already wraps it in a navigation controller, and a push
//  inside that stacks a second navigation bar.
//

import SwiftUI

@MainActor
@Observable
final class BookshelfViewModel {
    /// The object currently off the shelf, and where it travels between.
    struct Pull {
        let container: StorageContainer
        /// Where it stood on the shelf, in the bookshelf's coordinate space.
        let source: CGRect
        /// Where it's held up to look at.
        let stage: CGRect
        /// Its faces rendered ahead of time, so the pull only moves images.
        let snapshot: PullSnapshot?
        /// For a binder opening onto a two-page spread: the spread's width. The
        /// binder is held on its right-hand page (`stage`).
        let spreadWidth: CGFloat?
    }

    private(set) var pull: Pull?
    /// The container open full screen.
    var presented: StorageContainer?

    /// 0 standing on the shelf → 1 held at the stage. The lift off the shelf is
    /// derived from this, so the whole trip is a single animation.
    private(set) var travel: Double = 0
    /// How open it is once held up: a box's lid lifting, or a binder's cover
    /// swinging open. 0 closed → 1 open.
    private(set) var opened: Double = 0

    /// Bumped as the object leaves the shelf and as it opens, for haptics.
    private(set) var pullCount = 0
    private(set) var openCount = 0

    /// Where each shelf item is, updated as the bookcase scrolls. Not observed:
    /// it changes every scroll frame and only matters at the moment of a tap.
    @ObservationIgnored var itemFrames: [UUID: CGRect] = [:]
    /// The bookshelf screen's size, for placing the stage.
    var viewSize: CGSize = .zero
    /// Whether binders open onto two-page spreads here (iPad, or iPhone in
    /// landscape) — the same rule the binder screen uses.
    var usesSpreads = false
    /// Faces rendered while the bookshelf sits idle, keyed by what they depict.
    @ObservationIgnored private let snapshots = PullSnapshotCache()
    /// Whether the current pull's trip has begun, so it only runs once.
    @ObservationIgnored private var hasStartedPull = false

    /// Pulls a container off the shelf and opens it. Without motion (or without a
    /// known shelf position) it simply opens. `renderer` draws faces the prewarm
    /// hasn't; without one the live artwork is animated instead.
    func open(_ container: StorageContainer, animated: Bool, renderer: PullSnapshot.Renderer? = nil) {
        guard pull == nil, presented == nil else { return }
        guard animated, let source = itemFrames[container.id], viewSize != .zero else {
            presented = container
            return
        }
        let stages = Self.stages(for: container, in: viewSize, spreads: usesSpreads)
        let snapshot = renderer.flatMap { snapshot(for: container, renderer: $0) }
        pull = Pull(
            container: container,
            source: source,
            stage: stages.page,
            snapshot: snapshot,
            spreadWidth: stages.spread?.width
        )
        travel = 0
        opened = 0
        pullCount += 1
        hasStartedPull = false
    }

    /// Starts the trip once the pulled object is on screen at its shelf position.
    /// It can't start in `open`: the object is inserted in that same update, and a
    /// view that arrives mid-animation is simply drawn at its end state — so the
    /// pull would be skipped and the container would open immediately.
    func pulledObjectAppeared() {
        guard let container = pull?.container, !hasStartedPull else { return }
        hasStartedPull = true

        // Held up facing you, it opens — the binder's cover swings back, the box's
        // lid lifts — and then you're zoomed in, already open.
        let opening: Animation = container.kind == .binder
            ? .easeInOut(duration: 0.55)
            : .spring(duration: 0.4, bounce: 0.3)
        withAnimation(.smooth(duration: 0.7)) {
            travel = 1
        } completion: {
            withAnimation(opening) {
                self.opened = 1
            } completion: {
                self.enter(container)
            }
        }
    }

    /// Called once the full-screen container has been dismissed: close up and
    /// slide back into the gap on the shelf.
    func returnToShelf() {
        guard pull != nil else { return }
        withAnimation(.snappy(duration: 0.3)) {
            opened = 0
        } completion: {
            withAnimation(.smooth(duration: 0.55)) {
                self.travel = 0
            } completion: {
                self.pull = nil
            }
        }
    }

    /// Renders faces ahead of a tap for the containers currently on screen, a little
    /// at a time so the bookcase stays responsive. Only what's visible: a big
    /// collection would otherwise hold a full-screen image for every binder.
    func prewarmSnapshots(for containers: [StorageContainer], renderer: PullSnapshot.Renderer) async {
        guard viewSize != .zero else { return }
        let screen = CGRect(origin: .zero, size: viewSize)
        let visible = containers.filter { itemFrames[$0.id].map(screen.intersects) ?? false }
        for container in visible {
            guard !Task.isCancelled else { return }
            if !snapshots.contains(snapshotKey(for: container, renderer: renderer)) {
                _ = snapshot(for: container, renderer: renderer)
                try? await Task.sleep(for: .milliseconds(60))
            }
        }
    }

    private func enter(_ container: StorageContainer) {
        openCount += 1
        presented = container
    }

    private func snapshot(for container: StorageContainer, renderer: PullSnapshot.Renderer) -> PullSnapshot? {
        snapshots.snapshot(for: snapshotKey(for: container, renderer: renderer)) {
            let slot = BookcaseLayout.slot(for: container)
            let shelfSize = CGSize(
                width: slot.width,
                height: slot.isSpine ? BookcaseLayout.spineHeight : BookcaseLayout.objectHeight(for: container.kind)
            )
            return PullSnapshot.make(
                for: container,
                source: CGRect(origin: .zero, size: shelfSize),
                stage: Self.stages(for: container, in: viewSize, spreads: usesSpreads).page,
                renderer: renderer
            )
        }
    }

    /// Everything a snapshot depends on; any change renders a fresh one.
    private func snapshotKey(for container: StorageContainer, renderer: PullSnapshot.Renderer) -> String {
        [
            container.id.uuidString, container.name, container.colorName, container.coverStyle,
            "\(container.sheetCount)", "\(container.pocketsPerPage)", "\(viewSize.width)x\(viewSize.height)", "\(usesSpreads)",
            "\(renderer.scale)", "\(renderer.dynamicTypeSize)"
        ].joined(separator: "|")
    }

    /// Where a pulled container is held. A binder takes the shape of its pages, so
    /// the cover and first page it opens to line up with the binder screen's. With
    /// spreads, the binder is held on the right-hand page of a centred spread, so its
    /// cover can swing over to the left like a book.
    static func stages(for container: StorageContainer, in size: CGSize, spreads: Bool) -> (page: CGRect, spread: CGRect?) {
        guard container.kind == .binder else {
            return (stage(for: container.kind, in: size), nil)
        }
        let pageAspect = BinderPageView.aspectRatio(for: container.binderLayout)
        guard spreads else {
            return (stage(for: .binder, in: size, aspect: pageAspect), nil)
        }
        let spread = spreadStage(pageAspect: pageAspect, in: size)
        let page = CGRect(x: spread.midX, y: spread.minY, width: spread.width / 2, height: spread.height)
        return (page, spread)
    }

    /// A two-page spread, centred and as large as fits comfortably.
    static func spreadStage(pageAspect: CGFloat, in size: CGSize) -> CGRect {
        let aspect = pageAspect * 2
        var width = min(size.width * 0.9, 900)
        var height = width / aspect
        let maxHeight = size.height * 0.62
        if height > maxHeight {
            height = maxHeight
            width = height * aspect
        }
        return CGRect(
            x: (size.width - width) / 2,
            y: (size.height - height) / 2 - size.height * 0.03,
            width: width,
            height: height
        )
    }

    /// Where a pulled object is held: centred, a little above middle, as large as
    /// fits comfortably, in the object's shape (`aspect` overrides it).
    static func stage(for kind: StorageKind, in size: CGSize, aspect: CGFloat? = nil) -> CGRect {
        let aspect = aspect ?? (kind == .binder ? coverAspect : ContainerArtwork.aspectRatio(for: kind))
        var width = min(size.width * (kind == .binder ? 0.62 : 0.8), 380)
        var height = width / aspect
        let maxHeight = size.height * 0.56
        if height > maxHeight {
            height = maxHeight
            width = height * aspect
        }
        return CGRect(
            x: (size.width - width) / 2,
            y: (size.height - height) / 2 - size.height * 0.04,
            width: width,
            height: height
        )
    }

    /// Width ÷ height of the binder's front cover.
    static let coverAspect: CGFloat = 0.78
}
