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
    @State private var showingCreateDeck = false
    @State private var showingStarterDecks = false
    @State private var showingAIDeckBuilder = false

    var body: some View {
        navigationWrapper {
            ZStack {
                LorcanaBackground()

                if deckManager.decks.isEmpty {
                    EmptyDecksView(showingCreateDeck: $showingCreateDeck)
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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingStarterDecks = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.stack.3d.down.right")
                            Text("Starter")
                        }
                        .font(.caption)
                        .foregroundColor(.lorcanaGold)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: { showingAIDeckBuilder = true }) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.lorcanaGold)
                        }

                        Button(action: { showingCreateDeck = true }) {
                            Image(systemName: "plus")
                                .foregroundColor(.lorcanaGold)
                        }
                    }
                }
            }
        }
        .onAppear {
            deckManager.loadDecks(context: modelContext)
        }
        .sheet(isPresented: $showingCreateDeck) {
            CreateDeckView()
                .environmentObject(deckManager)
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
    }

    @ViewBuilder
    private func navigationWrapper<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 18.0, *), UIDevice.current.userInterfaceIdiom == .pad {
            content()
        } else {
            NavigationView {
                content()
            }
        }
    }
}

// MARK: - Empty State
struct EmptyDecksView: View {
    @Binding var showingCreateDeck: Bool
    @State private var showingStarterDecks = false
    @State private var showingAIDeckBuilder = false
    @EnvironmentObject var deckManager: DeckManager
    @EnvironmentObject var collectionManager: CollectionManager

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 72))
                .foregroundColor(.lorcanaGold.opacity(0.5))

            VStack(spacing: 8) {
                Text("Build Your First Deck")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Create competitive decks and track\nwhich cards you need to complete them")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button(action: { showingCreateDeck = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create Deck")
                    }
                    .font(.headline)
                    .foregroundColor(.lorcanaDark)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.lorcanaGold)
                    .cornerRadius(10)
                }

                Button(action: { showingAIDeckBuilder = true }) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("AI Deck Builder")
                    }
                    .font(.headline)
                    .foregroundColor(.lorcanaDark)
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
                    .cornerRadius(10)
                }

                Button(action: { showingStarterDecks = true }) {
                    HStack {
                        Image(systemName: "square.stack.3d.down.right.fill")
                        Text("Import Starter Deck")
                    }
                    .font(.headline)
                    .foregroundColor(.lorcanaGold)
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
    @State private var showingDetail = false

    var statistics: DeckStatistics {
        deckManager.calculateStatistics(for: deck, collectionManager: collectionManager)
    }

    var validation: DeckValidation {
        deckManager.validateDeck(deck)
    }

    var body: some View {
        Button(action: { showingDetail = true }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(deck.name)
                            .font(.headline)
                            .foregroundColor(.white)

                        Text(deck.deckFormat.rawValue)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    // Validation indicator
                    if !validation.isValid {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    } else if !validation.warnings.isEmpty {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.yellow)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
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
                                    .foregroundColor(.white)
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
                            .foregroundColor(.lorcanaGold)
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
                            .foregroundColor(.gray)
                        Text("\(statistics.totalCards)")
                            .font(.headline)
                            .foregroundColor(statistics.totalCards >= 60 ? .white : .orange)
                    }

                    // Completion
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Complete")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text("\(Int(statistics.completionPercentage))%")
                            .font(.headline)
                            .foregroundColor(statistics.completionPercentage == 100 ? .green : .lorcanaGold)
                    }

                    // Missing cards
                    if statistics.missingCards > 0 {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Missing")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Text("\(statistics.missingCards)")
                                .font(.headline)
                                .foregroundColor(.orange)
                        }
                    }

                    Spacer()

                    // Cost to complete
                    if statistics.costToComplete > 0 {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Cost")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Text("$\(statistics.costToComplete, specifier: "%.2f")")
                                .font(.headline)
                                .foregroundColor(.lorcanaGold)
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
        .sheet(isPresented: $showingDetail) {
            DeckDetailView(deck: deck)
                .environmentObject(collectionManager)
                .environmentObject(deckManager)
        }
    }
}

// MARK: - Create Deck View
struct CreateDeckView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var deckManager: DeckManager

    @State private var deckName = ""
    @State private var deckDescription = ""
    @State private var selectedFormat: DeckFormat = .infinityConstructed
    @State private var selectedColors: Set<InkColor> = []
    @State private var selectedArchetype: DeckArchetype? = nil

    var canCreate: Bool {
        !deckName.isEmpty && selectedColors.count <= selectedFormat.maxInkColors
    }

    var body: some View {
        NavigationView {
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
                                    .foregroundColor(.gray)
                            }
                            .tag(format)
                        }
                    }
                    .pickerStyle(.menu)

                    Text("Min \(selectedFormat.minimumCards) cards, max \(selectedFormat.maxInkColors) ink colors")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Section(header: Text("Ink Colors (max \(selectedFormat.maxInkColors))")) {
                    ForEach(InkColor.allCases, id: \.self) { color in
                        Button(action: {
                            if selectedColors.contains(color) {
                                selectedColors.remove(color)
                            } else if selectedColors.count < selectedFormat.maxInkColors {
                                selectedColors.insert(color)
                            }
                        }) {
                            HStack {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 20, height: 20)

                                Text(color.rawValue)
                                    .foregroundColor(.white)

                                Spacer()

                                if selectedColors.contains(color) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.lorcanaGold)
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
            .navigationTitle("Create Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createDeck()
                    }
                    .disabled(!canCreate)
                    .foregroundColor(canCreate ? .lorcanaGold : .gray)
                }
            }
        }
    }

    private func createDeck() {
        _ = deckManager.createDeck(
            name: deckName,
            description: deckDescription,
            format: selectedFormat,
            inkColors: Array(selectedColors),
            archetype: selectedArchetype
        )
        dismiss()
    }
}

// MARK: - Deck Detail View
struct DeckDetailView: View {
    let deck: Deck
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var collectionManager: CollectionManager
    @EnvironmentObject var deckManager: DeckManager

    @State private var showingBuilder = false
    @State private var showingExport = false
    @State private var showingDeleteConfirm = false
    @State private var showingEditDeck = false
    @State private var showingAICompleter = false
    @State private var exportedText = ""

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
        let grouped = Dictionary(grouping: deck.cards) { $0.cost }
        return grouped.map { (cost: $0.key, cards: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.cost < $1.cost }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Statistics Header
                    DeckStatisticsCard(statistics: statistics, validation: validation, deck: deck)

                    // Validation Warnings/Errors
                    if !validation.errors.isEmpty || !validation.warnings.isEmpty {
                        ValidationCard(validation: validation)
                    }

                    // Missing Cards
                    if !missingCards.isEmpty {
                        MissingCardsCard(
                            missingCards: missingCards,
                            costToComplete: statistics.costToComplete
                        )
                    }

                    // Cost Curve
                    CostCurveCard(costDistribution: statistics.costDistribution)

                    // Card List
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Cards (\(statistics.totalCards))")
                            .font(.headline)
                            .foregroundColor(.lorcanaGold)
                            .padding(.horizontal)

                        ForEach(cardsByCost, id: \.cost) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                // Cost header
                                HStack {
                                    Text("Cost \(section.cost)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.gray)

                                    Text("(\(section.cards.reduce(0) { $0 + $1.quantity }) cards)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal)

                                // Cards at this cost
                                ForEach(section.cards, id: \.cardId) { card in
                                    DeckCardRow(
                                        card: card,
                                        deck: deck,
                                        ownedQuantity: {
                                            // Try ID match first
                                            let byId = collectionManager.getCollectedQuantity(for: card.cardId)
                                            if byId > 0 {
                                                return byId
                                            }
                                            // Fallback to name match
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
            .background(LorcanaBackground())
            .navigationTitle(deck.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingBuilder = true }) {
                            Label("Add Cards", systemImage: "plus.circle")
                        }

                        Button(action: { showingAICompleter = true }) {
                            Label("AI Complete Deck", systemImage: "sparkles")
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
                            .foregroundColor(.lorcanaGold)
                    }
                }
            }
        }
        .sheet(isPresented: $showingBuilder) {
            DeckBuilderView(deck: deck)
                .environmentObject(deckManager)
                .environmentObject(collectionManager)
        }
        .sheet(isPresented: $showingAICompleter) {
            AIDeckCompleterView(deck: deck)
                .environmentObject(deckManager)
        }
        .sheet(isPresented: $showingExport) {
            ExportDeckView(deckText: exportedText, deckName: deck.name)
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
                        .foregroundColor(.gray)

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
                    .foregroundColor(.white)
                }

                Spacer()

                if validation.isValid {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Valid")
                    }
                    .font(.caption)
                    .foregroundColor(.green)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Invalid")
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
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
                StatItem(label: "Value", value: "$\(Int(statistics.totalValue))", color: .lorcanaGold)
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
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
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
                    .foregroundColor(.red)

                ForEach(validation.errors, id: \.self) { error in
                    Text("• \(error)")
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.9))
                }
            }

            if !validation.warnings.isEmpty {
                if !validation.errors.isEmpty {
                    Divider()
                }

                Label("Warnings", systemImage: "exclamationmark.circle.fill")
                    .font(.headline)
                    .foregroundColor(.orange)

                ForEach(validation.warnings, id: \.self) { warning in
                    Text("• \(warning)")
                        .font(.caption)
                        .foregroundColor(.orange.opacity(0.9))
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
                    .foregroundColor(.lorcanaGold)

                Spacer()

                Text("$\(costToComplete, specifier: "%.2f")")
                    .font(.headline)
                    .foregroundColor(.lorcanaGold)
            }

            ForEach(Array(missingCards.prefix(5)), id: \.card.cardId) { item in
                HStack {
                    Text("\(item.needed)x \(item.card.name)")
                        .font(.caption)
                        .foregroundColor(.white)

                    Spacer()

                    if let price = item.card.price {
                        Text("$\(price * Double(item.needed), specifier: "%.2f")")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }

            if missingCards.count > 5 {
                Text("+ \(missingCards.count - 5) more cards")
                    .font(.caption)
                    .foregroundColor(.gray)
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
                .foregroundColor(.lorcanaGold)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<10) { cost in
                    let count = costDistribution[cost] ?? 0
                    let height = maxCount > 0 ? CGFloat(count) / CGFloat(maxCount) * 80 : 0

                    VStack(spacing: 4) {
                        Text("\(count)")
                            .font(.caption2)
                            .foregroundColor(count > 0 ? .white : .clear)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(count > 0 ? Color.lorcanaGold : Color.gray.opacity(0.3))
                            .frame(height: max(height, 4))

                        Text("\(cost)")
                            .font(.caption2)
                            .foregroundColor(.gray)
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

    var body: some View {
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
                    Text("\(card.quantity)x \(card.name)")
                        .font(.subheadline)
                        .foregroundColor(.white)

                    HStack(spacing: 6) {
                        RarityBadge(rarity: card.cardRarity)

                        if let inkColor = card.cardInkColor {
                            HStack(spacing: 2) {
                                Circle()
                                    .fill(inkColor.color)
                                    .frame(width: 8, height: 8)
                                Text(inkColor.rawValue)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }

                        if card.inkwell {
                            Image(systemName: "drop.fill")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("\(ownedQuantity)/\(card.quantity)")
                            .font(.caption)
                            .foregroundColor(isComplete ? .green : .orange)
                        Image(systemName: isComplete ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(isComplete ? .green : .orange)
                    }

                    if let price = card.price {
                        Text("$\(price, specifier: "%.2f")")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.lorcanaDark.opacity(0.6))
            )
        }
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

    var body: some View {
        NavigationView {
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
                            .foregroundColor(.gray)
                        Spacer()
                        HStack(spacing: 12) {
                            Button(action: {
                                deckManager.updateCardQuantity(card, in: deck, quantity: card.quantity - 1)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }

                            Text("\(card.quantity)")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(width: 40)

                            Button(action: {
                                deckManager.updateCardQuantity(card, in: deck, quantity: card.quantity + 1)
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.green)
                            }
                            .disabled(card.quantity >= deck.deckFormat.maxCopiesPerCard)
                        }
                    }

                    HStack {
                        Text("You own:")
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(ownedQuantity)")
                            .foregroundColor(ownedQuantity >= card.quantity ? .green : .orange)
                    }

                    if ownedQuantity < card.quantity {
                        HStack {
                            Text("Need:")
                                .foregroundColor(.gray)
                            Spacer()
                            Text("\(card.quantity - ownedQuantity) more")
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.lorcanaDark.opacity(0.8))
                )

                Button(role: .destructive, action: {
                    deckManager.removeCard(card, from: deck)
                    dismiss()
                }) {
                    Label("Remove from Deck", systemImage: "trash")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .cornerRadius(10)
                }

                Spacer()
            }
            .padding()
            .background(LorcanaBackground())
            .navigationTitle(card.name)
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

// MARK: - Export Deck View
struct ExportDeckView: View {
    let deckText: String
    let deckName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                ScrollView {
                    Text(deckText)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.lorcanaDark.opacity(0.8))
                        )
                }

                Button(action: {
                    UIPasteboard.general.string = deckText
                }) {
                    Label("Copy to Clipboard", systemImage: "doc.on.clipboard")
                        .foregroundColor(.lorcanaDark)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.lorcanaGold)
                        .cornerRadius(10)
                }
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

// MARK: - Deck Builder View
struct DeckBuilderView: View {
    let deck: Deck
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject var deckManager: DeckManager
    @EnvironmentObject var collectionManager: CollectionManager
    @StateObject private var dataManager = SetsDataManager.shared

    @State private var searchText = ""
    @State private var showOwnedOnly = false
    @State private var selectedInkColor: InkColor? = nil
    @State private var selectedCost: Int? = nil
    @State private var availableCards: [LorcanaCard] = []
    @State private var showingCardToAdd: LorcanaCard? = nil

    private var gridHelper: AdaptiveGridHelper {
        AdaptiveGridHelper(horizontalSizeClass: horizontalSizeClass)
    }

    var filteredCards: [LorcanaCard] {
        var cards = availableCards

        // Filter by deck ink colors FIRST (most restrictive)
        if !deck.deckInkColors.isEmpty {
            let cardsWithInk = cards.filter { $0.inkColor != nil }

            if !cardsWithInk.isEmpty {
                cards = cards.filter { card in
                    guard let cardInk = card.inkColor else {
                        // If card has no ink color data, include it (data might be missing)
                        return true
                    }
                    let matches = deck.deckInkColors.contains { deckColor in
                        deckColor.rawValue.lowercased() == cardInk.lowercased()
                    }
                    return matches
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
            let ownedCards = cards.filter { card in
                // Try ID match first
                if collectionManager.isCardCollected(card.id) {
                    return true
                }

                // Fallback: try name + set + variant match
                return collectionManager.isCardCollectedByName(
                    card.name,
                    setName: card.setName,
                    variant: card.variant
                )
            }
            cards = ownedCards
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
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)

                    TextField("Search cards...", text: $searchText)
                        .foregroundColor(.white)

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color.lorcanaDark.opacity(0.6))

                // Owned/All Toggle - Prominent
                HStack {
                    Text("Show:")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Button(action: { showOwnedOnly = false }) {
                        Text("All Cards")
                            .font(.subheadline)
                            .fontWeight(showOwnedOnly ? .regular : .bold)
                            .foregroundColor(showOwnedOnly ? .gray : .lorcanaGold)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(showOwnedOnly ? Color.clear : Color.lorcanaGold.opacity(0.2))
                            )
                    }

                    Button(action: { showOwnedOnly = true }) {
                        Text("Owned Only")
                            .font(.subheadline)
                            .fontWeight(showOwnedOnly ? .bold : .regular)
                            .foregroundColor(showOwnedOnly ? .lorcanaGold : .gray)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(showOwnedOnly ? Color.lorcanaGold.opacity(0.2) : Color.clear)
                            )
                    }

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.2))

                // Filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {

                        // Ink color filter
                        Menu {
                            Button("All Colors") {
                                selectedInkColor = nil
                            }
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
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedInkColor != nil ? Color.lorcanaGold.opacity(0.2) : Color.lorcanaDark.opacity(0.6))
                            )
                        }

                        // Cost filter
                        Menu {
                            Button("All Costs") {
                                selectedCost = nil
                            }
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
                            .foregroundColor(.white)
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
                        .foregroundColor(.gray)

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 4)

                // Cards grid
                if filteredCards.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("No cards found")
                            .foregroundColor(.gray)
                        if showOwnedOnly {
                            Text("Try showing all cards")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: gridHelper.deckGridColumns(), spacing: gridHelper.gridSpacing) {
                            ForEach(filteredCards) { card in
                                BuilderCardView(
                                    card: card,
                                    deck: deck,
                                    inDeck: deck.cards.first(where: { $0.cardId == card.id }),
                                    onTap: { showingCardToAdd = card }
                                )
                            }
                        }
                        .padding(gridHelper.viewPadding)
                    }
                }
            }
            .background(LorcanaBackground())
            .navigationTitle("Add Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadAllCards()
        }
        .onChange(of: dataManager.isDataLoaded) { isLoaded in
            if isLoaded {
                loadAllCards()
            }
        }
        .sheet(item: $showingCardToAdd) { card in
            AddCardToDeckView(card: card, deck: deck)
                .environmentObject(deckManager)
                .environmentObject(collectionManager)
        }
    }

    private func loadAllCards() {
        // Check if data is loaded
        guard dataManager.isDataLoaded else {
            availableCards = []
            return
        }

        // Load all cards from all sets
        var allCards: [LorcanaCard] = []
        for set in dataManager.sets {
            let setCards = dataManager.getCardsForSet(set.name)
            allCards.append(contentsOf: setCards)
        }

        // Apply cached prices
        availableCards = allCards.map { card in
            dataManager.getCardWithCachedPrice(card)
        }
    }
}

// MARK: - Builder Card View
struct BuilderCardView: View {
    let card: LorcanaCard
    let deck: Deck
    let inDeck: DeckCard?
    let onTap: () -> Void

    var quantityInDeck: Int {
        inDeck?.quantity ?? 0
    }

    var body: some View {
        VStack(spacing: 4) {
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
                        .stroke(card.rarity.color, lineWidth: 1)
                )

                // In deck indicator
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
                                    .fontWeight(.bold)
                                    .foregroundColor(.lorcanaDark)
                            }
                        }
                        Spacer()
                    }
                    .padding(4)
                }
            }

            Text(card.name)
                .font(.caption2)
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .opacity(quantityInDeck >= deck.deckFormat.maxCopiesPerCard ? 0.5 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Add Card to Deck View
struct AddCardToDeckView: View {
    let card: LorcanaCard
    let deck: Deck
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var deckManager: DeckManager
    @EnvironmentObject var collectionManager: CollectionManager

    @State private var quantity = 1

    var ownedQuantity: Int {
        // Try ID match first
        let byId = collectionManager.getCollectedQuantity(for: card.id)
        if byId > 0 {
            return byId
        }
        // Fallback to name match
        return collectionManager.getCollectedQuantityByName(
            card.name,
            setName: card.setName,
            variant: card.variant
        )
    }

    var existingInDeck: DeckCard? {
        deck.cards.first(where: { $0.cardId == card.id })
    }

    var currentDeckQuantity: Int {
        existingInDeck?.quantity ?? 0
    }

    var maxQuantity: Int {
        deck.deckFormat.maxCopiesPerCard - currentDeckQuantity
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Card image
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

                // Card info
                VStack(spacing: 12) {
                    if currentDeckQuantity > 0 {
                        HStack {
                            Text("In deck:")
                                .foregroundColor(.gray)
                            Spacer()
                            Text("\(currentDeckQuantity)x")
                                .foregroundColor(.lorcanaGold)
                        }
                    }

                    HStack {
                        Text("You own:")
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(ownedQuantity)x")
                            .foregroundColor(ownedQuantity > 0 ? .green : .orange)
                    }

                    Divider()

                    // Quantity selector
                    VStack(spacing: 8) {
                        Text("Add to deck:")
                            .foregroundColor(.gray)

                        HStack(spacing: 20) {
                            Button(action: {
                                if quantity > 1 { quantity -= 1 }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(quantity > 1 ? .red : .gray)
                            }
                            .disabled(quantity <= 1)

                            Text("\(quantity)x")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 80)

                            Button(action: {
                                if quantity < maxQuantity { quantity += 1 }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(quantity < maxQuantity ? .green : .gray)
                            }
                            .disabled(quantity >= maxQuantity)
                        }

                        if maxQuantity == 0 {
                            Text("Already at maximum (\(deck.deckFormat.maxCopiesPerCard) copies)")
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else {
                            Text("Max: \(maxQuantity) more")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.lorcanaDark.opacity(0.8))
                )

                // Add button
                Button(action: {
                    deckManager.addCard(card, to: deck, quantity: quantity)
                    dismiss()
                }) {
                    Text("Add to Deck")
                        .font(.headline)
                        .foregroundColor(.lorcanaDark)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.lorcanaGold)
                        .cornerRadius(10)
                }
                .disabled(maxQuantity == 0)

                Spacer()
            }
            .padding()
            .background(LorcanaBackground())
            .navigationTitle(card.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
