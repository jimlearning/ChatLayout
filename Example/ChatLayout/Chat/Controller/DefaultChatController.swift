//
// ChatLayout
// DefaultChatController.swift
// https://github.com/ekazaev/ChatLayout
//
// Created by Eugene Kazaev in 2020-2025.
// Distributed under the MIT license.
//
// Become a sponsor:
// https://github.com/sponsors/ekazaev
//

import ChatLayout
import Foundation

final class DefaultChatController: ChatController {
    weak var delegate: ChatControllerDelegate?

    private let dataProvider: RandomDataProvider

    private var typingState: TypingState = .idle
    
    // Dictionary to keep track of streaming message IDs and their content
    private var streamingMessages: [String: String] = [:]

    private let dispatchQueue = DispatchQueue(label: "DefaultChatController", qos: .userInteractive)

    private var lastReadUUID: String?

    private var lastReceivedUUID: String?

    private let userId: Int

    var messages: [RawMessage] = []

    init(dataProvider: RandomDataProvider, userId: Int) {
        self.dataProvider = dataProvider
        self.userId = userId
    }

    func loadInitialMessages(completion: @escaping ([Section]) -> Void) {
        dataProvider.loadInitialMessages { messages in
            self.appendConvertingToMessages(messages)
            self.markAllMessagesAsReceived {
                self.markAllMessagesAsRead {
                    self.propagateLatestMessages { sections in
                        completion(sections)
                    }
                }
            }
        }
    }

    func loadPreviousMessages(completion: @escaping ([Section]) -> Void) {
        dataProvider.loadPreviousMessages(completion: { messages in
            self.appendConvertingToMessages(messages)
            self.markAllMessagesAsReceived {
                self.markAllMessagesAsRead {
                    self.propagateLatestMessages { sections in
                        completion(sections)
                    }
                }
            }
        })
    }

    func sendMessage(_ data: Message.Data, completion: @escaping ([Section]) -> Void) {
        messages.append(RawMessage(id: String(), date: Date(), data: convert(data), userId: userId))
        propagateLatestMessages { sections in
            completion(sections)
        }
    }

    private func appendConvertingToMessages(_ rawMessages: [RawMessage]) {
        var messages = messages
        messages.append(contentsOf: rawMessages)
        self.messages = messages.sorted(by: { $0.date.timeIntervalSince1970 < $1.date.timeIntervalSince1970 })
    }

    private func propagateLatestMessages(completion: @escaping ([Section]) -> Void) {
        var lastMessageStorage: Message?
        dispatchQueue.async { [weak self] in
            guard let self else {
                return
            }
            let messagesSplitByDay = messages
                .map { Message(id: $0.id,
                               date: $0.date,
                               data: self.convert($0.data),
                               owner: User(id: $0.userId),
                               type: $0.userId == self.userId ? .outgoing : .incoming,
                               status: $0.status) }
                .reduce(into: [[Message]]()) { result, message in
                    guard var section = result.last,
                          let prevMessage = section.last else {
                        let section = [message]
                        result.append(section)
                        return
                    }
                    if Calendar.current.isDate(prevMessage.date, equalTo: message.date, toGranularity: .hour) {
                        section.append(message)
                        result[result.count - 1] = section
                    } else {
                        let section = [message]
                        result.append(section)
                    }
                }

            let cells = messagesSplitByDay.enumerated().map { index, messages -> [Cell] in
                var cells: [Cell] = Array(messages.enumerated().map { index, message -> [Cell] in
                    let bubble: Cell.BubbleType
                    if index < messages.count - 1 {
                        let nextMessage = messages[index + 1]
                        bubble = nextMessage.owner == message.owner ? .normal : .tailed
                    } else {
                        bubble = .tailed
                    }
                    guard message.type != .outgoing else {
                        lastMessageStorage = message
                        return [.message(message, bubbleType: bubble)]
                    }

                    let titleCell = Cell.messageGroup(MessageGroup(id: message.id, title: "\(message.owner.name)", type: message.type))

                    if let lastMessage = lastMessageStorage {
                        if lastMessage.owner != message.owner {
                            lastMessageStorage = message
                            return [titleCell, .message(message, bubbleType: bubble)]
                        } else {
                            lastMessageStorage = message
                            return [.message(message, bubbleType: bubble)]
                        }
                    } else {
                        lastMessageStorage = message
                        return [titleCell, .message(message, bubbleType: bubble)]
                    }
                }.joined())

                if let firstMessage = messages.first {
                    let dateCell = Cell.date(DateGroup(id: firstMessage.id, date: firstMessage.date))
                    cells.insert(dateCell, at: 0)
                }

                if self.typingState == .typing,
                   index == messagesSplitByDay.count - 1 {
                    cells.append(.typingIndicator)
                }

                return cells // Section(id: sectionTitle.hashValue, title: sectionTitle, cells: cells)
            }.joined()

            DispatchQueue.main.async { [weak self] in
                guard self != nil else {
                    return
                }
                completion([Section(id: 0, title: "Loading...", cells: Array(cells))])
            }
        }
    }

    private func convert(_ data: RawMessage.Data) -> Message.Data {
        switch data {
        case let .url(url):
            let isLocallyStored: Bool
            if #available(iOS 13, *) {
                isLocallyStored = metadataCache.isEntityCached(for: url)
            } else {
                isLocallyStored = true
            }
            return .url(url, isLocallyStored: isLocallyStored)
        case let .image(source):
            func isPresentLocally(_ source: ImageMessageSource) -> Bool {
                switch source {
                case .image:
                    true
                case let .imageURL(url):
                    imageCache.isEntityCached(for: CacheableImageKey(url: url))
                }
            }
            return .image(source, isLocallyStored: isPresentLocally(source))
        case let .text(text):
            return .text(text)
        case let .streamingText(text, isComplete):
            return .streamingText(text, isComplete: isComplete)
        }
    }
    
    private func convert(_ data: Message.Data) -> RawMessage.Data {
        switch data {
        case let .url(url, isLocallyStored: _):
            .url(url)
        case let .image(source, isLocallyStored: _):
            .image(source)
        case let .text(text):
            .text(text)
        case let .streamingText(text, isComplete):
            .streamingText(text, isComplete: isComplete)
        }
    }

    // MARK: - Streaming Messages

    /// Start a new streaming message
    /// - Parameters:
    ///   - initialText: The initial text to display in the message (can be empty)
    ///   - fromUser: The user ID of the sender
    ///   - completion: Called with updated sections after creating the message
    /// - Returns: The ID of the newly created streaming message
    func startStreamingMessage(initialText: String = "", fromUser: Int, completion: @escaping ([Section]) -> Void) -> String {
        let messageId = UUID().uuidString
        let message = RawMessage(
            id: messageId,
            date: Date(),
            data: .streamingText(initialText, isComplete: false),
            userId: fromUser
        )
        
        // Add to streaming messages dictionary
        streamingMessages[messageId] = initialText
        
        // Add to messages collection
        messages.append(message)
        
        // Update UI
        propagateLatestMessages { sections in
            completion(sections)
        }
        
        return messageId
    }
    
    /// Update an existing streaming message with new content
    /// - Parameters:
    ///   - messageId: The ID of the message to update
    ///   - newContent: The new content to display (entire content, not just the delta)
    ///   - isComplete: Whether the streaming is complete
    ///   - completion: Called with updated sections after updating the message
    func updateStreamingMessage(messageId: String, newContent: String, isComplete: Bool, completion: @escaping ([Section]) -> Void) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else {
            // Create a valid Section with properly formatted cells
            let emptyCells: [Cell] = []
            completion([Section(id: 0, title: "Loading...", cells: emptyCells)])
            return
        }
        
        // Update streaming messages dictionary
        streamingMessages[messageId] = newContent
        
        // Update the message
        messages[index].data = .streamingText(newContent, isComplete: isComplete)
        
        // If complete, remove from tracking
        if isComplete {
            streamingMessages[messageId] = nil
        }
        
        // Update UI
        propagateLatestMessages { sections in
            completion(sections)
        }
    }

    /// Simulates a streaming message response, gradually sending words with typing delays
    /// - Parameters:
    ///   - finalText: The complete text that will be displayed at the end
    ///   - fromUser: The user ID to attribute the message to
    ///   - completion: Called after each update with the latest sections
    func simulateStreamingMessage(finalText: String, fromUser: Int, completion: @escaping ([Section]) -> Void) {
        // Storage for the message ID
        var messageId: String?
        
        // Split text into words
        let words = finalText.split(separator: " ").map(String.init)
        
        // Start with an empty string
        var currentText = ""
        
        // Add first empty message
        messageId = startStreamingMessage(initialText: currentText, fromUser: fromUser) { sections in
            completion(sections)
        }
        
        guard let streamingMessageId = messageId else { return }
        
        // Process one word at a time with delay
        var wordIndex = 0
        
        func sendNextWord() {
            guard wordIndex < words.count else {
                // All words sent, mark as complete
                self.updateStreamingMessage(
                    messageId: streamingMessageId,
                    newContent: currentText,
                    isComplete: true
                ) { sections in
                    completion(sections)
                }
                return
            }
            
            // Add the next word
            if wordIndex > 0 {
                currentText += " "
            }
            currentText += words[wordIndex]
            wordIndex += 1
            
            // Update the streaming message
            self.updateStreamingMessage(
                messageId: streamingMessageId,
                newContent: currentText,
                isComplete: false
            ) { sections in
                completion(sections)
            }
            
            // Schedule the next word with random delay
            let delay = Double.random(in: 0.05...0.2)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                sendNextWord()
            }
        }
        
        // Start the streaming process
        sendNextWord()
    }

    private func repopulateMessages(requiresIsolatedProcess: Bool = false) {
        propagateLatestMessages { sections in
            self.delegate?.update(with: sections, requiresIsolatedProcess: requiresIsolatedProcess)
        }
    }
}

extension DefaultChatController: RandomDataProviderDelegate {
    func received(messages: [RawMessage]) {
        appendConvertingToMessages(messages)
        markAllMessagesAsReceived {
            self.markAllMessagesAsRead {
                self.repopulateMessages()
            }
        }
    }

    func typingStateChanged(to state: TypingState) {
        typingState = state
        repopulateMessages()
    }

    func lastReadIdChanged(to id: String) {
        lastReadUUID = id
        markAllMessagesAsRead {
            self.repopulateMessages()
        }
    }

    func lastReceivedIdChanged(to id: String) {
        lastReceivedUUID = id
        markAllMessagesAsReceived {
            self.repopulateMessages()
        }
    }

    func markAllMessagesAsReceived(completion: @escaping () -> Void) {
        guard let lastReceivedUUID else {
            completion()
            return
        }
        dispatchQueue.async { [weak self] in
            guard let self else {
                return
            }
            var finished = false
            messages = messages.map { message in
                guard !finished, message.status != .received, message.status != .read else {
                    if message.id == lastReceivedUUID {
                        finished = true
                    }
                    return message
                }
                var message = message
                message.status = .received
                if message.id == lastReceivedUUID {
                    finished = true
                }
                return message
            }
            DispatchQueue.main.async {
                completion()
            }
        }
    }

    func markAllMessagesAsRead(completion: @escaping () -> Void) {
        guard let lastReadUUID else {
            completion()
            return
        }
        dispatchQueue.async { [weak self] in
            guard let self else {
                return
            }
            var finished = false
            messages = messages.map { message in
                guard !finished, message.status != .read else {
                    if message.id == lastReadUUID {
                        finished = true
                    }
                    return message
                }
                var message = message
                message.status = .read
                if message.id == lastReadUUID {
                    finished = true
                }
                return message
            }
            DispatchQueue.main.async {
                completion()
            }
        }
    }
}

extension DefaultChatController: ReloadDelegate {
    func reloadMessage(with id: String) {
        repopulateMessages()
    }
}

extension DefaultChatController: EditingAccessoryControllerDelegate {
    func deleteMessage(with id: String) {
        messages = Array(messages.filter { $0.id != id })
        repopulateMessages(requiresIsolatedProcess: true)
    }
}
