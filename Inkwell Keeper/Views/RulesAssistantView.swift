//
//  RulesAssistantView.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 1/30/26.
//

import SwiftUI

struct RulesAssistantView: View {
    @State private var service = RulesAssistantService.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var inputText = ""
    @State private var showingHistory = false
    @State private var showingSaveAlert = false
    @State private var showingCardSearch = false
    @State private var chatTitleInput = ""
    @State private var attachedCards: [LorcanaCard] = []
    @FocusState private var isInputFocused: Bool

    var initialCard: LorcanaCard?

    var body: some View {
        NavigationStack {
            ZStack {
                LorcanaBackground()

                if !subscriptionManager.isSubscribed {
                    RulesPaywallView()
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
                ToolbarItem(placement: .navigationBarLeading) {
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
                }
            }
            .sheet(isPresented: $showingHistory) {
                ChatHistoryView(service: service, isPresented: $showingHistory)
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
            if let card = initialCard, service.messages.isEmpty, subscriptionManager.isSubscribed {
                service.send("Tell me about the rules for this card and how to use it effectively.", cardContexts: [card])
            }
        }
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
                RulesWelcomeView(service: service, showingHistory: $showingHistory)
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

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(service.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    if !service.currentStreamingContent.isEmpty {
                        StreamingBubble(content: service.currentStreamingContent)
                            .id("streaming")
                    }

                    if service.isLoading && service.currentStreamingContent.isEmpty {
                        TypingIndicator()
                            .id("typing")
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
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: service.messages.count) {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: service.currentStreamingContent) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
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

// MARK: - Input Bar

struct RulesInputBar: View {
    let service: RulesAssistantService
    @Binding var inputText: String
    @Binding var attachedCards: [LorcanaCard]
    @Binding var showingCardSearch: Bool
    @FocusState.Binding var isInputFocused: Bool

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !service.isLoading
    }

    var body: some View {
        VStack(spacing: 0) {
            if !attachedCards.isEmpty {
                attachedCardsPreview
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
            ForEach(blocks) { block in
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

private struct MarkdownBlock: Identifiable {
    let id = UUID()
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
        }
        if string.hasPrefix("## ") {
            return Self.inline(String(string.dropFirst(3))).font(.headline).bold()
        }
        if string.hasPrefix("# ") {
            return Self.inline(String(string.dropFirst(2))).font(.title3).bold()
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

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: RulesMessage

    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                if message.isUser {
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
                } else {
                    MarkdownContentView(text: message.content)
                        .font(.body)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.lorcanaDark.opacity(0.85))
                        )
                        .textSelection(.enabled)
                }

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.gray.opacity(0.8))
                    .padding(.horizontal, 4)
            }

            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
    }
}

// MARK: - Streaming Bubble

struct StreamingBubble: View {
    let content: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                MarkdownContentView(text: content)
                    .font(.body)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.lorcanaDark.opacity(0.85))
                    )

                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .tint(.lorcanaGold)
                    Text("Thinking...")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
                .padding(.horizontal, 4)
            }

            Spacer(minLength: 60)
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var dotOpacities: [Double] = [0.3, 0.3, 0.3]

    var body: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.lorcanaGold)
                        .frame(width: 8, height: 8)
                        .opacity(dotOpacities[index])
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.lorcanaDark.opacity(0.85))
            )
            .onAppear {
                animateDots()
            }

            Spacer()
        }
    }

    private func animateDots() {
        for i in 0..<3 {
            withAnimation(
                .easeInOut(duration: 0.4)
                .repeatForever(autoreverses: true)
                .delay(Double(i) * 0.15)
            ) {
                dotOpacities[i] = 1.0
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

    private let maxAttachedCards = 4

    private func isCardAttached(_ card: LorcanaCard) -> Bool {
        attachedCards.contains { $0.id == card.id }
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

                    if searchText.isEmpty {
                        emptyState
                    } else if searchResults.isEmpty {
                        noResults
                    } else {
                        resultsList
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
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
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
