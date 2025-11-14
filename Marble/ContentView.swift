//
//  ContentView.swift
//  Marble
//
//  Created on 2025-11-14.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                
                Text("Welcome to Marble")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("A modern iOS Swift app")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Marble")
        }
    }
}

#Preview {
    ContentView()
}
