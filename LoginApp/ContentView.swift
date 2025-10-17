import SwiftUI

// If you still have your old User model for users.json:
struct BundledUser: Codable {
    let username: String
    let password: String
    let token: String
    let email: String?
}

enum InputType {
    case email
    case phone
    case unknown
}

struct ContentView: View {
    @StateObject private var auth = FirebaseAuthStore()

    @State private var emailOrPhone: String = ""
    @State private var password: String = ""
    @State private var showSignUp: Bool = false
    @State private var validationMessage = ""
    @State private var isValid = false
    @State private var inputType: InputType = .unknown

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
                    TextField("Email or Phone Number", text: $emailOrPhone)
                        .textContentType(.username)
                        .autocapitalization(.none)
                        .keyboardType(.default)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .onChange(of: emailOrPhone) { newValue in
                            validateInput(newValue)
                        }
                    
                    if !validationMessage.isEmpty {
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundColor(isValid ? .green : .red)
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
                .background(auth.isLoading ? Color.gray : (isValid ? Color.blue : Color.gray))
                .cornerRadius(8)
                .disabled(auth.isLoading || !isValid)

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
        guard isValid && !password.isEmpty else { return }
        
        switch inputType {
        case .email:
            await auth.signIn(email: emailOrPhone, password: password)
        case .phone:
            await auth.signInWithPhone(phone: emailOrPhone, password: password)
        case .unknown:
            return
        }
    }
    
    // MARK: - Smart Input Validation
    
    private func validateInput(_ input: String) {
        if input.isEmpty {
            validationMessage = ""
            isValid = false
            inputType = .unknown
            return
        }
        
        // Detect if input is email or phone
        if isEmailFormat(input) {
            validateEmail(input)
        } else if isPhoneFormat(input) {
            validatePhone(input)
        } else {
            validationMessage = "Please enter a valid email or Canadian phone number"
            isValid = false
            inputType = .unknown
        }
    }
    
    private func isEmailFormat(_ input: String) -> Bool {
        return input.contains("@") && input.contains(".")
    }
    
    private func isPhoneFormat(_ input: String) -> Bool {
        let digitsOnly = input.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        return digitsOnly.count >= 10 && digitsOnly.count <= 11
    }
    
    private func validateEmail(_ email: String) {
        inputType = .email
        
        // Basic format validation
        let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        if !emailPredicate.evaluate(with: email) {
            validationMessage = "Please enter a valid email address"
            isValid = false
            return
        }
        
        // Additional checks
        if email.count > 254 {
            validationMessage = "Email address is too long"
            isValid = false
            return
        }
        
        if email.hasPrefix(".") || email.hasSuffix(".") {
            validationMessage = "Email cannot start or end with a dot"
            isValid = false
            return
        }
        
        if email.contains("..") {
            validationMessage = "Email cannot contain consecutive dots"
            isValid = false
            return
        }
        
        // Check for common typos
        if email.hasSuffix("@gmai.com") || email.hasSuffix("@gmail.co") {
            validationMessage = "Did you mean @gmail.com?"
            isValid = false
            return
        }
        
        // For sign-in, just validate format - don't check duplicates
        validationMessage = "✓ Valid email address"
        isValid = true
    }
    
    private func validatePhone(_ phone: String) {
        inputType = .phone
        
        // Remove all non-digit characters for validation
        let digitsOnly = phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        // Check if it starts with 1 (North American country code)
        let phoneNumber: String
        if digitsOnly.hasPrefix("1") && digitsOnly.count == 11 {
            phoneNumber = String(digitsOnly.dropFirst()) // Remove the 1
        } else if digitsOnly.count == 10 {
            phoneNumber = digitsOnly
        } else {
            validationMessage = "Please enter a valid Canadian phone number"
            isValid = false
            return
        }
        
        // Validate length (should be 10 digits after removing country code)
        guard phoneNumber.count == 10 else {
            validationMessage = "Phone number must be 10 digits"
            isValid = false
            return
        }
        
        // Extract area code (first 3 digits)
        let areaCode = String(phoneNumber.prefix(3))
        
        // Validate Canadian area codes
        if !isValidCanadianAreaCode(areaCode) {
            validationMessage = "Please enter a valid Canadian area code"
            isValid = false
            return
        }
        
        // Validate NANP format (area code cannot start with 0 or 1)
        if areaCode.hasPrefix("0") || areaCode.hasPrefix("1") {
            validationMessage = "Invalid area code format"
            isValid = false
            return
        }
        
        // Validate exchange code (digits 4-6, cannot start with 0 or 1)
        let exchangeCode = String(phoneNumber.dropFirst(3).prefix(3))
        if exchangeCode.hasPrefix("0") || exchangeCode.hasPrefix("1") {
            validationMessage = "Invalid phone number format"
            isValid = false
            return
        }
        
        // For sign-in, just validate format - don't check duplicates
        validationMessage = "✓ Valid Canadian phone number"
        isValid = true
    }
    
    private func isValidCanadianAreaCode(_ areaCode: String) -> Bool {
        let canadianAreaCodes = [
            // Greater Toronto Area
            "416", "647", "905", "289", "365",
            // Ontario
            "613", "519", "705", "807", "249", "343", "437", "548", "683", "742", "753", "782", "825", "873",
            // Alberta
            "403", "587", "825", "780",
            // British Columbia
            "604", "778", "236", "672", "250",
            // Manitoba
            "204", "431",
            // New Brunswick
            "506",
            // Newfoundland and Labrador
            "709",
            // Northwest Territories
            "867",
            // Nova Scotia
            "902", "782",
            // Nunavut
            "867",
            // Prince Edward Island
            "902", "782",
            // Quebec
            "418", "438", "450", "514", "579", "581", "819", "873",
            // Saskatchewan
            "306", "639",
            // Yukon
            "867"
        ]
        
        return canadianAreaCodes.contains(areaCode)
    }
}
extension Notification.Name {
    static let didSignOut = Notification.Name("didSignOut")
}
