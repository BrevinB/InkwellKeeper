//
//  BinderSettingsSection.swift
//  Inkwell Keeper
//
//  Page size, sheet count, sidedness, and the optional set checklist for a binder.
//

import SwiftUI

struct BinderSettingsSection: View {
    @Binding var draft: ContainerDraft
    /// Cards already in the binder; it can't shrink below this.
    let cardCount: Int
    let isSubscribed: Bool
    let isEditing: Bool
    let onLockedSetBinder: () -> Void

    private var setNames: [String] {
        SetsDataManager.shared.sets.map(\.name)
    }

    var body: some View {
        Section {
            Picker("Pockets per page", selection: $draft.pocketsPerPage) {
                ForEach(BinderLayout.supportedPocketCounts, id: \.self) { count in
                    Text("\(count)").tag(count)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: draft.pocketsPerPage) { _, _ in
                if cardCount == 0 { sizeForChecklist() }
            }

            Stepper(value: $draft.sheetCount, in: draft.minimumSheets(for: cardCount)...max(250, draft.minimumSheets(for: cardCount))) {
                LabeledContent("Sheets", value: "\(draft.sheetCount)")
            }

            Toggle("Double-sided pages", isOn: $draft.isDoubleSided)
                .onChange(of: draft.isDoubleSided) { _, _ in
                    if cardCount == 0 { sizeForChecklist() }
                }
        } header: {
            Text("Pages")
        } footer: {
            if cardCount > 0, draft.sheetCount <= draft.minimumSheets(for: cardCount) {
                Text("^[\(draft.layout.pageCount) page](inflect: true) · \(draft.layout.totalSlots) pockets · the \(cardCount) cards inside need at least this many sheets")
            } else {
                Text("^[\(draft.layout.pageCount) page](inflect: true) · \(draft.layout.totalSlots) pockets")
            }
        }

        Section {
            if cardCount > 0 {
                // Its cards are placed by the current set's numbering (or freely), so the
                // set can only change once the binder is empty.
                LabeledContent("Set checklist", value: draft.linkedSetName ?? String(localized: "None"))
            } else if isSubscribed {
                Picker("Set checklist", selection: setBinding) {
                    Text("None").tag(String?.none)
                    ForEach(setNames, id: \.self) { name in
                        Text(name).tag(Optional(name))
                    }
                }
            } else {
                Button(action: onLockedSetBinder) {
                    HStack {
                        Text("Set checklist")
                            .foregroundStyle(.white)
                        Spacer()
                        ProPill()
                    }
                }
            }
            if draft.linkedSetName != nil {
                Toggle("Master set (normal + foil)", isOn: foilPocketsBinding)
                    .disabled(cardCount > 0)
            }
        } footer: {
            if cardCount > 0 {
                Text("Empty the binder to change its set checklist.")
            } else if draft.hasFoilPockets {
                Text("Each card gets a normal and a foil pocket side by side. Epic, Enchanted and Iconic cards only come as foils, so they get one.")
            } else {
                Text("Give every card in a set its own numbered pocket — a normal or a foil fills it. Only that set's cards can go in, and empty pockets show the cards you're missing.")
            }
        }
    }

    /// Resizes the binder so every pocket of the checklist exists.
    private func sizeForChecklist() {
        guard let name = draft.linkedSetName else { return }
        let checklist = SetChecklistLayout(
            printings: SetChecklistLayout.catalogPrintings(for: name),
            hasFoilPockets: draft.hasFoilPockets
        )
        if checklist.pocketCount > 0 {
            draft.sheetCount = draft.layout.sheetsNeeded(for: checklist.pocketCount)
        }
    }

    private var foilPocketsBinding: Binding<Bool> {
        Binding(
            get: { draft.hasFoilPockets },
            set: { isOn in
                draft.hasFoilPockets = isOn
                sizeForChecklist()
            }
        )
    }

    /// Choosing a set resizes the binder so every card number has a pocket.
    private var setBinding: Binding<String?> {
        Binding(
            get: { draft.linkedSetName },
            set: { name in
                draft.linkedSetName = name
                guard let name else {
                    draft.hasFoilPockets = false
                    return
                }
                sizeForChecklist()
                if draft.name.isEmpty {
                    draft.name = name
                }
            }
        )
    }
}
