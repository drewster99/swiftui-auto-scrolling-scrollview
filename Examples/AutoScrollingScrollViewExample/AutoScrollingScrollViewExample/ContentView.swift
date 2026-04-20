//
//  ContentView.swift
//  AutoScrollingScrollViewExample
//
//  Created by Andrew Benson on 4/18/25.
//
//
// A simulated stream of fake junk "messages",
// to demonstrate the use of `SwiftUIAutoScrollingScrollView`
//

import SwiftUI
import SwiftUIAutoScrollingScrollView

struct ContentView: View {
    /// Generates random text
    @State private var junkGenerator = JunkGenerator()

    /// An array of prior "messages"
    @State private var previousJunk: [String] = []
    /// Controls the lockToBottom state for the AutoScrollingScrollView
    @State private var lockToBottom: Bool = true
    /// A stable ID for the anchor at the very end of the scrollable content.
    private let contentBottomAnchorID = "contentBottomAnchor"

    /// Value to trigger auto-scrolling, combining current text and count of previous items.
    struct ExampleScrollTrigger: Equatable {
        let currentText: String
        let previousItemCount: Int
    }

    private var currentScrollTrigger: ExampleScrollTrigger {
        ExampleScrollTrigger(currentText: junkGenerator.text, previousItemCount: previousJunk.count)
    }

    var body: some View {
        VStack {
            HStack {
                Button("Start") {
                    junkGenerator.startGenerating()
                    lockToBottom = true // Ensure scrolling is active
                }
                Button("Stop") {
                    junkGenerator.stopGenerating()
                }
                Button("Next \"Message\"") {
                    if !junkGenerator.text.isEmpty {
                        previousJunk.append(junkGenerator.text)
                    }
                    junkGenerator.text = ""
                    lockToBottom = true // Ensure scrolling is active for new state
                }
                Button(lockToBottom ? "Unlock Scroll" : "Lock Scroll") {
                    lockToBottom.toggle()
                }
            }
            .buttonStyle(.bordered)

            AutoScrollingScrollView(
                .vertical, // Scroll axis
                lockToBottom: $lockToBottom, // Binding to control forced scrolling
                lastScrollViewID: contentBottomAnchorID, // ID of the last item to target
                autoScrollingOnChangeOf: currentScrollTrigger, // Value that triggers auto-scroll
                overlayContent: { // Content for the scroll-to-bottom button
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 24))
                        .padding(8)
                        .background(Color.black.opacity(0.2))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
            ) {
                LazyVStack(alignment: .leading) {
                    ForEach(previousJunk, id: \.self) { someJunk in
                        JunkView(junk: someJunk)
                    }
                    // View for the currently streaming/active junk text
                    JunkView(junk: junkGenerator.text)
                        // .id("currentStreamingJunk") // ID for current item if needed for specific targeting

                    // Invisible anchor at the very bottom of all content
                    Color.clear
                        .frame(height: 1)
                        .id(contentBottomAnchorID)
                }
                .scrollTargetLayout() // Enable scroll target behavior for children
            }
            .scrollIndicators(.hidden)
        }
        .padding()
    }
}

/// Displays our junk message
struct JunkView: View {
    let junk: String

    var body: some View {
        Text(junk)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
    }
}

#Preview {
    ContentView()
}
