# Oscars With Friends - iOS App

Native iOS app for predicting Oscar winners with friends.

## Requirements

- Xcode 16.0+
- iOS 18.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (for project generation)

## Setup

### 1. Install XcodeGen

```bash
brew install xcodegen
```

### 2. Add Firebase Configuration

Download `GoogleService-Info.plist` from the Firebase Console and place it in:
```
OscarsWithFriends/Resources/GoogleService-Info.plist
```

### 3. Configure Google Sign-In

1. Get the `REVERSED_CLIENT_ID` from your `GoogleService-Info.plist`
2. Add it to the Info.plist URL Schemes (already configured with `$(GOOGLE_REVERSED_CLIENT_ID)`)
3. Set the build setting or replace the variable directly

### 4. Generate Xcode Project

```bash
cd /Users/angusjohnston/src-ios-native/oscars-with-friends
xcodegen generate
```

### 5. Open and Run

```bash
open OscarsWithFriends.xcodeproj
```

## Features

- **Authentication**: Sign in with Apple, Google, or Email/Password
- **Competitions**: Create and join Oscar prediction competitions
- **Voting**: Vote on nominees in each category
- **Leaderboard**: Real-time scoring and rankings
- **Push Notifications**: Get notified when winners are announced

## Project Structure

```
OscarsWithFriends/
├── App/
│   ├── OscarsWithFriendsApp.swift    # App entry point
│   └── AppDelegate.swift              # Firebase & push setup
├── Models/
│   ├── User.swift
│   ├── Category.swift
│   ├── Competition.swift
│   ├── Participant.swift
│   └── Vote.swift
├── Services/
│   ├── AuthService.swift              # Firebase Auth
│   ├── FirestoreService.swift         # Real-time data
│   ├── CloudFunctionsService.swift    # API calls
│   └── NotificationService.swift      # Push notifications
├── Views/
│   ├── ContentView.swift              # Root view with auth state
│   ├── Auth/
│   ├── Home/
│   ├── Competition/
│   ├── Categories/
│   ├── Leaderboard/
│   └── Profile/
└── Resources/
    └── GoogleService-Info.plist       # Firebase config (add this)
```

## Dependencies

- [firebase-ios-sdk](https://github.com/firebase/firebase-ios-sdk) - Firebase Auth, Firestore, Functions, Messaging
- [GoogleSignIn-iOS](https://github.com/google/GoogleSignIn-iOS) - Google Sign-In

## Firebase Configuration

Ensure these are enabled in your Firebase project:
- Authentication (Apple, Google, Email/Password providers)
- Firestore Database
- Cloud Functions (asia-south1 region)
- Cloud Messaging
