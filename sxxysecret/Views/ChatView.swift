import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Conversation List
struct ChatListView: View {
    @State private var conversations: [Conversation] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var showNewChat = false
    @State private var searchEmail = ""
    @State private var isStartingChat = false
    @State private var navigateToConversation: Conversation?

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
                        message: "Toca + para iniciar un chat por email"
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showNewChat = true } label: {
                    Image(systemName: "square.and.pencil")
                        .foregroundStyle(Theme.gold)
                }
            }
        }
        .sheet(isPresented: $showNewChat) {
            NewChatSheet(onStart: { email in
                Task { await startChat(with: email) }
            })
            .presentationDetents([.medium])
        }
        .navigationDestination(item: $navigateToConversation) { conv in
            ChatDetailView(conversation: conv)
        }
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

    private func startChat(with email: String) async {
        isStartingChat = true
        defer { isStartingChat = false }
        showNewChat = false
        do {
            let conv = try await APIClient.shared.openConversationByEmail(email: email)
            // Refetch list and navigate
            await load()
            // Try to find it in the fresh list (the backend dedupes by pair key)
            if let found = conversations.first(where: { $0.id == conv.id }) ?? Optional(conv) {
                navigateToConversation = found
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - New Chat Sheet (email-based)
struct NewChatSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var email: String = ""
    @State private var error: String?
    @State private var isValidating = false
    @State private var foundUser: User?

    let onStart: (String) -> Void

    var body: some View {
        ZStack {
            Theme.bgPrimary.ignoresSafeArea()
            VStack(spacing: 20) {
                Capsule().fill(Theme.textTertiary.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Nuevo chat")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)

                    Text("Escribe el email de la persona con quien quieres chatear.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                            .textCase(.uppercase)
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundStyle(Theme.gold)
                            TextField("amigo@empresa.com", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .foregroundStyle(Theme.textPrimary)
                                .tint(Theme.gold)
                                .onChange(of: email) { _, _ in
                                    foundUser = nil
                                    error = nil
                                }
                        }
                        .padding(14)
                        .background(Theme.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if let found = foundUser {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(Theme.gold.opacity(0.2)).frame(width: 44, height: 44)
                                Text(found.initials).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.gold)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(found.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                                Text(found.email).font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.success)
                        }
                        .padding(12)
                        .background(Theme.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if let err = error {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(err).font(.system(size: 13))
                        }
                        .foregroundStyle(Theme.error)
                    }

                    HStack(spacing: 10) {
                        Button {
                            dismiss()
                        } label: {
                            Text("Cancelar")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Theme.bgCard)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        Button {
                            Task { await start() }
                        } label: {
                            HStack(spacing: 6) {
                                if isValidating { ProgressView().tint(.black) }
                                Text(isValidating ? "Buscando…" : "Iniciar chat")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.gold)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(email.trimmingCharacters(in: .whitespaces).isEmpty || isValidating)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .padding(.top, 8)
        }
        .preferredColorScheme(.dark)
    }

    private func start() async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return }
        isValidating = true
        defer { isValidating = false }
        do {
            // Open or fetch the conversation by email
            let conv = try await APIClient.shared.openConversationByEmail(email: trimmed)
            onStart(trimmed)
            _ = conv
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Conversation Row
struct ConversationRow: View {
    let conversation: Conversation

    var displayName: String {
        conversation.name ?? conversation.other?.name ?? "Conversación"
    }

    var lastText: String {
        if let m = conversation.lastMessage, !m.text.isEmpty {
            return m.text
        }
        if let att = conversation.lastMessage?.attachments?.first {
            return att.kind == "image" ? "📷 Imagen" : "📎 \(att.filename)"
        }
        return "—"
    }

    var when: String {
        guard let d = conversation.lastMessageAt else { return "" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: d, relativeTo: .now)
    }

    var body: some View {
        HStack(spacing: 12) {
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
    @State private var pendingAttachments: [PendingAttachment] = []
    @State private var showFilePicker = false
    @State private var showPhotoPicker = false
    @State private var photoSelections: [PhotosPickerItem] = []
    @State private var nextCursor: String?
    @State private var hasMore = false
    @State private var isLoadingMore = false
    @FocusState private var inputFocused: Bool

    var title: String {
        conversation.name ?? conversation.other?.name ?? "Conversación"
    }

    struct PendingAttachment: Identifiable, Equatable {
        let id = UUID()
        let name: String
        let data: Data
        let mimeType: String
        var preview: UIImage? { UIImage(data: data) }
    }

    var body: some View {
        ZStack {
            Theme.bgPrimary.ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if hasMore && !messages.isEmpty {
                                Button {
                                    Task { await loadMore(proxy: proxy) }
                                } label: {
                                    Text(isLoadingMore ? "Cargando…" : "Cargar mensajes anteriores")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Theme.gold)
                                        .padding(.vertical, 8)
                                }
                            }

                            ForEach(messages) { msg in
                                MessageBubble(message: msg, isMe: msg.sender.id == auth.user?.id)
                                    .id(msg.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        if let last = messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }

                if !pendingAttachments.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(pendingAttachments) { att in
                                ZStack(alignment: .topTrailing) {
                                    if let img = att.preview {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 70, height: 70)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    } else {
                                        VStack(spacing: 4) {
                                            Image(systemName: "doc.fill")
                                                .font(.system(size: 20))
                                                .foregroundStyle(Theme.gold)
                                            Text(att.name)
                                                .font(.system(size: 9))
                                                .foregroundStyle(Theme.textPrimary)
                                                .lineLimit(1)
                                                .frame(width: 70)
                                        }
                                        .frame(width: 70, height: 70)
                                        .background(Theme.bgCard)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    Button {
                                        pendingAttachments.removeAll { $0.id == att.id }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.white, .black.opacity(0.7))
                                            .font(.system(size: 18))
                                    }
                                    .offset(x: 6, y: -6)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                    }
                }

                if let err = error {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.error)
                        .padding(.horizontal, 16)
                }

                HStack(spacing: 8) {
                    // Attach button
                    Menu {
                        Button {
                            showPhotoPicker = true
                        } label: {
                            Label("Foto / Video", systemImage: "photo.on.rectangle")
                        }
                        Button {
                            showFilePicker = true
                        } label: {
                            Label("Documento", systemImage: "doc.fill")
                        }
                    } label: {
                        Image(systemName: "paperclip")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.gold)
                            .frame(width: 40, height: 40)
                            .background(Theme.bgCard)
                            .clipShape(Circle())
                    }

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
                                .fill(canSend ? Theme.gold : Theme.bgCard)
                                .frame(width: 40, height: 40)
                            Image(systemName: "paperplane.fill")
                                .foregroundStyle(canSend ? .black : Theme.textTertiary)
                        }
                    }
                    .disabled(!canSend || isSending)
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
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoSelections, maxSelectionCount: 5, matching: .any(of: [.images, .videos]))
        .onChange(of: photoSelections) { _, new in
            Task { await loadPhotoSelections(new) }
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.data], allowsMultipleSelection: true) { result in
            handleFileImport(result)
        }
        .task { await load() }
    }

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pendingAttachments.isEmpty
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await APIClient.shared.listMessages(conversationId: conversation.id)
            self.messages = page.messages
            self.nextCursor = page.nextCursor
            self.hasMore = page.hasMore
            self.error = nil
            // Mark as read (fire and forget)
            _ = try? await APIClient.shared.requestNoBody(
                "POST", "/chat/conversations/\(conversation.id)/read"
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func loadMore(proxy: ScrollViewProxy) async {
        guard let cursor = nextCursor, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await APIClient.shared.listMessages(conversationId: conversation.id, cursor: cursor)
            // Prepend older messages
            self.messages.insert(contentsOf: page.messages, at: 0)
            self.nextCursor = page.nextCursor
            self.hasMore = page.hasMore
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func loadPhotoSelections(_ items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let mime = "image/jpeg"
                let name = "photo_\(Int(Date().timeIntervalSince1970)).jpg"
                await MainActor.run {
                    pendingAttachments.append(PendingAttachment(name: name, data: data, mimeType: mime))
                }
            }
        }
        await MainActor.run { photoSelections.removeAll() }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                let didStart = url.startAccessingSecurityScopedResource()
                defer { if didStart { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url) {
                    let mime = mimeType(for: url)
                    pendingAttachments.append(PendingAttachment(name: url.lastPathComponent, data: data, mimeType: mime))
                }
            }
        case .failure(let err):
            error = err.localizedDescription
        }
    }

    private func mimeType(for url: URL) -> String {
        if let type = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType {
            return type
        }
        return "application/octet-stream"
    }

    private func send() async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !pendingAttachments.isEmpty else { return }
        isSending = true
        defer { isSending = false }

        let attachmentsToSend = pendingAttachments
        let textToSend = text.isEmpty ? nil : text
        input = ""
        pendingAttachments.removeAll()
        error = nil

        do {
            let sent: ChatMessage
            if attachmentsToSend.isEmpty {
                sent = try await APIClient.shared.sendMessage(conversationId: conversation.id, text: text)
            } else {
                let files = attachmentsToSend.map { (name: $0.name, data: $0.data, mimeType: $0.mimeType) }
                sent = try await APIClient.shared.sendMessageWithAttachments(
                    conversationId: conversation.id,
                    text: textToSend,
                    files: files
                )
            }
            self.messages.append(sent)
        } catch {
            self.error = error.localizedDescription
            // Restore input on failure so user can retry
            input = text
            pendingAttachments = attachmentsToSend
        }
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: ChatMessage
    let isMe: Bool

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: message.createdAt)
    }

    private func formatBytes(_ b: Int) -> String {
        if b < 1024 { return "\(b) B" }
        if b < 1024 * 1024 { return "\(b / 1024) KB" }
        return "\(b / (1024*1024)) MB"
    }

    private func fullURL(_ path: String) -> URL? {
        if path.hasPrefix("http") { return URL(string: path) }
        return URL(string: "https://sxxysecret.com" + path)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isMe { Spacer(minLength: 40) }

            VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                // Attachments (images inline)
                if let atts = message.attachments, !atts.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(atts) { att in
                            if att.kind == "image", let url = fullURL(att.url) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let img):
                                        img.resizable()
                                            .scaledToFill()
                                            .frame(maxWidth: 240, maxHeight: 240)
                                            .clipShape(RoundedRectangle(cornerRadius: 14))
                                    case .failure:
                                        Image(systemName: "photo")
                                            .font(.system(size: 32))
                                            .foregroundStyle(Theme.textTertiary)
                                            .frame(width: 120, height: 120)
                                            .background(Theme.bgCard)
                                            .clipShape(RoundedRectangle(cornerRadius: 14))
                                    default:
                                        ProgressView()
                                            .frame(width: 120, height: 120)
                                    }
                                }
                            } else {
                                HStack(spacing: 10) {
                                    Image(systemName: att.kind == "video" ? "play.rectangle.fill" : "doc.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(isMe ? .black : Theme.gold)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(att.filename)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(isMe ? .black : Theme.textPrimary)
                                            .lineLimit(1)
                                        if let s = att.size {
                                            Text(formatBytes(s))
                                                .font(.system(size: 11))
                                                .foregroundStyle(isMe ? .black.opacity(0.7) : Theme.textTertiary)
                                        }
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(isMe ? Theme.gold.opacity(0.3) : Theme.bgCard)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }

                if !message.text.isEmpty {
                    Text(message.text)
                        .font(.system(size: 15))
                        .foregroundStyle(isMe ? .black : Theme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(isMe ? Theme.gold : Theme.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }

                Text(timeString)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, 4)
            }

            if !isMe { Spacer(minLength: 40) }
        }
    }
}
