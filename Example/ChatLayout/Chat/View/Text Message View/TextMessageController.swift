//
// ChatLayout
// TextMessageController.swift
// https://github.com/ekazaev/ChatLayout
//
// Created by Eugene Kazaev in 2020-2025.
// Distributed under the MIT license.
//
// Become a sponsor:
// https://github.com/sponsors/ekazaev
//

import Foundation

final class TextMessageController {
    weak var view: TextMessageView? {
        didSet {
            view?.reloadData()
        }
    }

    let text: String

    let type: MessageType

    private let bubbleController: BubbleController

    init(text: String, type: MessageType, bubbleController: BubbleController) {
        self.text = text
        self.type = type
        self.bubbleController = bubbleController
    }
}

final class StreamingTextMessageController {
    weak var view: StreamingTextMessageView? {
        didSet {
            view?.reloadData()
        }
    }

    let text: String
    let type: MessageType
    let isComplete: Bool
    
    private let bubbleController: BubbleController
    
    // Typing indicator animation timer
//    private var typingTimer: Timer?
//    private var typingIndicatorState: Int = 0
    
    init(text: String, type: MessageType, isComplete: Bool, bubbleController: BubbleController) {
        self.text = text
        self.type = type
        self.isComplete = isComplete
        self.bubbleController = bubbleController
        
//        if !isComplete {
//            setupTypingIndicator()
//        }
    }
    
//    deinit {
//        typingTimer?.invalidate()
//    }
    
    func updateText(_ newText: String, isComplete: Bool) {
        guard let view = view else { return }
        view.updateText(newText, isComplete: isComplete)
        
//        if isComplete {
//            typingTimer?.invalidate()
//            typingTimer = nil
//        } else if typingTimer == nil {
//            setupTypingIndicator()
//        }
    }
    
//    private func setupTypingIndicator() {
//        typingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
//            guard let self = self else { return }
//            self.typingIndicatorState = (self.typingIndicatorState + 1) % 4
//            print("Typing indicator state: \(self.typingIndicatorState)")
//            self.view?.updateTypingIndicator(dots: self.typingIndicatorState)
//        }
//    }
}
