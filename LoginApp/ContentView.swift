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
    @State private var emailValidationMessage = ""
    @State private var isEmailValid = false

    var body: some View {
        if let u = auth.currentUser {
                    RoleBasedView(auth: auth)
                }
        else {
            VStack(spacing: 20) {
                Text("Courier Sign In")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 4) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .onChange(of: email) { newValue in
                            validateEmail(newValue)
                        }
                    
                    if !emailValidationMessage.isEmpty {
                        Text(emailValidationMessage)
                            .font(.caption)
                            .foregroundColor(isEmailValid ? .green : .red)
                    }
                }

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
                .background(auth.isLoading ? Color.gray : (isEmailValid ? Color.blue : Color.gray))
                .cornerRadius(8)
                .disabled(auth.isLoading || !isEmailValid)

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
        guard isEmailValid else { return }
        await auth.signIn(email: email, password: password)
    }
    
    // MARK: - Email Validation
    
    private func validateEmail(_ email: String) {
        if email.isEmpty {
            emailValidationMessage = ""
            isEmailValid = false
            return
        }
        
        // Basic format validation
        let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        if !emailPredicate.evaluate(with: email) {
            emailValidationMessage = "Please enter a valid email address"
            isEmailValid = false
            return
        }
        
        // Additional checks
        if email.count > 254 {
            emailValidationMessage = "Email address is too long"
            isEmailValid = false
            return
        }
        
        if email.hasPrefix(".") || email.hasSuffix(".") {
            emailValidationMessage = "Email cannot start or end with a dot"
            isEmailValid = false
            return
        }
        
        if email.contains("..") {
            emailValidationMessage = "Email cannot contain consecutive dots"
            isEmailValid = false
            return
        }
        
        // Check for common typos (only check for specific typos, not all Gmail addresses)
        if email.hasSuffix("@gmai.com") || email.hasSuffix("@gmail.co") {
            emailValidationMessage = "Did you mean @gmail.com?"
            isEmailValid = false
            return
        }
        
        emailValidationMessage = "✓ Valid email address"
        isEmailValid = true
    }
}
extension Notification.Name {
    static let didSignOut = Notification.Name("didSignOut")
}
