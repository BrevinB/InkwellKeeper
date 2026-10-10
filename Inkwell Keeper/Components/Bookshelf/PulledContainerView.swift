//
//  PulledContainerView.swift
//  Inkwell Keeper
//
//  The binder or box that's been taken off the bookcase, drawn above it. It
//  travels from its gap on the shelf to the stage in the middle of the screen,
//  growing as it comes — a binder turning from its spine to its cover on the way,
//  a box opening its lid once it arrives.
//

import SwiftUI

struct PulledContainerView: View, Animatable {
    let container: StorageContainer
    let source: CGRect
    let stage: CGRect
    let snapshot: PullSnapshot?
    /// Set when the binder opens onto a two-page spread; `stage` is its right page.
    let spreadWidth: CGFloat?
    /// The zoom into the container's screen starts from the held object.
    let zoomNamespace: Namespace.ID
    /// 0 on the shelf → 1 at the stage.
    var travel: Double
    /// How open it is at the stage: a box's lid, a binder's cover. 0 closed → 1 open.
    var opened: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(travel, opened) }
        set {
            travel = newValue.first
            opened = newValue.second
        }
    }

    var body: some View {
        // Where the binder or box itself is: travelling from its shelf to the stage.
        let objectCenter = CGPoint(
            x: source.midX + (stage.midX - source.midX) * travel,
            y: source.midY + (stage.midY - source.midY) * travel
        )
        // Laid out once at stage size and only transformed from there, so nothing is
        // redrawn as it travels: on the shelf it's scaled down to the size it stood at.
        let shelfScale = source.height / max(stage.height, 1)
        let scale = shelfScale + (1 - shelfScale) * travel
        // It rises clear of the shelf early in the trip and settles as it arrives:
        // an arc over the same travel, so the whole move is one smooth animation.
        let lift = sin(.pi * min(1, travel * 1.6)) * (1 - travel)
        // On a spread the frame also holds the empty left page, so the frame's centre
        // sits half a page left of the binder (scaled along with everything else).
        let leftPage = (spreadWidth ?? stage.width) - stage.width
        let center = CGPoint(x: objectCenter.x - leftPage / 2 * scale, y: objectCenter.y)

        PulledObject(
            container: container,
            source: source,
            stage: stage,
            snapshot: snapshot,
            spreadWidth: spreadWidth,
            travel: travel,
            opened: opened
        )
            .shadow(color: .black.opacity(0.5), radius: 18, y: 12)
            .matchedTransitionSource(id: container.id, in: zoomNamespace)
            // Lifting: drawn up and out of its gap.
            .scaleEffect(scale * (1 + 0.06 * lift))
            .offset(y: -40 * lift)
            .position(center)
    }
}
