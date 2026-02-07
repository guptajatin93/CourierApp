import SwiftUI

struct ProfileView: View {
    @ObservedObject var auth: FirebaseAuthStore
    @StateObject private var store = FirebaseProfileStore()
    @State private var showSaveSuccess = false
    @State private var showLinkPhoneSheet = false
    
    let token: String
    let initialName: String?
    let initialEmail: String?
    let initialPhone: String?
    let onSignOut: () -> Void
    
    init(
        auth: FirebaseAuthStore,
        token: String,
        initialName: String? = nil,
        initialEmail: String? = nil,
        initialPhone: String? = nil,
        onSignOut: @escaping () -> Void
    ) {
        self.auth = auth
        self.token = token
        self.initialName = initialName
        self.initialEmail = initialEmail
        self.initialPhone = initialPhone
        self.onSignOut = onSignOut
    }
    
    var body: some View {
        NavigationStack {
            if store.isLoading {
                VStack {
                    ProgressView("Loading profile...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .navigationTitle("Profile")
            } else {
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
                                Text("User ID • \(token.suffix(6))")
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
                        .onSubmit {
                            Task {
                                await saveProfileWithFeedback()
                            }
                        }
                        
                        TextField("Email", text: $store.profile.email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .onSubmit {
                                store.saveProfile()
                            }
                        
                        TextField("Phone", text: $store.profile.phone)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                            .onSubmit {
                                store.saveProfile()
                            }
                    }
                    
                    // Phone verification (link for login & password reset)
                    Section {
                        if auth.isPhoneLinked {
                            HStack {
                                Text("Phone linked")
                                    .foregroundColor(.secondary)
                                Spacer()
                                if let masked = auth.linkedPhoneMasked {
                                    Text(masked)
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                }
                            }
                            Text("You can sign in and reset password with this number.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Linking your phone lets you sign in with your phone number and use it for password reset.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Button("Verify & link phone") {
                                showLinkPhoneSheet = true
                            }
                            .disabled(store.profile.phone.isEmpty || store.profile.phone.filter { $0.isNumber }.count < 10)
                        }
                    } header: {
                        Text("Phone verification")
                    } footer: {
                        if !auth.isPhoneLinked && !store.profile.phone.isEmpty && store.profile.phone.filter({ $0.isNumber }).count < 10 {
                            Text("Enter a valid Canadian phone number above, then tap Verify & link phone.")
                        }
                    }
                    
                    // Addresses
                    Section("Addresses") {
                        TextField("Home address", text: $store.profile.homeAddress)
                            .textContentType(.fullStreetAddress)
                            .onSubmit {
                                store.saveProfile()
                            }
                        TextField("Work address", text: $store.profile.workAddress)
                            .textContentType(.fullStreetAddress)
                            .onSubmit {
                                store.saveProfile()
                            }
                    }
                    
                    // Preferences
                    Section("Preferences") {
                        Toggle("Notifications", isOn: $store.profile.notificationsEnabled)
                            .onChange(of: store.profile.notificationsEnabled) { _, _ in
                                Task {
                                    await saveProfileWithFeedback()
                                }
                            }
                    }
                    
                    // Help / About
                    Section {
                        NavigationLink("About") { about }
                        NavigationLink("Privacy") { privacy }
                    }
                    
                    // Save Profile
                    Section {
                        Button(action: {
                            Task {
                                await saveProfileWithFeedback()
                            }
                        }) {
                            HStack {
                                Spacer()
                                if store.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Saving...")
                                        .fontWeight(.semibold)
                                } else {
                                    Text(showSaveSuccess ? "✓ Saved!" : "Save Profile")
                                        .fontWeight(.semibold)
                                        .foregroundColor(showSaveSuccess ? .green : .primary)
                                }
                                Spacer()
                            }
                        }
                        .disabled(store.isLoading)
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
                    .navigationTitle("Profile")
                }
            }
        }
        .onAppear {
            // Refresh profile data from Firebase
            store.loadProfile()
        }
        .onChange(of: store.profile) { oldValue, newValue in
            // Only set initial values if profile is empty (first time login)
            if newValue.fullName.isEmpty, let n = initialName {
                store.profile.fullName = n
            }
            if newValue.email.isEmpty, let e = initialEmail {
                store.profile.email = e
            }
            if newValue.phone.isEmpty, let p = initialPhone {
                store.profile.phone = p
            }
        }
        .sheet(isPresented: $showLinkPhoneSheet) {
            LinkPhoneSheetView(
                auth: auth,
                phone: store.profile.phone,
                onSuccess: { store.loadProfile() }
            )
        }
    }
    
    // MARK: - Helper Functions
    
    private func saveProfileWithFeedback() async {
        store.saveProfile()
        
        // Show success feedback
        await MainActor.run {
            showSaveSuccess = true
        }
        
        // Hide success feedback after 2 seconds
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        await MainActor.run {
            showSaveSuccess = false
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
