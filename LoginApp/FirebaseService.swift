//
//  FirebaseService.swift
//  LoginApp
//
//  Created by Jatin Gupta on 2025-01-27.
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore

final class FirebaseService: ObservableObject {
    static let shared = FirebaseService()
    
    private let db = Firestore.firestore()
    
    private init() {
        // Firebase will be configured in AppDelegate or App struct
    }
    
    // MARK: - Authentication
    
    func signIn(email: String, password: String) async throws -> AppUser {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        return try await fetchUser(uid: result.user.uid)
    }
    
    /// Signs in a user with phone number and password
    /// - Parameters:
    ///   - phone: User's phone number
    ///   - password: User's password
    /// - Returns: AppUser object with user information
    /// - Throws: FirebaseAuthError if authentication fails
    func signInWithPhone(phone: String, password: String) async throws -> AppUser {
        // For now, we'll use a simpler approach: try to find the user by phone
        // and then authenticate with their email
        let normalizedPhone = phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        // Get all users and find the one with matching phone
        let snapshot = try await db.collection("users").getDocuments()
        
        guard let userDoc = snapshot.documents.first(where: { document in
            do {
                let user = try document.data(as: AppUser.self)
                return user.phone == normalizedPhone
            } catch {
                return false
            }
        }) else {
            throw NSError(domain: "FirebaseAuthError", code: 17011, userInfo: [NSLocalizedDescriptionKey: "No account found with this phone number."])
        }
        
        let user = try userDoc.data(as: AppUser.self)
        
        // Now sign in with the email and password
        let result = try await Auth.auth().signIn(withEmail: user.email, password: password)
        return try await fetchUser(uid: result.user.uid)
    }
    
    func signUp(email: String, password: String, fullName: String, phone: String, role: UserRole = .user) async throws -> AppUser {
        let normalizedPhone = normalizePhoneForStorage(phone)
        
        // Email duplicate: rely on Firebase Auth createUser (throws 17007 if email already in use)
        // Phone duplicate: check Firestore only if we have permission; otherwise catch at save
        let result: AuthDataResult
        do {
            result = try await Auth.auth().createUser(withEmail: email, password: password)
        } catch let err as NSError {
            if err.domain == "FIRAuthErrorDomain" && err.code == 17007 {
                throw NSError(domain: "FirebaseAuthError", code: 17007, userInfo: [NSLocalizedDescriptionKey: "An account with this email already exists."])
            }
            throw err
        }
        
        let user = AppUser(
            id: result.user.uid,
            fullName: fullName,
            email: email,
            phone: normalizedPhone,
            passwordHash: "", // Not needed with Firebase Auth
            token: result.user.uid,
            role: role
        )
        
        try await saveUser(user)
        try await result.user.sendEmailVerification()
        return user
    }
    
    /// Normalize phone to E.164 for Firebase (e.g. +1XXXXXXXXXX for Canada)
    func normalizePhoneForFirebase(_ phone: String) -> String {
        let digits = phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        if digits.hasPrefix("1") && digits.count == 11 {
            return "+" + digits
        }
        if digits.count == 10 {
            return "+1" + digits
        }
        return "+" + digits
    }
    
    /// Normalize phone for storage (digits only, 10 digits for Canada)
    func normalizePhoneForStorage(_ phone: String) -> String {
        let digits = phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        if digits.hasPrefix("1") && digits.count == 11 {
            return String(digits.dropFirst())
        }
        return digits.count == 10 ? digits : digits
    }
    
    // MARK: - Email verification (OTP / link)
    
    /// Sends email verification to the current user. Call after signup or when resending.
    func sendEmailVerification() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "FirebaseAuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No signed-in user."])
        }
        try await user.sendEmailVerification()
    }
    
    /// Returns whether the current user's email is verified (e.g. after they tapped the link).
    func isEmailVerified() -> Bool {
        Auth.auth().currentUser?.isEmailVerified ?? false
    }
    
    /// Reloads the current user from the server (e.g. to refresh isEmailVerified after they tap the link).
    func reloadCurrentUser() async throws {
        guard let user = Auth.auth().currentUser else { return }
        try await user.reload()
    }
    
    // MARK: - Phone OTP (signup verification and sign-in)
    
    /// Sends SMS OTP to the given phone number. Returns a verification ID to pass to verifyPhoneOTP.
    /// Phone must be E.164 (e.g. +14165551234). Use normalizePhoneForFirebase().
    func sendPhoneOTP(phoneNumberE164: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumberE164, uiDelegate: nil) { verificationID, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let vid = verificationID else {
                    continuation.resume(throwing: NSError(domain: "FirebaseAuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No verification ID returned."]))
                    return
                }
                continuation.resume(returning: vid)
            }
        }
    }
    
    /// Verifies the SMS code and returns a credential. Use to link to current user (signup) or sign in (password reset).
    func verifyPhoneOTP(verificationID: String, verificationCode: String) async throws -> AuthCredential {
        let credential = PhoneAuthProvider.provider().credential(withVerificationID: verificationID, verificationCode: verificationCode)
        return credential
    }
    
    /// Links the verified phone credential to the current user (call after signup so they can use phone for sign-in / reset).
    func linkPhoneCredential(_ credential: AuthCredential) async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "FirebaseAuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No signed-in user."])
        }
        try await user.link(with: credential)
    }
    
    /// Sign in with phone OTP: after verifying code, sign in with the credential. Returns Firestore AppUser if account exists.
    /// (Phone password reset only works for users who linked their phone at signup.)
    func signInWithPhoneCredential(_ credential: AuthCredential) async throws -> AppUser {
        let result = try await Auth.auth().signIn(with: credential)
        do {
            return try await fetchUser(uid: result.user.uid)
        } catch {
            try Auth.auth().signOut()
            throw NSError(domain: "FirebaseAuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No account found for this phone number. Use email sign-up first, then link your phone."])
        }
    }
    
    // MARK: - Password reset
    
    /// Sends password reset email to the given address (Firebase default: link in email).
    func sendPasswordResetEmail(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }
    
    /// Password reset by phone: send OTP, user enters code, then they sign in with phone credential and we let them set a new password.
    /// Call sendPhoneOTP first, then verifyPhoneOTP, then signInWithPhoneCredential. After that, call updatePassword.
    func updatePassword(newPassword: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "FirebaseAuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No signed-in user."])
        }
        try await user.updatePassword(to: newPassword)
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
    }
    
    func getCurrentUser() -> AppUser? {
        guard let firebaseUser = Auth.auth().currentUser else { return nil }
        return AppUser(
            id: firebaseUser.uid,
            fullName: firebaseUser.displayName ?? "",
            email: firebaseUser.email ?? "",
            phone: firebaseUser.phoneNumber ?? "",
            passwordHash: "",
            token: firebaseUser.uid
        )
    }
    
    // MARK: - User Management
    
    func fetchUser(uid: String) async throws -> AppUser {
        let document = try await db.collection("users").document(uid).getDocument()
        return try document.data(as: AppUser.self)
    }
    
    func saveUser(_ user: AppUser) async throws {
        try db.collection("users").document(user.token).setData(from: user)
    }
    
    func updateUser(_ user: AppUser) async throws {
        try await saveUser(user)
    }
    
    /// Updates the phone number on the user document (e.g. after linking phone to Auth).
    func updateUserPhone(uid: String, phoneNormalized: String) async throws {
        try await db.collection("users").document(uid).updateData(["phone": phoneNormalized])
    }
    
    // MARK: - Order Management
    
    func saveOrder(_ order: Order, userId: String) async throws {
        let documentId = order.id ?? UUID().uuidString
        var orderToSave = order
        orderToSave.id = documentId
        try db.collection("orders").document(documentId).setData(from: orderToSave)
    }
    
    func fetchOrders(userId: String) async throws -> [Order] {
        let snapshot = try await db.collection("orders")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        let orders = snapshot.documents.compactMap { document in
            try? document.data(as: Order.self)
        }
        
        // Sort locally instead of using Firestore ordering
        return orders.sorted { $0.createdAt > $1.createdAt }
    }
    
    func deleteOrder(_ orderId: String) async throws {
        try await db.collection("orders").document(orderId).delete()
    }
    
    // MARK: - Profile Management
    
    func saveProfile(_ profile: Profile, userId: String) async throws {
        try db.collection("profiles").document(userId).setData(from: profile)
    }
    
    func fetchProfile(userId: String) async throws -> Profile {
        let document = try await db.collection("profiles").document(userId).getDocument()
        return try document.data(as: Profile.self)
    }
    
    // MARK: - Admin Methods
    
    func fetchAllUsers() async throws -> [AppUser] {
        let snapshot = try await db.collection("users").getDocuments()
        return snapshot.documents.compactMap { document in
            try? document.data(as: AppUser.self)
        }
    }
    
    func fetchAllOrders() async throws -> [Order] {
        let snapshot = try await db.collection("orders")
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? document.data(as: Order.self)
        }
    }
    
    func updateOrderStatus(_ order: Order) async throws {
        guard let orderId = order.id, !orderId.isEmpty else {
            throw NSError(domain: "FirebaseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Order ID is missing or empty"])
        }
        try await db.collection("orders").document(orderId).setData(from: order)
    }
    
    // MARK: - Payment Management
    
    /// Updates the payment status of an order
    func updatePaymentStatus(_ orderId: String, status: PaymentStatus) async throws {
        try await db.collection("orders").document(orderId).updateData([
            "paymentStatus": status.rawValue
        ])
    }
    
    /// Processes a payment for an order (placeholder for future payment integration)
    func processPayment(_ orderId: String, amount: Double, paymentMethod: PaymentMethod) async throws -> Bool {
        // TODO: Integrate with actual payment processor (Stripe, Square, etc.)
        // For now, just update the payment status to paid
        try await updatePaymentStatus(orderId, status: .paid)
        return true
    }
    
    /// Gets payment methods available for a user
    func getPaymentMethods(for userId: String) async throws -> [PaymentMethod] {
        // TODO: Implement actual payment method retrieval
        // For now, return default methods
        return [.cash, .cardTap]
    }
    
    // MARK: - Driver Codes Management
    
    func validateDriverCode(_ code: String) async throws -> Bool {
        let snapshot = try await db.collection("driver_codes")
            .whereField("code", isEqualTo: code.uppercased())
            .whereField("isActive", isEqualTo: true)
            .whereField("usedAt", isEqualTo: NSNull())
            .getDocuments()
        
        return !snapshot.documents.isEmpty
    }
    
    func useDriverCode(_ code: String, userId: String) async throws {
        let snapshot = try await db.collection("driver_codes")
            .whereField("code", isEqualTo: code.uppercased())
            .whereField("isActive", isEqualTo: true)
            .whereField("usedAt", isEqualTo: NSNull())
            .getDocuments()
        
        guard let document = snapshot.documents.first else {
            throw NSError(domain: "DriverCodeError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Driver code not found or already used"])
        }
        
        try await document.reference.updateData([
            "usedAt": Timestamp(date: Date()),
            "usedBy": userId
        ])
    }
    
    func createDriverCode(_ code: String, createdBy: String, notes: String? = nil) async throws {
        let codeData: [String: Any] = [
            "code": code.uppercased(),
            "isActive": true,
            "createdAt": Timestamp(date: Date()),
            "createdBy": createdBy,
            "usedAt": NSNull(),
            "usedBy": NSNull(),
            "notes": notes ?? NSNull()
        ]
        
        try await db.collection("driver_codes").addDocument(data: codeData)
    }
    
    func getAllDriverCodes() async throws -> [[String: Any]] {
        let snapshot = try await db.collection("driver_codes")
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return snapshot.documents.map { document in
            var data = document.data()
            data["id"] = document.documentID
            return data
        }
    }
    
    func deactivateDriverCode(_ codeId: String) async throws {
        try await db.collection("driver_codes").document(codeId).updateData([
            "isActive": false
        ])
    }
    
    // MARK: - Duplicate Checking
    
    /// Checks if an email address is already in use by another user
    /// - Parameter email: Email address to check
    /// - Returns: True if email is already in use, false otherwise
    /// - Throws: FirebaseError if check fails
    func isEmailAlreadyInUse(_ email: String) async throws -> Bool {
        let snapshot = try await db.collection("users")
            .whereField("email", isEqualTo: email)
            .getDocuments()
        
        return !snapshot.documents.isEmpty
    }
    
    /// Checks if a phone number is already in use by another user
    /// - Parameter phone: Phone number to check
    /// - Returns: True if phone is already in use, false otherwise
    /// - Throws: FirebaseError if check fails
    func isPhoneAlreadyInUse(_ phone: String) async throws -> Bool {
        // Normalize phone number for comparison (remove formatting)
        let normalizedPhone = phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        let snapshot = try await db.collection("users")
            .whereField("phone", isEqualTo: normalizedPhone)
            .getDocuments()
        
        return !snapshot.documents.isEmpty
    }
}
