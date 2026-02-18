//
//  NailNoteApp.swift
//  NailNote
//
//  Created by Hideki Sato on 2026/02/18.
//

import SwiftUI
import CoreData

@main
struct NailNoteApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
