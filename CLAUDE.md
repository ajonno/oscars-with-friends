# Awards With Friends - iOS App Documentation

This document provides comprehensive documentation of the iOS app for use in building an identical Android version.

## Tech Stack

- **Platform**: iOS 18+
- **UI Framework**: SwiftUI
- **Architecture**: MVVM with @Observable pattern
- **Backend**: Firebase (Auth, Firestore, Cloud Functions, Cloud Messaging)
- **Region**: asia-south1 (Mumbai)
- **In-App Purchases**: StoreKit 2

## Project Structure

```
awards-with-friends/
├── App/
│   ├── awards_with_friendsApp.swift    # App entry point
│   └── AppDelegate.swift               # Push notification handling
├── Models/
│   ├── User.swift
│   ├── Competition.swift
│   ├── Ceremony.swift
│   ├── Category.swift
│   ├── Vote.swift
│   ├── Participant.swift
│   └── EventType.swift
├── Services/
│   ├── AuthService.swift
│   ├── FirestoreService.swift
│   ├── CloudFunctionsService.swift
│   ├── StoreService.swift
│   ├── ConfigService.swift
│   └── NotificationService.swift
└── Views/
    ├── Auth/
    ├── Home/
    ├── Competition/
    ├── Categories/
    ├── Ceremonies/
    ├── Leaderboard/
    └── Profile/
```

---

## Authentication

### Supported Auth Methods
1. **Sign in with Apple** - Primary method
2. **Google Sign-In** - Secondary method
3. **Email/Password** - Fallback method (sign up + sign in)

### Auth Flow
1. User opens app → Check for existing session
2. If no session → Show `LoginView`
3. User authenticates → Create/update user document in Firestore
4. Session persists automatically via Firebase Auth

### User Document Structure (Firestore: `/users/{uid}`)
```javascript
{
  uid: string,
  email: string,
  displayName: string,
  photoURL: string | null,
  fcmToken: string | null,
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

---

## Screens & Features

### 1. LoginView (`Views/Auth/LoginView.swift`)

**Purpose**: Entry point for unauthenticated users

**UI Elements**:
- App logo/icon at top
- "Awards With Friends" title
- Tagline text
- Sign in with Apple button (full-width, black)
- Sign in with Google button (full-width, white with Google colors)
- "Sign in with Email" button (text link style)
- Keyboard-aware layout

**User Interactions**:
- Tap Apple button → Native Apple Sign-In sheet
- Tap Google button → Google Sign-In web flow
- Tap Email link → Navigate to `EmailSignInView`

**State Management**:
- `isLoading: Bool` - Shows loading overlay during auth
- `error: String?` - Displays error alerts

---

### 2. EmailSignInView (`Views/Auth/EmailSignInView.swift`)

**Purpose**: Email/password authentication

**UI Elements**:
- Back button (navigation)
- Title: "Sign In" or "Create Account"
- Email text field (keyboard type: email)
- Password secure field
- Confirm password field (sign up mode only)
- Primary action button ("Sign In" / "Create Account")
- Toggle link ("Don't have an account?" / "Already have an account?")

**User Interactions**:
- Enter credentials → Tap action button
- Toggle between sign in / sign up modes
- Back button to return to LoginView

**Validation**:
- Email format validation
- Password minimum length (6 characters)
- Password confirmation match (sign up only)

**State Management**:
- `isSignUp: Bool` - Toggles between modes
- `email: String`
- `password: String`
- `confirmPassword: String`
- `isLoading: Bool`
- `error: String?`

---

### 3. HomeView (`Views/Home/HomeView.swift`)

**Purpose**: Main competitions list screen

**UI Elements**:
- Title: "Competitions" (large, bold)
- Plus button (top right) → Menu with Create/Join options
- Segmented filter: All | Mine | Joined
- Competition cards list (scrollable)
- Empty state with Create/Join buttons (full-width)

**Competition Card (`CompetitionCard.swift`)**:
- Competition name (bold)
- Event name (e.g., "97th Academy Awards")
- Status badge (Open/Locked/Completed/Inactive)
- Participant count
- Your score (if applicable)
- Leaderboard button (icon)
- Share button (icon) - owner only

**Filter Logic**:
- **All**: All competitions user is part of
- **Mine**: Competitions where `createdBy == currentUserId`
- **Joined**: Competitions where `createdBy != currentUserId`

**Sorting**:
- Active competitions first (sorted by createdAt descending)
- Inactive competitions at bottom

**State Management**:
- `competitions: [Competition]` - Real-time from Firestore
- `isLoading: Bool`
- `filter: CompetitionFilter`
- `selectedCompetition: Competition?` - For navigation
- `leaderboardCompetition: Competition?` - For leaderboard sheet
- `shareCompetition: Competition?` - For invite sheet
- `showPaywall: Bool` - IAP gate

**Navigation**:
- Tap card → `CompetitionDetailView`
- Tap leaderboard icon → `LeaderboardView`
- Tap share icon → `InviteSheet`

**Paywall Check**:
- Before Create/Join, check `canAccessCompetitions`:
  - If `!configService.requiresPaymentForCompetitions` → Allow
  - Else if `storeService.hasCompetitionsAccess` → Allow
  - Else → Show `PaywallView`

---

### 4. CreateCompetitionView (`Views/Competition/CreateCompetitionView.swift`)

**Purpose**: Create a new competition

**UI Elements**:
- Navigation title: "Create Competition"
- Cancel button (top left)
- Create button (top right, disabled until valid)
- Competition name text field
- Event picker (dropdown/wheel)
- Loading indicator during creation

**Event Picker**:
- Lists available ceremonies from Firestore
- Shows event name and date
- Sorted by date (upcoming first)

**Validation**:
- Name must not be empty
- Name max length (50 characters)
- Must select an event

**Flow**:
1. Enter competition name
2. Select event/ceremony
3. Tap Create
4. Cloud Function generates invite code
5. On success → Dismiss and show InviteSheet

**State Management**:
- `name: String`
- `selectedCeremony: Ceremony?`
- `ceremonies: [Ceremony]`
- `isLoading: Bool`
- `error: String?`

---

### 5. JoinCompetitionView (`Views/Competition/JoinCompetitionView.swift`)

**Purpose**: Join an existing competition via invite code

**UI Elements**:
- Navigation title: "Join Competition"
- Cancel button (top left)
- Join button (top right)
- Invite code text field (uppercase, 6 characters)
- Instructional text
- Loading indicator

**Validation**:
- Code must be exactly 6 characters
- Alphanumeric only, auto-uppercase

**Flow**:
1. Enter 6-character invite code
2. Tap Join
3. Cloud Function validates code and adds user
4. On success → Dismiss and refresh competitions list

**Error Handling**:
- Invalid code → "Competition not found"
- Already joined → "You're already in this competition"
- Competition locked → "This competition is no longer accepting participants"

---

### 6. CompetitionDetailView (`Views/Competition/CompetitionDetailView.swift`)

**Purpose**: View and interact with a specific competition

**UI Elements**:
- Back button
- Navigation title: Competition name
- Menu button (three dots) with:
  - Share/Invite (owner only)
  - View Leaderboard
  - Leave Competition (non-owner)
  - Delete Competition (owner only, if inactive)
- Categories list (grouped by status)
- Progress summary at top

**Categories List**:
- Grouped sections:
  - "Make Your Picks" - Categories needing votes
  - "Your Picks" - Categories already voted
  - "Winners Announced" - Completed categories
- Each row shows:
  - Category name
  - Your pick (if voted)
  - Winner indicator (if announced)
  - Checkmark if your pick won

**Category Row States**:
- **Not voted**: Category name, "Tap to vote" hint
- **Voted, no winner**: Category name, your pick name/thumbnail
- **Winner announced, you got it right**: Green checkmark, winner shown
- **Winner announced, you got it wrong**: Red X, your pick crossed out

**Navigation**:
- Tap category → `CategoryDetailView`

**Owner Actions**:
- Can share invite code
- Can delete competition (only if inactive/no votes)

**Participant Actions**:
- Can leave competition (confirmation dialog)

---

### 7. CategoryDetailView (`Views/Categories/CategoryDetailView.swift`)

**Purpose**: View nominees and cast vote for a category

**UI Elements**:
- Back button
- Category name as title
- Nominee cards (grid or list)
- "Locked" banner if voting closed
- "Winner" banner on winning nominee

**Nominee Card (`NomineeCard.swift`)**:
- Nominee image (movie poster or person photo)
- Nominee name (person for acting, movie for others)
- Secondary text (movie name for acting categories)
- Selection indicator (checkmark/border)
- Winner crown icon (if winner)

**Voting States**:
- **Open**: Can tap to select/change vote
- **Locked**: Cannot change, shows your pick
- **Winner Announced**: Shows winner, your pick marked right/wrong

**Vote Casting**:
1. Tap nominee card
2. Optimistic UI update
3. Cloud Function call to persist vote
4. On error → Revert UI and show error

**State Management**:
- `category: Category`
- `nominees: [Nominee]`
- `selectedNomineeId: String?`
- `isVotingLocked: Bool`
- `winnerId: String?`
- `isLoading: Bool`

---

### 8. CeremoniesView (`Views/Ceremonies/CeremoniesView.swift`)

**Purpose**: Browse all available award ceremonies

**UI Elements**:
- Navigation title: "Ceremonies"
- List of ceremony cards
- Search/filter (optional)

**Ceremony Card**:
- Event logo/icon
- Event name (e.g., "97th Academy Awards")
- Date
- Status badge (Upcoming/Live/Completed)
- Category count

**Navigation**:
- Tap ceremony → `CeremonyDetailView` (categories list)

---

### 9. LeaderboardView (`Views/Leaderboard/LeaderboardView.swift`)

**Purpose**: View competition rankings

**UI Elements**:
- Navigation title: "Leaderboard"
- Competition name subtitle
- Participant list (ranked)
- Current user highlighted

**Participant Row**:
- Rank number (1, 2, 3... with medals for top 3)
- Profile picture (or initials)
- Display name
- Score (X/Y correct)
- Progress bar (visual score)

**Sorting**:
- By score (descending)
- Ties broken by earliest correct picks

**Real-time Updates**:
- Scores update live as winners announced

**State Management**:
- `participants: [Participant]`
- `isLoading: Bool`
- Real-time listener on participants subcollection

---

### 10. ProfileView (`Views/Profile/ProfileView.swift`)

**Purpose**: User settings and account management

**UI Elements**:
- Profile header:
  - Profile picture (editable)
  - Display name (editable)
  - Email (read-only)
- Settings sections:
  - Push notifications toggle
  - App version info
- Actions:
  - Restore Purchases
  - Sign Out button
  - Delete Account (destructive)

**Edit Profile**:
- Tap profile picture → Image picker
- Tap name → Inline editing
- Changes saved automatically

**Restore Purchases**:
- Tap to restore IAP
- Shows loading indicator
- Success/failure alert

**Sign Out**:
- Confirmation dialog
- Clears local data
- Returns to LoginView

**Delete Account**:
- Double confirmation required
- Calls Cloud Function to delete user data
- Signs out and returns to LoginView

---

### 11. PaywallView (`Views/Home/PaywallView.swift`)

**Purpose**: In-app purchase gate for competitions access

**UI Elements**:
- Close button (X, top right)
- Trophy icon (large, centered)
- Title: "Unlock Competitions"
- Feature list with checkmarks:
  - "Create unlimited competitions"
  - "Join any competition"
  - "Compete with friends"
- Price display ($2.99, one-time)
- "Purchase" button (prominent, blue)
- "Restore Purchases" button (text link)
- Terms/privacy links at bottom

**Purchase Flow**:
1. Tap Purchase button
2. StoreKit 2 purchase sheet appears
3. User confirms with Face ID/password
4. On success → Dismiss paywall, grant access
5. On cancel/failure → Show appropriate message

**Restore Flow**:
1. Tap Restore Purchases
2. StoreKit restores transactions
3. If valid purchase found → Grant access
4. If none found → Show "No purchases to restore"

---

### 12. InviteSheet (`Views/Home/HomeView.swift`)

**Purpose**: Share competition invite code

**UI Elements**:
- Sheet presentation (medium detent)
- Title: "Invite Friends"
- Competition name
- Large invite code display (monospace font)
- "Copy Code" button
- "Share Invite" button (system share sheet)
- Done button

**Share Message Format**:
```
Join my [Event Name] competition!

Use invite code: XXXXXX

Download Awards With Friends:
https://apps.apple.com/app/id1638720136
```

---

## Services

### AuthService (`Services/AuthService.swift`)

**Responsibilities**:
- Firebase Auth integration
- Sign in with Apple
- Google Sign-In
- Email/password auth
- Session management
- User document creation/update

**Key Methods**:
```swift
func signInWithApple() async throws -> User
func signInWithGoogle() async throws -> User
func signInWithEmail(email: String, password: String) async throws -> User
func signUpWithEmail(email: String, password: String) async throws -> User
func signOut() throws
func deleteAccount() async throws
var currentUser: User? { get }
var isAuthenticated: Bool { get }
```

**Sign in with Apple Flow**:
1. Request Apple credential (ASAuthorizationController)
2. Create Firebase credential from Apple identity token
3. Sign in to Firebase Auth
4. Create/update user document in Firestore
5. Return user

**Google Sign-In Flow**:
1. Present Google Sign-In UI
2. Get Google credential
3. Create Firebase credential
4. Sign in to Firebase Auth
5. Create/update user document
6. Return user

---

### FirestoreService (`Services/FirestoreService.swift`)

**Responsibilities**:
- Real-time data listeners
- Data fetching and caching
- Firestore queries

**Key Methods**:
```swift
// Competitions
func myCompetitionsStream() -> AsyncThrowingStream<[Competition], Error>
func competitionStream(id: String) -> AsyncThrowingStream<Competition, Error>

// Categories
func categoriesStream(ceremonyId: String) -> AsyncThrowingStream<[Category], Error>
func nomineesStream(categoryId: String) -> AsyncThrowingStream<[Nominee], Error>

// Participants & Votes
func participantsStream(competitionId: String) -> AsyncThrowingStream<[Participant], Error>
func votesStream(competitionId: String, userId: String) -> AsyncThrowingStream<[Vote], Error>

// Ceremonies
func ceremoniesStream() -> AsyncThrowingStream<[Ceremony], Error>

// User
func userStream(uid: String) -> AsyncThrowingStream<User, Error>
func updateUser(uid: String, data: [String: Any]) async throws
```

**Collections Structure**:
```
/users/{uid}
/ceremonies/{ceremonyId}
/ceremonies/{ceremonyId}/categories/{categoryId}
/ceremonies/{ceremonyId}/categories/{categoryId}/nominees/{nomineeId}
/competitions/{competitionId}
/competitions/{competitionId}/participants/{odparticipantId}
/competitions/{competitionId}/votes/{odvoteId}
/config/features
```

---

### CloudFunctionsService (`Services/CloudFunctionsService.swift`)

**Responsibilities**:
- Callable Cloud Functions
- Server-side operations

**Region**: asia-south1

**Key Methods**:
```swift
func createCompetition(name: String, ceremonyId: String) async throws -> Competition
func joinCompetition(inviteCode: String) async throws -> Competition
func leaveCompetition(competitionId: String) async throws
func deleteCompetition(competitionId: String) async throws
func castVote(competitionId: String, categoryId: String, nomineeId: String) async throws
func updateFcmToken(token: String) async throws
func deleteAccount() async throws
```

**Cloud Functions Called**:
- `createCompetition` - Creates competition with generated invite code
- `joinCompetition` - Validates code and adds participant
- `leaveCompetition` - Removes participant from competition
- `deleteCompetition` - Removes competition (owner only)
- `castVote` - Records/updates vote
- `updateFcmToken` - Stores FCM token for push notifications
- `deleteAccount` - Deletes all user data

---

### StoreService (`Services/StoreService.swift`)

**Responsibilities**:
- StoreKit 2 integration
- In-app purchase management
- Purchase restoration

**Product ID**: `com.awardswithfriends.competitions`
**Price**: $2.99 (one-time, non-consumable)

**Key Properties & Methods**:
```swift
static let shared = StoreService()
static let competitionsProductId = "com.awardswithfriends.competitions"

var products: [Product]  // Available products
var purchasedProductIds: Set<String>  // Owned products

var hasCompetitionsAccess: Bool {
    purchasedProductIds.contains(Self.competitionsProductId)
}

@MainActor
func purchase() async throws -> Bool

func restorePurchases() async throws
```

**Purchase Flow**:
1. Load products from App Store
2. User initiates purchase
3. StoreKit presents purchase UI
4. User confirms (Face ID/password)
5. Transaction verified and finished
6. `purchasedProductIds` updated
7. UI reacts to state change

**Transaction Listener**:
- Listens for transaction updates
- Handles purchases made on other devices
- Verifies and finishes transactions

---

### ConfigService (`Services/ConfigService.swift`)

**Responsibilities**:
- Feature flags from Firestore
- Real-time configuration updates

**Key Properties**:
```swift
static let shared = ConfigService()
private(set) var requiresPaymentForCompetitions = true  // Default: true
private(set) var isLoaded = false
```

**Firestore Document**: `/config/features`
```javascript
{
  requiresPaymentForCompetitions: boolean
}
```

**Usage**:
- HomeView checks `configService.requiresPaymentForCompetitions`
- If false, all users can create/join without payment
- If true, requires IAP purchase

---

### NotificationService (`Services/NotificationService.swift`)

**Responsibilities**:
- Push notification registration
- FCM token management
- Notification handling

**Key Methods**:
```swift
func requestPermission() async -> Bool
func registerForRemoteNotifications()
func handleNotification(userInfo: [AnyHashable: Any])
```

**Notification Types**:
1. **Winner Announced**: Category winner revealed
2. **Voting Locked**: Category voting closed
3. **Competition Update**: General competition updates

**Payload Structure**:
```javascript
{
  "notification": {
    "title": "Winner Announced!",
    "body": "Best Picture winner has been revealed"
  },
  "data": {
    "type": "winner_announced",
    "competitionId": "xxx",
    "categoryId": "xxx"
  }
}
```

**Deep Linking**:
- Notifications can deep link to specific competition/category

---

## Data Models

### User
```swift
struct User: Codable, Identifiable {
    let uid: String
    var email: String
    var displayName: String
    var photoURL: String?
    var fcmToken: String?
    let createdAt: Timestamp
    var updatedAt: Timestamp
}
```

### Competition
```swift
struct Competition: Codable, Identifiable {
    let id: String
    var name: String
    let ceremonyId: String
    let inviteCode: String  // 6-character alphanumeric
    let createdBy: String   // User UID
    let createdAt: Timestamp
    var status: CompetitionStatus  // open, locked, completed, inactive
    var participantCount: Int

    var eventDisplayName: String  // Computed from ceremony
}

enum CompetitionStatus: String, Codable {
    case open       // Voting allowed
    case locked     // Voting closed, no winners yet
    case completed  // All winners announced
    case inactive   // Archived/deleted
}
```

### Ceremony
```swift
struct Ceremony: Codable, Identifiable {
    let id: String
    var name: String           // "97th Academy Awards"
    var eventType: EventType   // oscars, emmys, etc.
    var date: Timestamp        // Ceremony date
    var status: CeremonyStatus // upcoming, live, completed
    var categoryCount: Int
}

enum EventType: String, Codable, CaseIterable {
    case oscars = "oscars"
    case emmys = "emmys"
    case goldenglobes = "goldenglobes"
    case grammys = "grammys"
    case tonys = "tonys"
    case sagawards = "sagawards"
    case baftas = "baftas"
    case other = "other"

    var displayName: String { ... }
    var iconName: String { ... }
}
```

### Category
```swift
struct Category: Codable, Identifiable {
    let id: String
    let ceremonyId: String
    var name: String           // "Best Picture"
    var displayOrder: Int      // For sorting
    var isLocked: Bool         // Voting closed
    var winnerId: String?      // Winning nominee ID
    var nomineeCount: Int
}
```

### Nominee
```swift
struct Nominee: Codable, Identifiable {
    let id: String
    let categoryId: String
    var name: String           // Person or movie name
    var secondaryName: String? // Movie name for acting categories
    var imageURL: String?      // Poster or headshot
}
```

### Vote
```swift
struct Vote: Codable, Identifiable {
    let id: String             // {oduserId}_{categoryId}
    let odcompetitionId: String
    let oduserId: String
    let categoryId: String
    var nomineeId: String
    let createdAt: Timestamp
    var updatedAt: Timestamp
}
```

### Participant
```swift
struct Participant: Codable, Identifiable {
    let id: String             // Same as oduserId
    let odcompetitionId: String
    let oduserId: String
    var displayName: String
    var photoURL: String?
    var score: Int             // Correct picks count
    var totalVotes: Int        // Total votes cast
    let joinedAt: Timestamp
}
```

---

## Firebase Configuration

### Firestore Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write own document
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Ceremonies are public read
    match /ceremonies/{ceremonyId} {
      allow read: if request.auth != null;
      match /categories/{categoryId} {
        allow read: if request.auth != null;
        match /nominees/{nomineeId} {
          allow read: if request.auth != null;
        }
      }
    }

    // Competitions - participants can read
    match /competitions/{competitionId} {
      allow read: if request.auth != null &&
        exists(/databases/$(database)/documents/competitions/$(competitionId)/participants/$(request.auth.uid));

      match /participants/{participantId} {
        allow read: if request.auth != null;
      }

      match /votes/{voteId} {
        allow read: if request.auth != null;
      }
    }

    // Config - public read
    match /config/{docId} {
      allow read: if request.auth != null;
    }
  }
}
```

### Cloud Functions
Located in `/functions/src/index.ts`

Key functions:
- `createCompetition` - Generates invite code, creates competition
- `joinCompetition` - Validates code, adds participant
- `leaveCompetition` - Removes participant
- `deleteCompetition` - Removes competition (owner only)
- `castVote` - Creates/updates vote document
- `updateFcmToken` - Saves FCM token to user document
- `deleteAccount` - Cascading delete of user data
- `announceWinner` - Admin function to set winner (triggers notifications)

---

## Navigation Flow

```
App Launch
    │
    ├── Authenticated? ──No──> LoginView
    │                              │
    │                              ├── Sign in with Apple
    │                              ├── Sign in with Google
    │                              └── Email Sign In ──> EmailSignInView
    │
    └── Yes ──> TabView
                    │
                    ├── Home Tab ──> HomeView
                    │                    │
                    │                    ├── Create ──> CreateCompetitionView
                    │                    ├── Join ──> JoinCompetitionView
                    │                    ├── Tap Card ──> CompetitionDetailView
                    │                    │                      │
                    │                    │                      └── Tap Category ──> CategoryDetailView
                    │                    │
                    │                    └── Leaderboard ──> LeaderboardView
                    │
                    ├── Ceremonies Tab ──> CeremoniesView
                    │                          │
                    │                          └── Tap ──> CeremonyDetailView
                    │
                    └── Profile Tab ──> ProfileView
```

---

## Key Implementation Notes

### Real-time Updates
- All data uses `AsyncThrowingStream` for real-time Firestore listeners
- UI automatically updates when data changes
- No manual refresh needed (pull-to-refresh available as backup)

### Optimistic UI
- Vote casting shows immediate feedback
- Reverts on error with error message

### Error Handling
- All async operations wrapped in do-catch
- User-friendly error messages displayed
- Network errors show retry options

### Offline Support
- Firebase provides automatic offline caching
- Users can view cached data offline
- Actions queue and sync when online

### Deep Linking
- App handles `awardswithfriends://` URL scheme
- Supports direct links to competitions
- Push notifications can deep link

---

## Web Admin

Located in `/web-admin/` (React + TypeScript + Vite)

**URL**: https://awards-with-friends-admin.web.app

**Features**:
- Ceremony management (CRUD)
- Category management (CRUD)
- Nominee management (CRUD)
- Winner announcement
- Feature flag toggles (/settings)
- User management (view only)

**Settings Page** (`/settings`):
- Toggle `requiresPaymentForCompetitions` flag
- Stored in Firestore `/config/features`

---

## Landing Page

Located in `/landing-page/` (static HTML)

**URL**: https://awardswithfriends.com (or Firebase hosting URL)

**Pages**:
- `index.html` - Marketing/promo page with screenshots
- `privacy.html` - Privacy policy

---

## App Store Information

- **App ID**: 1638720136
- **Bundle ID**: com.awardswithfriends.app
- **IAP Product ID**: com.awardswithfriends.competitions
- **App Store URL**: https://apps.apple.com/app/id1638720136

---

## Android Implementation Checklist

When building the Android version, ensure feature parity with:

### Authentication
- [ ] Sign in with Apple (Android implementation)
- [ ] Google Sign-In
- [ ] Email/Password auth
- [ ] Session persistence
- [ ] User document creation

### Home/Competitions
- [ ] Competitions list with real-time updates
- [ ] Filter tabs (All/Mine/Joined)
- [ ] Competition cards with all info
- [ ] Create competition flow
- [ ] Join competition flow
- [ ] Invite/share functionality
- [ ] Paywall integration

### Categories/Voting
- [ ] Categories list grouped by status
- [ ] Nominee grid/list view
- [ ] Vote casting with optimistic UI
- [ ] Locked state handling
- [ ] Winner display

### Leaderboard
- [ ] Ranked participant list
- [ ] Real-time score updates
- [ ] Current user highlighting
- [ ] Medal icons for top 3

### Profile
- [ ] Profile editing (name, photo)
- [ ] Push notification toggle
- [ ] Restore purchases
- [ ] Sign out
- [ ] Delete account

### In-App Purchase
- [ ] Google Play Billing integration
- [ ] Same product ($2.99 one-time)
- [ ] Purchase restoration
- [ ] Feature flag check

### Push Notifications
- [ ] FCM integration
- [ ] Permission request
- [ ] Token registration
- [ ] Deep link handling

### Non-Functional
- [ ] Offline caching
- [ ] Error handling
- [ ] Loading states
- [ ] Empty states
- [ ] Pull-to-refresh
