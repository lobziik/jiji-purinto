//
//  jiji_purintoApp.swift
//  jiji-purinto
//
//  Created by lobziik on 20.01.2026.
//

import SwiftUI

@main
struct jiji_purintoApp: App {
    /// The app coordinator managing application state.
    @StateObject private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(coordinator)
        }
    }
}
