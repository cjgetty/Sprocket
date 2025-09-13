//
//  SprocketApp.swift
//  Sprocket
//
//  Created by Cameron Getty on 9/11/25.
//

import SwiftUI

@main
struct SprocketApp: App {
    let persistenceController = PersistenceController.shared
    @AppStorage("appearanceMode") private var appearanceMode = "system"

    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .preferredColorScheme(colorScheme)
        }
    }
    
    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil // System default
        }
    }
}

