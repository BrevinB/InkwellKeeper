//
//  ContainerEditorSheet.swift
//  Inkwell Keeper
//
//  Create or edit a binder, trove, box or bin. The object at the top is a live
//  preview that restyles itself as you pick a kind, color and finish.
//

import SwiftUI
import SwiftData

struct ContainerEditorSheet: View {
    /// Nil to create a new container.
    let container: StorageContainer?
    /// Told about a newly created container, so the caller can open it once this
    /// sheet has gone (the shelves do; Put Away just lists it).
    var onCreated: ((StorageContainer) -> Void)?

    @Environment(StorageManager.self) private var storageManager
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Deck.name) private var decks: [Deck]

    @State private var draft = ContainerDraft()
    @State private var showingPaywall = false
    @State private var paywallSource = "storageTheme"
    @FocusState private var nameFocused: Bool

    private let subscriptionManager = SubscriptionManager.shared

    private var isSubscribed: Bool { subscriptionManager.isSubscribed }

    /// Cards already inside the container being edited (0 when creating).
    private var cardCount: Int { container?.cardCount ?? 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ContainerPreview(draft: draft)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }

                Section("Name") {
                    TextField(draft.kind.displayName, text: $draft.name)
                        .focused($nameFocused)
                        .submitLabel(.done)
                }

                if container == nil {
                    Section("Kind") {
                        StorageKindPicker(selection: $draft.kind)
                    }
                }

                Section("Look") {
                    CoverColorPicker(selection: $draft.color)
                    CoverStylePicker(selection: $draft.style, isSubscribed: isSubscribed) {
                        paywallSource = "storageTheme"
                        showingPaywall = true
                    }
                }

                if draft.kind.usesSlots {
                    BinderSettingsSection(
                        draft: $draft,
                        cardCount: cardCount,
                        isSubscribed: isSubscribed,
                        isEditing: container != nil,
                        onLockedSetBinder: {
                            paywallSource = "storageSetBinder"
                            showingPaywall = true
                        }
                    )
                } else {
                    Section {
                        Toggle("Track capacity", isOn: $draft.tracksCapacity.animation())
                        if draft.tracksCapacity {
                            Stepper(
                                value: $draft.capacity,
                                in: max(10, cardCount)...max(5000, cardCount),
                                step: draft.capacity >= 200 ? 100 : 10
                            ) {
                                LabeledContent("Holds", value: "\(draft.capacity) cards")
                            }
                        }
                    } header: {
                        Text("Capacity")
                    } footer: {
                        if draft.tracksCapacity, cardCount > 0, draft.capacity <= cardCount {
                            Text("It already holds \(cardCount) cards, so it can't be made smaller. Take cards out first.")
                        }
                    }

                    if draft.kind == .deckBox, !decks.isEmpty {
                        Section {
                            Picker("Holds deck", selection: $draft.linkedDeckId) {
                                Text("None").tag(UUID?.none)
                                // A deck lives in one box at a time.
                                ForEach(decks.filter { storageManager.deckBox(for: $0.id) == nil || $0.id == container?.linkedDeckId }) { deck in
                                    Text(deck.name).tag(Optional(deck.id))
                                }
                            }
                        } footer: {
                            Text("See which cards from the deck are still missing from this box.")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(LorcanaBackground())
            .navigationTitle(container == nil ? "New \(draft.kind.displayName)" : "Edit \(draft.kind.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(container == nil ? "Create" : "Save", action: save)
                        .bold()
                }
            }
            .sheet(isPresented: $showingPaywall) {
                RulesPaywallView(source: paywallSource)
            }
            .onAppear {
                if let container {
                    draft = ContainerDraft(container: container)
                }
            }
            .onChange(of: draft) { _, _ in
                // Never let an edit leave less room than the cards already inside.
                draft.keepRoom(for: cardCount)
            }
            .sensoryFeedback(.selection, trigger: draft.kind)
            .sensoryFeedback(.selection, trigger: draft.color)
        }
        .tint(.lorcanaGold)
    }

    private func save() {
        if let container {
            draft.apply(to: container)
            storageManager.containerDidChange(container)
        } else {
            let created = storageManager.createContainer(name: draft.name, kind: draft.kind) { newContainer in
                draft.apply(to: newContainer)
            }
            if let created { onCreated?(created) }
        }
        dismiss()
    }
}
