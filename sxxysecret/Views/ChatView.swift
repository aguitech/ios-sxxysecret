import SwiftUI

// MARK: - Conversation List
struct ChatListView: View {
    @State private var conversations: [Conversation] = []
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        ZStack {
            Theme.bgPrimary.ignoresSafeArea()
            VStack(spacing: 0) {
                if isLoading {
                    Spacer()
                    ProgressView().tint(Theme.gold)
                    Spacer()
                } else if conversations.isEmpty {
                    Spacer()
                    EmptyStateCard(
                        icon: "bubble.left.and.bubble.right",
                        title: "Sin conversaciones",
                        message: "Inicia una conversación con un miembro del equipo"
                    )
                    .padding(20)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(conversations) { conv in
                                NavigationLink {
                                    ChatDetailView(conversation: conv)
                                } label: {
                                    ConversationRow(conversation: conv)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .refreshable { await load() }
                }
            }
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Theme.bgPrimary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            self.conversations = try await APIClient.shared.listConversations()
            self.error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct ConversationRow: View {
    let conversation: Conversation

    var displayName: String {
        conversation.name ?? conversation.other?.name ?? "Conversación"
    }

    var lastText: String {
        conversation.lastMessage?.text ?? "—"
    }

    var when: String {
        guard let d = conversation.lastMessageAt else { return "" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: d, relativeTo: .now)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Theme.gold.opacity(0.2))
                    .frame(width: 50, height: 50)
                Text(initials(displayName))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.gold)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(when)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                }
                Text(lastText)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }

            if let unread = conversation.unreadCount, unread > 0 {
                Text("\(unread)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.gold)
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .background(Theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }
}

// MARK: - Chat Detail
struct ChatDetailView: View {
    let conversation: Conversation
    @EnvironmentObject var auth: AuthService
    @State private var messages: [ChatMessage] = []
    @State private var input: String = ""
    @State private var isLoading = true
    @State private var isSending = false
    @State private var error: String?
    @FocusState private var inputFocused: Bool

    var title: String {
        conversation.name ?? conversation.other?.name ?? "Conversación"
    }

    var body: some View {
        ZStack {
            Theme.bgPrimary.ignoresSafeArea()
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView().tint(Theme.gold).frame(maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(messages) { msg in
                                    MessageBubble(message: msg, isMe: msg.senderUser?.id == auth.user?.id)
                                        .id(msg.id)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .onChange(of: messages.count) { _, _ in
                            if let last = messages.last {
                                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                        .onAppear {
                            if let last = messages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                if let err = error {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.error)
                        .padding(.horizontal, 16)
                }

                // Composer
                HStack(spacing: 10) {
                    TextField("Mensaje…", text: $input, axis: .vertical)
                        .lineLimit(1...4)
                        .focused($inputFocused)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Theme.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .foregroundStyle(Theme.textPrimary)
                        .tint(Theme.gold)

                    Button {
                        Task { await send() }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(input.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.bgCard : Theme.gold)
                                .frame(width: 44, height: 44)
                            Image(systemName: "paperplane.fill")
                                .foregroundStyle(input.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.textTertiary : .black)
                        }
                    }
                    .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Theme.bgPrimary)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.bgPrimary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            self.messages = try await APIClient.shared.listMessages(conversationId: conversation.id)
            self.error = nil
            // Mark as read
            _ = try? await APIClient.shared.requestNoBody(
                "POST", "/chat/conversations/\(conversation.id)/read"
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func send() async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSending = true
        defer { isSending = false }
        input = ""
        do {
            let sent = try await APIClient.shared.sendMessage(conversationId: conversation.id, text: text)
            self.messages.append(sent)
            self.error = nil
        } catch {
            self.error = error.localizedDescription
            input = text  // restore so user can retry
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    let isMe: Bool

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: message.createdAt)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isMe { Spacer(minLength: 40) }

            VStack(alignment: isMe ? .trailing : .leading, spacing: 2) {
                Text(message.text)
                    .font(.system(size: 15))
                    .foregroundStyle(isMe ? .black : Theme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isMe ? Theme.gold : Theme.bgCard)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                Text(timeString)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, 4)
            }

            if !isMe { Spacer(minLength: 40) }
        }
    }
}
