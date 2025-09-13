//
//  MainAppView.swift
//  Sprocket
//
//  Created by Cameron Getty on 9/13/25.
//

import SwiftUI

struct MainAppView: View {
    @State private var showSplash = true
    @State private var showMainContent = false
    
    var body: some View {
        ZStack {
            if showSplash {
                SplashScreenView()
                    .transition(.opacity)
            } else if showMainContent {
                ContentView()
                    .transition(.opacity)
            }
        }
        .onAppear {
            // Show splash screen for 2 seconds, then transition to main content
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showSplash = false
                    showMainContent = true
                }
            }
        }
    }
}

#Preview {
    MainAppView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}
