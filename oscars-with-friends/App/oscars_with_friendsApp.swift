//
//  oscars_with_friendsApp.swift
//  oscars-with-friends
//
//  Created by Angus Johnston on 1/1/2026.
//

import SwiftUI
import FirebaseCore

@main
struct oscars_with_friendsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var authService: AuthService

    init() {
        FirebaseApp.configure()
        _authService = State(initialValue: AuthService())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authService)
        }
    }
}
