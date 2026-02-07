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
    
    /// Verification ID from sendPhoneOTP; pass to verifyPhoneOTP with the code user enters.
    @Published var phoneVerificationID: String? = nil
    
    /// After sign-up, show email+phone verification before entering the app. ContentView presents this.
    @Published var pendingSignUpVerification: (email: String, phone: String)? = nil
    
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
    
    /// Signs in a user with phone number and password
    /// - Parameters:
    ///   - phone: User's phone number
    ///   - password: User's password
    func signInWithPhone(phone: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            currentUser = try await firebaseService.signInWithPhone(phone: phone, password: password)
        } catch {
            errorMessage = error.localizedDescription
            currentUser = nil
        }
        
        isLoading = false
    }
    
    func signUp(email: String, password: String, fullName: String, phone: String, role: UserRole = .user, inviteCode: String? = nil) async {
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
            
            // If user signed up as driver with invite code, mark the code as used
            if role == .driver, let code = inviteCode, let userId = currentUser?.id {
                try await firebaseService.useDriverCode(code, userId: userId)
            }
        } catch {
            errorMessage = error.localizedDescription
            currentUser = nil
        }
        
        isLoading = false
    }
    
    /// Call after sign-up succeeds so ContentView shows the verification flow (email then phone OTP).
    func setPendingSignUpVerification(email: String, phone: String) {
        pendingSignUpVerification = (email: email, phone: phone)
        errorMessage = nil
    }
    
    /// Call when user finishes or skips verification.
    func clearPendingSignUpVerification() {
        pendingSignUpVerification = nil
    }
    
    func signOut() {
        do {
            try firebaseService.signOut()
            currentUser = nil
            phoneVerificationID = nil
            pendingSignUpVerification = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Email verification
    
    func sendEmailVerification() async {
        isLoading = true
        errorMessage = nil
        do {
            try await firebaseService.sendEmailVerification()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func reloadUserEmailVerification() async {
        do {
            try await firebaseService.reloadCurrentUser()
            if firebaseService.isEmailVerified(), let uid = Auth.auth().currentUser?.uid {
                currentUser = try? await firebaseService.fetchUser(uid: uid)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    var isEmailVerified: Bool { firebaseService.isEmailVerified() }
    
    /// True if the current user has a phone number linked to Firebase Auth (for phone login & password reset).
    var isPhoneLinked: Bool {
        guard let phoneNumber = Auth.auth().currentUser?.phoneNumber else { return false }
        return !phoneNumber.isEmpty
    }
    
    /// Masked phone from Auth (e.g. +1 *** *** 1234) for display when linked.
    var linkedPhoneMasked: String? {
        guard let p = Auth.auth().currentUser?.phoneNumber, !p.isEmpty else { return nil }
        let digits = p.filter { $0.isNumber }
        if digits.count >= 4 {
            let suffix = String(digits.suffix(4))
            return "+*** *** *** \(suffix)"
        }
        return p
    }
    
    // MARK: - Phone OTP
    
    /// Sends SMS OTP to the given phone (Canadian number). Sets phoneVerificationID on success.
    func sendPhoneOTP(phone: String) async {
        isLoading = true
        errorMessage = nil
        phoneVerificationID = nil
        do {
            let e164 = firebaseService.normalizePhoneForFirebase(phone)
            let vid = try await firebaseService.sendPhoneOTP(phoneNumberE164: e164)
            phoneVerificationID = vid
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    /// Verifies the SMS code and links phone to the current user (call after signup).
    func verifyAndLinkPhoneOTP(code: String) async {
        guard let vid = phoneVerificationID else {
            errorMessage = "Please request a new code."
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let credential = try await firebaseService.verifyPhoneOTP(verificationID: vid, verificationCode: code)
            try await firebaseService.linkPhoneCredential(credential)
            phoneVerificationID = nil
            if let firebaseUser = Auth.auth().currentUser {
                let uid = firebaseUser.uid
                let linkedPhone = firebaseUser.phoneNumber ?? ""
                let normalized = firebaseService.normalizePhoneForStorage(linkedPhone)
                if !normalized.isEmpty {
                    try? await firebaseService.updateUserPhone(uid: uid, phoneNormalized: normalized)
                }
                currentUser = try await firebaseService.fetchUser(uid: uid)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    /// Sign in with phone OTP only (for password reset flow: verify code then set new password).
    func signInWithPhoneOTP(verificationID: String, code: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let credential = try await firebaseService.verifyPhoneOTP(verificationID: verificationID, verificationCode: code)
            currentUser = try await firebaseService.signInWithPhoneCredential(credential)
            phoneVerificationID = nil
        } catch {
            errorMessage = error.localizedDescription
            currentUser = nil
        }
        isLoading = false
    }
    
    // MARK: - Password reset
    
    func sendPasswordResetEmail(email: String) async {
        isLoading = true
        errorMessage = nil
        do {
            try await firebaseService.sendPasswordResetEmail(email: email)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func updatePassword(newPassword: String) async {
        isLoading = true
        errorMessage = nil
        do {
            try await firebaseService.updatePassword(newPassword: newPassword)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
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
