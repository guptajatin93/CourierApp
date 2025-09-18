# Firebase Setup Instructions

This guide will help you set up Firebase for your LoginApp project.

## 1. Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project" or "Add project"
3. Enter project name: `LoginApp` (or your preferred name)
4. Enable Google Analytics (optional)
5. Click "Create project"

## 2. Add iOS App to Firebase

1. In your Firebase project, click "Add app" and select iOS
2. Enter your iOS bundle ID: `com.yourcompany.LoginApp` (or update it in Xcode)
3. Enter app nickname: `LoginApp`
4. Click "Register app"

## 3. Download Configuration File

1. Download the `GoogleService-Info.plist` file
2. Replace the placeholder file in your Xcode project with the downloaded file
3. Make sure it's added to your target

## 4. Enable Authentication

1. In Firebase Console, go to "Authentication" > "Sign-in method"
2. Enable "Email/Password" provider
3. Click "Save"

## 5. Set up Firestore Database

1. In Firebase Console, go to "Firestore Database"
2. Click "Create database"
3. Choose "Start in test mode" (for development)
4. Select a location for your database
5. Click "Done"

## 6. Add Firebase Dependencies to Xcode

1. Open your Xcode project
2. Go to File > Add Package Dependencies
3. Enter: `https://github.com/firebase/firebase-ios-sdk.git`
4. Select version 10.0.0 or later
5. Add these products to your target:
   - FirebaseAuth
   - FirebaseFirestore

## 7. Update Bundle Identifier

1. In Xcode, select your project
2. Go to "Signing & Capabilities"
3. Update the Bundle Identifier to match what you used in Firebase Console

## 8. Test the Integration

1. Build and run your app
2. Try creating a new account
3. Check Firebase Console to see if data appears in Authentication and Firestore

## Security Rules (Optional)

For production, update your Firestore security rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Orders can only be accessed by the user who created them
    match /orders/{orderId} {
      allow read, write: if request.auth != null && 
        request.auth.uid == resource.data.userId;
    }
    
    // Profiles can only be accessed by the user who owns them
    match /profiles/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Troubleshooting

- Make sure `GoogleService-Info.plist` is in your project and added to the target
- Verify your bundle identifier matches Firebase configuration
- Check that Firebase dependencies are properly linked
- Ensure you're using iOS 15+ as the deployment target
