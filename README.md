# Marble

Marble is a SwiftUI-first iOS application that curates your Gmail newsletters using your own OpenAI API key. The interface mirrors the modern design of the iOS 17+ Mail app while staying simple, privacy-conscious, and App Store ready.

## Highlights
- **Gmail integration** – Sign in with OAuth, fetch, read, and archive newsletters directly from your inbox.
- **LLM-powered filtering** – Each message is classified with OpenAI so only newsletters reach the feed.
- **Offline friendly** – Message bodies are cached locally and scroll position is preserved across sessions.
- **Respectful by design** – No Marble servers. Credentials are stored in the Keychain and API traffic goes directly from the device to Gmail and OpenAI.

## Project Structure
```
Marble/
├── Marble.xcodeproj/               # Xcode project configuration
├── Marble/                         # Application sources
│   ├── AppModel.swift              # Root dependency container
│   ├── ConfigurationStore.swift    # Secure storage for API keys and OAuth tokens
│   ├── ContentView.swift           # Entry view that hosts the inbox experience
│   ├── GmailClient.swift           # OAuth + Gmail REST wrapper
│   ├── GmailConfiguration.swift    # Codable token model
│   ├── Models.swift                # Shared models and error definitions
│   ├── NewsletterCache.swift       # On-disk HTML cache for offline reading
│   ├── NewsletterDetailView.swift  # Reader experience with scroll restoration
│   ├── NewsletterFeedView.swift    # Inbox-style list of newsletters
│   ├── NewsletterStore.swift       # Main observable store for app state
│   ├── OpenAIClient.swift          # Minimal client for OpenAI Responses API
│   ├── SettingsView.swift          # User configuration for API keys and Gmail
│   ├── Info.plist                  # App configuration (update OAuth values here)
│   └── Assets.xcassets/            # Symbols and color assets
└── README.md
```

## Configuration
1. **Google OAuth**
   - Create an iOS OAuth client in the Google Cloud Console.
   - Set `GoogleClientID` and `GoogleRedirectURI` in `Marble/Info.plist`. The redirect URI must match the custom scheme you register (e.g. `com.ajuhasz.marble:/oauthredirect`).
2. **OpenAI API Key**
   - Generate an API key from the OpenAI dashboard.
   - Enter the key under *Settings → OpenAI* inside the app. The key is stored in the user’s Keychain.

## Running the App
1. Open `Marble.xcodeproj` in Xcode 15 or later.
2. Update the signing team and bundle identifier (`com.ajuhasz.marble`) if necessary.
3. Select an iOS 17+ simulator or device and run the app (`⌘R`).

## App Store Considerations
- OAuth authentication uses `ASWebAuthenticationSession`, complying with Apple’s guidelines.
- No third-party servers or embedded credentials are shipped with the binary.
- Privacy-sensitive strings are persisted with Keychain and `UserDefaults` only on device.

## License
Released under the MIT License. See the LICENSE file if provided, or adapt to your distribution needs.
