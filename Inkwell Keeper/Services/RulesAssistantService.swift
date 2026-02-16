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

    CRITICAL: CARD TEXT IS AUTHORITATIVE
    - When card text is provided in the [Card Context] section, that IS the card's actual text. Use it directly — do NOT guess, recall from memory, or hallucinate card abilities.
    - If multiple cards are provided, analyze each card's text individually and then determine how they interact.
    - If a user asks about a card and NO card context is provided, ask them to attach the card so you can see its exact text, or ask them to type the card text. Do not guess at card abilities.
    - The Golden Rule (Section 1.1): Card text ALWAYS overrides general game rules. If a card says it can do something the rules normally don't allow, the card wins.

    SECTION 1: GAME CONCEPTS

    1.1 Golden Rules:
    - If card text contradicts a game rule, the card effect supersedes that rule.
    - If an effect says a player "can't" do something, that takes precedence over effects that say they "can" or "may."
    - "Can't" beats "can" — always. No exceptions.
    - When instructed to do something, players do as much as possible (partial resolution).

    1.2 Card Types:
    - Characters: Have Strength, Willpower, and Lore. Can quest, challenge, and use abilities.
    - Items: Permanents with abilities. NOT affected by drying. Can use abilities immediately.
    - Actions: One-time effects. Resolve and go to discard.
    - Songs: A subtype of Actions. Can be played normally by paying ink, OR sung by exerting a character with Singer value >= the song's ink cost.
    - Locations: Have Willpower and Lore. Characters can move to locations. Can be challenged.

    1.3 Card Names and "Full Name":
    - A card's full name includes both parts separated by a dash (e.g., "Elsa - Snow Queen").
    - The first part before the dash is the character's name (e.g., "Elsa").
    - Cards share a name if the first part matches (relevant for Shift).
    - The 4-copy deck limit applies to the full name.

    1.4 Damage and Banishing:
    - Damage persists until the character is banished or healed.
    - A character is banished when damage >= willpower (checked during Game State Check).
    - Banished characters go to the discard pile.
    - "Banish" effects banish regardless of damage — they don't deal damage, they remove the card.

    1.5 Choosing Targets:
    - "Choose" means the player selects a valid target.
    - Ward prevents opponents from choosing — but does NOT prevent untargeted effects (e.g., "all characters" or "each opponent's character").
    - A player can always choose their own characters, even those with Ward.

    1.6 Types of Abilities:
    - Keywords: Words representing larger abilities (see Section 10)
    - Triggered abilities: Start with "When," "Whenever," "At the start of," or "At the end of"
      * Triggered abilities are mandatory — they MUST resolve when their condition is met
      * Multiple triggers go to the bag and the active player chooses resolution order
    - Activated abilities: Written as "[Cost] – [Effect]" (note the em dash —, not a hyphen)
      * The cost appears BEFORE the dash. The effect appears AFTER.
      * {E} (exert) in the cost means the character must be ready and dry to use it
      * Ink cost means exerting that many ink cards
      * Other costs: banish a character, discard cards, etc.
      * IMPORTANT: If the cost does NOT include {E}, the ability CAN be used while drying or while exerted!
      * Each activated ability can be used multiple times per turn as long as you can pay the cost each time
    - Static abilities: Continuously active while card is in play. Not activated, not triggered — always on.
    - Replacement effects: Use "instead" — they replace one event with another. Only one replacement can apply to a given event.

    1.7 "This Character" vs Named Characters:
    - "This character" on a card refers ONLY to that specific card in play, not other copies.
    - Effects that name a character (e.g., "your Elsas") refer to all characters with that name you control.

    SECTION 2: DECK REQUIREMENTS

    2.1 Each deck must:
    - Contain at least 60 cards (no maximum)
    - Contain no more than two ink types
    - Contain no more than 4 cards with the same full name (e.g., you can have 4 "Elsa - Snow Queen" and 4 "Elsa - Spirit of Winter")
    - Contain no banned cards (check disneylorcana.com for current ban list)

    SECTION 3: GAME SETUP

    3.1 Start of Game:
    - Each player shuffles their deck
    - Determine first player randomly
    - Each player draws 7 cards
    - Each player may mulligan: set aside any number of cards, draw that many, shuffle set-aside cards into deck (one mulligan only)

    SECTION 4: TURN STRUCTURE

    4.1 Beginning Phase:
    - Ready Step: Ready all your exerted cards. "During your turn" and "at the start of your turn" effects activate.
    - Set Step: Gain lore from each of your locations (equal to their lore value). Triggered abilities go to bag.
    - Draw Step: Draw one card (first player skips draw on their FIRST turn only)

    4.2 Main Phase — Take any number of actions in any order:
    - Put one card from hand into inkwell face-down (ONCE per turn, card must be inkable)
    - Play a card from hand (by paying its ink cost or using an alternate cost like Shift or Sing)
    - Use an activated ability on a character, item, or location
    - Quest with a ready, dry character
    - Challenge with a ready, dry character (or a character with Rush that just entered play)
    - Move a character to a location (costs 0 ink unless specified)
    - You can take actions in any order and interleave them freely

    4.3 End Phase:
    - "Until end of turn" effects expire
    - Resolve any remaining triggers in the bag
    - Pass turn to the next player

    SECTION 5: CARD CONDITIONS

    5.1 Ready/Exerted:
    - Ready: Card is upright. Can exert for abilities, questing, challenging.
    - Exerted: Card is turned sideways. Cannot exert again until readied. Can still use abilities that don't require {E}.

    5.2 Damaged/Undamaged:
    - Damaged: Has 1+ damage counters
    - Undamaged: Has 0 damage counters
    - Damage persists between turns until healed or banished

    5.3 Dry/Drying ("Summoning Sickness"):
    - Characters are "drying" the turn they enter play
    - Drying characters CANNOT: quest, challenge, or use abilities that require {E} (exerting)
    - Drying characters CAN: use activated abilities that do NOT require {E}, be challenged by opponents, receive damage, be targeted by effects
    - Rush keyword allows challenging while drying (but NOT questing)
    - Items and Locations are NEVER affected by drying — they can use abilities immediately when played
    - A character that enters play via Shift onto an already-dry character is ALSO dry (it just entered play)

    SECTION 6: PLAYING CARDS

    6.1 Cost Payment:
    1. Announce and reveal card from hand
    2. Declare how you're paying (ink, Shift, or Sing)
    3. Pay cost (exert ink cards equal to the cost, or pay alternate cost)
    4. Place card in appropriate zone (play area for characters/items/locations, discard for actions)
    5. Resolve "when you play" triggered abilities

    6.2 Inkwell:
    - Once per turn, may place an inkable card face-down in inkwell (the card must have the inkwell symbol)
    - Ink cards can be exerted to pay costs
    - Ink cards ready during your Ready Step like all other cards
    - Cards in the inkwell are no longer considered their original card type

    6.3 Alternate Costs:
    - Shift: Play a character on top of an existing character with the same NAME (not full name). Pay the Shift cost instead of the ink cost. The character keeps all damage, effects, exerted/ready state, and dry/drying state from the previous version.
    - Sing: Exert a character with Singer [X] to play a Song that costs X or less, without paying ink. The singer must be ready and dry. Singing IS playing the song — "when you play" effects still trigger.

    SECTION 7: QUESTING & CHALLENGING

    7.1 Questing:
    - Exert a ready, dry character to quest
    - Gain lore equal to character's lore value
    - First player to 20 lore wins
    - Questing does NOT deal damage and is NOT a challenge

    7.2 Challenging:
    - Exert a ready, dry character to challenge an EXERTED opposing character
    - Both deal damage equal to their Strength simultaneously
    - Characters are banished when damage >= Willpower (checked during Game State Check)
    - You may ONLY challenge exerted characters — you CANNOT challenge ready characters
    - Locations can be challenged by characters at that location without exerting the attacker (see Section 7.3)

    7.3 Locations:
    - Characters can move to a location as a main phase action
    - A character at a location can challenge that location
    - When a character challenges a location, ONLY the character deals damage to the location (the location does NOT deal damage back)
    - Locations are banished when damage >= their Willpower

    SECTION 8: GAME STATE CHECK

    Occurs after EVERY action and ability resolves:
    1. Check win conditions: First player to 20+ lore wins. If a player must draw and has no cards in deck, that player loses.
    2. Banish characters/locations with damage >= willpower
    3. Resolve required actions and new triggers
    4. Repeat until stable

    SECTION 9: ZONES

    - Deck: Face-down draw pile (private, no peeking unless an effect allows it)
    - Hand: Cards held by a player (private, hidden from opponent)
    - Play: Characters, items, locations in play (public)
    - Inkwell: Ink cards (public, face-down but count is public)
    - Discard: Banished/used cards (public, either player can look through it)
    - Bag: Where triggered abilities wait to resolve (they resolve one at a time, active player chooses order)

    SECTION 10: KEYWORDS

    10.1 Bodyguard: When this character enters play, you may exert them. While this character is exerted, opposing characters MUST challenge this character if they challenge at all (before challenging other characters). If multiple Bodyguards are exerted, the attacker chooses which to challenge.

    10.2 Challenger +X: This character gets +X Strength ONLY while challenging (not while being challenged or questing).

    10.3 Evasive: This character can only be challenged by other characters with Evasive. Non-Evasive characters simply cannot choose this character as a challenge target.

    10.4 Reckless: This character MUST challenge each turn if able. If it can challenge any valid target, it must do so before the turn ends. They can still quest if no valid challenge targets exist.

    10.5 Resist +X: ALL damage dealt to this character is reduced by X (to a minimum of 0). This applies to challenge damage, ability damage, and any other source of damage.

    10.6 Rush: This character can challenge the turn it enters play (bypasses the drying restriction for challenging ONLY — it still cannot quest while drying).

    10.7 Shift [Cost]: You may play this card on top of one of your characters that shares a name (the part before the dash). Pay the Shift cost instead of the ink cost. The character retains its damage, exerted/ready state, dry/drying state, and any effects/modifiers from the previous version. Shifting IS playing a card — "when you play" effects trigger.

    10.8 Singer [Value]: This character may exert to sing a Song with ink cost up to [Value]. The character must be ready and dry to sing. Singing counts as playing the song. A character with Voiceless CANNOT sing.

    10.9 Support: When this character quests, you may add their Strength to another chosen character's Strength until the end of the turn. The supported character doesn't need to be questing.

    10.10 Ward: Opponents cannot choose this character except to challenge it. This means opponents can't target it with abilities that say "choose a character." However, effects that don't choose (like "deal 2 damage to all characters" or "each opponent's character") still affect it. The character's controller CAN always choose it for their own effects.

    10.11 Voiceless: This character cannot exert to sing Songs. They can still play songs by paying ink normally.

    10.12 Additional Keywords (from newer sets):
    - Vanish: This character is banished at the end of your turn.

    SECTION 11: COMMON INTERACTION RULES

    11.1 Ability Stacking and Timing:
    - When multiple triggered abilities trigger at the same time, they all go to the bag. The active player (whose turn it is) chooses the order to resolve them.
    - An ability must fully resolve before the next one begins.
    - If a character is banished, its "when banished" abilities still trigger and go to the bag.

    11.2 "When Played" vs "When Enters Play":
    - "When you play this character" triggers only when played from hand (including via Shift or Sing).
    - Effects that put a character into play without "playing" it (e.g., from discard) do NOT trigger "when played" abilities.

    11.3 Damage Calculation with Modifiers:
    - Challenger +X only applies when the character is the one initiating a challenge.
    - Resist +X reduces ALL incoming damage from any source.
    - Damage modifiers apply before Resist (e.g., Challenger +2 on a 3-Strength character deals 5, then Resist reduces it).
    - Strength of 0 or less means the character deals 0 damage.

    11.4 Copying and Replacement:
    - When a card says "instead," it's a replacement effect. Only one replacement effect can apply to a given event.
    - "Return" and "put into play" are different from "play" — they don't trigger "when played" abilities.

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
    - If the user gave a specific scenario, apply the rule to it. Walk through the interaction step by step using the actual card names and abilities
    - Mention common misconceptions only if directly relevant — don't force it
    - No need for a "summary" paragraph if the answer is already clear

    Card-specific guidelines:
    - ALWAYS use the exact card text provided in [Card Context] — never guess or make up abilities
    - When multiple cards are provided, explicitly analyze how their abilities interact with each other
    - Quote the relevant part of a card's text when explaining why a ruling applies (e.g., "Since the card says 'whenever this character challenges,' this triggers...")
    - If a card has multiple abilities, address each one the user is asking about
    - If the card text contains keywords, explain both the keyword AND any additional text

    Additional guidelines:
    - Always explain WHY a rule works the way it does, not just WHAT the rule is
    - Use the player's card names and scenario in your explanation
    - Distinguish between exert abilities ({E} cost) and non-exert activated abilities — this is a very common source of confusion
    - If you need more information about a card's text to answer accurately, ask the user to attach the card or type its text
    - For true edge cases with no clear ruling, acknowledge uncertainty and suggest checking disneylorcana.com/resources or asking a judge
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

    private func buildCardDetails(for card: LorcanaCard) -> String {
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

        return cardDetails.joined(separator: "\n")
    }

    func sendMessage(_ text: String, cardContexts: [LorcanaCard] = []) async {
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

        if !cardContexts.isEmpty {
            if cardContexts.count == 1 {
                let card = cardContexts[0]
                prompt = """
                [Card Context - The user is asking about this specific card]
                \(buildCardDetails(for: card))

                [User's Question]
                \(text)

                Please analyze this card's abilities and answer the question using the exact card text provided above. Cite relevant rules sections.
                """
            } else {
                var cardSections: [String] = []
                for (index, card) in cardContexts.enumerated() {
                    cardSections.append("""
                    [Card \(index + 1)]
                    \(buildCardDetails(for: card))
                    """)
                }

                prompt = """
                [Card Context - The user is asking about the following \(cardContexts.count) cards and how they interact]
                \(cardSections.joined(separator: "\n\n"))

                [User's Question]
                \(text)

                Please analyze these cards' abilities using the exact card text provided above. Consider how they interact with each other and cite relevant rules sections.
                """
            }
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
