//
//  AutoScrollingScrollView.swift
//  SwiftUIAutoScrollingScrollView
//
//  Created by Andrew Benson on 4/18/25.
//  Copyright (C) 2025 Nuclear Cyborg Corp
//
//  MIT License
//

import Foundation
import SwiftUI
import OSLog

private let logger = Logger(subsystem: "SwiftUIAutoScrollingScrollView", category: "AutoScrollingScrollView")

/// A `SwiftUI` `ScrollView` that will automatically scroll to
/// the bottom when content changes, while respecting manual scrolling
/// performed by the user. This is accomplished by monitoring the provided
/// `value` for changes. When a change is observed, if the `content`
/// was already scrolled to the bottom (or very near to it), it will be scrolled
/// to the bottom again. However, if it wasn't near the bottom, no automatic
/// scrolling will be performed.
@available(iOS 18.0, macOS 15.0, tvOS 13.0, watchOS 6.0, *)
public struct AutoScrollingScrollView<Content, OverlayContent, V, ScrollPositionType> : View where Content : View, OverlayContent: View, V : Equatable, ScrollPositionType : (Hashable & Sendable) {
    /// An identifier for the current message.  This is so
    /// we can pull it out of the `ForEach` and (hopefully) not re-render ALL
    /// of the content when the current message changes.
    ///
    /// This is only part of the example, not part of the scrolling solution
    @Namespace private var currentMessageNamespace

    // MARK: - State used as part of the scrolling solution

    /// `true` if the bottom of the scroll view is visible
    @State private var isBottomOfScrollViewContentVisible = true
    //    @Binding private var shouldScrollOnAnyChange: Bool

    // bottomOfScrollView and bottomDetector are no longer needed as the component relies on lastScrollViewID
    // @Namespace private var bottomOfScrollView
    // @State private var bottomDetector = "bottom detector" // Removed
    // @State private var scrollPositionID: String? // Removed as unused

    @Binding private var lockToBottom: Bool

    /// The scroll view's content.
    public var content: Content

    /// Overlay content is overlaid at the bottom of the scroll area when there is additional content
    /// which will not be automatically scrolled to reveal
    public var overlayContent: OverlayContent

    /// The scrollable axes of the scroll view.
    ///
    /// The default value is ``Axis/vertical``.
    public var axes: Axis.Set

    /// Used to trigger changes
    public var value: V

    /// Creates a new instance that's scrollable in the direction of the given
    /// axis and can show indicators while scrolling.  f was scrollled to the
    /// bottom previously, will automatically scroll to the bottom on change
    /// of the given `value`.
    ///
    /// - Parameters:
    ///   - axes: The scroll view's scrollable axis. The default axis is the
    ///     vertical axis.
    ///   - value: An `equatable` value to monitor for changes.  Changes
    ///     in this value are used to trigger automatic scroll-to-bottom.
    ///   - content: The view builder that creates the scrollable view.
    @available(iOS 18.0, macOS 15.0, tvOS 13.0, watchOS 6.0, *) // Corrected availability
    public init(_ axes: Axis.Set = .vertical, lockToBottom: Binding<Bool>, lastScrollViewID: ScrollPositionType, autoScrollingOnChangeOf value: V, @ViewBuilder overlayContent: () -> OverlayContent, @ViewBuilder content: () -> Content) {
        self.axes = axes
        self._lockToBottom = lockToBottom
        //        self._shouldScrollOnAnyChange = shouldScrollOnAnyChange
        self.value = value
        self.content = content()
        self.overlayContent = overlayContent()
        self.lastScrollViewID = lastScrollViewID
    }
    let lastScrollViewID: ScrollPositionType

    @State private var scrollPhase: ScrollPhase = .idle
//    @State private var shouldDisplayScrollToBottomOverlay: Bool = false
    @State private var lastSeenID: ScrollPositionType?
    @State private var scrollViewPositionChecker = ScrollPosition(idType: ScrollPositionType.self)

    private var shouldDisplayScrollToBottomOverlay: Bool {
        // Show button if user scrolled up and scroll is idle.
        return !shouldAutoScrollOnNewContent && scrollPhase == .idle
    }
//    private func updateShouldDisplayScrollToBottomOverlay() {
//        let newValue = !isBottomOfScrollViewContentVisible && scrollPhase == .idle
//        if shouldDisplayScrollToBottomOverlay != newValue {
//            withAnimation(Animation.easeInOut(duration: 0.5)) {
//                shouldDisplayScrollToBottomOverlay = newValue
//            }
//        }
//    }
    struct ScrollData: Equatable {
        let size: CGSize
        let visible: CGRect
    }
    @State private var scrollData: ScrollData?
    @State private var weSeeIt: Bool = false
    @State private var isBottomVisible: Bool = false

    @State private var shouldAutoScrollOnNewContent: Bool = true

    /// The content and behavior of the scroll view.
    public var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(axes) {
                content
            }
            .simultaneousGesture(DragGesture(minimumDistance: 0.01)
                .onChanged { _ in
                    Task { @MainActor in
                        if shouldAutoScrollOnNewContent { // if true, set to false
                            shouldAutoScrollOnNewContent = false
                            logger.log("AutoScrollingScrollView: DragGesture.onChanged, set shouldAutoScrollOnNewContent = false")
                        }
                    }
                }
                .onEnded { value in
                    Task { @MainActor in
                        // After drag ends, check if we are at the bottom.
                        if scrollViewPositionChecker.viewID(type: ScrollPositionType.self) == self.lastScrollViewID {
                            if !shouldAutoScrollOnNewContent {
                                shouldAutoScrollOnNewContent = true
                                logger.log("AutoScrollingScrollView: DragGesture.onEnded at bottom, set shouldAutoScrollOnNewContent = true")
                            }
                        }
                    }
                }
            )
            .defaultScrollAnchor(shouldAutoScrollOnNewContent ? .bottom : nil) // Conditionally apply anchor
            .scrollPosition($scrollViewPositionChecker, anchor: .bottom)
            .onScrollPhaseChange({ _, newPhase in
                DispatchQueue.main.async {
                    if scrollPhase != newPhase {
                        scrollPhase = newPhase
                    }
                }
            })
            /*
            .overlay(alignment: .top) {
                Text("Target = \(lastScrollViewID)\n\(scrollViewPositionChecker.viewID(type: ScrollPositionType.self))\nisPositionedByUser = \(scrollViewPositionChecker.isPositionedByUser ? "YES" : "no")")
                    .background(.ultraThinMaterial)
            }
             */
            .overlay(alignment: .bottom) {
                Button {
                    logger.log("AutoScrollingScrollView: Scroll to bottom button tapped, scrolling to ID: \(String(describing: self.lastScrollViewID))")
                    withAnimation(.easeInOut(duration: 0.3)) {
                        scrollProxy.scrollTo(self.lastScrollViewID, anchor: .bottom)
                    }
                    shouldAutoScrollOnNewContent = true
                } label: {
                    overlayContent
                }
                .buttonStyle(.plain)
                .disabled(!shouldDisplayScrollToBottomOverlay)
                .opacity(shouldDisplayScrollToBottomOverlay ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.55), value: shouldDisplayScrollToBottomOverlay) // Updated animation
            }
            .onChange(of: value) { oldValue, newValue in
                // Auto-scroll if allowed.
                if self.shouldAutoScrollOnNewContent {
                    logger.log("AutoScrollingScrollView: New value, auto-scrolling to ID: \(String(describing: self.lastScrollViewID))")
                    scrollProxy.scrollTo(self.lastScrollViewID, anchor: .bottom)
                } else {
                    logger.log("AutoScrollingScrollView: New value, but auto-scroll disabled.")
                }
            }
            .onChange(of: scrollViewPositionChecker.viewID(type: ScrollPositionType.self)) { _, newViewIDAtBottom in
                // Re-enable auto-scroll if user manually scrolls to the bottom,
                // AND if the view is supposed to be locked to the bottom (externally controlled).
                if newViewIDAtBottom == self.lastScrollViewID {
                    if !self.shouldAutoScrollOnNewContent && self.lockToBottom {
                        logger.log("AutoScrollingScrollView: User scrolled to bottom (ID: \(String(describing: newViewIDAtBottom))) and view is locked, re-enabling auto-scroll.")
                        self.shouldAutoScrollOnNewContent = true
                    }
                }
                // Note: DragGesture handles setting shouldAutoScrollOnNewContent to false when user scrolls up.
            }
            .onChange(of: lockToBottom) { _, newLockState in
                // Handle external lockToBottom changes.
                if newLockState {
                    if !self.shouldAutoScrollOnNewContent {
                        self.shouldAutoScrollOnNewContent = true
                        logger.log("AutoScrollingScrollView: lockToBottom true, enabling auto-scroll.")
                    }
                    // Ensure scroll to bottom when locked.
                    Task { @MainActor in
                        logger.log("AutoScrollingScrollView: lockToBottom true, scrolling to ID: \(String(describing: self.lastScrollViewID)).")
                        withAnimation(.easeInOut(duration: 0.3)) {
                            scrollProxy.scrollTo(self.lastScrollViewID, anchor: .bottom)
                        }
                    }
                } else {
                    if self.shouldAutoScrollOnNewContent {
                        self.shouldAutoScrollOnNewContent = false
                        logger.log("AutoScrollingScrollView: lockToBottom false, disabling auto-scroll.")
                    }
                }
            }
        }
    }
}
