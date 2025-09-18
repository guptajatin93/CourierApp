//
//  AppUser.swift
//  LoginApp
//
//  Created by Jatin Gupta on 2025-09-12.
//


import Foundation
import CryptoKit
import FirebaseFirestore

// User roles for the courier app
enum UserRole: String, Codable, CaseIterable {
    case user = "user"
    case driver = "driver"
    case admin = "admin"
    
    var displayName: String {
        switch self {
        case .user: return "Customer"
        case .driver: return "Driver"
        case .admin: return "Admin"
        }
    }
}

// Avoid colliding with your existing `User` type used for users.json
struct AppUser: Codable, Identifiable {
    @DocumentID var id: String?
    var fullName: String
    var email: String
    var phone: String
    var passwordHash: String
    var token: String
    var role: UserRole = .user
    var isActive: Bool = true
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: String? = nil,
        fullName: String,
        email: String,
        phone: String,
        passwordHash: String = "",
        token: String = UUID().uuidString,
        role: UserRole = .user
    ) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.phone = phone
        self.passwordHash = passwordHash
        self.token = token
        self.role = role
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

final class AuthStore: ObservableObject {
    @Published var currentUser: AppUser? = nil

    private let key = "registered_users_v1"

    // MARK: - Public API

    func register(fullName: String, email: String, phone: String, password: String) throws {
        var users = loadRegistered()
        guard users.first(where: { $0.email.caseInsensitiveCompare(email) == .orderedSame }) == nil else {
            throw NSError(domain: "Auth", code: 1, userInfo: [NSLocalizedDescriptionKey: "An account with this email already exists."])
        }
        let hash = Self.hash(password: password)
        let user = AppUser(fullName: fullName, email: email, phone: phone, passwordHash: hash)
        users.append(user)
        saveRegistered(users)
        currentUser = user
    }

    /// Returns the authenticated user if valid, otherwise nil
    func signIn(email: String, password: String, bundledFallback: [AppUser] = []) -> AppUser? {
        let hash = Self.hash(password: password)

        // 1) Check registered users
        var users = loadRegistered()
        if let u = users.first(where: { $0.email.caseInsensitiveCompare(email) == .orderedSame && $0.passwordHash == hash }) {
            currentUser = u
            return u
        }

        // 2) Fallback: bundled users (converted to AppUser)
        if let u = bundledFallback.first(where: { $0.email.caseInsensitiveCompare(email) == .orderedSame && $0.passwordHash == hash }) {
            // Optional: persist this bundled user into registered list so it behaves like a normal account
            users.append(u)
            saveRegistered(users)
            currentUser = u
            return u
        }

        return nil
    }

    // MARK: - Registered storage

    func loadRegistered() -> [AppUser] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([AppUser].self, from: data) else {
            return []
        }
        return list
    }

    private func saveRegistered(_ users: [AppUser]) {
        if let data = try? JSONEncoder().encode(users) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // MARK: - Utilities

    static func hash(password: String) -> String {
        let digest = SHA256.hash(data: Data(password.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
