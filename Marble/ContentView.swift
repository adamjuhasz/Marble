//
//  ContentView.swift
//  Marble
//
//  Created by OpenAI Assistant on 2025-11-14.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        NewsletterFeedView()
    }
}

#Preview {
    let appModel = AppModel()
    return ContentView()
        .environmentObject(appModel)
        .environmentObject(appModel.newsletterStore)
}
