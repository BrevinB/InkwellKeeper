//
//  DecksView.swift
//  Inkwell Keeper
//
//  Main deck list view
//

import SwiftUI
import SwiftData

struct DecksView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var collectionManager: CollectionManager
    @StateObject private var deckManager = DeckManager()
    @State private var showingStarterDecks = false
    @State private var showingAIDeckBuilder = false
    @State private var showingImportDeck = false
    @State private var showingCreateDeck = false
    @State private var newlyCreatedDeck: Deck?
    @State private var path: [Deck] = []

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                LorcanaBackground()

                if deckManager.decks.isEmpty {
                    EmptyDecksView(onCreateDeck: { showingCreateDeck = true })
                        .environmentObject(deckManager)
                        .environmentObject(collectionManager)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(deckManager.decks) { deck in
                                DeckRow(deck: deck)
                                    .environmentObject(collectionManager)
                                    .environmentObject(deckManager)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Decks")
            .navigationDestination(for: Deck.self) { deck in
                DeckWorkspaceView(deck: deck)
                    .environmentObject(collectionManager)
                    .environmentObject(deckManager)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingStarterDecks = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.stack.3d.down.right")
                            Text("Starter")
                        }
                        .font(.caption)
                        .foregroundStyle(.lorcanaGold)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: { showingImportDeck = true }) {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundStyle(.lorcanaGold)
                        }
                        .accessibilityLabel("Import deck")

                        Button(action: { showingAIDeckBuilder = true }) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.lorcanaGold)
                        }
                        .accessibilityLabel("AI deck builder")

                        Button(action: { showingCreateDeck = true }) {
                            Image(systemName: "plus")
                                .foregroundStyle(.lorcanaGold)
                        }
                        .accessibilityLabel("Create deck")
                    }
                }
            }
        }
        .onAppear {
            deckManager.loadDecks(context: modelContext)
        }
        .sheet(isPresented: $showingStarterDecks) {
            StarterDecksView()
                .environmentObject(deckManager)
                .environmentObject(collectionManager)
        }
        .sheet(isPresented: $showingAIDeckBuilder) {
            AIDeckBuilderView()
                .environmentObject(deckManager)
        }
        .sheet(isPresented: $showingImportDeck) {
            ImportDeckView()
                .environmentObject(deckManager)
        }
        .sheet(isPresented: $showingCreateDeck, onDismiss: pushCreatedDeck) {
            NewDeckSheet(onCreated: { newlyCreatedDeck = $0 })
                .environmentObject(deckManager)
        }
    }

    /// After the create sheet dismisses, push into the new deck's workspace (already filtered to chosen inks).
    private func pushCreatedDeck() {
        guard let deck = newlyCreatedDeck else { return }
        newlyCreatedDeck = nil
        path.append(deck)
    }
}

// MARK: - Empty State
struct EmptyDecksView: View {
    let onCreateDeck: () -> Void
    @State private var showingStarterDecks = false
    @State private var showingAIDeckBuilder = false
    @EnvironmentObject var deckManager: DeckManager
    @EnvironmentObject var collectionManager: CollectionManager

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 72))
                .foregroundStyle(.lorcanaGold.opacity(0.5))

            VStack(spacing: 8) {
                Text("Build Your First Deck")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text("Create competitive decks and track\nwhich cards you need to complete them")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button(action: onCreateDeck) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create Deck")
                    }
                    .font(.headline)
                    .foregroundStyle(.lorcanaDark)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.lorcanaGold)
                    .clipShape(.rect(cornerRadius: 10))
                }

                Button(action: { showingAIDeckBuilder = true }) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("AI Deck Builder")
                    }
                    .font(.headline)
                    .foregroundStyle(.lorcanaDark)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color.lorcanaGold, Color.lorcanaGold.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(.rect(cornerRadius: 10))
                }

                Button(action: { showingStarterDecks = true }) {
                    HStack {
                        Image(systemName: "square.stack.3d.down.right.fill")
                        Text("Import Starter Deck")
                    }
                    .font(.headline)
                    .foregroundStyle(.lorcanaGold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.lorcanaGold, lineWidth: 2)
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .sheet(isPresented: $showingStarterDecks) {
            StarterDecksView()
                .environmentObject(deckManager)
                .environmentObject(collectionManager)
        }
        .sheet(isPresented: $showingAIDeckBuilder) {
            AIDeckBuilderView()
                .environmentObject(deckManager)
        }
    }
}

// MARK: - Deck Row
struct DeckRow: View {
    let deck: Deck
    @EnvironmentObject var collectionManager: CollectionManager
    @EnvironmentObject var deckManager: DeckManager

    var statistics: DeckStatistics {
        deckManager.calculateStatistics(for: deck, collectionManager: collectionManager)
    }

    var validation: DeckValidation {
        deckManager.validateDeck(deck)
    }

    var body: some View {
        NavigationLink(value: deck) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(deck.name)
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text(deck.deckFormat.rawValue)
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }

                    Spacer()

                    // Validation indicator
                    if !validation.isValid {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .accessibilityLabel("Invalid deck")
                    } else if !validation.warnings.isEmpty {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.yellow)
                            .accessibilityLabel("Deck has warnings")
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .accessibilityLabel("Valid deck")
                    }
                }

                // Ink colors
                if !deck.deckInkColors.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(deck.deckInkColors, id: \.self) { color in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 12, height: 12)
                                Text(color.rawValue)
                                    .font(.caption2)
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(color.color.opacity(0.2))
                            )
                        }

                        if let archetype = deck.deckArchetype {
                            HStack(spacing: 4) {
                                Image(systemName: archetype.systemImage)
                                    .font(.caption2)
                                Text(archetype.rawValue)
                                    .font(.caption2)
                            }
                            .foregroundStyle(.lorcanaGold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.lorcanaGold.opacity(0.2))
                            )
                        }
                    }
                }

                Divider()
                    .background(Color.gray.opacity(0.3))

                // Statistics
                HStack(spacing: 20) {
                    // Card count
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cards")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                        Text("\(statistics.totalCards)")
                            .font(.headline)
                            .foregroundStyle(statistics.totalCards >= 60 ? .white : .orange)
                    }

                    // Completion
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Complete")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                        Text("\(Int(statistics.completionPercentage))%")
                            .font(.headline)
                            .foregroundStyle(statistics.completionPercentage == 100 ? .green : .lorcanaGold)
                    }

                    // Missing cards
                    if statistics.missingCards > 0 {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Missing")
                                .font(.caption2)
                                .foregroundStyle(.gray)
                            Text("\(statistics.missingCards)")
                                .font(.headline)
                                .foregroundStyle(.orange)
                        }
                    }

                    Spacer()

                    // Cost to complete
                    if statistics.costToComplete > 0 {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Cost")
                                .font(.caption2)
                                .foregroundStyle(.gray)
                            Text(PricingService.formatPrice(statistics.costToComplete))
                                .font(.headline)
                                .foregroundStyle(.lorcanaGold)
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.lorcanaDark.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                validation.isValid ? Color.lorcanaGold.opacity(0.3) : Color.orange.opacity(0.5),
                                lineWidth: validation.isValid ? 1 : 2
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Edit Deck View
struct EditDeckView: View {
    let deck: Deck
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var deckManager: DeckManager

    @State private var deckName: String
    @State private var deckDescription: String
    @State private var selectedFormat: DeckFormat
    @State private var selectedColors: Set<InkColor>
    @State private var selectedArchetype: DeckArchetype?

    init(deck: Deck) {
        self.deck = deck
        _deckName = State(initialValue: deck.name)
        _deckDescription = State(initialValue: deck.deckDescription)
        _selectedFormat = State(initialValue: deck.deckFormat)
        _selectedColors = State(initialValue: Set(deck.deckInkColors))
        _selectedArchetype = State(initialValue: deck.deckArchetype)
    }

    var canSave: Bool {
        !deckName.isEmpty && selectedColors.count <= selectedFormat.maxInkColors
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Basic Info")) {
                    TextField("Deck Name", text: $deckName)
                    TextField("Description (optional)", text: $deckDescription)
                }

                Section(header: Text("Format")) {
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(DeckFormat.allCases, id: \.self) { format in
                            VStack(alignment: .leading) {
                                Text(format.rawValue)
                                Text(format.description)
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                            .tag(format)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedFormat) { _, newFormat in
                        while selectedColors.count > newFormat.maxInkColors {
                            if let extra = selectedColors.first {
                                selectedColors.remove(extra)
                            }
                        }
                    }

                    Text("Min \(selectedFormat.minimumCards) cards, max \(selectedFormat.maxInkColors) ink colors")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }

                Section(header: Text("Ink Colors (max \(selectedFormat.maxInkColors))"),
                        footer: Text("Optional — auto-detected from the cards you add.")) {
                    ForEach(InkColor.allCases, id: \.self) { color in
                        Button {
                            if selectedColors.contains(color) {
                                selectedColors.remove(color)
                            } else if selectedColors.count < selectedFormat.maxInkColors {
                                selectedColors.insert(color)
                            }
                        } label: {
                            HStack {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 20, height: 20)

                                Text(color.rawValue)
                                    .foregroundStyle(.white)

                                Spacer()

                                if selectedColors.contains(color) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.lorcanaGold)
                                }
                            }
                        }
                    }
                }

                Section(header: Text("Archetype (optional)")) {
                    Picker("Archetype", selection: $selectedArchetype) {
                        Text("None").tag(nil as DeckArchetype?)
                        ForEach(DeckArchetype.allCases, id: \.self) { archetype in
                            HStack {
                                Image(systemName: archetype.systemImage)
                                Text(archetype.rawValue)
                            }
                            .tag(archetype as DeckArchetype?)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("Edit Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveDeck() }
                        .disabled(!canSave)
                        .foregroundStyle(canSave ? Color.lorcanaGold : .gray)
                }
            }
        }
    }

    private func saveDeck() {
        deck.name = deckName
        deck.deckDescription = deckDescription
        deck.deckFormat = selectedFormat
        deck.deckInkColors = Array(selectedColors)
        deck.deckArchetype = selectedArchetype
        deck.lastModified = Date()
        dismiss()
    }
}


// MARK: - Deck Overview (deck stats + card list; shown in the workspace slide-up)
struct DeckOverview: View {
    let deck: Deck
    @EnvironmentObject var collectionManager: CollectionManager
    @EnvironmentObject var deckManager: DeckManager

    var statistics: DeckStatistics {
        deckManager.calculateStatistics(for: deck, collectionManager: collectionManager)
    }

    var validation: DeckValidation {
        deckManager.validateDeck(deck)
    }

    var missingCards: [(card: DeckCard, needed: Int)] {
        deckManager.getMissingCards(for: deck, collectionManager: collectionManager)
    }

    var cardsByCost: [(cost: Int, cards: [DeckCard])] {
        let grouped = Dictionary(grouping: deck.cards ?? []) { $0.cost }
        return grouped.map { (cost: $0.key, cards: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.cost < $1.cost }
    }

    var body: some View {
        ScrollView {
            if (deck.cards ?? []).isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.largeTitle)
                        .foregroundStyle(.lorcanaGold.opacity(0.6))
                    Text("No cards yet")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Add cards from the browser to start building.")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                .padding()
            } else {
                VStack(spacing: 16) {
                    DeckStatisticsCard(statistics: statistics, validation: validation, deck: deck)

                    if !validation.errors.isEmpty || !validation.warnings.isEmpty {
                        ValidationCard(validation: validation)
                    }

                    if !missingCards.isEmpty {
                        MissingCardsCard(
                            missingCards: missingCards,
                            costToComplete: statistics.costToComplete
                        )
                    }

                    CostCurveCard(costDistribution: statistics.costDistribution)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Cards (\(statistics.totalCards))")
                            .font(.headline)
                            .foregroundStyle(.lorcanaGold)
                            .padding(.horizontal)

                        ForEach(cardsByCost, id: \.cost) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Cost \(section.cost)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.gray)

                                    Text("(\(section.cards.reduce(0) { $0 + $1.quantity }) cards)")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                                .padding(.horizontal)

                                ForEach(section.cards, id: \.cardId) { card in
                                    DeckCardRow(
                                        card: card,
                                        deck: deck,
                                        ownedQuantity: {
                                            let byId = collectionManager.getCollectedQuantity(for: card.cardId)
                                            if byId > 0 {
                                                return byId
                                            }
                                            return collectionManager.getCollectedQuantityByName(
                                                card.name,
                                                setName: card.setName,
                                                variant: card.cardVariant
                                            )
                                        }()
                                    )
                                    .environmentObject(deckManager)
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
                .padding()
            }
        }
        .background(LorcanaBackground())
    }
}

// MARK: - Deck Summary Bar (live progress shown atop the workspace)
struct DeckSummaryBar: View {
    let count: Int
    let inkColors: [InkColor]
    let costDistribution: [Int: Int]
    let isValid: Bool
    let hasCards: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text("\(count)/60")
                    .font(.headline)
                    .bold()
                    .foregroundStyle(count >= 60 ? .green : .lorcanaGold)

                if !inkColors.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(inkColors, id: \.self) { ink in
                            Circle()
                                .fill(ink.color)
                                .frame(width: 10, height: 10)
                        }
                    }
                }

                if hasCards {
                    CurveSparkline(costDistribution: costDistribution)
                }

                Spacer()

                if hasCards {
                    Image(systemName: isValid ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(isValid ? .green : .orange)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color.lorcanaDark.opacity(0.85))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(count) of 60 cards. Tap to view deck.")
    }
}

// MARK: - Cost Curve Sparkline
struct CurveSparkline: View {
    let costDistribution: [Int: Int]

    private var maxCount: Int {
        max(costDistribution.values.max() ?? 1, 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<8, id: \.self) { cost in
                let value = costDistribution[cost] ?? 0
                Capsule()
                    .fill(value > 0 ? Color.lorcanaGold : Color.gray.opacity(0.3))
                    .frame(width: 3, height: max(CGFloat(value) / CGFloat(maxCount) * 18, 2))
            }
        }
        .frame(height: 18)
    }
}

// MARK: - Statistics Card
struct DeckStatisticsCard: View {
    let statistics: DeckStatistics
    let validation: DeckValidation
    let deck: Deck

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(deck.deckFormat.rawValue)
                        .font(.caption)
                        .foregroundStyle(.gray)

                    HStack(spacing: 6) {
                        ForEach(deck.deckInkColors, id: \.self) { color in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 10, height: 10)
                                Text(color.rawValue)
                                    .font(.caption2)
                            }
                        }
                    }
                    .foregroundStyle(.white)
                }

                Spacer()

                if validation.isValid {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Valid")
                    }
                    .font(.caption)
                    .foregroundStyle(.green)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Invalid")
                    }
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }

            Divider()

            // Stats Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatItem(label: "Cards", value: "\(statistics.totalCards)", color: statistics.totalCards >= 60 ? .white : .orange)
                StatItem(label: "Unique", value: "\(statistics.uniqueCards)", color: .white)
                StatItem(label: "Avg Cost", value: String(format: "%.1f", statistics.averageCost), color: .white)
                StatItem(label: "Inkable", value: "\(Int(statistics.inkableRatio * 100))%", color: statistics.inkableRatio >= 0.3 ? .white : .orange)
                StatItem(label: "Complete", value: "\(Int(statistics.completionPercentage))%", color: statistics.completionPercentage == 100 ? .green : .lorcanaGold)
                StatItem(label: "Value", value: PricingService.formatPrice(statistics.totalValue), color: .lorcanaGold)
            }
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
    }
}

struct StatItem: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.gray)
        }
    }
}

// MARK: - Validation Card
struct ValidationCard: View {
    let validation: DeckValidation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !validation.errors.isEmpty {
                Label("Errors", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.red)

                ForEach(validation.errors, id: \.self) { error in
                    Text("• \(error)")
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.9))
                }
            }

            if !validation.warnings.isEmpty {
                if !validation.errors.isEmpty {
                    Divider()
                }

                Label("Warnings", systemImage: "exclamationmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)

                ForEach(validation.warnings, id: \.self) { warning in
                    Text("• \(warning)")
                        .font(.caption)
                        .foregroundStyle(.orange.opacity(0.9))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange, lineWidth: 1)
                )
        )
    }
}

// MARK: - Missing Cards Card
struct MissingCardsCard: View {
    let missingCards: [(card: DeckCard, needed: Int)]
    let costToComplete: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Missing Cards", systemImage: "cart")
                    .font(.headline)
                    .foregroundStyle(.lorcanaGold)

                Spacer()

                Text(PricingService.formatPrice(costToComplete))
                    .font(.headline)
                    .foregroundStyle(.lorcanaGold)
            }

            ForEach(Array(missingCards.prefix(5)), id: \.card.cardId) { item in
                HStack {
                    Text("\(item.needed)x \(item.card.name)")
                        .font(.caption)
                        .foregroundStyle(.white)

                    Spacer()

                    if let price = item.card.price {
                        Text(PricingService.formatPrice(price * Double(item.needed)))
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                }
            }

            if missingCards.count > 5 {
                Text("+ \(missingCards.count - 5) more cards")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
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
    }
}

// MARK: - Cost Curve Card
struct CostCurveCard: View {
    let costDistribution: [Int: Int]

    var maxCount: Int {
        costDistribution.values.max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cost Curve")
                .font(.headline)
                .foregroundStyle(.lorcanaGold)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<10) { cost in
                    let count = costDistribution[cost] ?? 0
                    let height = maxCount > 0 ? CGFloat(count) / CGFloat(maxCount) * 80 : 0

                    VStack(spacing: 4) {
                        Text("\(count)")
                            .font(.caption2)
                            .foregroundStyle(count > 0 ? .white : .clear)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(count > 0 ? Color.lorcanaGold : Color.gray.opacity(0.3))
                            .frame(height: max(height, 4))

                        Text("\(cost)")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                }
            }
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
    }
}

// MARK: - Deck Card Row
struct DeckCardRow: View {
    let card: DeckCard
    let deck: Deck
    let ownedQuantity: Int
    @EnvironmentObject var deckManager: DeckManager
    @State private var showingDetail = false

    var isComplete: Bool {
        ownedQuantity >= card.quantity
    }

    private var atMax: Bool { card.quantity >= deck.deckFormat.maxCopiesPerCard }

    private func addOne() {
        guard !atMax else { return }
        deckManager.updateCardQuantity(card, in: deck, quantity: card.quantity + 1)
    }

    private func removeOne() {
        if card.quantity <= 1 {
            deckManager.removeCard(card, from: deck)
        } else {
            deckManager.updateCardQuantity(card, in: deck, quantity: card.quantity - 1)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Tap the image/info to open the full card detail
            Button(action: { showingDetail = true }) {
                HStack(spacing: 12) {
                    AsyncImage(url: card.bestImageUrl()) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 40, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.name)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            RarityBadge(rarity: card.cardRarity)

                            if let inkColor = card.cardInkColor {
                                HStack(spacing: 2) {
                                    Circle()
                                        .fill(inkColor.color)
                                        .frame(width: 8, height: 8)
                                    Text(inkColor.rawValue)
                                        .font(.caption2)
                                        .foregroundStyle(.gray)
                                }
                            }

                            if card.inkwell {
                                Image(systemName: "drop.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            }
                        }

                        HStack(spacing: 6) {
                            Image(systemName: isComplete ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(isComplete ? .green : .orange)
                            Text("\(ownedQuantity)/\(card.quantity) owned")
                                .font(.caption2)
                                .foregroundStyle(isComplete ? .green : .orange)

                            if let price = card.price {
                                Text("· \(PricingService.formatPrice(price))")
                                    .font(.caption2)
                                    .foregroundStyle(.gray)
                            }
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Inline quantity stepper
            HStack(spacing: 12) {
                Button(action: removeOne) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                }
                .accessibilityLabel("Remove one \(card.name)")

                Text("\(card.quantity)")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(.white)
                    .frame(minWidth: 18)

                Button(action: addOne) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(atMax ? .gray : .green)
                }
                .disabled(atMax)
                .accessibilityLabel("Add one \(card.name)")
            }
            .font(.title3)
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.lorcanaDark.opacity(0.6))
        )
        .sensoryFeedback(.impact, trigger: card.quantity)
        .sheet(isPresented: $showingDetail) {
            DeckCardDetailView(card: card, deck: deck, ownedQuantity: ownedQuantity)
                .environmentObject(deckManager)
        }
    }
}

// MARK: - Deck Card Detail
struct DeckCardDetailView: View {
    let card: DeckCard
    let deck: Deck
    let ownedQuantity: Int
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var deckManager: DeckManager
    @State private var showingRemoveConfirm = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                AsyncImage(url: card.bestImageUrl()) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(maxWidth: 300)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(spacing: 12) {
                    HStack {
                        Text("Quantity:")
                            .foregroundStyle(.gray)
                        Spacer()
                        HStack(spacing: 12) {
                            Button(action: {
                                deckManager.updateCardQuantity(card, in: deck, quantity: card.quantity - 1)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .accessibilityLabel("Decrease quantity")

                            Text("\(card.quantity)")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(width: 40)

                            Button(action: {
                                deckManager.updateCardQuantity(card, in: deck, quantity: card.quantity + 1)
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.green)
                            }
                            .disabled(card.quantity >= deck.deckFormat.maxCopiesPerCard)
                            .accessibilityLabel("Increase quantity")
                        }
                    }

                    HStack {
                        Text("You own:")
                            .foregroundStyle(.gray)
                        Spacer()
                        Text("\(ownedQuantity)")
                            .foregroundStyle(ownedQuantity >= card.quantity ? .green : .orange)
                    }

                    if ownedQuantity < card.quantity {
                        HStack {
                            Text("Need:")
                                .foregroundStyle(.gray)
                            Spacer()
                            Text("\(card.quantity - ownedQuantity) more")
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.lorcanaDark.opacity(0.8))
                )

                Button(role: .destructive, action: {
                    showingRemoveConfirm = true
                }) {
                    Label("Remove from Deck", systemImage: "trash")
                        .foregroundStyle(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .clipShape(.rect(cornerRadius: 10))
                }

                Spacer()
            }
            .padding()
            .background(LorcanaBackground())
            .navigationTitle(card.name)
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(.selection, trigger: card.quantity)
            .confirmationDialog(
                "Remove \(card.name) from this deck?",
                isPresented: $showingRemoveConfirm,
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    deckManager.removeCard(card, from: deck)
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Export Deck View
struct ExportDeckView: View {
    let deckText: String
    let deckName: String
    @Environment(\.dismiss) private var dismiss
    @State private var didCopy = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                ScrollView {
                    Text(deckText)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.lorcanaDark.opacity(0.8))
                        )
                }

                Button(action: {
                    UIPasteboard.general.string = deckText
                    withAnimation { didCopy = true }
                }) {
                    Label(didCopy ? "Copied!" : "Copy to Clipboard",
                          systemImage: didCopy ? "checkmark" : "doc.on.clipboard")
                        .foregroundStyle(.lorcanaDark)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.lorcanaGold)
                        .clipShape(.rect(cornerRadius: 10))
                }
                .sensoryFeedback(.success, trigger: didCopy)
            }
            .padding()
            .background(LorcanaBackground())
            .navigationTitle("Export Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}


// MARK: - New Deck Sheet (pick inks first; the workspace browser then filters to them)
struct NewDeckSheet: View {
    var onCreated: (Deck) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var deckManager: DeckManager

    @State private var name = ""
    @State private var format: DeckFormat = .casual
    @State private var colors: Set<InkColor> = []

    private var maxInks: Int { format.maxInkColors }

    var body: some View {
        NavigationStack {
            ZStack {
                LorcanaBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DECK NAME")
                                .font(.caption)
                                .foregroundStyle(.lorcanaGold)
                            TextField("New Deck", text: $name)
                                .textFieldStyle(.plain)
                                .foregroundStyle(.white)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.lorcanaDark.opacity(0.8))
                                )
                        }

                        // Format
                        VStack(alignment: .leading, spacing: 8) {
                            Text("FORMAT")
                                .font(.caption)
                                .foregroundStyle(.lorcanaGold)
                            Picker("Format", selection: $format) {
                                ForEach([DeckFormat.casual, .coreConstructed, .infinityConstructed], id: \.self) { fmt in
                                    Text(fmt.rawValue).tag(fmt)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: format) { _, newFormat in
                                while colors.count > newFormat.maxInkColors {
                                    if let extra = colors.first { colors.remove(extra) }
                                }
                            }
                        }

                        // Ink colors
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("INK COLORS")
                                    .font(.caption)
                                    .foregroundStyle(.lorcanaGold)
                                Spacer()
                                Text("\(colors.count)/\(maxInks)")
                                    .font(.caption2)
                                    .foregroundStyle(.gray)
                            }
                            Text("The card browser will filter to just these colors.")
                                .font(.caption2)
                                .foregroundStyle(.gray)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(InkColor.allCases, id: \.self) { ink in
                                    inkButton(ink)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("New Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.lorcanaGold)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Start Building") { create() }
                        .bold()
                        .foregroundStyle(.lorcanaGold)
                }
            }
        }
    }

    private func inkButton(_ ink: InkColor) -> some View {
        let selected = colors.contains(ink)
        return Button {
            if selected {
                colors.remove(ink)
            } else if colors.count < maxInks {
                colors.insert(ink)
            }
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(ink.color)
                    .frame(width: 24, height: 24)
                Text(ink.rawValue)
                    .foregroundStyle(.white)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.lorcanaGold)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selected ? ink.color.opacity(0.25) : Color.lorcanaDark.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selected ? ink.color : .clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!selected && colors.count >= maxInks)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func create() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let deck = deckManager.createDeck(
            name: trimmed.isEmpty ? "New Deck" : trimmed,
            description: "",
            format: format,
            inkColors: Array(colors).sorted { $0.rawValue < $1.rawValue },
            archetype: nil
        )
        onCreated(deck)
        dismiss()
    }
}

// MARK: - Deck Workspace (unified build + view screen)
enum WorkspaceMode: Hashable {
    case add
    case deck
}

struct DeckWorkspaceView: View {
    let deck: Deck
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject var deckManager: DeckManager
    @EnvironmentObject var collectionManager: CollectionManager

    @State private var mode: WorkspaceMode

    init(deck: Deck) {
        self.deck = deck
        // New/empty decks open on the browser; decks with cards open on the deck view
        _mode = State(initialValue: (deck.cards ?? []).isEmpty ? .add : .deck)
    }

    // Workspace chrome
    @State private var showingExport = false
    @State private var showingDeleteConfirm = false
    @State private var showingEditDeck = false
    @State private var showingAICompleter = false
    @State private var showingAIStrategy = false
    @State private var showingShareSheet = false
    @State private var showingRename = false
    @State private var renameText = ""
    @State private var exportedText = ""
    @State private var shareCode = ""

    private var gridHelper: AdaptiveGridHelper {
        AdaptiveGridHelper(horizontalSizeClass: horizontalSizeClass)
    }

    var statistics: DeckStatistics {
        deckManager.calculateStatistics(for: deck, collectionManager: collectionManager)
    }

    var validation: DeckValidation {
        deckManager.validateDeck(deck)
    }

    private var deckCardCount: Int {
        (deck.cards ?? []).reduce(0) { $0 + $1.quantity }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Live summary bar
            DeckSummaryBar(
                count: deckCardCount,
                inkColors: deck.deckInkColors,
                costDistribution: statistics.costDistribution,
                isValid: validation.isValid,
                hasCards: deckCardCount > 0,
                onTap: { withAnimation { mode = .deck } }
            )

            // Mode toggle: build (browser) vs. view your deck
            Picker("View", selection: $mode.animation()) {
                Text("Add Cards").tag(WorkspaceMode.add)
                Text("Deck (\(deckCardCount))").tag(WorkspaceMode.deck)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.2))

            if mode == .add {
                BuilderBrowser(deck: deck, gridHelper: gridHelper)
                    .environmentObject(deckManager)
                    .environmentObject(collectionManager)
            } else {
                DeckOverview(deck: deck)
                    .environmentObject(deckManager)
                    .environmentObject(collectionManager)
            }
        }
        .background(LorcanaBackground())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button(action: { renameText = deck.name; showingRename = true }) {
                    HStack(spacing: 6) {
                        Text(deck.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundStyle(.lorcanaGold)
                    }
                }
                .accessibilityLabel("Deck name \(deck.name). Tap to rename.")
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingAICompleter = true }) {
                        Label("AI Complete Deck", systemImage: "sparkles")
                    }
                    Button(action: { showingAIStrategy = true }) {
                        Label("AI Strategy Guide", systemImage: "brain.head.profile")
                    }
                    Button(action: { showingEditDeck = true }) {
                        Label("Edit Deck Info", systemImage: "pencil")
                    }
                    Button(action: {
                        exportedText = deckManager.exportDeckList(deck)
                        showingExport = true
                    }) {
                        Label("Export Deck List", systemImage: "square.and.arrow.up")
                    }
                    Button(action: {
                        if let code = deckManager.generateShareCode(for: deck) {
                            shareCode = code
                            showingShareSheet = true
                        }
                    }) {
                        Label("Share Deck", systemImage: "paperplane")
                    }
                    Button(action: {
                        _ = deckManager.duplicateDeck(deck)
                    }) {
                        Label("Duplicate Deck", systemImage: "doc.on.doc")
                    }

                    Divider()

                    Button(role: .destructive, action: { showingDeleteConfirm = true }) {
                        Label("Delete Deck", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.lorcanaGold)
                }
            }
        }
        .onDisappear {
            // Only auto-detect inks when the user didn't choose them at creation
            if deck.deckInkColors.isEmpty {
                deckManager.updateDeckColorsFromCards(deck)
            }
        }
        .sheet(isPresented: $showingAICompleter) {
            AIDeckCompleterView(deck: deck)
                .environmentObject(deckManager)
                .environmentObject(collectionManager)
        }
        .sheet(isPresented: $showingAIStrategy) {
            AIDeckStrategyView(deck: deck)
        }
        .sheet(isPresented: $showingExport) {
            ExportDeckView(deckText: exportedText, deckName: deck.name)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareDeckView(shareCode: shareCode, deckName: deck.name)
        }
        .sheet(isPresented: $showingEditDeck) {
            EditDeckView(deck: deck)
                .environmentObject(deckManager)
        }
        .alert("Rename Deck", isPresented: $showingRename) {
            TextField("Deck name", text: $renameText)
            Button("Save") {
                let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    deck.name = trimmed
                    deck.lastModified = Date()
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Delete Deck?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deckManager.deleteDeck(deck)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete \"\(deck.name)\"? This action cannot be undone.")
        }
    }

}

// MARK: - Builder Browser (search + filters + card grid with inline add)
/// Owns its own search/filter state and the card list so that typing or filtering only re-renders
/// the browser — not the parent workspace, which recomputes deck statistics/validation on each pass.
struct BuilderBrowser: View {
    let deck: Deck
    let gridHelper: AdaptiveGridHelper
    @EnvironmentObject var deckManager: DeckManager
    @EnvironmentObject var collectionManager: CollectionManager
    @StateObject private var dataManager = SetsDataManager.shared

    @State private var searchText = ""
    @State private var showOwnedOnly = false
    @State private var selectedInkColor: InkColor? = nil
    @State private var selectedCost: Int? = nil
    @State private var availableCards: [LorcanaCard] = []

    var filteredCards: [LorcanaCard] {
        var cards = availableCards

        // Filter by deck ink colors FIRST (most restrictive)
        if !deck.deckInkColors.isEmpty {
            let cardsWithInk = cards.filter { $0.inkColor != nil }

            if !cardsWithInk.isEmpty {
                cards = cards.filter { card in
                    guard let cardInk = card.inkColor else {
                        return true
                    }
                    return deck.deckInkColors.contains { deckColor in
                        deckColor.rawValue.lowercased() == cardInk.lowercased()
                    }
                }
            }
        }

        // Filter by search text
        if !searchText.isEmpty {
            cards = cards.filter { card in
                card.name.localizedCaseInsensitiveContains(searchText) ||
                card.type.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Filter by owned/all
        if showOwnedOnly {
            cards = cards.filter { card in
                if collectionManager.isCardCollected(card.id) {
                    return true
                }
                return collectionManager.isCardCollectedByName(
                    card.name,
                    setName: card.setName,
                    variant: card.variant
                )
            }
        }

        // Filter by ink color (manual selection)
        if let inkColor = selectedInkColor {
            cards = cards.filter { card in
                card.inkColor?.lowercased() == inkColor.rawValue.lowercased()
            }
        }

        // Filter by cost
        if let cost = selectedCost {
            cards = cards.filter { $0.cost == cost }
        }

        return cards.sorted { $0.name < $1.name }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.gray)

                TextField("Search cards...", text: $searchText)
                    .foregroundStyle(.white)
                    .autocorrectionDisabled()

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.gray)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding()
            .background(Color.lorcanaDark.opacity(0.6))

            // Owned/All toggle
            HStack {
                Text("Show:")
                    .font(.caption)
                    .foregroundStyle(.gray)

                Button(action: { showOwnedOnly = false }) {
                    Text("All Cards")
                        .font(.subheadline)
                        .fontWeight(showOwnedOnly ? .regular : .bold)
                        .foregroundStyle(showOwnedOnly ? .gray : .lorcanaGold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(showOwnedOnly ? Color.clear : Color.lorcanaGold.opacity(0.2))
                        )
                }
                .accessibilityAddTraits(showOwnedOnly ? [] : .isSelected)

                Button(action: { showOwnedOnly = true }) {
                    Text("Owned Only")
                        .font(.subheadline)
                        .fontWeight(showOwnedOnly ? .bold : .regular)
                        .foregroundStyle(showOwnedOnly ? .lorcanaGold : .gray)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(showOwnedOnly ? Color.lorcanaGold.opacity(0.2) : Color.clear)
                        )
                }
                .accessibilityAddTraits(showOwnedOnly ? .isSelected : [])

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.2))

            // Filters
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    Menu {
                        Button("All Colors") { selectedInkColor = nil }
                        Divider()
                        ForEach(deck.deckInkColors.isEmpty ? InkColor.allCases : deck.deckInkColors, id: \.self) { color in
                            Button(action: {
                                selectedInkColor = (selectedInkColor == color) ? nil : color
                            }) {
                                HStack {
                                    Circle()
                                        .fill(color.color)
                                        .frame(width: 12, height: 12)
                                    Text(color.rawValue)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if let color = selectedInkColor {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 12, height: 12)
                                Text(color.rawValue)
                            } else {
                                Image(systemName: "paintpalette")
                                Text("Color")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedInkColor != nil ? Color.lorcanaGold.opacity(0.2) : Color.lorcanaDark.opacity(0.6))
                        )
                    }

                    Menu {
                        Button("All Costs") { selectedCost = nil }
                        Divider()
                        ForEach(0..<10) { cost in
                            Button("\(cost)") {
                                selectedCost = (selectedCost == cost) ? nil : cost
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "circle.hexagongrid")
                            Text(selectedCost != nil ? "\(selectedCost!)" : "Cost")
                        }
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedCost != nil ? Color.lorcanaGold.opacity(0.2) : Color.lorcanaDark.opacity(0.6))
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(Color.black.opacity(0.3))

            // Results count
            HStack {
                Text("\(filteredCards.count) cards")
                    .font(.caption)
                    .foregroundStyle(.gray)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 4)

            // Cards grid
            if filteredCards.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(.gray)
                    Text("No cards found")
                        .foregroundStyle(.gray)
                    if showOwnedOnly {
                        Text("Try showing all cards")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let deckCardsByCardId = deckCardLookup
                ScrollView {
                    LazyVGrid(columns: gridHelper.deckGridColumns(), spacing: gridHelper.gridSpacing) {
                        ForEach(filteredCards) { card in
                            BuilderCardView(
                                card: card,
                                deck: deck,
                                inDeck: deckCardsByCardId[card.id]
                            )
                            .environmentObject(deckManager)
                        }
                    }
                    .padding(gridHelper.viewPadding)
                }
            }
        }
        .onAppear { loadAllCards() }
        .onChange(of: dataManager.isDataLoaded) { _, isLoaded in
            if isLoaded { loadAllCards() }
        }
    }

    /// cardId → DeckCard, built once per render so each grid cell is an O(1) lookup
    /// instead of an O(deck size) scan.
    private var deckCardLookup: [String: DeckCard] {
        Dictionary((deck.cards ?? []).map { ($0.cardId, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private func loadAllCards() {
        guard dataManager.isDataLoaded else {
            availableCards = []
            return
        }

        var allCards: [LorcanaCard] = []
        for set in dataManager.sets {
            allCards.append(contentsOf: dataManager.getCardsForSet(set.name))
        }

        availableCards = allCards.map { dataManager.getCardWithCachedPrice($0) }
    }
}

// MARK: - Builder Card View
struct BuilderCardView: View {
    let card: LorcanaCard
    let deck: Deck
    let inDeck: DeckCard?
    @EnvironmentObject var deckManager: DeckManager

    var quantityInDeck: Int {
        inDeck?.quantity ?? 0
    }

    private var maxCopies: Int { deck.deckFormat.maxCopiesPerCard }
    private var atMax: Bool { quantityInDeck >= maxCopies }

    private func addOne() {
        guard !atMax else { return }
        deckManager.addCard(card, to: deck, quantity: 1)
    }

    private func removeOne() {
        guard let inDeck else { return }
        if quantityInDeck <= 1 {
            deckManager.removeCard(inDeck, from: deck)
        } else {
            deckManager.updateCardQuantity(inDeck, in: deck, quantity: quantityInDeck - 1)
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            // Tap the image to add one copy
            Button(action: addOne) {
                ZStack {
                    AsyncImage(url: card.bestImageUrl()) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .aspectRatio(0.7, contentMode: .fit)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(quantityInDeck > 0 ? Color.lorcanaGold : card.rarity.color,
                                    lineWidth: quantityInDeck > 0 ? 2 : 1)
                    )

                    // In-deck quantity badge
                    if quantityInDeck > 0 {
                        VStack {
                            HStack {
                                Spacer()
                                ZStack {
                                    Circle()
                                        .fill(Color.lorcanaGold)
                                        .frame(width: 28, height: 28)
                                    Text("\(quantityInDeck)")
                                        .font(.caption)
                                        .bold()
                                        .foregroundStyle(.lorcanaDark)
                                }
                            }
                            Spacer()
                        }
                        .padding(4)
                    }
                }
                .opacity(atMax ? 0.55 : 1.0)
            }
            .buttonStyle(.plain)
            .disabled(atMax)
            .accessibilityLabel(card.name)
            .accessibilityValue(quantityInDeck > 0 ? "\(quantityInDeck) in deck" : "Not in deck")
            .accessibilityHint(atMax ? "At maximum copies" : "Add one copy")

            Text(card.name)
                .font(.caption2)
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            // Inline stepper appears once the card is in the deck
            if quantityInDeck > 0 {
                HStack(spacing: 14) {
                    Button(action: removeOne) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .accessibilityLabel("Remove one \(card.name)")

                    Text("\(quantityInDeck)")
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(.white)
                        .frame(minWidth: 20)

                    Button(action: addOne) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(atMax ? .gray : .green)
                    }
                    .disabled(atMax)
                    .accessibilityLabel("Add one \(card.name)")
                }
                .font(.title3)
            }
        }
        .sensoryFeedback(.impact, trigger: quantityInDeck)
    }
}

// MARK: - Share Deck View
struct ShareDeckView: View {
    let shareCode: String
    let deckName: String
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.lorcanaGold)

                    Text("Share \"\(deckName)\"")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text("Send this code to a friend so they can import your deck into Ink Well Keeper.")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)

                ScrollView {
                    Text(shareCode)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.lorcanaDark.opacity(0.8))
                        )
                }
                .frame(maxHeight: 200)

                VStack(spacing: 12) {
                    Button(action: {
                        UIPasteboard.general.string = shareCode
                        copied = true
                    }) {
                        Label(copied ? "Copied!" : "Copy Code", systemImage: copied ? "checkmark" : "doc.on.clipboard")
                            .foregroundStyle(.lorcanaDark)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.lorcanaGold)
                            .clipShape(.rect(cornerRadius: 10))
                    }

                    ShareLink(item: shareCode) {
                        Label("Share via...", systemImage: "square.and.arrow.up")
                            .foregroundStyle(.lorcanaGold)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.lorcanaGold, lineWidth: 2)
                            )
                    }
                }
            }
            .padding()
            .background(LorcanaBackground())
            .navigationTitle("Share Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Import Deck View
struct ImportDeckView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var deckManager: DeckManager
    @State private var shareCode = ""
    @State private var importError = false
    @State private var importSuccess = false
    @State private var importedDeckName = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.lorcanaGold)

                    Text("Import a Deck")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text("Paste a deck share code from another Ink Well Keeper user to import their deck.")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Deck Code")
                        .font(.caption)
                        .foregroundStyle(.gray)

                    TextEditor(text: $shareCode)
                        .font(.system(.caption2, design: .monospaced))
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.lorcanaDark.opacity(0.8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.lorcanaGold.opacity(0.3), lineWidth: 1)
                                )
                        )
                }

                if let clipboardString = UIPasteboard.general.string, clipboardString.hasPrefix("IWK:") && shareCode.isEmpty {
                    Button(action: {
                        shareCode = clipboardString
                    }) {
                        Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                            .font(.subheadline)
                            .foregroundStyle(.lorcanaGold)
                    }
                }

                Button(action: {
                    if let deck = deckManager.importDeck(from: shareCode) {
                        importedDeckName = deck.name
                        importSuccess = true
                    } else {
                        importError = true
                    }
                }) {
                    Text("Import Deck")
                        .fontWeight(.semibold)
                        .foregroundStyle(.lorcanaDark)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(shareCode.isEmpty ? Color.gray : Color.lorcanaGold)
                        .clipShape(.rect(cornerRadius: 10))
                }
                .disabled(shareCode.isEmpty)

                Spacer()
            }
            .padding()
            .background(LorcanaBackground())
            .navigationTitle("Import Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Import Failed", isPresented: $importError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The deck code is invalid. Make sure you copied the full code starting with \"IWK:\".")
            }
            .alert("Deck Imported!", isPresented: $importSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("\"\(importedDeckName)\" has been added to your decks.")
            }
        }
    }
}
