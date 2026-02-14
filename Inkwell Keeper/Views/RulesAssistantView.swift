//
//  RulesAssistantView.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 1/30/26.
//

import SwiftUI

struct RulesAssistantView: View {
    @StateObject private var service = RulesAssistantService.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var dataManager = SetsDataManager.shared
    @State private var inputText = ""
    @State private var showingHistory = false
    @State private var showingSaveAlert = false
    @State private var showingCardSearch = false
    @State private var chatTitleInput = ""
    @State private var attachedCard: LorcanaCard?
    @FocusState private var isInputFocused: Bool

    var initialCard: LorcanaCard?

    var body: some View {
        NavigationView {
            ZStack {
                LorcanaBackground()

                if !subscriptionManager.isSubscribed {
                    SubscriptionPaywallView()
                } else if service.availability == .available {
                    availableContent
                } else if service.availability == .checking {
                    checkingContent
                } else {
                    unavailableContent
                }
            }
            .navigationTitle("Rules Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if subscriptionManager.isSubscribed && service.availability == .available {
                        Button(action: { showingHistory = true }) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.lorcanaGold)
                        }
                    }
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if subscriptionManager.isSubscribed && service.availability == .available {
                        if !service.messages.isEmpty {
                            Button(action: { showingSaveAlert = true }) {
                                Image(systemName: "square.and.arrow.down")
                                    .foregroundColor(.lorcanaGold)
                            }

                            Button(action: { service.startNewChat() }) {
                                Image(systemName: "plus.bubble")
                                    .foregroundColor(.lorcanaGold)
                            }
                        }
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
            if subscriptionManager.isSubscribed, let card = initialCard, service.messages.isEmpty {
                Task {
                    await service.sendMessage("Tell me about the rules for this card and how to use it effectively.", cardContext: card)
                }
            }
        }
    }

    // MARK: - Available Content
    private var availableContent: some View {
        VStack(spacing: 0) {
            if service.messages.isEmpty && service.currentStreamingContent.isEmpty {
                welcomeScreen
            } else {
                chatMessages
            }

            inputBar
        }
    }

    // MARK: - Welcome Screen
    private var welcomeScreen: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 20)

                Image(systemName: "book.circle.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.lorcanaGold)

                VStack(spacing: 8) {
                    Text("Lorcana Rules Assistant")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Ask about rules, keywords, or card interactions")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Try asking:")
                        .font(.headline)
                        .foregroundColor(.lorcanaGold)
                        .padding(.horizontal)

                    ForEach(RulesAssistantService.suggestedQuestions, id: \.self) { question in
                        Button(action: {
                            Task {
                                await service.sendMessage(question)
                            }
                        }) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.lorcanaGold)
                                    .font(.caption)

                                Text(question)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.leading)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.lorcanaGold.opacity(0.5))
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

                // Recent chats section
                if !service.savedChats.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Recent Chats")
                                .font(.headline)
                                .foregroundColor(.lorcanaGold)

                            Spacer()

                            Button("See All") {
                                showingHistory = true
                            }
                            .font(.caption)
                            .foregroundColor(.lorcanaGold.opacity(0.8))
                        }
                        .padding(.horizontal)

                        ForEach(service.savedChats.prefix(3)) { chat in
                            Button(action: { service.loadChat(chat) }) {
                                HStack {
                                    if chat.isPinned {
                                        Image(systemName: "pin.fill")
                                            .foregroundColor(.lorcanaGold)
                                            .font(.caption)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(chat.title)
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                            .lineLimit(1)

                                        Text(chat.updatedAt, style: .relative)
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
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

                Spacer()
                    .frame(height: 20)
            }
        }
    }

    // MARK: - Chat Messages
    private var chatMessages: some View {
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

                    // Bottom padding for keyboard
                    Color.clear.frame(height: 8)
                        .id("bottom")
                }
                .padding(.horizontal)
                .padding(.top, 12)
            }
            .onChange(of: service.messages.count) { _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: service.currentStreamingContent) { _ in
                proxy.scrollTo("bottom", anchor: .bottom)
            }
            .onTapGesture {
                isInputFocused = false
            }
        }
    }

    // MARK: - Input Bar
    private var inputBar: some View {
        VStack(spacing: 0) {
            // Attached card preview
            if let card = attachedCard {
                HStack(spacing: 10) {
                    AsyncImage(url: card.bestImageUrl()) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 30, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text("Card attached")
                            .font(.caption2)
                            .foregroundColor(.lorcanaGold)
                    }

                    Spacer()

                    Button(action: { attachedCard = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.lorcanaDark.opacity(0.95))
            }

            Divider()
                .background(Color.lorcanaGold.opacity(0.3))

            HStack(spacing: 10) {
                // Attach card button
                Button(action: { showingCardSearch = true }) {
                    Image(systemName: attachedCard != nil ? "rectangle.stack.badge.checkmark" : "rectangle.stack.badge.plus")
                        .font(.system(size: 20))
                        .foregroundColor(attachedCard != nil ? .lorcanaGold : .gray)
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
                    .foregroundColor(.white)
                    .focused($isInputFocused)
                    .lineLimit(1...4)
                    .submitLabel(.send)
                    .onSubmit {
                        sendMessage()
                    }

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(canSend ? .lorcanaGold : .gray.opacity(0.5))
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.lorcanaDark.opacity(0.98))
        }
        .sheet(isPresented: $showingCardSearch) {
            CardSearchSheet(selectedCard: $attachedCard, isPresented: $showingCardSearch)
        }
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !service.isLoading
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let cardToSend = attachedCard
        inputText = ""
        attachedCard = nil

        Task {
            await service.sendMessage(text, cardContext: cardToSend)
        }
    }

    // MARK: - Checking Content
    private var checkingContent: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.lorcanaGold)

            Text("Checking availability...")
                .font(.headline)
                .foregroundColor(.white)
        }
    }

    // MARK: - Unavailable Content
    private var unavailableContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 60)

                Image(systemName: service.availability.systemImage)
                    .font(.system(size: 80))
                    .foregroundColor(.gray)

                VStack(spacing: 12) {
                    Text(service.availability.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text(service.availability.description)
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button(action: {
                    service.checkAvailability()
                }) {
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
                .padding(.top, 8)

                VStack(spacing: 16) {
                    Text("In the meantime, you can find the official rules at:")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    Link(destination: URL(string: "https://www.disneylorcana.com/en-US/resources#tabcontent-4")!) {
                        HStack {
                            Image(systemName: "book.fill")
                            Text("Official Lorcana Rules")
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
                .padding(.top, 20)

                Spacer()
            }
        }
    }
}

// MARK: - Chat History View
struct ChatHistoryView: View {
    @ObservedObject var service: RulesAssistantService
    @Binding var isPresented: Bool
    @State private var chatToRename: SavedChat?
    @State private var renameText = ""
    @State private var chatToDelete: SavedChat?

    var body: some View {
        NavigationView {
            ZStack {
                LorcanaBackground()

                if service.savedChats.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)

                        Text("No Saved Chats")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text("Your conversations will appear here")
                            .font(.subheadline)
                            .foregroundColor(.gray)
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
                                    .foregroundColor(.lorcanaGold)
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
                                    .foregroundColor(.lorcanaGold)
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
                    .foregroundColor(.lorcanaGold)
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
        Button(action: {
            service.loadChat(chat)
            isPresented = false
        }) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(chat.title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()

                    Text(chat.updatedAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Text("\(chat.messages.count) messages")
                    .font(.caption)
                    .foregroundColor(.gray)
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

// MARK: - Markdown Helper
private func markdownText(_ string: String) -> Text {
    if let attributed = try? AttributedString(markdown: string, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
        return Text(attributed)
    }
    return Text(string)
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
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.lorcanaGold.opacity(0.35))
                        )
                        .textSelection(.enabled)
                } else {
                    markdownText(message.content)
                        .font(.body)
                        .foregroundColor(.white)
                        .tint(.lorcanaGold)
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
                    .foregroundColor(.gray.opacity(0.8))
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
                markdownText(content)
                    .font(.body)
                    .foregroundColor(.white)
                    .tint(.lorcanaGold)
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
                        .foregroundColor(.gray)
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
    @Binding var selectedCard: LorcanaCard?
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var searchResults: [LorcanaCard] = []
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationView {
            ZStack {
                LorcanaBackground()

                VStack(spacing: 0) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)

                        TextField("Search for a card...", text: $searchText)
                            .textFieldStyle(.plain)
                            .foregroundColor(.white)
                            .autocorrectionDisabled()

                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.lorcanaDark.opacity(0.8))
                    )
                    .padding()
                    .onChange(of: searchText) { newValue in
                        searchTask?.cancel()
                        searchTask = Task {
                            try? await Task.sleep(nanoseconds: 200_000_000)
                            if !Task.isCancelled {
                                await MainActor.run {
                                    performSearch(query: newValue)
                                }
                            }
                        }
                    }

                    if searchText.isEmpty {
                        // Empty state
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "rectangle.stack.badge.plus")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("Search for a card to attach")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("The AI will use the card's details to answer your question")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            Spacer()
                        }
                    } else if searchResults.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("No cards found")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                        }
                    } else {
                        // Results list
                        List(searchResults, id: \.id) { card in
                            Button(action: {
                                selectedCard = card
                                isPresented = false
                            }) {
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
                                    .clipShape(RoundedRectangle(cornerRadius: 4))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(card.name)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .lineLimit(1)

                                        HStack(spacing: 8) {
                                            Text(card.type)
                                                .font(.caption)
                                                .foregroundColor(.gray)

                                            Text("•")
                                                .foregroundColor(.gray)

                                            Text("\(card.cost) ink")
                                                .font(.caption)
                                                .foregroundColor(.lorcanaGold)
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: "plus.circle")
                                        .foregroundColor(.lorcanaGold)
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(Color.lorcanaDark.opacity(0.6))
                        }
                        .scrollContentBackground(.hidden)
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("Attach Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.lorcanaGold)
                }
            }
        }
        .onDisappear {
            searchTask?.cancel()
        }
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
