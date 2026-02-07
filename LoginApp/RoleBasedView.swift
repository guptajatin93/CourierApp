//
//  RoleBasedView.swift
//  LoginApp
//
//  Created by Jatin Gupta on 2025-01-27.
//

import SwiftUI

struct RoleBasedView: View {
    @ObservedObject var auth: FirebaseAuthStore
    @StateObject private var orderStore = FirebaseOrderStore()
    
    var body: some View {
        Group {
            if let user = auth.currentUser {
                switch user.role {
                case .user:
                    UserPageView(
                        auth: auth,
                        token: user.token,
                        initialName: user.fullName,
                        initialEmail: user.email,
                        initialPhone: user.phone
                    )
                case .driver:
                    DriverPageView(
                        driverId: user.token,
                        driverName: user.fullName
                    )
                case .admin:
                    AdminPageView()
                }
            } else {
                // This shouldn't happen as we check for currentUser in ContentView
                Text("No user found")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didSignOut)) { _ in
            auth.signOut()
        }
    }
}
