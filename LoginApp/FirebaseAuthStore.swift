//
//  FirebaseAuthStore.swift
//  LoginApp
//
//  Created by Jatin Gupta on 2025-01-27.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class FirebaseAuthStore: ObservableObject {
    @Published var currentUser: AppUser? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    private let firebaseService = FirebaseService.shared
    
    init() {
        // Listen for auth state changes
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    do {
                        self?.currentUser = try await self?.firebaseService.fetchUser(uid: user.uid)
                    } catch {
                        print("Error fetching user: \(error)")
                        self?.currentUser = nil
                    }
                } else {
                    self?.currentUser = nil
                }
            }
        }
    }
    
    // MARK: - Authentication Methods
    
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            currentUser = try await firebaseService.signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
            currentUser = nil
        }
        
        isLoading = false
    }
    
    func signUp(email: String, password: String, fullName: String, phone: String, role: UserRole = .user) async {
        isLoading = true
        errorMessage = nil
        
        do {
            currentUser = try await firebaseService.signUp(
                email: email,
                password: password,
                fullName: fullName,
                phone: phone,
                role: role
            )
        } catch {
            errorMessage = error.localizedDescription
            currentUser = nil
        }
        
        isLoading = false
    }
    
    func signOut() {
        do {
            try firebaseService.signOut()
            currentUser = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - User Management
    
    func updateUser(_ user: AppUser) async {
        do {
            try await firebaseService.updateUser(user)
            currentUser = user
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
