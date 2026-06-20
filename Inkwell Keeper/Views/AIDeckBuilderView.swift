//
//  AIDeckBuilderView.swift
//  Inkwell Keeper
//
//  AI-powered deck creation and completion interface
//

import SwiftUI

// MARK: - AI Deck Builder View (Create New Deck)
struct AIDeckBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var deckManager: DeckManager
    @EnvironmentObject var collectionManager: CollectionManager
    @State private var aiService = AIDeckService.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var deckName = ""
    @State private var deckDescription = ""
    @State private var selectedFormat: DeckFormat = .casual
    @State private var selectedColors: Set<InkColor> = []
    @State private var selectedArchetype: DeckArchetype? = nil
    @State private var userPrompt = ""
    @State private var useCollectionOnly = false
    @State private var hasGenerated = false
    @State private var showingApplyConfirm = false
    @State private var showingAddCard = false
    @State private var suggestionToReplace: AIDeckSuggestion?
    @State private var generationTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ZStack {
                LorcanaBackground()

                if !subscriptionManager.isSubscribed {
                    RulesPaywallView()
                } else if aiService.availability != .available && !aiService.isLoading && aiService.rawResponse.isEmpty {
                    unavailableContent
                } else if hasGenerated {
                    resultsContent
                } else {
                    inputContent
                }
            }
            .navigationTitle("AI Deck Builder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        cancelGeneration()
                        dismiss()
                    }
                    .foregroundStyle(.lorcanaGold)
                }
            }
        }
        .sensoryFeedback(.success, trigger: aiService.isLoading) { wasLoading, isLoading in
            wasLoading && !isLoading && aiService.matchedCount > 0
        }
        .sheet(item: $suggestionToReplace) { suggestion in
            CardSelectionView(mode: .replace(suggestion), aiService: aiService, collectionOnly: useCollectionOnly, collectionManager: collectionManager)
        }
        .sheet(isPresented: $showingAddCard) {
            CardSelectionView(mode: .add, aiService: aiService, collectionOnly: useCollectionOnly, collectionManager: collectionManager)
        }
        .onAppear {
            subscriptionManager.checkSubscriptionStatus()
        }
    }

    // MARK: - Input Content
    private var inputContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 50))
                        .foregroundStyle(.lorcanaGold)

                    Text("AI Deck Builder")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text("Describe the deck you want and AI will build it for you")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                // Deck Settings
                VStack(alignment: .leading, spacing: 16) {
                    // Deck Name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Deck Name")
                            .font(.caption)
                            .foregroundStyle(.lorcanaGold)
                        TextField("My AI Deck", text: $deckName)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.lorcanaDark.opacity(0.8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.lorcanaGold.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .foregroundStyle(.white)
                    }

                    // Format
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Format")
                            .font(.caption)
                            .foregroundStyle(.lorcanaGold)

                        Picker("Format", selection: $selectedFormat) {
                            ForEach(DeckFormat.allCases.filter { $0 != .tripleDeck }, id: \.self) { format in
                                Text(format.rawValue).tag(format)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedFormat) { _, newFormat in
                            // Trim any colors beyond the new format's limit
                            while selectedColors.count > newFormat.maxInkColors {
                                if let extra = selectedColors.first {
                                    selectedColors.remove(extra)
                                }
                            }
                        }
                    }

                    // Ink Colors
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Ink Colors")
                                .font(.caption)
                                .foregroundStyle(.lorcanaGold)

                            Spacer()

                            Text("optional - max \(selectedFormat.maxInkColors)")
                                .font(.caption2)
                                .foregroundStyle(.gray)
                        }

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(InkColor.allCases, id: \.self) { color in
                                Button(action: {
                                    if selectedColors.contains(color) {
                                        selectedColors.remove(color)
                                    } else if selectedColors.count < selectedFormat.maxInkColors {
                                        selectedColors.insert(color)
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(color.color)
                                            .frame(width: 14, height: 14)
                                        Text(color.rawValue)
                                            .font(.caption)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedColors.contains(color) ? color.color.opacity(0.25) : Color.lorcanaDark.opacity(0.6))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(selectedColors.contains(color) ? color.color : Color.clear, lineWidth: 1.5)
                                            )
                                    )
                                    .foregroundStyle(.white)
                                }
                            }
                        }
                    }

                    // Archetype
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Archetype")
                                .font(.caption)
                                .foregroundStyle(.lorcanaGold)

                            Spacer()

                            Text("optional")
                                .font(.caption2)
                                .foregroundStyle(.gray)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(DeckArchetype.allCases, id: \.self) { archetype in
                                    Button(action: {
                                        selectedArchetype = selectedArchetype == archetype ? nil : archetype
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: archetype.systemImage)
                                                .font(.caption)
                                            Text(archetype.rawValue)
                                                .font(.caption)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(selectedArchetype == archetype ? Color.lorcanaGold.opacity(0.25) : Color.lorcanaDark.opacity(0.6))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(selectedArchetype == archetype ? Color.lorcanaGold : Color.clear, lineWidth: 1.5)
                                                )
                                        )
                                        .foregroundStyle(selectedArchetype == archetype ? .lorcanaGold : .white)
                                    }
                                }
                            }
                        }
                    }

                    // Card Source
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Card Source")
                            .font(.caption)
                            .foregroundStyle(.lorcanaGold)

                        HStack {
                            Button(action: { useCollectionOnly = false }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.grid.2x2")
                                        .font(.caption)
                                    Text("All Cards")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(!useCollectionOnly ? Color.lorcanaGold.opacity(0.25) : Color.lorcanaDark.opacity(0.6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(!useCollectionOnly ? Color.lorcanaGold : Color.clear, lineWidth: 1.5)
                                        )
                                )
                                .foregroundStyle(!useCollectionOnly ? .lorcanaGold : .white)
                            }

                            Button(action: { useCollectionOnly = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "person.crop.rectangle.stack")
                                        .font(.caption)
                                    Text("My Collection")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(useCollectionOnly ? Color.lorcanaGold.opacity(0.25) : Color.lorcanaDark.opacity(0.6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(useCollectionOnly ? Color.lorcanaGold : Color.clear, lineWidth: 1.5)
                                        )
                                )
                                .foregroundStyle(useCollectionOnly ? .lorcanaGold : .white)
                            }
                        }

                        if useCollectionOnly {
                            Text("\(collectionManager.collectedCards.count) cards in your collection")
                                .font(.caption2)
                                .foregroundStyle(.gray)
                        }
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Describe your deck")
                            .font(.caption)
                            .foregroundStyle(.lorcanaGold)

                        TextField("e.g., A fast aggro deck focused on questing with low-cost characters...", text: $userPrompt, axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(3...6)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.lorcanaDark.opacity(0.8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.lorcanaGold.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal)

                // Suggestions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Ideas")
                        .font(.caption)
                        .foregroundStyle(.lorcanaGold)
                        .padding(.horizontal)

                    ForEach(quickIdeas, id: \.self) { idea in
                        Button(action: { userPrompt = idea }) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .font(.caption)
                                    .foregroundStyle(.lorcanaGold)
                                Text(idea)
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.gray)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.lorcanaDark.opacity(0.6))
                            )
                        }
                        .padding(.horizontal)
                    }
                }

                // Generate Button
                Button(action: generate) {
                    HStack {
                        if aiService.isLoading {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Image(systemName: "sparkles")
                            Text("Generate Deck")
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(canGenerate ? Color.lorcanaGold : Color.gray.opacity(0.4))
                    )
                    .foregroundStyle(canGenerate ? .black : .gray)
                }
                .disabled(!canGenerate)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Results Content
    private var resultsContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Streaming indicator
                if aiService.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.lorcanaGold)
                            .scaleEffect(1.2)

                        Text("Building your deck...")
                            .font(.headline)
                            .foregroundStyle(.white)

                        if !aiService.currentStreamingContent.isEmpty {
                            markdownText(aiService.currentStreamingContent)
                                .font(.body)
                                .foregroundStyle(.white)
                                .tint(.lorcanaGold)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.lorcanaDark.opacity(0.8))
                                )
                        }

                        Button("Cancel", role: .cancel, action: cancelGeneration)
                            .buttonStyle(.bordered)
                            .tint(.lorcanaGold)
                            .padding(.top, 4)
                    }
                    .padding()
                } else {
                    // Strategy overview
                    if !aiService.strategyText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Strategy", systemImage: "lightbulb.fill")
                                .font(.headline)
                                .foregroundStyle(.lorcanaGold)

                            ScrollView {
                                markdownText(aiService.strategyText)
                                    .font(.body)
                                    .foregroundStyle(.white)
                                    .tint(.lorcanaGold)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 200)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.lorcanaDark.opacity(0.8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.lorcanaGold.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal)
                    }

                    // Stats bar
                    HStack(spacing: 16) {
                        StatPill(label: "Cards", value: "\(aiService.totalSuggestedCards)")
                        StatPill(label: "Matched", value: "\(aiService.matchedCount)", color: .green)
                        if aiService.unmatchedCount > 0 {
                            StatPill(label: "Unmatched", value: "\(aiService.unmatchedCount)", color: .orange)
                        }
                    }
                    .padding(.horizontal)

                    // Card list
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Deck List")
                            .font(.headline)
                            .foregroundStyle(.lorcanaGold)
                            .padding(.horizontal)

                        ForEach(aiService.suggestions) { suggestion in
                            AISuggestionRow(suggestion: suggestion, onReplace: {
                                suggestionToReplace = suggestion
                            }, onDelete: {
                                aiService.removeSuggestion(id: suggestion.id)
                            })
                        }

                        // Add Card button
                        Button(action: { showingAddCard = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.subheadline)
                                Text("Add Card")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(.lorcanaGold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.lorcanaGold.opacity(0.4), lineWidth: 1)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.lorcanaDark.opacity(0.4))
                                    )
                            )
                            .padding(.horizontal)
                        }
                    }

                    // Color constraint note
                    if let note = aiService.colorConstraintNote {
                        HStack(spacing: 8) {
                            Image(systemName: "paintpalette.fill")
                                .foregroundStyle(.blue)
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.blue.opacity(0.1))
                        )
                        .padding(.horizontal)
                    }

                    // Warning for unmatched cards
                    if aiService.unmatchedCount > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("\(aiService.unmatchedCount) cards could not be matched. Tap a card to replace it.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.orange.opacity(0.1))
                        )
                        .padding(.horizontal)
                    }

                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: { showingApplyConfirm = true }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Create Deck")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(aiService.matchedCount > 0 ? Color.lorcanaGold : Color.gray.opacity(0.4))
                            )
                            .foregroundStyle(aiService.matchedCount > 0 ? .black : .gray)
                        }
                        .disabled(aiService.matchedCount == 0)

                        Button(action: {
                            hasGenerated = false
                            aiService.reset()
                        }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Start Over")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.lorcanaGold)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .padding(.top)
        }
        .alert("Create Deck?", isPresented: $showingApplyConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Create") {
                applyAndCreate()
            }
        } message: {
            Text("This will create \"\(deckName.isEmpty ? "AI Deck" : deckName)\" with \(aiService.matchedCount) matched cards (\(aiService.suggestions.filter { $0.matchedCard != nil }.reduce(0) { $0 + $1.quantity }) total).")
        }
    }

    // MARK: - Unavailable Content
    private var unavailableContent: some View {
        VStack(spacing: 24) {
            Image(systemName: aiService.availability.systemImage)
                .font(.system(size: 70))
                .foregroundStyle(.gray)

            VStack(spacing: 8) {
                Text("AI Deck Builder Unavailable")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text(aiService.availability.description)
                    .font(.body)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button(action: { aiService.checkAvailability() }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.headline)
                .foregroundStyle(.black)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.lorcanaGold)
                )
            }
        }
    }

    // MARK: - Helpers
    private var canGenerate: Bool {
        !userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !aiService.isLoading
    }

    private func generate() {
        hasGenerated = true
        Analytics.send(.aiDeckGenerated(
            ink: selectedColors.map(\.rawValue).sorted().joined(separator: "/")
        ))
        let ownedQuantities = useCollectionOnly ? collectionManager.collectedCardQuantities : [:]
        generationTask = Task {
            await aiService.generateDeck(
                description: userPrompt,
                format: selectedFormat,
                inkColors: Array(selectedColors),
                archetype: selectedArchetype,
                collectionOnly: useCollectionOnly,
                ownedCardQuantities: ownedQuantities
            )
        }
    }

    private func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        aiService.reset()
        hasGenerated = false
    }

    private func applyAndCreate() {
        let name = deckName.isEmpty ? "AI Deck" : deckName
        let deck = deckManager.createDeck(
            name: name,
            description: deckDescription.isEmpty ? userPrompt : deckDescription,
            format: selectedFormat,
            inkColors: Array(selectedColors),
            archetype: selectedArchetype
        )
        aiService.applySuggestions(to: deck, deckManager: deckManager)
        deckManager.updateDeckColorsFromCards(deck)
        aiService.reset()
        dismiss()
    }

    private let quickIdeas = [
        "A fast aggro deck that wins by questing with low-cost characters",
        "A control deck that removes threats and wins late game",
        "A deck built around the Shift mechanic with strong midrange characters",
        "A ramp deck that plays expensive powerful cards earlier than usual"
    ]
}

// MARK: - AI Deck Completer View (Complete Existing Deck)
struct AIDeckCompleterView: View {
    let deck: Deck
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var deckManager: DeckManager
    @EnvironmentObject var collectionManager: CollectionManager
    @State private var aiService = AIDeckService.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var additionalNotes = ""
    @State private var useCollectionOnly = false
    @State private var hasGenerated = false
    @State private var showingApplyConfirm = false
    @State private var showingAddCard = false
    @State private var suggestionToReplace: AIDeckSuggestion?

    var body: some View {
        NavigationStack {
            ZStack {
                LorcanaBackground()

                if !subscriptionManager.isSubscribed {
                    RulesPaywallView()
                } else if aiService.availability != .available && !aiService.isLoading && aiService.rawResponse.isEmpty {
                    unavailableContent
                } else if hasGenerated {
                    resultsContent
                } else {
                    inputContent
                }
            }
            .navigationTitle("AI Complete Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        aiService.reset()
                        dismiss()
                    }
                    .foregroundStyle(.lorcanaGold)
                }
            }
        }
        .sheet(item: $suggestionToReplace) { suggestion in
            CardSelectionView(mode: .replace(suggestion), aiService: aiService, collectionOnly: useCollectionOnly, collectionManager: collectionManager)
        }
        .sheet(isPresented: $showingAddCard) {
            CardSelectionView(mode: .add, aiService: aiService, collectionOnly: useCollectionOnly, collectionManager: collectionManager)
        }
        .onAppear {
            subscriptionManager.checkSubscriptionStatus()
        }
    }

    // MARK: - Input Content
    private var inputContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 50))
                        .foregroundStyle(.lorcanaGold)

                    Text("Complete Your Deck")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text("AI will analyze your current cards and suggest additions")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                // Current deck info
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(deck.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(deck.totalCards)/60 cards")
                            .font(.subheadline)
                            .foregroundStyle(deck.totalCards >= 60 ? .green : .orange)
                    }

                    HStack(spacing: 8) {
                        Text(deck.deckFormat.rawValue)
                            .font(.caption)
                            .foregroundStyle(.gray)

                        ForEach(deck.deckInkColors, id: \.self) { color in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 10, height: 10)
                                Text(color.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.white)
                            }
                        }

                        if let archetype = deck.deckArchetype {
                            HStack(spacing: 4) {
                                Image(systemName: archetype.systemImage)
                                    .font(.caption2)
                                Text(archetype.rawValue)
                                    .font(.caption)
                            }
                            .foregroundStyle(.lorcanaGold)
                        }
                    }

                    if deck.totalCards >= 60 {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Your deck already has 60 cards. AI will suggest improvements and swaps instead.")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                    }

                    // Card summary
                    Divider().background(Color.gray.opacity(0.3))

                    let cardsByCost = Dictionary(grouping: deck.cards ?? []) { $0.cost }
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(0..<10) { cost in
                            let count = cardsByCost[cost]?.reduce(0, { $0 + $1.quantity }) ?? 0
                            VStack(spacing: 2) {
                                Text("\(count)")
                                    .font(.system(size: 9))
                                    .foregroundStyle(count > 0 ? .white : .clear)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(count > 0 ? Color.lorcanaGold : Color.gray.opacity(0.2))
                                    .frame(height: max(CGFloat(count) * 4, 2))
                                Text("\(cost)")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.gray)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 60)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.lorcanaDark.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.lorcanaGold.opacity(0.3), lineWidth: 1)
                        )
                )
                .padding(.horizontal)

                // Additional notes
                VStack(alignment: .leading, spacing: 6) {
                    Text("Additional Notes (optional)")
                        .font(.caption)
                        .foregroundStyle(.lorcanaGold)

                    TextField("e.g., I want to focus more on questing, add more removal...", text: $additionalNotes, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(2...4)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.lorcanaDark.opacity(0.8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.lorcanaGold.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .foregroundStyle(.white)
                }
                .padding(.horizontal)

                // Card Source
                VStack(alignment: .leading, spacing: 6) {
                    Text("Card Source")
                        .font(.caption)
                        .foregroundStyle(.lorcanaGold)

                    HStack {
                        Button(action: { useCollectionOnly = false }) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.grid.2x2")
                                    .font(.caption)
                                Text("All Cards")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(!useCollectionOnly ? Color.lorcanaGold.opacity(0.25) : Color.lorcanaDark.opacity(0.6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(!useCollectionOnly ? Color.lorcanaGold : Color.clear, lineWidth: 1.5)
                                    )
                            )
                            .foregroundStyle(!useCollectionOnly ? .lorcanaGold : .white)
                        }

                        Button(action: { useCollectionOnly = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "person.crop.rectangle.stack")
                                    .font(.caption)
                                Text("My Collection")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(useCollectionOnly ? Color.lorcanaGold.opacity(0.25) : Color.lorcanaDark.opacity(0.6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(useCollectionOnly ? Color.lorcanaGold : Color.clear, lineWidth: 1.5)
                                    )
                            )
                            .foregroundStyle(useCollectionOnly ? .lorcanaGold : .white)
                        }
                    }

                    if useCollectionOnly {
                        Text("\(collectionManager.collectedCards.count) cards in your collection")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                }
                .padding(.horizontal)

                // Generate Button
                Button(action: generateCompletion) {
                    HStack {
                        if aiService.isLoading {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Image(systemName: "wand.and.stars")
                            Text(deck.totalCards >= 60 ? "Get Suggestions" : "Complete Deck")
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(!aiService.isLoading ? Color.lorcanaGold : Color.gray.opacity(0.4))
                    )
                    .foregroundStyle(!aiService.isLoading ? .black : .gray)
                }
                .disabled(aiService.isLoading)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Results Content
    private var resultsContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                if aiService.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.lorcanaGold)
                            .scaleEffect(1.2)

                        Text("Analyzing your deck...")
                            .font(.headline)
                            .foregroundStyle(.white)

                        if !aiService.currentStreamingContent.isEmpty {
                            markdownText(aiService.currentStreamingContent)
                                .font(.body)
                                .foregroundStyle(.white)
                                .tint(.lorcanaGold)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.lorcanaDark.opacity(0.8))
                                )
                        }
                    }
                    .padding()
                } else {
                    // Strategy overview
                    if !aiService.strategyText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Analysis", systemImage: "lightbulb.fill")
                                .font(.headline)
                                .foregroundStyle(.lorcanaGold)

                            ScrollView {
                                markdownText(aiService.strategyText)
                                    .font(.body)
                                    .foregroundStyle(.white)
                                    .tint(.lorcanaGold)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 200)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.lorcanaDark.opacity(0.8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.lorcanaGold.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal)
                    }

                    // Stats
                    HStack(spacing: 16) {
                        StatPill(label: "Suggested", value: "\(aiService.totalSuggestedCards)")
                        StatPill(label: "Matched", value: "\(aiService.matchedCount)", color: .green)
                        if aiService.unmatchedCount > 0 {
                            StatPill(label: "Unmatched", value: "\(aiService.unmatchedCount)", color: .orange)
                        }
                    }
                    .padding(.horizontal)

                    // Suggestion list
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Suggested Additions")
                            .font(.headline)
                            .foregroundStyle(.lorcanaGold)
                            .padding(.horizontal)

                        ForEach(aiService.suggestions) { suggestion in
                            AISuggestionRow(suggestion: suggestion, onReplace: {
                                suggestionToReplace = suggestion
                            }, onDelete: {
                                aiService.removeSuggestion(id: suggestion.id)
                            })
                        }

                        // Add Card button
                        Button(action: { showingAddCard = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.subheadline)
                                Text("Add Card")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(.lorcanaGold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.lorcanaGold.opacity(0.4), lineWidth: 1)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.lorcanaDark.opacity(0.4))
                                    )
                            )
                            .padding(.horizontal)
                        }
                    }

                    // Color constraint note
                    if let note = aiService.colorConstraintNote {
                        HStack(spacing: 8) {
                            Image(systemName: "paintpalette.fill")
                                .foregroundStyle(.blue)
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.blue.opacity(0.1))
                        )
                        .padding(.horizontal)
                    }

                    if aiService.unmatchedCount > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("\(aiService.unmatchedCount) cards could not be matched. Tap a card to replace it.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.orange.opacity(0.1))
                        )
                        .padding(.horizontal)
                    }

                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: { showingApplyConfirm = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add to Deck")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(aiService.matchedCount > 0 ? Color.lorcanaGold : Color.gray.opacity(0.4))
                            )
                            .foregroundStyle(aiService.matchedCount > 0 ? .black : .gray)
                        }
                        .disabled(aiService.matchedCount == 0)

                        Button(action: {
                            hasGenerated = false
                            aiService.reset()
                        }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Try Again")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.lorcanaGold)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .padding(.top)
        }
        .alert("Add Cards?", isPresented: $showingApplyConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Add") {
                applyToExistingDeck()
            }
        } message: {
            Text("This will add \(aiService.suggestions.filter { $0.matchedCard != nil }.reduce(0) { $0 + $1.quantity }) cards to \"\(deck.name)\".")
        }
    }

    // MARK: - Unavailable Content
    private var unavailableContent: some View {
        VStack(spacing: 24) {
            Image(systemName: aiService.availability.systemImage)
                .font(.system(size: 70))
                .foregroundStyle(.gray)

            VStack(spacing: 8) {
                Text("AI Unavailable")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text(aiService.availability.description)
                    .font(.body)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button(action: { aiService.checkAvailability() }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.headline)
                .foregroundStyle(.black)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.lorcanaGold)
                )
            }
        }
    }

    // MARK: - Helpers
    private func generateCompletion() {
        hasGenerated = true
        let ownedQuantities = useCollectionOnly ? collectionManager.collectedCardQuantities : [:]
        Task {
            var description = additionalNotes
            if deck.totalCards >= 60 {
                description = "My deck already has 60 cards. Please suggest improvements - which cards to swap out and what to replace them with. " + description
            }
            await aiService.completeDeck(
                existingCards: deck.cards ?? [],
                format: deck.deckFormat,
                inkColors: deck.deckInkColors,
                archetype: deck.deckArchetype,
                targetCount: max(60, deck.totalCards),
                collectionOnly: useCollectionOnly,
                ownedCardQuantities: ownedQuantities
            )
        }
    }

    private func applyToExistingDeck() {
        aiService.applySuggestions(to: deck, deckManager: deckManager)
        deckManager.updateDeckColorsFromCards(deck)
        aiService.reset()
        dismiss()
    }
}

// MARK: - Suggestion Row
struct AISuggestionRow: View {
    let suggestion: AIDeckSuggestion
    var onReplace: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var isMatched: Bool {
        suggestion.matchedCard != nil
    }

    var body: some View {
        Button(action: { onReplace?() }) {
            HStack(spacing: 12) {
                // Card image
                if let card = suggestion.matchedCard {
                    AsyncImage(url: card.bestImageUrl()) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 36, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 36, height: 50)
                        .overlay(
                            Image(systemName: "questionmark")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        )
                }

                // Card info
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(suggestion.quantity)x \(suggestion.cardName)")
                        .font(.subheadline)
                        .foregroundStyle(isMatched ? .white : .gray)
                        .lineLimit(1)

                    if let card = suggestion.matchedCard {
                        HStack(spacing: 6) {
                            if let inkColor = InkColor.fromString(card.inkColor ?? "") {
                                HStack(spacing: 2) {
                                    Circle()
                                        .fill(inkColor.color)
                                        .frame(width: 8, height: 8)
                                    Text(inkColor.rawValue)
                                        .font(.caption2)
                                        .foregroundStyle(.gray)
                                }
                            }

                            Text("Cost \(card.cost)")
                                .font(.caption2)
                                .foregroundStyle(.gray)

                            Text(card.type)
                                .font(.caption2)
                                .foregroundStyle(.gray)
                        }
                    } else {
                        Text("Card not found — tap to replace")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                Spacer()

                // Swap icon
                Image(systemName: "arrow.2.squarepath")
                    .foregroundStyle(.lorcanaGold.opacity(0.6))
                    .font(.caption)

                // Match indicator
                Image(systemName: isMatched ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .foregroundStyle(isMatched ? .green : .orange)
                    .font(.subheadline)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.lorcanaDark.opacity(isMatched ? 0.6 : 0.3))
            )
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                onDelete?()
            } label: {
                Label("Remove", systemImage: "trash")
            }
            Button {
                onReplace?()
            } label: {
                Label("Replace", systemImage: "arrow.2.squarepath")
            }
        }
    }
}

// MARK: - Card Replacement View
/// Unified card-search sheet used for both replacing an unmatched AI suggestion and adding a new card.
/// `mode` controls the header, action button, initial quantity, and commit behavior.
struct CardSelectionView: View {
    enum Mode {
        case replace(AIDeckSuggestion)
        case add
    }

    let mode: Mode
    let aiService: AIDeckService
    var collectionOnly: Bool = false
    var collectionManager: CollectionManager? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var selectedCard: LorcanaCard? = nil
    @State private var quantity: Int = 1

    private let resultLimit = 50

    private var navTitle: String {
        switch mode {
        case .replace: return "Replace Card"
        case .add: return "Add Card"
        }
    }

    private var emptyPrompt: (icon: String, text: String) {
        switch mode {
        case .replace: return ("magnifyingglass", "Search for a card to replace with")
        case .add: return ("plus.circle", "Search for a card to add")
        }
    }

    private var actionLabel: (icon: String, text: String) {
        switch mode {
        case .replace: return ("arrow.2.squarepath", "Replace")
        case .add: return ("plus.circle.fill", "Add")
        }
    }

    private var defaultQuantity: Int {
        switch mode {
        case .replace(let suggestion): return suggestion.quantity
        case .add: return 1
        }
    }

    private func commit(_ card: LorcanaCard) {
        switch mode {
        case .replace(let suggestion):
            aiService.replaceSuggestion(id: suggestion.id, with: card, quantity: quantity)
        case .add:
            aiService.addSuggestion(card: card, quantity: quantity)
        }
        dismiss()
    }

    private var allNormalCards: [LorcanaCard] {
        let cards = SetsDataManager.shared.getAllCards().filter { $0.variant == .normal }
        if collectionOnly, let manager = collectionManager {
            let ownedNames = Set(manager.collectedCards.map { $0.name })
            return cards.filter { ownedNames.contains($0.name) }
        }
        return cards
    }

    private var filteredCards: [LorcanaCard] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        let query = searchText.lowercased()
        return allNormalCards
            .filter { $0.name.lowercased().contains(query) || $0.type.lowercased().contains(query) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LorcanaBackground()

                VStack(spacing: 0) {
                    // "Replacing X" header only applies to replace mode
                    if case .replace(let suggestion) = mode {
                        VStack(spacing: 4) {
                            Text("Replacing")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Text("\(suggestion.quantity)x \(suggestion.cardName)")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.lorcanaDark.opacity(0.8))
                    }

                    SearchBar(text: $searchText)
                        .padding(.horizontal)
                        .padding(.top, 12)

                    if let card = selectedCard {
                        selectionDetail(card)
                    } else {
                        searchResults
                    }
                }
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(.selection, trigger: selectedCard?.id)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.lorcanaGold)
                }
            }
        }
    }

    // MARK: Selected-card confirmation

    private func selectionDetail(_ card: LorcanaCard) -> some View {
        VStack(spacing: 16) {
            Spacer()

            AsyncImage(url: card.bestImageUrl()) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(card.name)
                .font(.headline)
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                if let inkColor = InkColor.fromString(card.inkColor ?? "") {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(inkColor.color)
                            .frame(width: 10, height: 10)
                        Text(inkColor.rawValue)
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                }
                Text("Cost \(card.cost)")
                    .font(.caption)
                    .foregroundStyle(.gray)
                Text(card.type)
                    .font(.caption)
                    .foregroundStyle(.gray)
            }

            // Quantity picker
            HStack(spacing: 16) {
                Text("Quantity:")
                    .font(.subheadline)
                    .foregroundStyle(.white)

                HStack(spacing: 0) {
                    ForEach(1...4, id: \.self) { num in
                        Button(action: { quantity = num }) {
                            Text("\(num)")
                                .font(.headline)
                                .frame(width: 44, height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(quantity == num ? Color.lorcanaGold : Color.lorcanaDark.opacity(0.6))
                                )
                                .foregroundStyle(quantity == num ? .black : .white)
                        }
                        .accessibilityLabel("Quantity \(num)")
                        .accessibilityAddTraits(quantity == num ? .isSelected : [])
                    }
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                Button(action: {
                    selectedCard = nil
                    quantity = 1
                }) {
                    Text("Back")
                        .font(.subheadline)
                        .foregroundStyle(.lorcanaGold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.lorcanaGold, lineWidth: 1)
                        )
                }

                Button(action: { commit(card) }) {
                    HStack {
                        Image(systemName: actionLabel.icon)
                        Text(actionLabel.text)
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.lorcanaGold)
                    )
                    .foregroundStyle(.black)
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }

    // MARK: Search results

    @ViewBuilder
    private var searchResults: some View {
        if filteredCards.isEmpty && !searchText.isEmpty {
            emptyResults(icon: "magnifyingglass", text: "No cards found")
        } else if searchText.isEmpty {
            emptyResults(icon: emptyPrompt.icon, text: emptyPrompt.text)
        } else {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredCards.prefix(resultLimit)) { card in
                        Button(action: {
                            selectedCard = card
                            quantity = defaultQuantity
                        }) {
                            cardResultRow(card)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }

                    if filteredCards.count > resultLimit {
                        Text("Showing first \(resultLimit) of \(filteredCards.count) — refine your search")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private func emptyResults(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(.gray)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.gray)
            Spacer()
        }
    }

    private func cardResultRow(_ card: LorcanaCard) -> some View {
        HStack(spacing: 10) {
            AsyncImage(url: card.bestImageUrl()) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 32, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                Text(card.name)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let inkColor = InkColor.fromString(card.inkColor ?? "") {
                        HStack(spacing: 2) {
                            Circle()
                                .fill(inkColor.color)
                                .frame(width: 8, height: 8)
                            Text(inkColor.rawValue)
                                .font(.caption2)
                                .foregroundStyle(.gray)
                        }
                    }
                    Text("Cost \(card.cost)")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                    Text(card.setName)
                        .font(.caption2)
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.gray)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.lorcanaDark.opacity(0.6))
        )
    }
}

// MARK: - AI Deck Strategy View
struct AIDeckStrategyView: View {
    let deck: Deck
    @Environment(\.dismiss) private var dismiss
    @State private var aiService = AIDeckService.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var hasStarted = false

    var body: some View {
        NavigationStack {
            ZStack {
                LorcanaBackground()

                if !subscriptionManager.isSubscribed {
                    RulesPaywallView()
                } else if aiService.availability != .available && !aiService.isLoading && aiService.rawResponse.isEmpty {
                    unavailableContent
                } else {
                    strategyContent
                }
            }
            .navigationTitle("AI Strategy Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        aiService.reset()
                        dismiss()
                    }
                    .foregroundStyle(.lorcanaGold)
                }
            }
        }
        .onAppear {
            subscriptionManager.checkSubscriptionStatus()
            if !hasStarted {
                hasStarted = true
                Task {
                    await aiService.generateStrategy(for: deck)
                }
            }
        }
    }

    private var strategyContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Deck info header
                VStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 36))
                        .foregroundStyle(.lorcanaGold)

                    Text(deck.name)
                        .font(.headline)
                        .foregroundStyle(.white)

                    HStack(spacing: 8) {
                        Text(deck.deckFormat.rawValue)
                            .font(.caption)
                            .foregroundStyle(.gray)

                        ForEach(deck.deckInkColors, id: \.self) { color in
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 8, height: 8)
                                Text(color.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                        }

                        Text("\(deck.totalCards) cards")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                }
                .padding(.top, 8)

                if aiService.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.lorcanaGold)
                            .scaleEffect(1.2)

                        Text("Analyzing your deck...")
                            .font(.headline)
                            .foregroundStyle(.white)

                        if !aiService.currentStreamingContent.isEmpty {
                            markdownText(aiService.currentStreamingContent)
                                .font(.body)
                                .foregroundStyle(.white)
                                .tint(.lorcanaGold)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.lorcanaDark.opacity(0.8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.lorcanaGold.opacity(0.3), lineWidth: 1)
                                        )
                                )
                                .padding(.horizontal)
                        }
                    }
                    .padding()
                } else if !aiService.rawResponse.isEmpty {
                    markdownText(aiService.rawResponse)
                        .font(.body)
                        .foregroundStyle(.white)
                        .tint(.lorcanaGold)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.lorcanaDark.opacity(0.8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.lorcanaGold.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal)

                    // Regenerate button
                    Button(action: {
                        Task {
                            await aiService.generateStrategy(for: deck)
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Regenerate")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.lorcanaGold)
                    }
                    .padding(.bottom, 20)
                } else if let error = aiService.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title)
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                            .multilineTextAlignment(.center)

                        Button(action: {
                            Task {
                                await aiService.generateStrategy(for: deck)
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Try Again")
                            }
                            .font(.headline)
                            .foregroundStyle(.black)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.lorcanaGold)
                            )
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private var unavailableContent: some View {
        VStack(spacing: 24) {
            Image(systemName: aiService.availability.systemImage)
                .font(.system(size: 70))
                .foregroundStyle(.gray)

            VStack(spacing: 8) {
                Text("AI Unavailable")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text(aiService.availability.description)
                    .font(.body)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button(action: { aiService.checkAvailability() }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.headline)
                .foregroundStyle(.black)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.lorcanaGold)
                )
            }
        }
    }
}

// MARK: - Stat Pill
struct StatPill: View {
    let label: String
    let value: String
    var color: Color = .white

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.lorcanaDark.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.lorcanaGold.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Markdown Helper
private func markdownText(_ string: String) -> Text {
    if let attributed = try? AttributedString(markdown: string, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
        return Text(attributed)
    }
    return Text(string)
}
