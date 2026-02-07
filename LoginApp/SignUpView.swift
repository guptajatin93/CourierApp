//
//  SignUpView.swift
//  LoginApp
//
//  Created by Jatin Gupta on 2025-09-12.
//


import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var auth: FirebaseAuthStore

    @State private var fullName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var agree = false
    @State private var selectedRole: UserRole = .user
    @State private var emailValidationMessage = ""
    @State private var isEmailValid = false
    @State private var inviteCode = ""
    @State private var isCodeValid = false
    @State private var codeValidationMessage = ""
    @State private var isCheckingCode = false
    @State private var phoneValidationMessage = ""
    @State private var isPhoneValid = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Your Info") {
                    TextField("Full name", text: $fullName)
                        .textContentType(.name)
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .onChange(of: email) { newValue in
                                validateEmail(newValue)
                            }
                        
                        if !emailValidationMessage.isEmpty {
                            Text(emailValidationMessage)
                                .font(.caption)
                                .foregroundColor(isEmailValid ? .green : .red)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Phone (Canadian)", text: $phone)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                            .onChange(of: phone) { newValue in
                                validatePhone(newValue)
                            }
                        
                        if !phoneValidationMessage.isEmpty {
                            Text(phoneValidationMessage)
                                .font(.caption)
                                .foregroundColor(isPhoneValid ? .green : .red)
                        }
                    }
                }

                Section("Password") {
                    SecureField("Password (min 6 chars)", text: $password)
                    SecureField("Confirm password", text: $confirmPassword)
                }
                
                Section("Invite Code (Optional)") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Enter driver invite code", text: $inviteCode)
                            .textCase(.uppercase)
                            .autocapitalization(.allCharacters)
                            .onChange(of: inviteCode) { newValue in
                                validateInviteCode(newValue)
                            }
                        
                        if isCheckingCode {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Checking code...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else if !codeValidationMessage.isEmpty {
                            Text(codeValidationMessage)
                                .font(.caption)
                                .foregroundColor(isCodeValid ? .green : .red)
                        }
                    }
                }
                
                Section("Account Type") {
                    Picker("Role", selection: $selectedRole) {
                        Text("Customer").tag(UserRole.user)
                        if isCodeValid {
                            Text("Driver").tag(UserRole.driver)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(!isCodeValid && selectedRole == .driver)
                }

                Section {
                    Toggle("I agree to Terms & Privacy", isOn: $agree)
                }

                if let errorMessage = auth.errorMessage {
                    Section {
                        Text(errorMessage).foregroundColor(.red)
                    }
                }

                Section {
                    Button("Create Account") {
                        Task {
                            await submit()
                        }
                    }
                    .disabled(!canSubmit || auth.isLoading || !isEmailValid)
                }
            }
            .navigationTitle("Create Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var canSubmit: Bool {
        !fullName.isEmpty &&
        isEmailValid &&
        isPhoneValid &&
        password.count >= 6 &&
        password == confirmPassword &&
        agree
    }

    private func submit() async {
        guard canSubmit && isEmailValid else { return }
        
        // If signing up as driver, validate and use the invite code
        if selectedRole == .driver {
            guard isCodeValid && !inviteCode.isEmpty else { return }
        }
        
        await auth.signUp(email: email, password: password, fullName: fullName, phone: phone, role: selectedRole, inviteCode: selectedRole == .driver ? inviteCode : nil)
        if auth.currentUser != nil {
            auth.setPendingSignUpVerification(email: email, phone: phone)
            dismiss()
        }
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
        
        // Format only; duplicate check happens at sign-up (Firebase Auth returns "email already in use")
        emailValidationMessage = "✓ Valid email address"
        isEmailValid = true
    }
    
    // MARK: - Invite Code Validation
    
    private func validateInviteCode(_ code: String) {
        if code.isEmpty {
            codeValidationMessage = ""
            isCodeValid = false
            selectedRole = .user // Reset to customer if code is cleared
            return
        }
        
        // Basic format validation
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedCode.count < 3 {
            codeValidationMessage = "Code too short"
            isCodeValid = false
            return
        }
        
        // Check code with Firebase
        isCheckingCode = true
        codeValidationMessage = ""
        
        Task {
            do {
                let isValid = try await FirebaseService.shared.validateDriverCode(trimmedCode)
                await MainActor.run {
                    isCheckingCode = false
                    if isValid {
                        codeValidationMessage = "✓ Valid driver code"
                        isCodeValid = true
                    } else {
                        codeValidationMessage = "Invalid or already used code"
                        isCodeValid = false
                        selectedRole = .user // Reset to customer if code is invalid
                    }
                }
            } catch {
                await MainActor.run {
                    isCheckingCode = false
                    codeValidationMessage = "Error checking code. Please try again."
                    isCodeValid = false
                    selectedRole = .user
                }
            }
        }
    }
    
    // MARK: - Phone Validation
    
    private func validatePhone(_ phone: String) {
        if phone.isEmpty {
            phoneValidationMessage = ""
            isPhoneValid = false
            return
        }
        
        // Remove all non-digit characters for validation
        let digitsOnly = phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        // Check if it starts with 1 (North American country code)
        let phoneNumber: String
        if digitsOnly.hasPrefix("1") && digitsOnly.count == 11 {
            phoneNumber = String(digitsOnly.dropFirst()) // Remove the 1
        } else if digitsOnly.count == 10 {
            phoneNumber = digitsOnly
        } else {
            phoneValidationMessage = "Please enter a valid Canadian phone number"
            isPhoneValid = false
            return
        }
        
        // Validate length (should be 10 digits after removing country code)
        guard phoneNumber.count == 10 else {
            phoneValidationMessage = "Phone number must be 10 digits"
            isPhoneValid = false
            return
        }
        
        // Extract area code (first 3 digits)
        let areaCode = String(phoneNumber.prefix(3))
        
        // Validate Canadian area codes
        if !isValidCanadianAreaCode(areaCode) {
            phoneValidationMessage = "Please enter a valid Canadian area code"
            isPhoneValid = false
            return
        }
        
        // Validate NANP format (area code cannot start with 0 or 1)
        if areaCode.hasPrefix("0") || areaCode.hasPrefix("1") {
            phoneValidationMessage = "Invalid area code format"
            isPhoneValid = false
            return
        }
        
        // Validate exchange code (digits 4-6, cannot start with 0 or 1)
        let exchangeCode = String(phoneNumber.dropFirst(3).prefix(3))
        if exchangeCode.hasPrefix("0") || exchangeCode.hasPrefix("1") {
            phoneValidationMessage = "Invalid phone number format"
            isPhoneValid = false
            return
        }
        
        // Format only; duplicate phone is not checked here (would require Firestore read before sign-in)
        phoneValidationMessage = "✓ Valid Canadian phone number"
        isPhoneValid = true
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
