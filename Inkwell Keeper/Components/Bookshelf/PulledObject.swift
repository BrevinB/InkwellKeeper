//
//  PulledObject.swift
//  Inkwell Keeper
//
//  The pulled container itself, always laid out at its full stage size: a binder
//  part-way through turning from spine to cover (then opening its cover onto its
//  real first page), or a box (then lifting its lid). `PulledContainerView` scales
//  and moves it, so its size never changes from frame to frame.
//

import SwiftUI

struct PulledObject: View {
    let container: StorageContainer
    let source: CGRect
    let stage: CGRect
    /// Pre-rendered faces; without them (tests, failed render) the live artwork is drawn.
    let snapshot: PullSnapshot?
    /// Set when the binder opens onto a two-page spread: the frame is the whole
    /// spread, with the binder on its right-hand page.
    var spreadWidth: CGFloat?
    let travel: Double
    /// 0 closed → 1 open: the binder's cover swung back, or the box's lid lifted.
    let opened: Double

    var body: some View {
        if container.kind == .binder {
            ZStack {
                // The real first page waits under the cover for the whole trip —
                // invisible until the cover opens, but mounted, so its card images
                // have loaded by the time it's revealed.
                BinderOpeningPage(container: container)
                    .frame(width: stage.width, height: stage.height)
                    .opacity(opened > 0 ? 1 : 0)

                if opened > 0, spreadWidth != nil {
                    // On a spread the cover swings right over to the left page, showing
                    // the inside cover — exactly the spread the binder screen opens to.
                    let angle = -180 * opened
                    Group {
                        LeafCastShadow(angle: angle)
                        PageLeaf(
                            angle: angle,
                            front: PulledCoverFace(container: container, snapshot: snapshot),
                            back: BinderOpeningInsideCover(container: container)
                        )
                    }
                    .frame(width: stage.width, height: stage.height)
                } else if opened > 0 {
                    // One page at a time: the cover swings up and away off that page,
                    // the same way it does inside the binder.
                    let angle = -100 * opened
                    Group {
                        LeafCastShadow(angle: angle)
                        PageLeaf(
                            angle: angle,
                            front: PulledCoverFace(container: container, snapshot: snapshot),
                            back: PageSheetBackground(),
                            fadesAfterEdgeOn: true
                        )
                    }
                    .frame(width: stage.width, height: stage.height)
                } else {
                    let spineWidth = snapshot?.spineSize.width ?? source.width * stage.height / max(source.height, 1)
                    BookTurnView(angle: 90 * travel, spineWidth: spineWidth, coverWidth: stage.width, height: stage.height) {
                        if let spine = snapshot?.spine {
                            spine.resizable()
                        } else {
                            BinderSpineView(name: container.name, color: container.coverColor, style: container.cover)
                        }
                    } cover: {
                        PulledCoverFace(container: container, snapshot: snapshot)
                    }
                }
            }
            .frame(width: spreadWidth ?? stage.width, height: stage.height, alignment: .trailing)
        } else {
            Group {
                // Only the lid needs the live, layered artwork.
                if let face = snapshot?.face, opened == 0 {
                    face.resizable()
                } else {
                    ContainerArtwork(kind: container.kind, color: container.coverColor, style: container.cover, lidLift: opened)
                }
            }
            .frame(width: stage.width, height: stage.height)
        }
    }
}

#if DEBUG
/// Frozen frames of a pulled binder opening its cover onto its first page.
#Preview("Opening frames") {
    let fixture = StoragePreviewFixture.shared
    let binder = fixture.binder
    let stage = CGRect(origin: .zero, size: CGSize(width: 150, height: 150 / BinderPageView.aspectRatio(for: binder.binderLayout)))
    VStack(spacing: 20) {
        ForEach([0.0, 0.45, 0.8, 1.0], id: \.self) { opened in
            PulledObject(
                container: binder,
                source: CGRect(x: 0, y: 0, width: 34, height: 168),
                stage: stage,
                snapshot: nil,
                travel: 1,
                opened: opened
            )
        }
        .frame(maxWidth: .infinity)
    }
    .environment(fixture.storageManager)
    .environment(fixture.collectionManager)
    .padding()
    .background(LorcanaBackground())
}
#endif
