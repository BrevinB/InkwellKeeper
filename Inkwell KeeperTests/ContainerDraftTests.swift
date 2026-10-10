//
//  ContainerDraftTests.swift
//  Inkwell KeeperTests
//
//  Editing a container must never leave less room than the cards already inside.
//

import Testing
@testable import Inkwell_Keeper

struct ContainerDraftTests {
    @Test func shrinkingPocketsAddsSheetsToKeepEveryCard() {
        var draft = ContainerDraft()
        draft.kind = .binder
        draft.pocketsPerPage = 4
        draft.sheetCount = 2 // 16 pockets
        draft.isDoubleSided = true

        draft.keepRoom(for: 30)

        #expect(draft.layout.totalSlots >= 30)
        #expect(draft.sheetCount == 4)
    }

    @Test func roomyBindersAreLeftAlone() {
        var draft = ContainerDraft()
        draft.kind = .binder
        draft.sheetCount = 20

        draft.keepRoom(for: 10)

        #expect(draft.sheetCount == 20)
    }

    @Test func boxCapacityCannotDropBelowItsContents() {
        var draft = ContainerDraft()
        draft.kind = .storageBox
        draft.tracksCapacity = true
        draft.capacity = 50

        draft.keepRoom(for: 72)

        #expect(draft.capacity == 72)
    }

    @Test func untrackedCapacityIsNotForcedOn() {
        var draft = ContainerDraft()
        draft.kind = .trove
        draft.tracksCapacity = false
        draft.capacity = 10

        draft.keepRoom(for: 72)

        #expect(draft.capacity == 10)
    }

    @Test func minimumSheetsCoversTheCards() {
        var draft = ContainerDraft()
        draft.pocketsPerPage = 9
        draft.isDoubleSided = true
        #expect(draft.minimumSheets(for: 0) == 1)
        #expect(draft.minimumSheets(for: 19) == 2)
    }
}
