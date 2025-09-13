//
//  Profile.swift
//  LoginApp
//
//  Created by Jatin Gupta on 2025-09-12.
//


import Foundation

struct Profile: Codable {
    var fullName: String = ""
    var email: String = ""
    var phone: String = ""
    var homeAddress: String = ""
    var workAddress: String = ""
    var notificationsEnabled: Bool = true
}

final class ProfileStore: ObservableObject {
    @Published var profile: Profile {
        didSet { save() }
    }

    private static let key = "profile_v1"

    init() {
        self.profile = Self.load()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    private static func load() -> Profile {
        guard let data = UserDefaults.standard.data(forKey: key),
              let profile = try? JSONDecoder().decode(Profile.self, from: data) else {
            return Profile()
        }
        return profile
    }
}
