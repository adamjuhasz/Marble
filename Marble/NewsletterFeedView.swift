//
//  NewsletterFeedView.swift
//  Marble
//
//  Created by OpenAI Assistant on 2025-11-14.
//

import SwiftUI
import UIKit

struct NewsletterFeedView: View {
    @EnvironmentObject private var store: NewsletterStore
    @EnvironmentObject private var appModel: AppModel
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                if store.newsletters.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(store.newsletters) { newsletter in
                            NavigationLink {
                                NewsletterDetailView(newsletter: newsletter)
                            } label: {
                                NewsletterRow(newsletter: newsletter)
                            }
                            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 12))
                            .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await store.archive(newsletter) }
                                } label: {
                                    Label("Archive", systemImage: "archivebox")
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.insetGrouped)
                    .refreshable {
                        await store.loadNewsletters(force: true)
                    }
                }
                if store.state != .idle {
                    ProgressView("Loading newsletters…")
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(.thinMaterial, in: Capsule())
                }
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Inbox")
            .toolbar { toolbarContent }
            .task { await store.loadNewsletters() }
            .overlay(alignment: .bottom) {
                if let message = store.errorMessage {
                    ErrorBanner(message: message)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
                    .environmentObject(appModel.configurationStore)
                    .environmentObject(store)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showingSettings = false }
                        }
                    }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            Text("No newsletters yet")
                .font(.title3.weight(.semibold))
            Text("Connect your Gmail account and add your OpenAI key to start curating newsletters.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Connect Gmail") {
                Task { await store.authorizeGmail() }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
            Button("Open Settings") {
                showingSettings = true
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                Task { await store.loadNewsletters(force: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(store.state == .loading)
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
        }
    }
}

private struct NewsletterRow: View {
    let newsletter: Newsletter

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(newsletter.subject)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                Text(newsletter.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(newsletter.sender)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(newsletter.snippet)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 6)
    }
}

private struct ErrorBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.red.opacity(0.9), in: Capsule())
            .padding()
    }
}
