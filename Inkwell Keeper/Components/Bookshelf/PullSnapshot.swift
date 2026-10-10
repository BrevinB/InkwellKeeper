//
//  PullSnapshot.swift
//  Inkwell Keeper
//
//  Flat images of a pulled container, rendered once when it leaves the shelf.
//
//  The live artwork is several tinted, masked, blended layers; redrawing that at a
//  new size every frame of the pull is what made it stutter. Instead the faces are
//  rendered at full stage size up front, and the pull only moves, scales and turns
//  these images — work the GPU does for free.
//

import SwiftUI

struct PullSnapshot {
    /// How to render to match what's on screen.
    struct Renderer {
        let scale: CGFloat
        let dynamicTypeSize: DynamicTypeSize
    }

    /// The binder's spine at stage scale (binders only).
    let spine: Image?
    /// The binder's front cover, or the closed box, at stage size.
    let face: Image
    /// The spine's size at stage scale.
    let spineSize: CGSize

    @MainActor
    static func make(for container: StorageContainer, source: CGRect, stage: CGRect, renderer: Renderer) -> Self? {
        if container.kind == .binder {
            let stageScale = stage.height / max(source.height, 1)
            let spineSize = CGSize(width: source.width * stageScale, height: stage.height)
            let spine = render(
                BinderSpineView(name: container.name, color: container.coverColor, style: container.cover),
                size: spineSize,
                renderer: renderer
            )
            let cover = render(ClosedBinderCover(container: container), size: stage.size, renderer: renderer)
            guard let spine, let cover else { return nil }
            return Self(spine: spine, face: cover, spineSize: spineSize)
        }
        let box = render(
            ContainerArtwork(kind: container.kind, color: container.coverColor, style: container.cover),
            size: stage.size,
            renderer: renderer
        )
        return box.map { Self(spine: nil, face: $0, spineSize: .zero) }
    }

    @MainActor
    private static func render(_ view: some View, size: CGSize, renderer: Renderer) -> Image? {
        let content = view
            .frame(width: size.width, height: size.height)
            .environment(\.dynamicTypeSize, renderer.dynamicTypeSize)
        let imageRenderer = ImageRenderer(content: content)
        imageRenderer.scale = renderer.scale
        guard let image = imageRenderer.cgImage else { return nil }
        return Image(decorative: image, scale: renderer.scale)
    }
}

/// The snapshots a pull renders, beside the live artwork they stand in for.
#Preview("Snapshots") {
    let binder: StorageContainer = {
        let binder = StorageContainer(name: "Main Binder", kind: .binder)
        binder.coverColor = .sapphire
        binder.cover = .leather
        return binder
    }()
    let trove: StorageContainer = {
        let trove = StorageContainer(name: "Trove", kind: .trove)
        trove.coverColor = .amber
        return trove
    }()
    let renderer = PullSnapshot.Renderer(scale: 3, dynamicTypeSize: .large)
    let source = CGRect(x: 0, y: 0, width: 34, height: 168)
    let stage = CGRect(x: 0, y: 0, width: 156, height: 200)
    let boxStage = CGRect(x: 0, y: 0, width: 168, height: 140)
    let binderShot = PullSnapshot.make(for: binder, source: source, stage: stage, renderer: renderer)
    let troveShot = PullSnapshot.make(for: trove, source: CGRect(x: 0, y: 0, width: 125, height: 104), stage: boxStage, renderer: renderer)
    VStack(spacing: 20) {
        HStack(alignment: .bottom, spacing: 12) {
            binderShot?.spine?.resizable().frame(width: binderShot?.spineSize.width, height: stage.height)
            binderShot?.face.resizable().frame(width: stage.width, height: stage.height)
            ClosedBinderCover(container: binder).frame(width: stage.width, height: stage.height)
        }
        HStack(spacing: 12) {
            troveShot?.face.resizable().frame(width: boxStage.width, height: boxStage.height)
            ContainerArtwork(kind: .trove, color: .amber, style: .classic).frame(width: boxStage.width, height: boxStage.height)
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(LorcanaBackground())
}
