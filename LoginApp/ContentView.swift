import SwiftUI

// If you still have your old User model for users.json:
struct BundledUser: Codable {
    let username: String
    let password: String
    let token: String
    let email: String?
}

struct ContentView: View {
    @StateObject private var auth = AuthStore()

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoggedIn: Bool = false
    @State private var showSignUp: Bool = false
    @State private var message: String = ""

    var body: some View {
        if isLoggedIn, let u = auth.currentUser {
                    UserPageView(
                        token: u.token,
                        initialName: u.fullName,
                        initialEmail: u.email
                    )
                    .onReceive(NotificationCenter.default.publisher(for: .didSignOut)) { _ in
                        auth.currentUser = nil
                        isLoggedIn = false
                    }
                }
        else {
            VStack(spacing: 20) {
                Text("Courier Sign In")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                SecureField("Password", text: $password)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                Button("Sign In") {
                    signIn()
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(8)

                Button("Create Account") {
                    showSignUp = true
                }
                .padding(.top, 4)

                if !message.isEmpty {
                    Text(message)
                        .foregroundColor(.red)
                }
            }
            .padding()
            .sheet(isPresented: $showSignUp) {
                SignUpView(auth: auth)
            }
        }
    }

    private func signIn() {
        message = ""
        let fallback = loadBundledUsersAsAppUsers()
        if let _ = auth.signIn(email: email, password: password, bundledFallback: fallback) {
            isLoggedIn = true
        } else {
            message = "Invalid credentials"
        }
    }

    private func loadBundledUsersAsAppUsers() -> [AppUser] {
        guard let url = Bundle.main.url(forResource: "users", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([BundledUser].self, from: data) else {
            return []
        }
        // Map to AppUser with hashed password so sign-in path is uniform
        return raw.map {
            let hashed = AuthStore.hash(password: $0.password)
            return AppUser(fullName: $0.username,
                           email: $0.email ?? "\($0.username)@example.com",
                           phone: "",
                           passwordHash: hashed,
                           token: $0.token)
        }
    }
}
extension Notification.Name {
    static let didSignOut = Notification.Name("didSignOut")
}
