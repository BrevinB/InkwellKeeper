//
//  RulesAssistantService.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 1/30/26.
//

import Foundation
import SwiftUI

// MARK: - Message Model
struct RulesMessage: Identifiable, Equatable, Codable {
    /// Just enough of an attached card to render it in the transcript — the full rules
    /// text lives in `cardContext`.
    struct AttachedCard: Codable, Equatable {
        let id: String
        let name: String
        let imageUrl: String
    }

    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date
    /// Formatted card details attached to (or auto-detected for) this message. Persisted so
    /// follow-up questions retain the card context across turns. Optional for backward
    /// compatibility with chats saved before this field existed.
    let cardContext: String?
    /// The cards attached to this message, shown as thumbnails in the transcript.
    let attachedCards: [AttachedCard]?
    /// App-generated error bubbles ("Sorry, I encountered an error…"). Shown in the UI but
    /// excluded from the API conversation so the model never sees them as its own replies.
    let isError: Bool

    init(
        content: String,
        isUser: Bool,
        cardContext: String? = nil,
        attachedCards: [AttachedCard]? = nil,
        isError: Bool = false
    ) {
        self.id = UUID()
        self.content = content
        self.isUser = isUser
        self.timestamp = Date()
        self.cardContext = cardContext
        self.attachedCards = attachedCards
        self.isError = isError
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        isUser = try container.decode(Bool.self, forKey: .isUser)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        cardContext = try container.decodeIfPresent(String.self, forKey: .cardContext)
        attachedCards = try container.decodeIfPresent([AttachedCard].self, forKey: .attachedCards)
        // Chats saved before this field existed decode as non-error messages.
        isError = try container.decodeIfPresent(Bool.self, forKey: .isError) ?? false
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
@Observable
class RulesAssistantService {
    static let shared = RulesAssistantService()

    var messages: [RulesMessage] = []
    var isLoading = false
    var availability: RulesAssistantAvailability = .checking
    var currentStreamingContent: String = ""
    var savedChats: [SavedChat] = []
    var currentChatId: UUID?
    /// True when the most recent generation failed, so the UI can offer a retry.
    var lastSendFailed = false

    private var apiKey: String?
    private let savedChatsKey = "RulesAssistantSavedChats"

    // Rules answers are reasoning-heavy, so use a stronger model than the deck builder and a
    // low temperature for deterministic, factual rulings. The model is remotely configurable.
    private var rulesModel: String { AIConfigService.shared.rulesModel }
    private let rulesTemperature = 0.3

    // Lightweight client-side abuse guard for the shared API key. Remotely configurable.
    var dailyMessageLimit: Int { AIConfigService.shared.rulesDailyLimit }
    /// Most recent conversation messages replayed to the API each turn; older turns age out
    /// so long chats don't grow token cost without bound.
    private static let maxReplayedMessages = 16
    private let dailyCountKey = "RulesAssistantDailyCount"
    private let dailyDateKey = "RulesAssistantDailyDate"

    /// The current generation task, retained so the user can stop it mid-stream.
    @ObservationIgnored private var generationTask: Task<Void, Never>?

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

    /// The digest actually sent as the system prompt — remotely updated when a newer copy
    /// has been fetched from CloudKit, otherwise the bundled snapshot below.
    private var systemInstructions: String {
        RulesDigestService.shared.currentDigest
    }

    // Bundled fallback digest. Based on Disney Lorcana Comprehensive Rules v2.2.0 (Effective July 9, 2026)
    // Source: files.disneylorcana.com/Comprehensive-Rules_2.2.0-EN.pdf
    // Newer rules ship via the CloudKit `RulesDigest` record (see RulesDigestService).
    static let bundledRulesDigest = """
    You are a Disney Lorcana rules assistant. Answer rules questions accurately, citing section numbers from the Comprehensive Rules when relevant. Your knowledge reflects Comprehensive Rules v2.2.0 (July 2026), current through Attack of the Vine! (Set 13).

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
    - Dual-named characters (Set 13+): a card like "Mickey Mouse & Minnie Mouse - Adventuring Duo" is a character named "Mickey Mouse," a character named "Minnie Mouse," AND a character named "Mickey Mouse & Minnie Mouse" — but is still a single character (Section 5.2.6).

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

    SECTION 2: DECK REQUIREMENTS & FORMATS

    2.1 Each deck must:
    - Contain at least 60 cards (no maximum)
    - Contain no more than two ink types
    - Contain no more than 4 cards with the same full name (e.g., you can have 4 "Elsa - Snow Queen" and 4 "Elsa - Spirit of Winter")
    - Contain no banned cards (check disneylorcana.com for current ban list)
    - Dual-ink cards (Set 13+) have two ink type symbols and count as EACH of those types. A dual-ink card can only go in a deck whose two ink types are exactly those types (Section 5.2.5).
    - Some cards modify deck-construction rules for their own deck (e.g., "GATHER THE PARTY: You can have other Hunny characters in your deck regardless of ink type") — card text wins (Section 1.10.1.3).

    2.2 Constructed formats (as of July 2026 — verify current rotation at disneylorcana.com):
    - Core Constructed: rotating. Currently sets 9-13 only (Fabled, Whispers in the Well, Winterspell, Wilds Unknown, Attack of the Vine!). Any printing of a legal card is allowed. No banned cards currently.
    - Infinity Constructed: all sets legal, no rotation. Currently banned: Hiram Flaversham - Toymaker.

    SECTION 3: GAME SETUP

    3.1 Start of Game:
    - Each player shuffles their deck
    - Determine first player randomly
    - Each player draws 7 cards
    - Each player may mulligan: set aside any number of cards, draw that many, shuffle set-aside cards into deck (one mulligan only)

    SECTION 4: TURN STRUCTURE

    4.1 Start-of-Turn Phase (formerly called the Beginning Phase):
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
    - Shift: Play a card on top of an existing card with the same NAME (not full name). Pay the Shift cost instead of the ink cost. The character keeps all damage, effects, exerted/ready state, and dry/drying state from the previous version. (See Section 10.7 for Shift variants.)
    - Sing: Exert a character with Singer [X] to play a Song that costs X or less, without paying ink. The singer must be ready and dry. Singing IS playing the song — "when you play" effects still trigger.
    - "For free" is formally an alternate cost (Section 1.5.5.3). You choose exactly ONE alternate cost per play — so you cannot Shift a card that is being played "for free."

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
    1. Check win/loss conditions: First player to 20+ lore wins. A player who ENDS THEIR TURN with no cards in their deck loses (Section 2.3.3.2).
    2. Banish characters/locations with damage >= willpower
    3. Resolve required actions and new triggers
    4. Repeat until stable

    IMPORTANT deck-out rule change (CR 2.0, Feb 2026): running out of cards no longer loses the game at the moment you would draw. Drawing from an empty deck simply does nothing; you only LOSE if your deck is empty when your turn ends. Older sources state the pre-2026 rule — that rule is obsolete.

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

    10.7 Shift [Cost]: You may play this card on top of one of your cards that shares a name (the part before the dash). Pay the Shift cost instead of the ink cost. The character retains its damage, exerted/ready state, dry/drying state, and any effects/modifiers from the previous version. Shifting IS playing a card — "when you play" effects trigger.
    Shift variants (Section 8.10.8):
    - [Classification] Shift (e.g., "Puppy Shift 3"): shift onto any of your characters with that classification instead of a shared name.
    - Universal Shift: shift onto ANY of your characters.
    - Duo Shift (Set 13+): if you have TWO characters in play each matching one of the names on this dual-named card, play it on top of BOTH (stack the two under it in any order).
    - Combo Shift (Set 13+): two Shift abilities in one — shift onto ONE character sharing either of the card's names, or onto TWO characters (one of each name).
    - Temporary Shift (Set 13+): a normal same-name shift, plus: at the end of your turn, if this card is in play, remove all damage from it and return ONLY the top card to your hand.
    - Potato Shift (Set 13+): if you have an item named Potato in play, shift onto that ITEM. The character is dry if the item was in play since the start of the turn.
    - Combined variants (e.g., "Temporary Red Panda Shift") require ALL conditions of every variant named.
    - When shifting onto multiple cards: if any base is exerted the shifted character enters exerted; if any base is drying it enters drying (Section 8.10.4.2).

    10.8 Singer [Value]: This character may exert to sing a Song with ink cost up to [Value]. The character must be ready and dry to sing. Singing counts as playing the song. A character with Voiceless CANNOT sing. Effects granting "+N cost to sing songs" add to the Singer number (Section 8.11.3).

    10.9 Sing Together [Value]: You may exert any number of your ready, dry characters with total ink cost [Value] or more to sing this song for free.

    10.10 Support: When this character quests, you may add their Strength to another chosen character's Strength until the end of the turn. The supported character doesn't need to be questing.

    10.11 Ward: Opponents cannot choose this character except to challenge it. This means opponents can't target it with abilities that say "choose a character." However, effects that don't choose (like "deal 2 damage to all characters" or "each opponent's character") still affect it. The character's controller CAN always choose it for their own effects.

    10.12 Voiceless: This character cannot exert to sing Songs. They can still play songs by paying ink normally.

    10.13 Vanish: When an opponent chooses this character for an action, this character is banished (after the action resolves). Being chosen by abilities (not actions) does not trigger Vanish.

    10.14 Alert (Set 10+): This character ignores the challenging limiters of Evasive — it can challenge Evasive characters as if it had Evasive. Alert does NOT grant Evasive (it doesn't protect this character from being challenged).

    10.15 Boost N (Set 10+): Once during your turn, you may pay N ink to put the top card of your deck facedown under this card. Facedown cards under a card can never be looked at by anyone, are NOT in play, and putting them there is not "playing" them (Section 8.4). Card text on the Boost card typically gives benefits based on cards underneath.

    10.16 Note on named abilities: recurring named abilities like UNDERDOG ("If this is your first turn and you're not the first player, you pay 1 ink less to play this character") or STONE BY DAY are NOT keywords — their full rules text is printed on the card. Read the card text.

    SECTION 11: COMMON INTERACTION RULES

    11.1 Ability Stacking and Timing:
    - When multiple triggered abilities trigger at the same time, they all go to the bag. The active player (whose turn it is) chooses the order to resolve them.
    - An ability must fully resolve before the next one begins.
    - If a character is banished, its "when banished" abilities still trigger and go to the bag.

    11.2 "When Played" vs "When Enters Play":
    - "When you play this character" triggers only when played from hand (including via Shift or Sing).
    - Effects that put a character into play without "playing" it (e.g., from discard) do NOT trigger "when played" abilities.

    11.3 Damage Calculation with Modifiers (updated in CR 2.1/2.2):
    - Challenger +X only applies when the character is the one initiating a challenge.
    - "Deals" vs "takes" damage are distinct (Section 1.9): a source whose damage is reduced to 0 by Resist still DEALS damage (so "whenever this character deals damage" abilities trigger), but the target TAKES no damage.
    - Resist +X reduces only damage that is DEALT (challenges, "deal N damage" effects). Damage that is PUT on or MOVED to a character bypasses Resist entirely (Section 8.8.3).
    - Damage modifiers apply before Resist (e.g., Challenger +2 on a 3-Strength character deals 5, then Resist reduces it).
    - Strength of 0 or less means the character deals 0 damage.
    - Damage MOVED from one card to another cannot be returned to its source by the same effect.

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
    - Stay on topic: only answer questions about Disney Lorcana. If asked about something unrelated, politely steer back to Lorcana rules
    - Section numbers are general references to help players find the relevant rule. If you're not certain of the exact number, describe the rule plainly instead of inventing a precise citation
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

    /// Entry point from the UI. Appends the user's message and kicks off a streamed reply.
    /// Returns immediately; observe `isLoading` / `currentStreamingContent` for progress.
    func send(_ text: String, cardContexts: [LorcanaCard] = []) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoading else { return }

        // Explicit attachments win; otherwise auto-detect card names mentioned in the question.
        let cards = cardContexts.isEmpty ? detectCards(in: trimmed) : cardContexts
        let context = cards.isEmpty ? nil : buildCardContext(for: cards)
        let summaries = cards.map {
            RulesMessage.AttachedCard(id: $0.id, name: $0.name, imageUrl: $0.imageUrl)
        }

        messages.append(RulesMessage(
            content: trimmed,
            isUser: true,
            cardContext: context,
            attachedCards: summaries.isEmpty ? nil : summaries
        ))
        startGeneration()
    }

    /// Re-runs the assistant for the most recent user message. Used to recover from a failure.
    func retryLast() {
        guard !isLoading, let lastUserIndex = messages.lastIndex(where: { $0.isUser }) else { return }
        // Drop any assistant turns after the last user message so we regenerate cleanly.
        if lastUserIndex < messages.count - 1 {
            messages.removeSubrange((lastUserIndex + 1)...)
        }
        startGeneration()
    }

    /// Stops an in-flight generation, keeping whatever text has streamed so far.
    func stopGenerating() {
        generationTask?.cancel()
    }

    private func startGeneration() {
        // The daily allowance is only consumed when a reply actually arrives
        // (`commitStreamedReply`), so failed sends never burn quota. This check also
        // covers retries, which bypass `send`.
        guard remainingMessagesToday > 0 else {
            appendErrorResponse("You've reached today's limit of \(dailyMessageLimit) questions. Please try again tomorrow.")
            return
        }

        lastSendFailed = false
        isLoading = true
        currentStreamingContent = ""
        generationTask = Task { await streamAssistantReply() }
    }

    private func streamAssistantReply() async {
        defer {
            isLoading = false
            generationTask = nil
        }

        guard let apiKey else {
            appendErrorResponse("Service not available. Please try again later.")
            lastSendFailed = true
            return
        }

        // Replay only recent, real conversation turns: error bubbles are UI-only, and long
        // chats are trimmed so cost doesn't grow without bound. Card context lives on the
        // user messages inside the window, so recent attachments always survive the trim.
        var openAIMessages: [OpenAIChatMessage] = [
            OpenAIChatMessage(role: "system", content: systemInstructions)
        ]
        for message in messages.filter({ !$0.isError }).suffix(Self.maxReplayedMessages) {
            openAIMessages.append(OpenAIChatMessage(
                role: message.isUser ? "user" : "assistant",
                content: apiContent(for: message)
            ))
        }

        do {
            let stream = OpenAIService.shared.streamChatCompletion(
                apiKey: apiKey,
                messages: openAIMessages,
                model: rulesModel,
                temperature: rulesTemperature
            )

            for try await chunk in stream {
                if Task.isCancelled { break }
                currentStreamingContent += chunk
            }

            if currentStreamingContent.isEmpty {
                if Task.isCancelled {
                    // Stopped before the first chunk: no reply to keep, but surface the
                    // Retry affordance so the question isn't left dangling.
                    lastSendFailed = true
                } else {
                    // Empty with no cancellation means the request produced nothing useful.
                    appendErrorResponse("Sorry, I encountered an error. Please try again.")
                    lastSendFailed = true
                }
            } else {
                commitStreamedReply()
            }
        } catch {
            if currentStreamingContent.isEmpty {
                appendErrorResponse("Sorry, I encountered an error. Please try again.")
                lastSendFailed = true
            } else {
                // Keep the partial answer we did receive.
                commitStreamedReply()
            }
        }
    }

    private func commitStreamedReply() {
        messages.append(RulesMessage(content: currentStreamingContent, isUser: false))
        currentStreamingContent = ""
        lastSendFailed = false
        consumeDailyAllowance()
        // Auto-persist so an app termination doesn't lose the conversation.
        saveCurrentChat()
    }

    /// The content sent to the API for a message — user turns carry their stored card context,
    /// which keeps attached-card text available across follow-up questions.
    private func apiContent(for message: RulesMessage) -> String {
        guard message.isUser, let context = message.cardContext else {
            return message.content
        }
        return """
        \(context)

        [User's Question]
        \(message.content)

        Please answer using the exact card text provided above. Cite relevant rules sections.
        """
    }

    /// Builds the `[Card Context]` block for one or more cards.
    private func buildCardContext(for cards: [LorcanaCard]) -> String {
        if cards.count == 1 {
            return """
            [Card Context - The user is asking about this specific card]
            \(buildCardDetails(for: cards[0]))
            """
        }
        let sections = cards.enumerated().map { index, card in
            """
            [Card \(index + 1)]
            \(buildCardDetails(for: card))
            """
        }
        return """
        [Card Context - The user is asking about the following \(cards.count) cards and how they interact]
        \(sections.joined(separator: "\n\n"))
        """
    }

    /// Scans the question for full card names so their text can be auto-attached. Matching is
    /// dash/case/punctuation-insensitive ("elsa snow queen" matches "Elsa - Snow Queen") but
    /// still requires the full name + subtitle, to avoid false positives on common first names
    /// like "Belle" or "Stitch".
    private func detectCards(in text: String) -> [LorcanaCard] {
        let haystack = Self.matchableText(text)
        var matches: [LorcanaCard] = []
        var seenNames = Set<String>()
        for card in SetsDataManager.shared.getAllCards() where card.variant == .normal {
            guard card.name.contains(" - ") else { continue }
            if haystack.contains(Self.matchableText(card.name)), seenNames.insert(card.name).inserted {
                matches.append(card)
                if matches.count >= 4 { break }
            }
        }
        return matches
    }

    /// The single best full-name card mention in `text`, for the "Did you mean…?" attach chip.
    /// Prefers the longest matching name so "Mickey Mouse - Brave Little Tailor" wins over any
    /// shorter name it happens to contain. Returns `nil` when nothing matches.
    static func fuzzyCardSuggestion(in text: String, from cards: [LorcanaCard]) -> LorcanaCard? {
        let haystack = matchableText(text)
        guard !haystack.isEmpty else { return nil }

        var best: (card: LorcanaCard, matchLength: Int)?
        for card in cards where card.variant == .normal {
            guard card.name.contains(" - ") else { continue }
            let needle = matchableText(card.name)
            if haystack.contains(needle), needle.count > (best?.matchLength ?? 0) {
                best = (card, needle.count)
            }
        }
        return best?.card
    }

    /// Normalizes text for card-name matching: dash/case/diacritic-insensitive with the
    /// name's " - " separator collapsed, so spoken-style names line up with card names.
    private static func matchableText(_ text: String) -> String {
        DeckListTextCodec.normalize(text).replacing(" - ", with: " ")
    }

    // MARK: - Daily Allowance

    /// Returns true and records a use if the user is under today's limit.
    @discardableResult
    private func consumeDailyAllowance() -> Bool {
        let defaults = UserDefaults.standard
        let today = Calendar.current.startOfDay(for: Date())
        let storedDay = (defaults.object(forKey: dailyDateKey) as? Date).map { Calendar.current.startOfDay(for: $0) }

        var count = defaults.integer(forKey: dailyCountKey)
        if storedDay != today {
            count = 0
            defaults.set(today, forKey: dailyDateKey)
        }
        guard count < dailyMessageLimit else { return false }
        defaults.set(count + 1, forKey: dailyCountKey)
        return true
    }

    /// How many questions the user can still ask today.
    var remainingMessagesToday: Int {
        let defaults = UserDefaults.standard
        let today = Calendar.current.startOfDay(for: Date())
        let storedDay = (defaults.object(forKey: dailyDateKey) as? Date).map { Calendar.current.startOfDay(for: $0) }
        if storedDay != today { return dailyMessageLimit }
        return max(0, dailyMessageLimit - defaults.integer(forKey: dailyCountKey))
    }

    private func appendErrorResponse(_ message: String) {
        messages.append(RulesMessage(content: message, isUser: false, isError: true))
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
