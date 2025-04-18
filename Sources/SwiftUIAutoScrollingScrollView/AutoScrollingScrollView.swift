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

/// A `SwiftUI` `ScrollView` that will automatically scroll to
/// the bottom when content changes, while respecting manual scrolling
/// performed by the user. This is accomplished by monitoring the provided
/// `value` for changes. When a change is observed, if the `content`
/// was already scrolled to the bottom (or very near to it), it will be scrolled
/// to the bottom again. However, if it wasn't near the bottom, no automatic
/// scrolling will be performed.
@available(iOS 18.0, macOS 15, tvOS 13.0, watchOS 6.0, *)
public struct AutoScrollingScrollView<Content, V> : View where Content : View, V : Equatable {
    /// An identifier for the current message.  This is so
    /// we can pull it out of the `ForEach` and (hopefully) not re-render ALL
    /// of the content when the current message changes.
    ///
    /// This is only part of the example, not part of the scrolling solution
    @Namespace private var currentMessageNamespace

    // MARK: - State used as part of the scrolling solution

    /// `true` if the bottom of the scroll view is visible
    @State private var isBottomOfScrollViewContentVisible = false

    @Namespace private var bottomOfScrollView

    /// The scroll view's content.
    public var content: Content

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
    @available(iOS 18.0, macOS 15.0, tvOS 13.0, watchOS 6.0, *)
    public init(_ axes: Axis.Set = .vertical, autoScrollingOnChangeOf value: V, @ViewBuilder content: () -> Content) {
        self.axes = axes
        self.value = value
        self.content = content()
    }

    /// The content and behavior of the scroll view.
    @MainActor @preconcurrency public var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(axes) {
                content
                    .overlay(alignment: .bottom) {
                        Text("")
                            .onScrollVisibilityChange { visible in
                                isBottomOfScrollViewContentVisible = visible
                            }
                    }
                    .id(bottomOfScrollView)
            }
            .onChange(of: value) {
                // We got new content - if we can see the bottom of the
                // ScrollView, then we should scroll to the bottom (of the
                // new content)
                if isBottomOfScrollViewContentVisible {
                    scrollProxy.scrollTo(bottomOfScrollView, anchor: .bottom)
                }
            }
        }
    }
}
