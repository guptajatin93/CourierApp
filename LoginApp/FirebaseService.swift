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
    
    func signUp(email: String, password: String, fullName: String, phone: String, role: UserRole = .user) async throws -> AppUser {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        
        let user = AppUser(
            id: result.user.uid,
            fullName: fullName,
            email: email,
            phone: phone,
            passwordHash: "", // Not needed with Firebase Auth
            token: result.user.uid,
            role: role
        )
        
        try await saveUser(user)
        return user
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
    
    // MARK: - Order Management
    
    func saveOrder(_ order: Order, userId: String) async throws {
        let documentId = order.id ?? UUID().uuidString
        try db.collection("orders").document(documentId).setData(from: order)
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
        try await db.collection("orders").document(order.id ?? "").setData(from: order)
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
}
