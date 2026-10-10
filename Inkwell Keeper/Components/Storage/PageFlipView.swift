//
//  PageFlipView.swift
//  Inkwell Keeper
//
//  Turns binder pages. Drag the page toward the spine to turn it — it follows your
//  finger and finishes or falls back depending on how far and fast you swiped — or
//  use the page buttons. With Reduce Motion on, pages cross-fade instead.
//
//  Two-up (spreads): the leaf is the right-hand page. Turning forward, its front is
//  the current right page and its back is the next spread's left page, while the
//  next right page is revealed beneath. Turning back runs the same leaf in reverse.
//  One-up: the leaf is the whole page, turning away to reveal the next.
//

import SwiftUI

struct PageFlipView<Page: View, SheetBack: View, Cover: View>: View {
    let model: BinderViewModel
    /// Aspect ratio (width ÷ height) of a single page.
    let pageAspectRatio: CGFloat
    /// Swipe-to-turn is off in arrange mode so pockets can be dragged.
    let allowsSwipe: Bool
    /// Renders a page; nil is the inside of the cover.
    @ViewBuilder let page: (Int?) -> Page
    /// The bare back of a sheet, shown on the turning page in one-up mode.
    @ViewBuilder let sheetBack: () -> SheetBack
    /// While non-nil, the closed front cover lies on top at this angle; the binder
    /// animates it from 0 to −180 to open itself.
    let coverAngle: Double?
    @ViewBuilder let cover: () -> Cover

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flip: Flip?
    @State private var width: CGFloat = 1

    private struct Flip: Equatable {
        var forward: Bool
        var angle: Double
    }

    private var leafWidth: CGFloat {
        model.isTwoUp ? width / 2 : width
    }

    var body: some View {
        let visible = visiblePages

        ZStack(alignment: .trailing) {
            if model.isTwoUp {
                HStack(spacing: 0) {
                    page(visible.baseLeft)
                    page(visible.baseRight)
                }
                .overlay { SpineShadow() }
                .id(reduceMotion ? model.position : 0)
                .transition(.opacity)
            } else {
                page(visible.baseRight)
                    .id(reduceMotion ? model.position : 0)
                    .transition(.opacity)
            }

            if let flip {
                LeafCastShadow(angle: flip.angle)
                    .frame(width: leafWidth)
                PageLeaf(
                    angle: flip.angle,
                    front: page(visible.leafFront),
                    back: backFace(visible.leafBack),
                    fadesAfterEdgeOn: !model.isTwoUp
                )
                .frame(width: leafWidth)
                .allowsHitTesting(false)
            }

            if let coverAngle {
                LeafCastShadow(angle: coverAngle)
                    .frame(width: leafWidth)
                PageLeaf(angle: coverAngle, front: cover(), back: backFace(nil), fadesAfterEdgeOn: !model.isTwoUp)
                    .frame(width: leafWidth)
            }
        }
        .aspectRatio(pageAspectRatio * (model.isTwoUp ? 2 : 1), contentMode: .fit)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = max(1, $0) }
        .contentShape(.rect)
        .gesture(swipe, isEnabled: allowsSwipe && !reduceMotion)
        .gesture(quickSwipe, isEnabled: allowsSwipe && reduceMotion)
        .onChange(of: model.turnRequest) { _, request in
            if let request { turn(forward: request.forward) }
        }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: model.position)
    }

    @ViewBuilder
    private func backFace(_ index: Int?) -> some View {
        if model.isTwoUp {
            page(index)
        } else {
            sheetBack()
        }
    }

    // MARK: - What's where during a turn

    private struct VisiblePages {
        var baseLeft: Int?
        var baseRight: Int?
        var leafFront: Int?
        var leafBack: Int?
    }

    private var visiblePages: VisiblePages {
        let position = model.position
        let current = model.pages(at: position)
        guard let flip else {
            return VisiblePages(baseLeft: current.left, baseRight: current.right)
        }
        if flip.forward {
            let next = model.pages(at: position + 1)
            return VisiblePages(baseLeft: current.left, baseRight: next.right, leafFront: current.right, leafBack: next.left)
        }
        let previous = model.pages(at: position - 1)
        return VisiblePages(baseLeft: previous.left, baseRight: current.right, leafFront: previous.right, leafBack: current.left)
    }

    // MARK: - Turning

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { value in
                let progress = value.translation.width / leafWidth
                if flip == nil {
                    if progress < 0, model.canGoForward {
                        flip = Flip(forward: true, angle: 0)
                    } else if progress > 0, model.canGoBack {
                        flip = Flip(forward: false, angle: -180)
                    } else {
                        return
                    }
                }
                guard var current = flip else { return }
                current.angle = current.forward
                    ? min(0, max(-1, progress)) * 180
                    : -180 + min(1, max(0, progress)) * 180
                flip = current
            }
            .onEnded { value in
                guard let current = flip else { return }
                let predicted = value.predictedEndTranslation.width / leafWidth
                let completes = current.forward ? predicted < -0.45 : predicted > 0.45
                finish(current, completes: completes)
            }
    }

    /// With Reduce Motion, a swipe simply cross-fades to the next page.
    private var quickSwipe: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                if value.translation.width < -40 {
                    turn(forward: true)
                } else if value.translation.width > 40 {
                    turn(forward: false)
                }
            }
    }

    /// Turns one page forward or back, as the page buttons and VoiceOver do.
    private func turn(forward: Bool) {
        guard flip == nil, forward ? model.canGoForward : model.canGoBack else { return }
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.2)) {
                model.position += forward ? 1 : -1
            }
            return
        }
        let start = Flip(forward: forward, angle: forward ? 0 : -180)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { flip = start }
        finish(start, completes: true)
    }

    private func finish(_ current: Flip, completes: Bool) {
        let target: Double = current.forward == completes ? -180 : 0
        withAnimation(.spring(duration: 0.5, bounce: 0.05)) {
            flip = Flip(forward: current.forward, angle: target)
        } completion: {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                if completes {
                    model.position += current.forward ? 1 : -1
                }
                flip = nil
            }
        }
    }
}
