//
//  NewsletterDetailView.swift
//  Marble
//
//  Created by OpenAI Assistant on 2025-11-14.
//

import SwiftUI
import WebKit

struct NewsletterDetailView: View {
    @EnvironmentObject private var store: NewsletterStore
    @Environment(\.dismiss) private var dismiss
    @State private var scrollOffset: Double
    let newsletter: Newsletter

    init(newsletter: Newsletter) {
        self.newsletter = newsletter
        _scrollOffset = State(initialValue: newsletter.scrollOffset)
    }

    var body: some View {
        NewsletterReader(htmlURL: newsletter.htmlContentPath, scrollOffset: $scrollOffset)
            .navigationTitle(newsletter.subject)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await store.archive(newsletter)
                            await MainActor.run { dismiss() }
                        }
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                }
            }
            .onChange(of: scrollOffset) { _, newValue in
                store.setScrollOffset(newValue, for: newsletter)
            }
    }
}

private struct NewsletterReader: UIViewRepresentable {
    let htmlURL: URL
    @Binding var scrollOffset: Double

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptEnabled = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.delegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.scrollView.showsVerticalScrollIndicator = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        context.coordinator.load(htmlURL, into: webView, scrollOffset: scrollOffset)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.parent = self
        if uiView.url != htmlURL {
            context.coordinator.load(htmlURL, into: uiView, scrollOffset: scrollOffset)
        } else {
            context.coordinator.restoreScrollPosition(on: uiView, offset: scrollOffset)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, UIScrollViewDelegate {
        var parent: NewsletterReader
        private var isRestoringScroll = false

        init(parent: NewsletterReader) {
            self.parent = parent
        }

        func load(_ url: URL, into webView: WKWebView, scrollOffset: Double) {
            let baseURL = url.deletingLastPathComponent()
            webView.loadFileURL(url, allowingReadAccessTo: baseURL)
            restoreScrollPosition(on: webView, offset: scrollOffset)
        }

        func restoreScrollPosition(on webView: WKWebView, offset: Double) {
            guard !isRestoringScroll else { return }
            isRestoringScroll = true
            let adjustedOffset = CGPoint(x: 0, y: offset)
            webView.scrollView.setContentOffset(adjustedOffset, animated: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.isRestoringScroll = false
            }
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            parent.scrollOffset = scrollView.contentOffset.y
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            restoreScrollPosition(on: webView, offset: parent.scrollOffset)
        }
    }
}
