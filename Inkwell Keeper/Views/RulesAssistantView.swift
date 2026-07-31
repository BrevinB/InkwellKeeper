//
//  RulesAssistantView.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 1/30/26.
//

import SwiftUI
import SwiftData

struct RulesAssistantView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var service = RulesAssistantService.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var inputText = ""
    @State private var showingHistory = false
    @State private var showingSaveAlert = false
    @State private var showingCardSearch = false
    @State private var showingGlossary = false
    @State private var chatTitleInput = ""
    @State private var attachedCards: [LorcanaCard] = []
    /// Set when opened via "Ask About This Card" and the question hasn't fired yet —
    /// it may have to wait for the subscription check or the availability probe.
    @State private var pendingCardAsk = false
    @FocusState private var isInputFocused: Bool

    var initialCard: LorcanaCard?
    /// True when shown as a sheet (card detail, lore counter) rather than as the Rules tab —
    /// modal presentations get an explicit Done button, which matters most for free users
    /// who land on the paywall with no other way out but a swipe.
    var presentedModally: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                LorcanaBackground()

                if !subscriptionManager.isSubscribed {
                    RulesPaywallView(source: initialCard != nil ? "cardAsk" : "rulesTab")
                } else if service.availability == .available {
                    RulesAvailableView(
                        service: service,
                        inputText: $inputText,
                        attachedCards: $attachedCards,
                        showingHistory: $showingHistory,
                        showingCardSearch: $showingCardSearch,
                        isInputFocused: $isInputFocused
                    )
                } else if service.availability == .checking {
                    RulesCheckingView()
                } else {
                    RulesUnavailableView(availability: service.availability) {
                        service.checkAvailability()
                    }
                }
            }
            .navigationTitle("Rules Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    // The glossary is free and offline — visible to everyone, including
                    // visitors who land on the paywall.
                    Button("Glossary", systemImage: "character.book.closed") {
                        showingGlossary = true
                    }
                    .foregroundStyle(.lorcanaGold)

                    if subscriptionManager.isSubscribed && service.availability == .available {
                        Button("History", systemImage: "clock.arrow.circlepath") {
                            showingHistory = true
                        }
                        .foregroundStyle(.lorcanaGold)
                    }
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if subscriptionManager.isSubscribed && service.availability == .available && !service.messages.isEmpty {
                        Button("Save chat", systemImage: "square.and.arrow.down") {
                            showingSaveAlert = true
                        }
                        .foregroundStyle(.lorcanaGold)

                        Button("New chat", systemImage: "plus.bubble") {
                            service.startNewChat()
                        }
                        .foregroundStyle(.lorcanaGold)
                    }

                    if presentedModally {
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundStyle(.lorcanaGold)
                    }
                }
            }
            .sheet(isPresented: $showingHistory) {
                ChatHistoryView(service: service, isPresented: $showingHistory)
            }
            .sheet(isPresented: $showingGlossary) {
                KeywordGlossaryView { question in
                    // Pre-fill for subscribers; free users return to the paywall funnel.
                    if subscriptionManager.isSubscribed {
                        inputText = question
                        isInputFocused = true
                    }
                }
            }
            .alert("Save Chat", isPresented: $showingSaveAlert) {
                TextField("Chat title", text: $chatTitleInput)
                Button("Save") {
                    service.saveCurrentChat(title: chatTitleInput.isEmpty ? nil : chatTitleInput)
                    chatTitleInput = ""
                }
                Button("Cancel", role: .cancel) {
                    chatTitleInput = ""
                }
            } message: {
                Text("Give this conversation a name")
            }
        }
        .onAppear {
            subscriptionManager.checkSubscriptionStatus()
            if initialCard != nil {
                pendingCardAsk = true
                fireCardAskIfReady()
            }
        }
        .onChange(of: service.availability) {
            fireCardAskIfReady()
        }
        .onChange(of: subscriptionManager.isSubscribed) {
            fireCardAskIfReady()
        }
    }

    /// Runs the "Ask About This Card" question once the service and subscription are ready.
    /// Always starts a fresh conversation (saving the previous one) so the card actually
    /// lands in context — the service is a singleton and an old chat would otherwise
    /// swallow the tap.
    private func fireCardAskIfReady() {
        guard pendingCardAsk,
              let card = initialCard,
              subscriptionManager.isSubscribed,
              service.availability == .available,
              !service.isLoading else { return }

        pendingCardAsk = false
        if !service.messages.isEmpty {
            service.startNewChat()
        }
        service.send("Tell me about the rules for this card and how to use it effectively.", cardContexts: [card])
    }
}

// MARK: - Available Content

struct RulesAvailableView: View {
    let service: RulesAssistantService
    @Binding var inputText: String
    @Binding var attachedCards: [LorcanaCard]
    @Binding var showingHistory: Bool
    @Binding var showingCardSearch: Bool
    @FocusState.Binding var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if service.messages.isEmpty && service.currentStreamingContent.isEmpty {
                RulesWelcomeView(
                    service: service,
                    showingHistory: $showingHistory,
                    showingCardSearch: $showingCardSearch
                )
            } else {
                RulesChatView(service: service)
            }

            RulesInputBar(
                service: service,
                inputText: $inputText,
                attachedCards: $attachedCards,
                showingCardSearch: $showingCardSearch,
                isInputFocused: $isInputFocused
            )
        }
    }
}

// MARK: - Welcome Screen

struct RulesWelcomeView: View {
    let service: RulesAssistantService
    @Binding var showingHistory: Bool
    @Binding var showingCardSearch: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 20)

                Image(systemName: "book.circle.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(.lorcanaGold)

                VStack(spacing: 8) {
                    Text("Lorcana Rules Assistant")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(.white)

                    Text("Ask about rules, keywords, or card interactions")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                }

                Button {
                    showingCardSearch = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.stack.badge.plus")
                            .font(.title3)
                            .foregroundStyle(.lorcanaGold)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ask about specific cards")
                                .font(.subheadline)
                                .bold()
                                .foregroundStyle(.white)
                            Text("Attach up to 4 cards from your collection or search")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.lorcanaGold.opacity(0.6))
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.lorcanaDark.opacity(0.8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.lorcanaGold.opacity(0.4), lineWidth: 1)
                            )
                    )
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Try asking:")
                        .font(.headline)
                        .foregroundStyle(.lorcanaGold)
                        .padding(.horizontal)

                    ForEach(RulesAssistantService.suggestedQuestions, id: \.self) { question in
                        Button {
                            service.send(question)
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.lorcanaGold)
                                    .font(.caption)

                                Text(question)
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.leading)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.lorcanaGold.opacity(0.5))
                                    .font(.caption)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.lorcanaDark.opacity(0.8))
                            )
                        }
                        .padding(.horizontal)
                    }
                }

                if !service.savedChats.isEmpty {
                    recentChats
                }

                Spacer()
                    .frame(height: 20)
            }
        }
    }

    private var recentChats: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent Chats")
                    .font(.headline)
                    .foregroundStyle(.lorcanaGold)

                Spacer()

                Button("See All") {
                    showingHistory = true
                }
                .font(.caption)
                .foregroundStyle(.lorcanaGold.opacity(0.8))
            }
            .padding(.horizontal)

            ForEach(service.savedChats.prefix(3)) { chat in
                Button {
                    service.loadChat(chat)
                } label: {
                    HStack {
                        if chat.isPinned {
                            Image(systemName: "pin.fill")
                                .foregroundStyle(.lorcanaGold)
                                .font(.caption)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(chat.title)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Text(chat.updatedAt, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.gray)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundStyle(.gray)
                            .font(.caption)
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
        .padding(.top, 8)
    }
}

// MARK: - Chat Messages

struct RulesChatView: View {
    let service: RulesAssistantService

    /// Message id → whether the user marked the answer helpful (session-local).
    @State private var ratedMessages: [UUID: Bool] = [:]
    @State private var rulingToShare: RulingShareData?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // Plain VStack on purpose: LazyVStack estimates offscreen row heights and
                // corrects them as they materialize, which bounces the scroll position
                // while an answer streams. Chats are short; laziness buys nothing here.
                VStack(spacing: 12) {
                    ForEach(Array(service.messages.enumerated()), id: \.element.id) { index, message in
                        messageView(message, at: index)
                            .id(message.id)
                    }

                    if let chips = followUpSuggestions, !service.isLoading {
                        FollowUpChipsView(suggestions: chips) { question in
                            service.send(question)
                        }
                    }

                    if !service.currentStreamingContent.isEmpty {
                        StreamingBubble(content: service.currentStreamingContent)
                    }

                    if service.isLoading && service.currentStreamingContent.isEmpty {
                        TypingIndicator()
                    }

                    if service.lastSendFailed && !service.isLoading {
                        retryButton
                    }

                    Color.clear.frame(height: 8)
                        .id("bottom")
                }
                .padding(.horizontal)
                .padding(.top, 12)
            }
            // Keeps the view pinned to the bottom as streamed content grows — the
            // system-provided behavior for transcripts, replacing per-chunk scrollTo
            // calls that fought the settling layout.
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: service.messages.count) {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .sheet(item: $rulingToShare) { ruling in
                ShareCardPresenter(
                    analyticsType: "ruling",
                    qrPayload: AppLinks.appStoreURLString,
                    tagline: "Ask the Lorcana Rules Assistant",
                    fileName: "InkwellKeeper-Ruling",
                    canvasHeight: nil,
                    preloadURLs: ruling.preloadURLs
                ) { images in
                    RulingShareCardView(ruling: ruling, images: images)
                }
            }
        }
    }

    @ViewBuilder
    private func messageView(_ message: RulesMessage, at index: Int) -> some View {
        if message.isUser {
            UserQuestionView(message: message)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                AssistantAnswerView(content: message.content, isError: message.isError)
                    .contextMenu {
                        if !message.isError {
                            Button("Share Ruling", systemImage: "square.and.arrow.up") {
                                rulingToShare = makeShareData(forAnswerAt: index)
                            }
                            Button("Copy Answer", systemImage: "doc.on.doc") {
                                UIPasteboard.general.string = message.content
                            }
                        }
                    }

                if !message.isError, index == lastAssistantIndex {
                    answerActions(for: message, at: index)
                }
            }
        }
    }

    /// Share + thumbs row shown under the most recent answer.
    private func answerActions(for message: RulesMessage, at index: Int) -> some View {
        HStack(spacing: 14) {
            Button("Share", systemImage: "square.and.arrow.up") {
                rulingToShare = makeShareData(forAnswerAt: index)
            }
            .font(.caption)
            .foregroundStyle(.lorcanaGold.opacity(0.9))

            Spacer()

            if let rating = ratedMessages[message.id] {
                Label(rating ? "Glad it helped!" : "Thanks for the feedback",
                      systemImage: rating ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                    .font(.caption)
                    .foregroundStyle(.gray)
            } else {
                Button("Helpful", systemImage: "hand.thumbsup") {
                    rate(message, helpful: true)
                }
                .labelStyle(.iconOnly)
                .font(.subheadline)
                .foregroundStyle(.gray)

                Button("Not helpful", systemImage: "hand.thumbsdown") {
                    rate(message, helpful: false)
                }
                .labelStyle(.iconOnly)
                .font(.subheadline)
                .foregroundStyle(.gray)
            }
        }
        .padding(.horizontal, 4)
    }

    private func rate(_ message: RulesMessage, helpful: Bool) {
        withAnimation { ratedMessages[message.id] = helpful }
        Analytics.send(.rulesAnswerRated(helpful: helpful))
    }

    private var lastAssistantIndex: Int? {
        service.messages.lastIndex { !$0.isUser && !$0.isError }
    }

    /// The question and attached cards belonging to the answer at `index`.
    private func makeShareData(forAnswerAt index: Int) -> RulingShareData {
        let priorUser = service.messages[..<index].last { $0.isUser }
        return RulingShareData(
            question: priorUser?.content ?? "Lorcana rules question",
            answer: service.messages[index].content,
            cards: priorUser?.attachedCards ?? []
        )
    }

    /// Deterministic follow-up prompts for the cards in play — only when the conversation
    /// is resting on an answer.
    private var followUpSuggestions: [String]? {
        guard let last = service.messages.last, !last.isUser, !last.isError else { return nil }
        guard let cards = service.messages.last(where: { $0.isUser })?.attachedCards,
              !cards.isEmpty else { return nil }
        let suggestions = RulesFollowUps.suggestions(for: cards)
        return suggestions.isEmpty ? nil : suggestions
    }

    private var retryButton: some View {
        Button("Retry", systemImage: "arrow.clockwise") {
            service.retryLast()
        }
        .font(.subheadline)
        .foregroundStyle(.lorcanaGold)
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
            Capsule()
                .stroke(Color.lorcanaGold.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Follow-up Chips

/// Horizontally scrolling suggested follow-up questions, generated locally (no API cost)
/// from the attached cards' text.
struct FollowUpChipsView: View {
    let suggestions: [String]
    let onTap: (String) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        onTap(suggestion)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                            Text(suggestion)
                                .font(.caption)
                        }
                        .foregroundStyle(.lorcanaGold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(Color.lorcanaDark.opacity(0.8))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.lorcanaGold.opacity(0.4), lineWidth: 1)
                                )
                        )
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

/// Builds card-aware follow-up questions by matching keywords in the attached cards' text.
enum RulesFollowUps {
    private static let keywordPrompts: [(keyword: String, prompt: String)] = [
        ("Shift", "How does Shift timing work here?"),
        ("Singer", "How does Singer interact with song costs?"),
        ("Sing Together", "How does Sing Together add up?"),
        ("Bodyguard", "How does Bodyguard affect challenges here?"),
        ("Ward", "What can still affect this card through Ward?"),
        ("Evasive", "Who can challenge this Evasive character?"),
        ("Challenger", "When does the Challenger bonus apply?"),
        ("Resist", "How does Resist reduce this damage?"),
        ("Rush", "Can this character challenge the turn it's played?"),
        ("Reckless", "What does Reckless force this character to do?"),
        ("Support", "How does Support work when this character quests?"),
        ("Vanish", "When exactly does Vanish trigger?")
    ]

    /// Card text resolved once per card id — this runs from view bodies, and
    /// `getAllCards()` is far too expensive per render.
    @MainActor private static var cardTextCache: [String: String] = [:]

    @MainActor
    static func suggestions(for cards: [RulesMessage.AttachedCard]) -> [String] {
        let combinedText = cards.map { cardText(forId: $0.id) }.joined(separator: "\n")

        var prompts = keywordPrompts
            .filter { combinedText.localizedStandardContains($0.keyword) }
            .map { $0.prompt }

        if prompts.isEmpty {
            prompts = ["What are good combos with this card?", "How would an opponent play around it?"]
        }
        return Array(prompts.prefix(3))
    }

    @MainActor
    private static func cardText(forId id: String) -> String {
        if let cached = cardTextCache[id] { return cached }
        let text = SetsDataManager.shared.getAllCards().first { $0.id == id }?.cardText ?? ""
        cardTextCache[id] = text
        return text
    }
}

// MARK: - Input Bar

struct RulesInputBar: View {
    let service: RulesAssistantService
    @Binding var inputText: String
    @Binding var attachedCards: [LorcanaCard]
    @Binding var showingCardSearch: Bool
    @FocusState.Binding var isInputFocused: Bool

    /// Card the typed text appears to mention, offered as a one-tap attach.
    @State private var suggestedCard: LorcanaCard?
    @State private var suggestionTask: Task<Void, Never>?
    /// Normal-variant cards, loaded once — `getAllCards()` is too expensive per keystroke.
    @State private var matchCandidates: [LorcanaCard] = []

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !service.isLoading
    }

    var body: some View {
        VStack(spacing: 0) {
            if !attachedCards.isEmpty {
                attachedCardsPreview
            }

            if let suggestion = suggestedCard {
                suggestionChip(suggestion)
            }

            Divider()
                .background(Color.lorcanaGold.opacity(0.3))

            if service.remainingMessagesToday <= 5 {
                Text("\(service.remainingMessagesToday) question\(service.remainingMessagesToday == 1 ? "" : "s") left today")
                    .font(.caption2)
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 6)
            }

            HStack(spacing: 10) {
                Button {
                    showingCardSearch = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: attachedCards.isEmpty ? "rectangle.stack.badge.plus" : "rectangle.stack.badge.checkmark")
                            .font(.system(size: 20))
                            .foregroundStyle(attachedCards.isEmpty ? .gray : .lorcanaGold)

                        if attachedCards.count > 1 {
                            Text("\(attachedCards.count)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.black)
                                .frame(width: 14, height: 14)
                                .background(Circle().fill(Color.lorcanaGold))
                                .offset(x: 4, y: -4)
                        }
                    }
                }

                TextField("Ask about rules...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.lorcanaDark.opacity(0.9))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.lorcanaGold.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .foregroundStyle(.white)
                    .focused($isInputFocused)
                    .lineLimit(1...4)
                    .submitLabel(.send)
                    .onSubmit(sendMessage)

                if service.isLoading {
                    Button("Stop", systemImage: "stop.circle.fill") {
                        service.stopGenerating()
                    }
                    .labelStyle(.iconOnly)
                    .font(.system(size: 32))
                    .foregroundStyle(.red)
                } else {
                    Button("Send", systemImage: "arrow.up.circle.fill", action: sendMessage)
                        .labelStyle(.iconOnly)
                        .font(.system(size: 32))
                        .foregroundStyle(canSend ? .lorcanaGold : .gray.opacity(0.5))
                        .disabled(!canSend)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.lorcanaDark.opacity(0.98))
        }
        .sheet(isPresented: $showingCardSearch) {
            CardSearchSheet(attachedCards: $attachedCards, isPresented: $showingCardSearch)
        }
        .task {
            if matchCandidates.isEmpty {
                matchCandidates = SetsDataManager.shared.getAllCards().filter { $0.variant == .normal }
            }
        }
        .onChange(of: inputText) { _, newValue in
            suggestionTask?.cancel()
            guard !newValue.isEmpty else {
                suggestedCard = nil
                return
            }
            suggestionTask = Task {
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                let match = RulesAssistantService.fuzzyCardSuggestion(in: newValue, from: matchCandidates)
                if let match, !attachedCards.contains(where: { $0.id == match.id }) {
                    suggestedCard = match
                } else {
                    suggestedCard = nil
                }
            }
        }
    }

    /// "Did you mean …?" one-tap attach for a card name the user typed loosely.
    private func suggestionChip(_ card: LorcanaCard) -> some View {
        HStack(spacing: 8) {
            AsyncImage(url: card.bestImageUrl()) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 24, height: 34)
            .clipShape(.rect(cornerRadius: 3))

            Text("Talking about **\(card.name)**?")
                .font(.caption)
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            Button {
                if attachedCards.count < 4 {
                    attachedCards.append(card)
                }
                suggestedCard = nil
            } label: {
                Label("Attach", systemImage: "paperclip")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.lorcanaDark)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.lorcanaGold))
            }

            Button("Dismiss", systemImage: "xmark.circle.fill") {
                suggestedCard = nil
            }
            .labelStyle(.iconOnly)
            .font(.caption)
            .foregroundStyle(.gray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.lorcanaDark.opacity(0.95))
    }

    private var attachedCardsPreview: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(attachedCards, id: \.id) { card in
                    HStack(spacing: 6) {
                        AsyncImage(url: card.bestImageUrl()) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 24, height: 34)
                        .clipShape(.rect(cornerRadius: 3))

                        Text(card.name)
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Button("Remove", systemImage: "xmark.circle.fill") {
                            attachedCards.removeAll { $0.id == card.id }
                        }
                        .labelStyle(.iconOnly)
                        .font(.caption2)
                        .foregroundStyle(.gray)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.lorcanaDark.opacity(0.9))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.lorcanaGold.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .padding(.vertical, 8)
        .background(Color.lorcanaDark.opacity(0.95))
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let cardsToSend = attachedCards
        inputText = ""
        attachedCards = []
        Analytics.send(.aiRulesQuestionAsked)
        service.send(text, cardContexts: cardsToSend)
    }
}

// MARK: - Checking Content

struct RulesCheckingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.lorcanaGold)

            Text("Checking availability...")
                .font(.headline)
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Unavailable Content

struct RulesUnavailableView: View {
    let availability: RulesAssistantAvailability
    let onRetry: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 60)

                Image(systemName: availability.systemImage)
                    .font(.system(size: 80))
                    .foregroundStyle(.gray)

                VStack(spacing: 12) {
                    Text(availability.title)
                        .font(.title2)
                        .bold()
                        .foregroundStyle(.white)

                    Text(availability.description)
                        .font(.body)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button("Try Again", systemImage: "arrow.clockwise", action: onRetry)
                    .font(.headline)
                    .foregroundStyle(.black)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.lorcanaGold)
                    )
                    .padding(.top, 8)

                VStack(spacing: 16) {
                    Text("In the meantime, you can find the official rules at:")
                        .font(.subheadline)
                        .foregroundStyle(.gray)

                    Link(destination: URL(string: "https://www.disneylorcana.com/en-US/resources#tabcontent-4")!) {
                        Label("Official Lorcana Rules", systemImage: "book.fill")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.lorcanaGold)
                            )
                    }
                }
                .padding(.top, 20)

                Spacer()
            }
        }
    }
}

// MARK: - Chat History View

struct ChatHistoryView: View {
    let service: RulesAssistantService
    @Binding var isPresented: Bool
    @State private var chatToRename: SavedChat?
    @State private var renameText = ""
    @State private var chatToDelete: SavedChat?

    var body: some View {
        NavigationStack {
            ZStack {
                LorcanaBackground()

                if service.savedChats.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 60))
                            .foregroundStyle(.gray)

                        Text("No Saved Chats")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text("Your conversations will appear here")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                    }
                } else {
                    List {
                        if service.savedChats.contains(where: { $0.isPinned }) {
                            Section {
                                ForEach(service.savedChats.filter { $0.isPinned }) { chat in
                                    chatRow(chat)
                                }
                            } header: {
                                Label("Pinned", systemImage: "pin.fill")
                                    .foregroundStyle(.lorcanaGold)
                            }
                            .listRowBackground(Color.lorcanaDark.opacity(0.6))
                        }

                        Section {
                            ForEach(service.savedChats.filter { !$0.isPinned }) { chat in
                                chatRow(chat)
                            }
                        } header: {
                            if service.savedChats.contains(where: { $0.isPinned }) {
                                Text("Recent")
                                    .foregroundStyle(.lorcanaGold)
                            }
                        }
                        .listRowBackground(Color.lorcanaDark.opacity(0.6))
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Chat History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundStyle(.lorcanaGold)
                }
            }
            .alert("Rename Chat", isPresented: Binding(
                get: { chatToRename != nil },
                set: { if !$0 { chatToRename = nil } }
            )) {
                TextField("Chat title", text: $renameText)
                Button("Save") {
                    if let chat = chatToRename {
                        service.renameChat(chat, to: renameText)
                    }
                    chatToRename = nil
                    renameText = ""
                }
                Button("Cancel", role: .cancel) {
                    chatToRename = nil
                    renameText = ""
                }
            }
            .alert("Delete Chat?", isPresented: Binding(
                get: { chatToDelete != nil },
                set: { if !$0 { chatToDelete = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let chat = chatToDelete {
                        service.deleteChat(chat)
                    }
                    chatToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    chatToDelete = nil
                }
            } message: {
                Text("This cannot be undone.")
            }
        }
    }

    @ViewBuilder
    private func chatRow(_ chat: SavedChat) -> some View {
        Button {
            service.loadChat(chat)
            isPresented = false
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(chat.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer()

                    Text(chat.updatedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }

                Text("\(chat.messages.count) messages")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .padding(.vertical, 4)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                chatToDelete = chat
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                renameText = chat.title
                chatToRename = chat
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                service.togglePinChat(chat)
            } label: {
                Label(chat.isPinned ? "Unpin" : "Pin", systemImage: chat.isPinned ? "pin.slash" : "pin")
            }
            .tint(.lorcanaGold)
        }
        .contextMenu {
            Button {
                service.loadChat(chat)
                isPresented = false
            } label: {
                Label("Open", systemImage: "bubble.left")
            }

            Button {
                service.togglePinChat(chat)
            } label: {
                Label(chat.isPinned ? "Unpin" : "Pin", systemImage: chat.isPinned ? "pin.slash" : "pin")
            }

            Button {
                renameText = chat.title
                chatToRename = chat
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                chatToDelete = chat
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Markdown Rendering

/// Lightweight block-level markdown renderer for assistant replies. Handles headings, bullet
/// lists, and inline emphasis — block elements that `Text(AttributedString)` alone can't show.
struct MarkdownContentView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Position-based identity keeps existing blocks stable while streaming appends
            // text — fresh UUIDs here made SwiftUI rebuild every block on every chunk,
            // which visibly jittered the transcript.
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                block.view
            }
        }
    }

    private var blocks: [MarkdownBlock] {
        text
            .components(separatedBy: "\n")
            .map { MarkdownBlock(line: $0) }
            .filter { !$0.isBlank }
    }
}

private struct MarkdownBlock {
    let line: String

    var isBlank: Bool { line.trimmingCharacters(in: .whitespaces).isEmpty }

    @ViewBuilder
    var view: some View {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if let heading = heading(for: trimmed) {
            heading
        } else if let bullet = bulletBody(for: trimmed) {
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .foregroundStyle(.lorcanaGold)
                Self.inline(bullet)
                    .tint(.lorcanaGold)
            }
        } else {
            Self.inline(trimmed)
                .tint(.lorcanaGold)
        }
    }

    private func heading(for string: String) -> Text? {
        if string.hasPrefix("### ") {
            return Self.inline(String(string.dropFirst(4))).font(.subheadline).bold()
                .foregroundStyle(.lorcanaGold)
        }
        if string.hasPrefix("## ") {
            return Self.inline(String(string.dropFirst(3))).font(.headline).bold()
                .foregroundStyle(.lorcanaGold)
        }
        if string.hasPrefix("# ") {
            return Self.inline(String(string.dropFirst(2))).font(.title3).bold()
                .foregroundStyle(.lorcanaGold)
        }
        return nil
    }

    private func bulletBody(for string: String) -> String? {
        for prefix in ["- ", "* ", "• "] where string.hasPrefix(prefix) {
            return String(string.dropFirst(prefix.count))
        }
        return nil
    }

    static func inline(_ string: String) -> Text {
        if let attributed = try? AttributedString(
            markdown: string,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attributed)
        }
        return Text(string)
    }
}

// MARK: - Transcript Views

/// The user's question: a compact trailing bubble, with thumbnails of any attached cards
/// above it so the transcript remembers which cards each question was about.
struct UserQuestionView: View {
    let message: RulesMessage

    /// Card being viewed fullscreen — tapping a thumbnail opens the full card so the user
    /// can fact-check the assistant against the actual card text.
    @State private var viewingCard: LorcanaCard?

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if let cards = message.attachedCards, !cards.isEmpty {
                HStack(spacing: 8) {
                    ForEach(cards, id: \.id) { card in
                        Button {
                            viewingCard = resolve(card)
                        } label: {
                            AttachedCardThumbnail(card: card)
                        }
                        .accessibilityLabel("View \(card.name) full size")
                    }
                }
            }

            Text(message.content)
                .font(.body)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.lorcanaGold.opacity(0.35))
                )
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.leading, 48)
        .fullScreenCover(item: $viewingCard) { card in
            FullscreenCardViewer(card: card)
        }
    }

    /// Resolves the stored summary back to a full card via the local database; falls back to
    /// a minimal card built from the summary (still shows the image) for cards this app
    /// version doesn't know.
    private func resolve(_ card: RulesMessage.AttachedCard) -> LorcanaCard {
        if let known = SetsDataManager.shared.getAllCards().first(where: { $0.id == card.id }) {
            return known
        }
        return LorcanaCard(
            id: card.id,
            name: card.name,
            cost: 0,
            type: "",
            rarity: .common,
            setName: "",
            imageUrl: card.imageUrl
        )
    }
}

/// A small framed card image identifying an attached card in the transcript.
struct AttachedCardThumbnail: View {
    let card: RulesMessage.AttachedCard

    var body: some View {
        VStack(spacing: 3) {
            AsyncImage(url: URL(string: card.imageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 56, height: 78)
            .clipShape(.rect(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.lorcanaGold.opacity(0.5), lineWidth: 1)
            )

            Text(card.name.components(separatedBy: " - ").first ?? card.name)
                .font(.caption2)
                .foregroundStyle(.gray)
                .lineLimit(1)
                .frame(width: 60)
        }
    }
}

/// An assistant answer: a full-width panel with a gold accent rule, styled like app
/// content rather than a chat bubble.
struct AssistantAnswerView: View {
    let content: String
    var isError: Bool = false
    /// Disabled while streaming — live selection machinery on rapidly changing text
    /// causes re-layout churn.
    var selectable: Bool = true

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: isError
                            ? [.red.opacity(0.8), .red.opacity(0.2)]
                            : [.lorcanaGold, .lorcanaGold.opacity(0.15)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 3)

            if selectable {
                markdownContent
                    .textSelection(.enabled)
            } else {
                markdownContent
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isError ? Color.red.opacity(0.12) : Color.lorcanaDark.opacity(0.6))
        )
    }

    private var markdownContent: some View {
        MarkdownContentView(text: content)
            .font(.body)
            .foregroundStyle(.white)
    }
}

// MARK: - Streaming Bubble

struct StreamingBubble: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AssistantAnswerView(content: content, selectable: false)

            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.6)
                    .tint(.lorcanaGold)
                Text("Consulting the rules…")
                    .font(.caption2)
                    .foregroundStyle(.gray)
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var dotOpacities: [Double] = [0.3, 0.3, 0.3]

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "book.pages")
                .font(.subheadline)
                .foregroundStyle(.lorcanaGold)

            Text("Consulting the rules")
                .font(.subheadline)
                .foregroundStyle(.gray)

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.lorcanaGold)
                        .frame(width: 6, height: 6)
                        .opacity(dotOpacities[index])
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.lorcanaDark.opacity(0.6))
        )
        .onAppear {
            animateDots()
        }
    }

    private func animateDots() {
        for index in 0..<3 {
            withAnimation(
                .easeInOut(duration: 0.4)
                .repeatForever(autoreverses: true)
                .delay(Double(index) * 0.15)
            ) {
                dotOpacities[index] = 1.0
            }
        }
    }
}

// MARK: - Card Search Sheet

struct CardSearchSheet: View {
    @StateObject private var dataManager = SetsDataManager.shared
    @Binding var attachedCards: [LorcanaCard]
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var searchResults: [LorcanaCard] = []
    @State private var searchTask: Task<Void, Never>?

    /// The user's collection, newest first, so cards can be attached without typing.
    @Query(sort: \CollectedCard.dateAdded, order: .reverse) private var collectedCards: [CollectedCard]

    private let maxAttachedCards = 4

    private func isCardAttached(_ card: LorcanaCard) -> Bool {
        attachedCards.contains { $0.id == card.id }
    }

    /// Recently collected cards, deduplicated across variants (a foil and normal of the
    /// same card read as one entry for rules purposes).
    private var recentCollectionCards: [LorcanaCard] {
        var seen = Set<String>()
        var cards: [LorcanaCard] = []
        for collected in collectedCards where !collected.isWishlisted {
            guard seen.insert(collected.name).inserted else { continue }
            cards.append(collected.toLorcanaCard)
            if cards.count >= 30 { break }
        }
        return cards
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LorcanaBackground()

                VStack(spacing: 0) {
                    if !attachedCards.isEmpty {
                        attachedSummary
                    }

                    searchField

                    if !searchText.isEmpty && searchResults.isEmpty {
                        noResults
                    } else if !searchText.isEmpty {
                        resultsList
                    } else if !recentCollectionCards.isEmpty {
                        collectionList
                    } else {
                        emptyState
                    }
                }
            }
            .navigationTitle("Attach Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundStyle(.lorcanaGold)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if !attachedCards.isEmpty {
                        Button("Done") {
                            isPresented = false
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(.lorcanaGold)
                    }
                }
            }
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }

    private var attachedSummary: some View {
        VStack(spacing: 6) {
            HStack {
                Text("\(attachedCards.count) card\(attachedCards.count == 1 ? "" : "s") attached")
                    .font(.caption)
                    .foregroundStyle(.lorcanaGold)
                Spacer()
                if attachedCards.count > 1 {
                    Button("Clear All") {
                        attachedCards.removeAll()
                    }
                    .font(.caption)
                    .foregroundStyle(.gray)
                }
            }

            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(attachedCards, id: \.id) { card in
                        HStack(spacing: 4) {
                            Text(card.name)
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Button("Remove", systemImage: "xmark.circle.fill") {
                                attachedCards.removeAll { $0.id == card.id }
                            }
                            .labelStyle(.iconOnly)
                            .font(.caption2)
                            .foregroundStyle(.gray)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.lorcanaGold.opacity(0.2))
                        )
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.lorcanaDark.opacity(0.95))
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.gray)

            TextField("Search for a card...", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button("Clear", systemImage: "xmark.circle.fill") {
                    searchText = ""
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(.gray)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.lorcanaDark.opacity(0.8))
        )
        .padding()
        .onChange(of: searchText) { _, newValue in
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(for: .milliseconds(200))
                if !Task.isCancelled {
                    performSearch(query: newValue)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 50))
                .foregroundStyle(.gray)
            Text(attachedCards.isEmpty ? "Search for a card to attach" : "Search for another card")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Attach up to \(maxAttachedCards) cards to ask about interactions")
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
    }

    private var noResults: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundStyle(.gray)
            Text("No cards found")
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
        }
    }

    private var resultsList: some View {
        List(searchResults, id: \.id) { card in
            cardRow(card)
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
    }

    private var collectionList: some View {
        List {
            Section {
                ForEach(recentCollectionCards, id: \.id) { card in
                    cardRow(card)
                }
            } header: {
                Text("From Your Collection")
                    .foregroundStyle(.lorcanaGold)
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
    }

    @ViewBuilder
    private func cardRow(_ card: LorcanaCard) -> some View {
        let alreadyAttached = isCardAttached(card)
        Button {
            if alreadyAttached {
                attachedCards.removeAll { $0.id == card.id }
            } else if attachedCards.count < maxAttachedCards {
                attachedCards.append(card)
            }
        } label: {
            HStack(spacing: 12) {
                AsyncImage(url: card.bestImageUrl()) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 40, height: 56)
                .clipShape(.rect(cornerRadius: 4))

                VStack(alignment: .leading, spacing: 4) {
                    Text(card.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(card.type)
                            .font(.caption)
                            .foregroundStyle(.gray)

                        Text("•")
                            .foregroundStyle(.gray)

                        Text("\(card.cost) ink")
                            .font(.caption)
                            .foregroundStyle(.lorcanaGold)
                    }
                }

                Spacer()

                if alreadyAttached {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.lorcanaGold)
                } else if attachedCards.count >= maxAttachedCards {
                    Image(systemName: "circle")
                        .foregroundStyle(.gray.opacity(0.3))
                } else {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.lorcanaGold)
                }
            }
            .padding(.vertical, 4)
            .opacity((!alreadyAttached && attachedCards.count >= maxAttachedCards) ? 0.5 : 1.0)
        }
        .disabled(!alreadyAttached && attachedCards.count >= maxAttachedCards)
        .listRowBackground(
            alreadyAttached
                ? Color.lorcanaGold.opacity(0.1)
                : Color.lorcanaDark.opacity(0.6)
        )
    }

    private func performSearch(query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        searchResults = Array(dataManager.searchCards(query: query).prefix(50))
    }
}

#Preview {
    RulesAssistantView()
}
