//
//  BinderViewModel.swift
//  Inkwell Keeper
//
//  Navigation and arrange-mode state for an open binder. The binder shows either
//  one page at a time (iPhone portrait) or two-page spreads (iPad, landscape);
//  `position` is a page index in the first case and a spread index in the second.
//

import Foundation

@MainActor
@Observable
final class BinderViewModel {
    private(set) var layout: BinderLayout
    private(set) var isTwoUp: Bool
    /// Current page (one-up) or spread (two-up).
    var position: Int = 0

    /// Arrange mode: pockets can be picked up and moved.
    var isEditing = false {
        didSet {
            if !isEditing { pickedUpItemId = nil }
            if isEditing { isSelecting = false }
        }
    }
    /// Select mode: tap cards to choose several, then move them together.
    var isSelecting = false {
        didSet {
            selectedItemIds = []
            if isSelecting { isEditing = false }
        }
    }
    /// Cards chosen in select mode.
    var selectedItemIds: Set<UUID> = []
    /// The card lifted out of its pocket in arrange mode, waiting for a destination.
    var pickedUpItemId: UUID?
    /// A pocket to highlight, e.g. after "Show in binder" from a card's detail.
    var focusedSlot: Int?

    init(layout: BinderLayout, isTwoUp: Bool, focusSlot: Int? = nil) {
        self.layout = layout
        self.isTwoUp = isTwoUp
        if let focusSlot {
            focusedSlot = focusSlot
            position = position(forSlot: focusSlot)
        }
    }

    // MARK: - Positions

    var positionCount: Int {
        isTwoUp ? layout.spreadCount : layout.pageCount
    }

    var canGoForward: Bool { position < positionCount - 1 }
    var canGoBack: Bool { position > 0 }

    /// Pages visible at a position: (left, right) for spreads, (nil, page) one-up.
    func pages(at position: Int) -> (left: Int?, right: Int?) {
        isTwoUp ? layout.pages(inSpread: position) : (nil, position < layout.pageCount ? position : nil)
    }

    func position(forSlot slot: Int) -> Int {
        let page = layout.position(of: slot).page
        return isTwoUp ? layout.spread(containing: page) : page
    }

    /// A page turn asked for by a button or VoiceOver; `PageFlipView` animates it.
    struct TurnRequest: Equatable {
        let id = UUID()
        let forward: Bool
    }

    private(set) var turnRequest: TurnRequest?

    func requestTurn(forward: Bool) {
        guard forward ? canGoForward : canGoBack else { return }
        turnRequest = TurnRequest(forward: forward)
    }

    func show(slot: Int) {
        position = min(max(0, position(forSlot: slot)), positionCount - 1)
    }

    /// e.g. "Page 3 of 40" or "Pages 3–4 of 40".
    var positionLabel: String {
        let visible = pages(at: position)
        let numbers = [visible.left, visible.right].compactMap { $0 }.map { $0 + 1 }
        guard let first = numbers.first else { return "" }
        if numbers.count == 2 {
            return "Pages \(first)–\(numbers[1]) of \(layout.pageCount)"
        }
        return "Page \(first) of \(layout.pageCount)"
    }

    // MARK: - Updates

    /// Switching between one-up and spreads keeps the same page in view.
    func setTwoUp(_ twoUp: Bool) {
        guard twoUp != isTwoUp else { return }
        let visible = pages(at: position)
        let anchorPage = visible.right ?? visible.left ?? 0
        isTwoUp = twoUp
        position = twoUp ? layout.spread(containing: anchorPage) : anchorPage
    }

    func updateLayout(_ newLayout: BinderLayout) {
        guard newLayout != layout else { return }
        layout = newLayout
        position = min(position, positionCount - 1)
    }

    // MARK: - Arrange mode

    enum PocketAction: Equatable {
        case open(UUID)
        case fill(slot: Int)
        case pickUp(UUID)
        case putDown
        case move(UUID, toSlot: Int)
        case toggleSelection(UUID)
        /// Nothing to do (an empty pocket while selecting).
        case none
    }

    /// Decides what a tap on a pocket means, given arrange mode and what's picked up.
    func action(forTapOnSlot slot: Int, occupant: UUID?) -> PocketAction {
        if isSelecting {
            return occupant.map { .toggleSelection($0) } ?? .none
        }
        guard isEditing else {
            return occupant.map { .open($0) } ?? .fill(slot: slot)
        }
        if let pickedUpItemId {
            return occupant == pickedUpItemId ? .putDown : .move(pickedUpItemId, toSlot: slot)
        }
        return occupant.map { .pickUp($0) } ?? .fill(slot: slot)
    }

    func toggleSelection(_ id: UUID) {
        selectedItemIds.formSymmetricDifference([id])
    }
}
