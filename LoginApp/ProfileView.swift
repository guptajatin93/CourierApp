import SwiftUI

struct ProfileView: View {
    @StateObject private var store = FirebaseProfileStore()

    let token: String
    let initialName: String?
    let initialEmail: String?
    let onSignOut: () -> Void

    init(
        token: String,
        initialName: String? = nil,
        initialEmail: String? = nil,
        onSignOut: @escaping () -> Void
    ) {
        self.token = token
        self.initialName = initialName
        self.initialEmail = initialEmail
        self.onSignOut = onSignOut
    }

    var body: some View {
        NavigationStack {
            Form {
                // Header
                Section {
                    HStack(spacing: 16) {
                        avatar
                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.profile.fullName.isEmpty ? "Your Name" : store.profile.fullName)
                                .font(.headline)
                            Text(store.profile.email.isEmpty ? "email@example.com" : store.profile.email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Token • \(token.suffix(6))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }

                // Account
                Section("Account") {
                    TextField("Full name", text: $store.profile.fullName)
                        .textContentType(.name)
                        .autocorrectionDisabled()

                    TextField("Email", text: $store.profile.email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)

                    TextField("Phone", text: $store.profile.phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                }

                // Addresses
                Section("Addresses") {
                    TextField("Home address", text: $store.profile.homeAddress)
                        .textContentType(.fullStreetAddress)
                    TextField("Work address", text: $store.profile.workAddress)
                        .textContentType(.fullStreetAddress)
                }

                // Preferences
                Section("Preferences") {
                    Toggle("Notifications", isOn: $store.profile.notificationsEnabled)
                }

                // Help / About
                Section {
                    NavigationLink("About") { about }
                    NavigationLink("Privacy") { privacy }
                }

                // Sign Out
                Section {
                    Button(role: .destructive) {
                        onSignOut()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Profile")
        }
        .onAppear {
            // 🔹 Always overwrite with login details
            if let n = initialName { store.profile.fullName = n }
            if let e = initialEmail { store.profile.email = e }
        }
    }

    // MARK: - Pieces

    private var avatar: some View {
        ZStack {
            Circle().fill(Color(.systemGray6))
            Text(initials(from: store.profile.fullName))
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .frame(width: 64, height: 64)
        .overlay(Circle().stroke(Color(.systemGray4), lineWidth: 1))
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first?.uppercased() }
        return letters.joined().isEmpty ? "👤" : letters.joined()
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Courier App").font(.title2).bold()
            Text("Version 1.0").foregroundColor(.secondary)
            Text("A simple courier demo with pickup/dropoff, routing, and orders.")
                .padding(.top, 8)
            Spacer()
        }
        .padding()
        .navigationTitle("About")
    }

    private var privacy: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Privacy").font(.title2).bold()
            Text("Profile is stored locally on your device using UserDefaults.")
                .padding(.top, 8)
            Spacer()
        }
        .padding()
        .navigationTitle("Privacy")
    }
}
