import SwiftUI

// If you still have your old User model for users.json:
struct BundledUser: Codable {
    let username: String
    let password: String
    let token: String
    let email: String?
}

struct ContentView: View {
    @StateObject private var auth = FirebaseAuthStore()

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showSignUp: Bool = false

    var body: some View {
        if let u = auth.currentUser {
                    RoleBasedView(auth: auth)
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
                    Task {
                        await signIn()
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(auth.isLoading ? Color.gray : Color.blue)
                .cornerRadius(8)
                .disabled(auth.isLoading)

                Button("Create Account") {
                    showSignUp = true
                }
                .padding(.top, 4)

                if let errorMessage = auth.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .padding()
            .sheet(isPresented: $showSignUp) {
                SignUpView(auth: auth)
            }
        }
    }

    private func signIn() async {
        await auth.signIn(email: email, password: password)
    }
}
extension Notification.Name {
    static let didSignOut = Notification.Name("didSignOut")
}
