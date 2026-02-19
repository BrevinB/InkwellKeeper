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
    @StateObject private var aiService = AIDeckService.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var deckName = ""
    @State private var deckDescription = ""
    @State private var selectedFormat: DeckFormat = .infinityConstructed
    @State private var selectedColors: Set<InkColor> = []
    @State private var selectedArchetype: DeckArchetype? = nil
    @State private var userPrompt = ""
    @State private var hasGenerated = false
    @State private var showingApplyConfirm = false

    var body: some View {
        NavigationView {
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
                        aiService.reset()
                        dismiss()
                    }
                    .foregroundColor(.lorcanaGold)
                }
            }
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
                        .foregroundColor(.lorcanaGold)

                    Text("AI Deck Builder")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Describe the deck you want and AI will build it for you")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                // Deck Settings
                VStack(alignment: .leading, spacing: 16) {
                    // Deck Name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Deck Name")
                            .font(.caption)
                            .foregroundColor(.lorcanaGold)
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
                            .foregroundColor(.white)
                    }

                    // Format
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Format")
                            .font(.caption)
                            .foregroundColor(.lorcanaGold)

                        Picker("Format", selection: $selectedFormat) {
                            ForEach(DeckFormat.allCases.filter { $0 != .tripleDeck }, id: \.self) { format in
                                Text(format.rawValue).tag(format)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Ink Colors
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Ink Colors")
                                .font(.caption)
                                .foregroundColor(.lorcanaGold)

                            Spacer()

                            Text("optional - max 2")
                                .font(.caption2)
                                .foregroundColor(.gray)
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
                                    } else if selectedColors.count < 2 {
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
                                    .foregroundColor(.white)
                                }
                            }
                        }
                    }

                    // Archetype
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Archetype")
                                .font(.caption)
                                .foregroundColor(.lorcanaGold)

                            Spacer()

                            Text("optional")
                                .font(.caption2)
                                .foregroundColor(.gray)
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
                                        .foregroundColor(selectedArchetype == archetype ? .lorcanaGold : .white)
                                    }
                                }
                            }
                        }
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Describe your deck")
                            .font(.caption)
                            .foregroundColor(.lorcanaGold)

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
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal)

                // Suggestions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Ideas")
                        .font(.caption)
                        .foregroundColor(.lorcanaGold)
                        .padding(.horizontal)

                    ForEach(quickIdeas, id: \.self) { idea in
                        Button(action: { userPrompt = idea }) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .font(.caption)
                                    .foregroundColor(.lorcanaGold)
                                Text(idea)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
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
                    .foregroundColor(canGenerate ? .black : .gray)
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
                            .foregroundColor(.white)

                        if !aiService.currentStreamingContent.isEmpty {
                            markdownText(aiService.currentStreamingContent)
                                .font(.body)
                                .foregroundColor(.white)
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
                            Label("Strategy", systemImage: "lightbulb.fill")
                                .font(.headline)
                                .foregroundColor(.lorcanaGold)

                            markdownText(aiService.strategyText)
                                .font(.body)
                                .foregroundColor(.white)
                                .tint(.lorcanaGold)
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
                            .foregroundColor(.lorcanaGold)
                            .padding(.horizontal)

                        ForEach(aiService.suggestions) { suggestion in
                            AISuggestionRow(suggestion: suggestion)
                        }
                    }

                    // Error for unmatched cards
                    if aiService.unmatchedCount > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("\(aiService.unmatchedCount) cards could not be matched to the card database and will be skipped.")
                                .font(.caption)
                                .foregroundColor(.orange)
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
                            .foregroundColor(aiService.matchedCount > 0 ? .black : .gray)
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
                            .foregroundColor(.lorcanaGold)
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
                .foregroundColor(.gray)

            VStack(spacing: 8) {
                Text("AI Deck Builder Unavailable")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text(aiService.availability.description)
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button(action: { aiService.checkAvailability() }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.headline)
                .foregroundColor(.black)
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
        Task {
            await aiService.generateDeck(
                description: userPrompt,
                format: selectedFormat,
                inkColors: Array(selectedColors),
                archetype: selectedArchetype
            )
        }
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
    @StateObject private var aiService = AIDeckService.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var additionalNotes = ""
    @State private var hasGenerated = false
    @State private var showingApplyConfirm = false

    var body: some View {
        NavigationView {
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
                    .foregroundColor(.lorcanaGold)
                }
            }
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
                        .foregroundColor(.lorcanaGold)

                    Text("Complete Your Deck")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("AI will analyze your current cards and suggest additions")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                // Current deck info
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(deck.name)
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(deck.totalCards)/60 cards")
                            .font(.subheadline)
                            .foregroundColor(deck.totalCards >= 60 ? .green : .orange)
                    }

                    HStack(spacing: 8) {
                        Text(deck.deckFormat.rawValue)
                            .font(.caption)
                            .foregroundColor(.gray)

                        ForEach(deck.deckInkColors, id: \.self) { color in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 10, height: 10)
                                Text(color.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        }

                        if let archetype = deck.deckArchetype {
                            HStack(spacing: 4) {
                                Image(systemName: archetype.systemImage)
                                    .font(.caption2)
                                Text(archetype.rawValue)
                                    .font(.caption)
                            }
                            .foregroundColor(.lorcanaGold)
                        }
                    }

                    if deck.totalCards >= 60 {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Your deck already has 60 cards. AI will suggest improvements and swaps instead.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    // Card summary
                    Divider().background(Color.gray.opacity(0.3))

                    let cardsByCost = Dictionary(grouping: deck.cards) { $0.cost }
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(0..<10) { cost in
                            let count = cardsByCost[cost]?.reduce(0, { $0 + $1.quantity }) ?? 0
                            VStack(spacing: 2) {
                                Text("\(count)")
                                    .font(.system(size: 9))
                                    .foregroundColor(count > 0 ? .white : .clear)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(count > 0 ? Color.lorcanaGold : Color.gray.opacity(0.2))
                                    .frame(height: max(CGFloat(count) * 4, 2))
                                Text("\(cost)")
                                    .font(.system(size: 9))
                                    .foregroundColor(.gray)
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
                        .foregroundColor(.lorcanaGold)

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
                        .foregroundColor(.white)
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
                    .foregroundColor(!aiService.isLoading ? .black : .gray)
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
                            .foregroundColor(.white)

                        if !aiService.currentStreamingContent.isEmpty {
                            markdownText(aiService.currentStreamingContent)
                                .font(.body)
                                .foregroundColor(.white)
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
                                .foregroundColor(.lorcanaGold)

                            markdownText(aiService.strategyText)
                                .font(.body)
                                .foregroundColor(.white)
                                .tint(.lorcanaGold)
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
                            .foregroundColor(.lorcanaGold)
                            .padding(.horizontal)

                        ForEach(aiService.suggestions) { suggestion in
                            AISuggestionRow(suggestion: suggestion)
                        }
                    }

                    if aiService.unmatchedCount > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("\(aiService.unmatchedCount) cards could not be matched and will be skipped.")
                                .font(.caption)
                                .foregroundColor(.orange)
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
                            .foregroundColor(aiService.matchedCount > 0 ? .black : .gray)
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
                            .foregroundColor(.lorcanaGold)
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
                .foregroundColor(.gray)

            VStack(spacing: 8) {
                Text("AI Unavailable")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text(aiService.availability.description)
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button(action: { aiService.checkAvailability() }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.headline)
                .foregroundColor(.black)
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
        Task {
            var description = additionalNotes
            if deck.totalCards >= 60 {
                description = "My deck already has 60 cards. Please suggest improvements - which cards to swap out and what to replace them with. " + description
            }
            await aiService.completeDeck(
                existingCards: deck.cards,
                format: deck.deckFormat,
                inkColors: deck.deckInkColors,
                archetype: deck.deckArchetype,
                targetCount: max(60, deck.totalCards)
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

    var isMatched: Bool {
        suggestion.matchedCard != nil
    }

    var body: some View {
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
                            .foregroundColor(.gray)
                    )
            }

            // Card info
            VStack(alignment: .leading, spacing: 3) {
                Text("\(suggestion.quantity)x \(suggestion.cardName)")
                    .font(.subheadline)
                    .foregroundColor(isMatched ? .white : .gray)
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
                                    .foregroundColor(.gray)
                            }
                        }

                        Text("Cost \(card.cost)")
                            .font(.caption2)
                            .foregroundColor(.gray)

                        Text(card.type)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                } else {
                    Text("Card not found in database")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            // Match indicator
            Image(systemName: isMatched ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundColor(isMatched ? .green : .orange)
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
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
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
