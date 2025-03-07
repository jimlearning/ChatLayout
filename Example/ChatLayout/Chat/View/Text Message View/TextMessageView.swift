//
// ChatLayout
// TextMessageView.swift
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
import UIKit

final class TextMessageView: UIView, ContainerCollectionViewCellDelegate {
    private var viewPortWidth: CGFloat = 300

    private lazy var textView = MessageTextView()

    private var controller: TextMessageController?

    private var textViewWidthConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSubviews()
    }

    func prepareForReuse() {
        textView.resignFirstResponder()
    }

    // Uncomment this method to test the performance without calculating text cell size using autolayout
    // For the better illustration set DefaultRandomDataProvider.enableRichContent/enableNewMessages
    // to false
//    func preferredLayoutAttributesFitting(_ layoutAttributes: ChatLayoutAttributes) -> ChatLayoutAttributes? {
//        viewPortWidth = layoutAttributes.layoutFrame.width
//        guard let text = controller?.text as NSString? else {
//            return layoutAttributes
//        }
//        let maxWidth = viewPortWidth * Constants.maxWidth
//        var rect = text.boundingRect(with: CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude),
//            options: [.usesLineFragmentOrigin, .usesFontLeading],
//            attributes: [NSAttributedString.Key.font: textView.font as Any], context: nil)
//        rect = rect.insetBy(dx: 0, dy: -8)
//        layoutAttributes.size = CGSize(width: layoutAttributes.layoutFrame.width, height: rect.height)
//        setupSize()
//        return layoutAttributes
//    }

    func apply(_ layoutAttributes: ChatLayoutAttributes) {
        viewPortWidth = layoutAttributes.layoutFrame.width
        setupSize()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
    }

    func setup(with controller: TextMessageController) {
        self.controller = controller
        reloadData()
    }

    func reloadData() {
        guard let controller else {
            return
        }
        textView.text = controller.text
        UIView.performWithoutAnimation {
            if #available(iOS 13.0, *) {
                textView.textColor = controller.type.isIncoming ? UIColor.label : .systemBackground
                textView.linkTextAttributes = [.foregroundColor: controller.type.isIncoming ? UIColor.systemBlue : .systemGray6,
                                               .underlineStyle: 1]
            } else {
                let color = controller.type.isIncoming ? UIColor.black : .white
                textView.textColor = color
                textView.linkTextAttributes = [.foregroundColor: color,
                                               .underlineStyle: 1]
            }
        }
    }

    private func setupSubviews() {
        layoutMargins = .zero
        translatesAutoresizingMaskIntoConstraints = false
        insetsLayoutMarginsFromSafeArea = false

        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isScrollEnabled = false
        textView.isEditable = false
        textView.spellCheckingType = .no
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.dataDetectorTypes = .all
        textView.font = .preferredFont(forTextStyle: .body)
        textView.scrollsToTop = false
        textView.bounces = false
        textView.bouncesZoom = false
        textView.showsHorizontalScrollIndicator = false
        textView.showsVerticalScrollIndicator = false
        textView.isExclusiveTouch = true
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            textView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor)
        ])
        textViewWidthConstraint = textView.widthAnchor.constraint(lessThanOrEqualToConstant: viewPortWidth)
        textViewWidthConstraint?.isActive = true
    }

    private func setupSize() {
        UIView.performWithoutAnimation {
            self.textViewWidthConstraint?.constant = viewPortWidth * Constants.maxWidth
            setNeedsLayout()
        }
    }
}

extension TextMessageView: AvatarViewDelegate {
    func avatarTapped() {
        if enableSelfSizingSupport {
            layoutMargins = layoutMargins == .zero ? UIEdgeInsets(top: 50, left: 0, bottom: 50, right: 0) : .zero
            setNeedsLayout()
            if let cell = superview(of: UICollectionViewCell.self) {
                cell.contentView.invalidateIntrinsicContentSize()
            }
        }
    }
}

final class StreamingTextMessageView: UIView, ContainerCollectionViewCellDelegate {
    private var viewPortWidth: CGFloat = 300

    private lazy var textView = MessageTextView()
//    private lazy var typingIndicatorLabel = UILabel()
    
    private var controller: StreamingTextMessageController?
    private var textViewWidthConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSubviews()
    }

    func prepareForReuse() {
        textView.resignFirstResponder()
    }

    func apply(_ layoutAttributes: ChatLayoutAttributes) {
        viewPortWidth = layoutAttributes.layoutFrame.width
        setupSize()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
    }

    func setup(with controller: StreamingTextMessageController) {
        self.controller = controller
        reloadData()
    }
    
    func updateText(_ newText: String, isComplete: Bool) {
        textView.text = newText
//        typingIndicatorLabel.isHidden = isComplete
    }
    
//    func updateTypingIndicator(dots: Int) {
//        let dotsText: String
//        switch dots {
//        case 0: dotsText = ""
//        case 1: dotsText = "."
//        case 2: dotsText = ".."
//        case 3: dotsText = "..."
//        default: dotsText = ""
//        }
//        typingIndicatorLabel.text = dotsText
//    }

    func reloadData() {
        guard let controller else {
            return
        }
        textView.text = controller.text
//        typingIndicatorLabel.isHidden = controller.isComplete
        
        UIView.performWithoutAnimation {
            if #available(iOS 13.0, *) {
                textView.textColor = controller.type.isIncoming ? UIColor.label : .systemBackground
                textView.linkTextAttributes = [.foregroundColor: controller.type.isIncoming ? UIColor.systemBlue : .systemGray6,
                                               .underlineStyle: 1]
//                typingIndicatorLabel.textColor = controller.type.isIncoming ? UIColor.systemGray : .systemGray6
            } else {
                let color = controller.type.isIncoming ? UIColor.black : .white
                textView.textColor = color
                textView.linkTextAttributes = [.foregroundColor: color,
                                               .underlineStyle: 1]
//                typingIndicatorLabel.textColor = controller.type.isIncoming ? UIColor.darkGray : .lightGray
            }
        }
    }

    private func setupSubviews() {
        layoutMargins = .zero
        translatesAutoresizingMaskIntoConstraints = false
        insetsLayoutMarginsFromSafeArea = false

        // Configure text view
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isScrollEnabled = false
        textView.isEditable = false
        textView.spellCheckingType = .no
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.dataDetectorTypes = .all
        textView.font = .preferredFont(forTextStyle: .body)
        textView.scrollsToTop = false
        textView.bounces = false
        textView.bouncesZoom = false
        textView.showsHorizontalScrollIndicator = false
        textView.showsVerticalScrollIndicator = false
        textView.isExclusiveTouch = true
        addSubview(textView)
        
        // Configure typing indicator
//        typingIndicatorLabel.translatesAutoresizingMaskIntoConstraints = false
//        typingIndicatorLabel.font = UIFont.preferredFont(forTextStyle: .body)
//        addSubview(typingIndicatorLabel)
        
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor),
            
//            typingIndicatorLabel.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 2),
//            typingIndicatorLabel.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
//            typingIndicatorLabel.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor)
        ])
        
        textViewWidthConstraint = textView.widthAnchor.constraint(lessThanOrEqualToConstant: viewPortWidth)
        textViewWidthConstraint?.isActive = true
    }

    private func setupSize() {
        UIView.performWithoutAnimation {
            self.textViewWidthConstraint?.constant = viewPortWidth * Constants.maxWidth
            setNeedsLayout()
        }
    }
}

extension StreamingTextMessageView: AvatarViewDelegate {
    func avatarTapped() {
        if enableSelfSizingSupport {
            layoutMargins = layoutMargins == .zero ? UIEdgeInsets(top: 50, left: 0, bottom: 50, right: 0) : .zero
            setNeedsLayout()
            if let cell = superview(of: UICollectionViewCell.self) {
                cell.contentView.invalidateIntrinsicContentSize()
            }
        }
    }
}

private final class MessageTextView: UITextView {
    override var canBecomeFirstResponder: Bool {
        false
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard super.point(inside: point, with: event) else {
            return false
        }

        if let pos = closestPosition(to: point), let range = tokenizer.rangeEnclosingPosition(pos, with: .character, inDirection: UITextDirection(rawValue: 1)) {
            let startIndex = offset(from: beginningOfDocument, to: range.start)
            return attributedText.attribute(.link, at: startIndex, effectiveRange: nil) != nil
        }
        return false
    }
}
