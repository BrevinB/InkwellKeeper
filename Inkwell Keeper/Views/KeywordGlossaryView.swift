//
//  KeywordGlossaryView.swift
//  Inkwell Keeper
//
//  Free, offline reference for Lorcana keywords and core concepts. Available to everyone —
//  each entry funnels tricky interaction questions toward the Pro Rules Assistant.
//

import SwiftUI

struct GlossaryEntry: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let definition: String

    init(_ title: String, systemImage: String, definition: String) {
        self.id = title
        self.title = title
        self.systemImage = systemImage
        self.definition = definition
    }
}

enum LorcanaGlossary {
    static let keywords: [GlossaryEntry] = [
        GlossaryEntry("Alert", systemImage: "eye.fill",
                      definition: "This character can challenge Evasive characters as if it had Evasive. Alert doesn't grant Evasive — it doesn't protect this character from being challenged."),
        GlossaryEntry("Bodyguard", systemImage: "shield.fill",
                      definition: "This character may enter play exerted. While a Bodyguard character is exerted, opposing characters must challenge a Bodyguard character if they challenge at all."),
        GlossaryEntry("Boost N", systemImage: "square.stack.3d.up.fill",
                      definition: "Once during your turn, you may pay N ink to put the top card of your deck facedown under this card. Nobody may look at facedown cards underneath, and they're not in play — the card's other abilities say what the stack is for."),
        GlossaryEntry("Challenger +N", systemImage: "bolt.fill",
                      definition: "This character gets +N Strength while challenging. The bonus applies only when it challenges — not when it's being challenged."),
        GlossaryEntry("Evasive", systemImage: "wind",
                      definition: "Only characters with Evasive can challenge this character."),
        GlossaryEntry("Reckless", systemImage: "flame.fill",
                      definition: "This character can't quest, and must challenge each turn if able."),
        GlossaryEntry("Resist +N", systemImage: "shield.lefthalf.filled",
                      definition: "Damage dealt to this character is reduced by N."),
        GlossaryEntry("Rush", systemImage: "hare.fill",
                      definition: "This character can challenge the turn it's played. Rush doesn't allow questing that turn — its ink is still drying for everything else."),
        GlossaryEntry("Shift N", systemImage: "arrow.triangle.2.circlepath",
                      definition: "You may pay N ink to play this character on top of one of your characters with the specified name. The shifted character keeps damage, its ready/exerted state, and can act as if it were the character beneath. Newer sets add variants — classification Shift, Universal, Duo, Combo, Temporary, and Potato Shift — that change what you may shift onto; the card spells out which."),
        GlossaryEntry("Singer N", systemImage: "music.note",
                      definition: "This character counts as costing N for the purpose of singing songs, letting them sing songs of cost N or less."),
        GlossaryEntry("Sing Together N", systemImage: "music.note.list",
                      definition: "You may exert any number of your characters with total cost N or more to sing this song for free."),
        GlossaryEntry("Support", systemImage: "person.2.fill",
                      definition: "Whenever this character quests, you may add its Strength to another chosen character's Strength this turn."),
        GlossaryEntry("Ward", systemImage: "sparkles",
                      definition: "Opponents can't choose this character with effects. Challenges don't \"choose,\" so Ward characters can still be challenged."),
        GlossaryEntry("Vanish", systemImage: "cloud.fog.fill",
                      definition: "When an opponent chooses this character for an action, this character is banished.")
    ]

    static let concepts: [GlossaryEntry] = [
        GlossaryEntry("Inkwell & Inkable", systemImage: "drop.fill",
                      definition: "Once per turn you may put a card with the inkwell symbol facedown into your inkwell. Cards there are ink — exert them to pay costs. They stay facedown for the rest of the game."),
        GlossaryEntry("Drying", systemImage: "hourglass",
                      definition: "The turn a character is played, its ink is drying: it can't quest, challenge, or exert to use abilities until your next turn (unless something like Rush says otherwise)."),
        GlossaryEntry("Quest", systemImage: "diamond.fill",
                      definition: "Exert a dry character to gain lore equal to its Lore value. First player to 20 lore wins."),
        GlossaryEntry("Challenge", systemImage: "figure.fencing",
                      definition: "Exert a dry character to challenge an exerted opposing character (or a location). The two characters deal damage to each other equal to their Strength."),
        GlossaryEntry("Banish", systemImage: "xmark.bin.fill",
                      definition: "A banished card goes to its player's discard pile. Characters are banished when damage on them meets or exceeds their Willpower."),
        GlossaryEntry("Locations", systemImage: "map.fill",
                      definition: "Locations enter play like characters and can gain you lore at the start of your turn. Characters may move to a location by paying its move cost, and locations can be challenged directly.")
    ]
}

struct KeywordGlossaryView: View {
    /// Called with a suggested question when the user wants to go deeper on an entry.
    var onAsk: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                LorcanaBackground()

                List {
                    Section {
                        ForEach(LorcanaGlossary.keywords) { entry in
                            GlossaryRow(entry: entry, isSubscribed: subscriptionManager.isSubscribed) {
                                ask(about: entry)
                            }
                        }
                    } header: {
                        Text("Keywords")
                            .foregroundStyle(.lorcanaGold)
                    }
                    .listRowBackground(Color.lorcanaDark.opacity(0.6))

                    Section {
                        ForEach(LorcanaGlossary.concepts) { entry in
                            GlossaryRow(entry: entry, isSubscribed: subscriptionManager.isSubscribed) {
                                ask(about: entry)
                            }
                        }
                    } header: {
                        Text("Core Concepts")
                            .foregroundStyle(.lorcanaGold)
                    }
                    .listRowBackground(Color.lorcanaDark.opacity(0.6))
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Keyword Glossary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.lorcanaGold)
                }
            }
        }
    }

    private func ask(about entry: GlossaryEntry) {
        dismiss()
        onAsk("How does \(entry.title) interact with other abilities?")
    }
}

/// One expandable glossary entry with an "ask the assistant" funnel at the bottom.
struct GlossaryRow: View {
    let entry: GlossaryEntry
    let isSubscribed: Bool
    let onAsk: () -> Void

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                Text(entry.definition)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))

                Button(action: onAsk) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text("Ask about a specific interaction")
                        if !isSubscribed {
                            ProPill()
                        }
                    }
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.lorcanaGold)
                }
            }
            .padding(.vertical, 4)
        } label: {
            Label {
                Text(entry.title)
                    .foregroundStyle(.white)
            } icon: {
                Image(systemName: entry.systemImage)
                    .foregroundStyle(.lorcanaGold)
            }
        }
        .tint(.lorcanaGold)
    }
}
