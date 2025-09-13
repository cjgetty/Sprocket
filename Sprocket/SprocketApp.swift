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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

