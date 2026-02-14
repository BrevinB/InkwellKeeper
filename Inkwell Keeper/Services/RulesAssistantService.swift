//
//  RulesAssistantService.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 1/30/26.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Message Model
struct RulesMessage: Identifiable, Equatable, Codable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date

    init(content: String, isUser: Bool) {
        self.id = UUID()
        self.content = content
        self.isUser = isUser
        self.timestamp = Date()
    }
}

// MARK: - Saved Chat Model
struct SavedChat: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var messages: [RulesMessage]
    let createdAt: Date
    var updatedAt: Date
    var isPinned: Bool

    init(title: String, messages: [RulesMessage]) {
        self.id = UUID()
        self.title = title
        self.messages = messages
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isPinned = false
    }

    var preview: String {
        messages.first(where: { $0.isUser })?.content ?? "New conversation"
    }
}

// MARK: - Availability State
enum RulesAssistantAvailability: Equatable {
    case available
    case unavailableNoNetwork
    case unavailableServiceError
    case checking

    var title: String {
        switch self {
        case .available:
            return "Rules Assistant"
        case .unavailableNoNetwork:
            return "No Internet Connection"
        case .unavailableServiceError:
            return "Service Unavailable"
        case .checking:
            return "Checking Availability..."
        }
    }

    var description: String {
        switch self {
        case .available:
            return "Ask me anything about Disney Lorcana rules!"
        case .unavailableNoNetwork:
            return "The Rules Assistant requires an internet connection. Please check your network settings and try again."
        case .unavailableServiceError:
            return "The Rules Assistant is temporarily unavailable. Please try again later."
        case .checking:
            return "Checking if Rules Assistant is available..."
        }
    }

    var systemImage: String {
        switch self {
        case .available:
            return "book.circle.fill"
        case .unavailableNoNetwork:
            return "wifi.slash"
        case .unavailableServiceError:
            return "exclamationmark.icloud"
        case .checking:
            return "hourglass"
        }
    }
}

// MARK: - Rules Assistant Service
@MainActor
class RulesAssistantService: ObservableObject {
    static let shared = RulesAssistantService()

    @Published var messages: [RulesMessage] = []
    @Published var isLoading = false
    @Published var availability: RulesAssistantAvailability = .checking
    @Published var currentStreamingContent: String = ""
    @Published var savedChats: [SavedChat] = []
    @Published var currentChatId: UUID?

    private var apiKey: String?
    private let savedChatsKey = "RulesAssistantSavedChats"

    private init() {
        loadSavedChats()
        checkAvailability()
    }

    // MARK: - Chat History Management
    private func loadSavedChats() {
        if let data = UserDefaults.standard.data(forKey: savedChatsKey),
           let chats = try? JSONDecoder().decode([SavedChat].self, from: data) {
            savedChats = chats.sorted {
                if $0.isPinned != $1.isPinned {
                    return $0.isPinned
                }
                return $0.updatedAt > $1.updatedAt
            }
        }
    }

    private func saveChatsToDisk() {
        if let data = try? JSONEncoder().encode(savedChats) {
            UserDefaults.standard.set(data, forKey: savedChatsKey)
        }
    }

    func saveCurrentChat(title: String? = nil) {
        guard !messages.isEmpty else { return }

        let chatTitle = title ?? generateChatTitle()

        if let existingIndex = savedChats.firstIndex(where: { $0.id == currentChatId }) {
            savedChats[existingIndex].messages = messages
            savedChats[existingIndex].updatedAt = Date()
            if let title = title {
                savedChats[existingIndex].title = title
            }
        } else {
            let newChat = SavedChat(title: chatTitle, messages: messages)
            currentChatId = newChat.id
            savedChats.insert(newChat, at: 0)
        }

        sortChats()
        saveChatsToDisk()
    }

    func loadChat(_ chat: SavedChat) {
        messages = chat.messages
        currentChatId = chat.id
    }

    func deleteChat(_ chat: SavedChat) {
        savedChats.removeAll { $0.id == chat.id }
        if currentChatId == chat.id {
            currentChatId = nil
        }
        saveChatsToDisk()
    }

    func togglePinChat(_ chat: SavedChat) {
        if let index = savedChats.firstIndex(where: { $0.id == chat.id }) {
            savedChats[index].isPinned.toggle()
            sortChats()
            saveChatsToDisk()
        }
    }

    func renameChat(_ chat: SavedChat, to newTitle: String) {
        if let index = savedChats.firstIndex(where: { $0.id == chat.id }) {
            savedChats[index].title = newTitle
            saveChatsToDisk()
        }
    }

    private func sortChats() {
        savedChats.sort {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned
            }
            return $0.updatedAt > $1.updatedAt
        }
    }

    private func generateChatTitle() -> String {
        if let firstUserMessage = messages.first(where: { $0.isUser }) {
            let content = firstUserMessage.content
            if content.count > 40 {
                return String(content.prefix(40)) + "..."
            }
            return content
        }
        return "Chat \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))"
    }

    // MARK: - System Instructions
    // Based on Disney Lorcana Comprehensive Rules (Effective May 27, 2025)
    // Source: files.disneylorcana.com/Disney-Lorcana-Comprehensive-Rules-052725-EN.pdf
    private let systemInstructions = """
    You are a Disney Lorcana rules assistant. Answer rules questions accurately, citing section numbers from the Comprehensive Rules when relevant.

    SECTION 1: GAME CONCEPTS

    1.1 Golden Rules:
    - If card text contradicts a game rule, the card effect supersedes that rule.
    - If an effect says a player "can't" do something, that takes precedence over effects that say they "can" or "may."
    - When instructed to do something, players do as much as possible.

    1.6 Types of Abilities:
    - Keywords: Words representing larger abilities (see Section 10)
    - Triggered abilities: Start with "When," "Whenever," "At the start of," or "At the end of"
    - Activated abilities: Written as "[Cost] – [Effect]". The cost may include:
      * {E} (exert) - Cannot use while drying or already exerted
      * Ink cost - Pay by exerting ink cards
      * Other costs (banish a character, discard cards, etc.)
      * If NO {E} in cost, can use even while drying!
    - Static abilities: Continuously active while card is in play
    - Replacement effects: Replace one effect with another

    SECTION 2: DECK REQUIREMENTS

    2.1 Each deck must:
    - Contain at least 60 cards (no maximum)
    - Contain no more than two ink types
    - Contain no more than 4 cards with the same full name
    - Contain no banned cards

    SECTION 4: TURN STRUCTURE

    4.1 Beginning Phase:
    - Ready Step: Ready all your cards; "During your turn" effects apply
    - Set Step: Gain lore from locations; triggered abilities go to bag
    - Draw Step: Draw one card (first player skips on first turn)

    4.2 Main Phase - Take actions in any order:
    - Put one card in inkwell (once per turn)
    - Play a card from hand
    - Activate item abilities
    - Use character abilities
    - Quest with characters
    - Challenge with characters
    - Move characters to/from locations

    4.3 End Phase: "Until end of turn" effects end; resolve bag; next player's turn

    SECTION 5: CARD CONDITIONS

    5.1 Ready/Exerted:
    - Ready: Card is upright, can use exert abilities
    - Exerted: Card is sideways, cannot use abilities requiring exert

    5.2 Damaged/Undamaged:
    - Damaged: Has 1+ damage counters
    - Undamaged: Has 0 damage

    5.3 Dry/Drying ("Summoning Sickness"):
    - Characters are "drying" the turn they enter play
    - Drying characters CANNOT: quest, challenge, or use abilities that require exerting ({E})
    - Drying characters CAN: use activated abilities that do NOT require exerting, be challenged, receive damage
    - Rush keyword allows challenging while drying (but not questing)
    - Items and Locations are NOT affected by drying - they can use abilities immediately

    SECTION 6: PLAYING CARDS

    6.1 Cost Payment:
    1. Announce and reveal card
    2. Declare cost type (ink or alternate like Shift/Sing)
    3. Verify resources available
    4. Pay cost (exert ink cards)
    5. Place in appropriate zone
    6. Resolve "when you play" triggers

    6.2 Inkwell:
    - Once per turn, may place an inkable card face-down as ink
    - Ink cards can be exerted to pay costs
    - Ink cards ready during your Ready step

    SECTION 7: QUESTING & CHALLENGING

    7.1 Questing:
    - Exert a ready character to quest
    - Gain lore equal to character's lore value
    - First player to 20 lore wins

    7.2 Challenging:
    - Exert a ready character to challenge an EXERTED opposing character or location
    - Both deal damage equal to their Strength simultaneously
    - Characters are banished when damage >= Willpower
    - You may ONLY challenge exerted characters/locations

    SECTION 8: GAME STATE CHECK

    Occurs after every action/ability resolves:
    1. Check win/loss conditions (20 lore or opponent can't draw)
    2. Banish characters/locations with damage >= willpower
    3. Apply required actions
    4. Resolve new triggers

    SECTION 9: ZONES

    - Deck: Draw pile (face-down, private)
    - Hand: Cards held (private)
    - Play: Characters, items, locations in play (public)
    - Inkwell: Ink cards (public)
    - Discard: Banished/used cards (public)
    - Bag: Where triggered abilities wait to resolve

    SECTION 10: KEYWORDS

    10.1 Bodyguard: May enter play exerted. While exerted, opponents must challenge this character if able.

    10.2 Challenger +X: Gets +X Strength while challenging.

    10.3 Evasive: Can only be challenged by characters with Evasive.

    10.4 Reckless: Must challenge each turn if able.

    10.5 Resist +X: Damage dealt to this is reduced by X.

    10.6 Rush: Can challenge the turn it enters play (bypasses drying).

    10.7 Shift [Cost]: May play onto a character with the same name by paying the Shift cost. Character keeps damage, effects, exerted state.

    10.8 Singer [Value]: May exert to sing Songs with cost up to the Singer value instead of paying ink.

    10.9 Support: When questing, may add this character's Strength to another chosen character's Strength this turn.

    10.10 Ward: Opponents can't choose this character except to challenge.

    10.11 Voiceless: Can't exert to sing Songs.

    RESPONSE GUIDELINES:

    Format rules:
    - Write in a natural, conversational tone — like an experienced player explaining to a friend
    - NEVER use numbered lists like "1. DIRECT ANSWER:" or "2. EXPLAIN THE RULE:" — that looks robotic
    - Use **bold** for key terms, keywords, and rule names
    - Use bullet points sparingly for listing multiple related items
    - Keep paragraphs short (2-3 sentences max)
    - Cite rule sections inline like "(Section 10.1)" rather than as a separate callout

    Structure (follow this flow naturally, without labeling each section):
    - Lead with the answer — tell the player exactly what happens or what they can/can't do. This should fully answer the question on its own
    - Then briefly explain why, citing the rule section. Keep the reasoning short — only include what's needed to understand the answer
    - If the user gave a specific scenario, apply the rule to it. Otherwise give a quick practical example
    - Mention common misconceptions only if directly relevant — don't force it
    - No need for a "summary" paragraph if the answer is already clear

    Additional guidelines:
    - Always explain WHY a rule works the way it does, not just WHAT the rule is
    - Use the player's card names and scenario in your explanation
    - Distinguish between exert abilities ({E} cost) and non-exert activated abilities
    - If you need more information about a card's text to answer accurately, ask for it
    - For edge cases, acknowledge uncertainty and suggest disneylorcana.com/resources
    """

    // MARK: - Public Methods
    func checkAvailability() {
        Task {
            do {
                let key = try await CloudKitKeyService.shared.fetchAPIKey("openai")
                self.apiKey = key
                self.availability = .available
            } catch let error as CloudKitKeyError {
                print("[RulesAssistant] CloudKit error: \(error.localizedDescription ?? "unknown")")
                switch error {
                case .noNetwork:
                    self.availability = .unavailableNoNetwork
                case .recordNotFound, .iCloudUnavailable, .unknownError:
                    self.availability = .unavailableServiceError
                }
            } catch {
                print("[RulesAssistant] Unexpected error: \(error)")
                self.availability = .unavailableServiceError
            }
        }
    }

    func sendMessage(_ text: String, cardContext: LorcanaCard? = nil) async {
        let userMessage = RulesMessage(content: text, isUser: true)
        messages.append(userMessage)

        isLoading = true
        currentStreamingContent = ""

        guard let apiKey = apiKey else {
            appendErrorResponse("Service not available. Please try again later.")
            isLoading = false
            return
        }

        var prompt = text

        if let card = cardContext {
            var cardDetails: [String] = []
            cardDetails.append("Name: \(card.name)")
            cardDetails.append("Type: \(card.type)")
            cardDetails.append("Ink Cost: \(card.cost)")

            if let inkColor = card.inkColor {
                cardDetails.append("Ink Color: \(inkColor)")
            }

            if let inkwell = card.inkwell {
                cardDetails.append("Inkable: \(inkwell ? "Yes" : "No")")
            }

            if let strength = card.strength {
                cardDetails.append("Strength: \(strength)")
            }

            if let willpower = card.willpower {
                cardDetails.append("Willpower: \(willpower)")
            }

            if let lore = card.lore {
                cardDetails.append("Lore: \(lore)")
            }

            if !card.cardText.isEmpty {
                cardDetails.append("Card Text/Abilities: \(card.cardText)")
            }

            prompt = """
            [Card Context - The user is asking about this specific card]
            \(cardDetails.joined(separator: "\n"))

            [User's Question]
            \(text)

            Please analyze this card's abilities and answer the question, citing relevant rules sections.
            """
        }

        // Build messages array for OpenAI
        var openAIMessages: [OpenAIChatMessage] = [
            OpenAIChatMessage(role: "system", content: systemInstructions)
        ]

        // Add conversation history (excluding the message we just appended)
        for message in messages.dropLast() {
            openAIMessages.append(OpenAIChatMessage(
                role: message.isUser ? "user" : "assistant",
                content: message.content
            ))
        }

        // Add the current user message
        openAIMessages.append(OpenAIChatMessage(role: "user", content: prompt))

        do {
            let stream = OpenAIService.shared.streamChatCompletion(
                apiKey: apiKey,
                messages: openAIMessages
            )

            for try await chunk in stream {
                currentStreamingContent += chunk
            }

            let assistantMessage = RulesMessage(content: currentStreamingContent, isUser: false)
            messages.append(assistantMessage)
            currentStreamingContent = ""
        } catch {
            if currentStreamingContent.isEmpty {
                appendErrorResponse("Sorry, I encountered an error. Please try again.")
            } else {
                // We got partial content, save what we have
                let assistantMessage = RulesMessage(content: currentStreamingContent, isUser: false)
                messages.append(assistantMessage)
                currentStreamingContent = ""
            }
        }

        isLoading = false
    }

    private func appendErrorResponse(_ message: String) {
        let response = RulesMessage(content: message, isUser: false)
        messages.append(response)
        currentStreamingContent = ""
    }

    func clearConversation(saveFirst: Bool = false) {
        if saveFirst && !messages.isEmpty {
            saveCurrentChat()
        }

        messages.removeAll()
        currentStreamingContent = ""
        currentChatId = nil
    }

    func startNewChat() {
        if !messages.isEmpty {
            saveCurrentChat()
        }
        clearConversation(saveFirst: false)
    }

    // MARK: - Suggested Questions
    static let suggestedQuestions = [
        "When can I challenge an opponent's character?",
        "How does the Shift keyword work?",
        "What's the difference between Singer and Sing?",
        "How does Bodyguard work with multiple characters?",
        "When does 'drying' (summoning sickness) apply?",
        "How do triggered abilities resolve?"
    ]
}
