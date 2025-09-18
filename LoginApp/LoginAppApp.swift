//
//  LoginAppApp.swift
//  LoginApp
//
//  Created by Jatin Gupta on 2025-09-10.
//

import SwiftUI
import Firebase

@main
struct LoginAppApp: App {
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
