//
//  AnimatableContainerArtwork.swift
//  Inkwell Keeper
//
//  Container artwork whose lid position animates smoothly.
//

import SwiftUI

/// Lets SwiftUI interpolate the lid, so it glides open instead of snapping.
struct AnimatableContainerArtwork: View, Animatable {
    let container: StorageContainer
    var lidLift: Double

    var animatableData: Double {
        get { lidLift }
        set { lidLift = newValue }
    }

    var body: some View {
        ContainerArtwork(kind: container.kind, color: container.coverColor, style: container.cover, lidLift: lidLift)
    }
}
