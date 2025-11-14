//
//  MarbleApp.swift
//  Marble
//
//  Created by OpenAI Assistant on 2025-11-14.
//

import SwiftUI

@main
struct MarbleApp: App {
    @StateObject private var appModel = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
                .environmentObject(appModel.newsletterStore)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                appModel.persist()
            default:
                break
            }
        }
    }
}
