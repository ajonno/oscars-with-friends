//
//  oscars_with_friendsApp.swift
//  oscars-with-friends
//
//  Created by Angus Johnston on 1/1/2026.
//

import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct oscars_with_friendsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var authService: AuthService

    init() {
        FirebaseApp.configure()

        // Configure Google Sign-In with client ID from Firebase
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }

        _authService = State(initialValue: AuthService())
    }
    

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authService)
                .task {
                    await EventTypeCache.shared.load()
                }
        }
    }
}
