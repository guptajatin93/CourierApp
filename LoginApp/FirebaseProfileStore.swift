//
//  FirebaseProfileStore.swift
//  LoginApp
//
//  Created by Jatin Gupta on 2025-01-27.
//

import Foundation
import FirebaseAuth

@MainActor
final class FirebaseProfileStore: ObservableObject {
    @Published var profile: Profile = Profile()
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    private let firebaseService = FirebaseService.shared
    
    init() {
        loadProfile()
    }
    
    func loadProfile() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        Task {
            isLoading = true
            do {
                profile = try await firebaseService.fetchProfile(userId: userId)
            } catch {
                errorMessage = error.localizedDescription
                // Create default profile if none exists
                profile = Profile()
            }
            isLoading = false
        }
    }
    
    func saveProfile() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        Task {
            do {
                profile.updatedAt = Date()
                try await firebaseService.saveProfile(profile, userId: userId)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func updateProfile(_ newProfile: Profile) {
        profile = newProfile
        saveProfile()
    }
}

