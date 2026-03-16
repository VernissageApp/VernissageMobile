# Vernissage for iOS

[![Swift](https://img.shields.io/badge/Language-Swift-orange.svg?style=flat)](https://www.swift.org)
[![SwiftUI](https://img.shields.io/badge/Framework-SwiftUI-blue.svg?style=flat)](https://developer.apple.com/swiftui/)
[![Platforms iOS](https://img.shields.io/badge/Platforms-iOS-lightgray.svg?style=flat)](https://developer.apple.com)

<p align="center">
  <img src="Resources/01.png" width="200" alt="Vernissage for iOS screenshot 1">
  <img src="Resources/02.png" width="200" alt="Vernissage for iOS screenshot 2">
  <img src="Resources/03.png" width="200" alt="Vernissage for iOS screenshot 3">
  <img src="Resources/04.png" width="200" alt="Vernissage for iOS screenshot 4">
</p>

Native SwiftUI client for **Vernissage**, a federated, community-driven photo-sharing platform connected to the fediverse through **ActivityPub**.

Vernissage is built for people who want a photo-first experience: no mixed-media feed, no ads, and no recommendation algorithm deciding what should be seen first. This app focuses on browsing, publishing, and managing photography on Vernissage servers from a native iPhone experience.

## Highlights

- Native iOS app built entirely with SwiftUI
- OAuth sign-in against supported Vernissage servers
- Sign up flow for servers that allow registration
- Photo-first timelines: private, featured, trending, local, and global
- Search across users, hashtags, statuses, and direct profile/status URLs
- Post composer with attachments, metadata, visibility, and content warnings
- Notifications, profile management, account switching, and share extension support

## Quick Links

- Create an account: [vernissage.photos](https://vernissage.photos) or in other instance
- Server directory: [joinvernissage.org/servers.html](https://joinvernissage.org/servers.html)
- Project website: [joinvernissage.org](https://joinvernissage.org)
- Documentation: [docs.joinvernissage.org](https://docs.joinvernissage.org)
- API server: [VernissageServer](https://github.com/VernissageApp/VernissageServer)
- Web client: [VernissageWeb](https://github.com/VernissageApp/VernissageWeb)

## Requirements

- macOS
- Xcode with iOS 26 SDK support
- iOS 26 simulator or a physical iPhone
- Optional: access to a local or remote Vernissage server

## Getting Started

1. Clone the repository.
2. Open `VernissageMobile.xcodeproj` in Xcode.
3. Select the `VernissageMobile` scheme.
4. Choose an iOS simulator or connected device.
5. Build and run.

### Signing

If you want to run the app on a physical device or use your own Apple team configuration:

- set your own Development Team in Xcode,
- update bundle identifiers if your signing setup requires unique IDs,
- keep the share extension target aligned with the main app target.

### Connecting to a Server

When the app launches, provide the base URL of your home Vernissage server.

Typical examples:

- `https://vernissage.photos`
- `http://localhost:4200`
- `https://your-server.example`

The iOS client is intended for **Vernissage servers**. If you are developing locally, a local Vernissage backend is enough to start working on authentication, timelines, search, and publishing flows.

## Repository Layout

The project follows a feature-oriented SwiftUI structure:

- `VernissageMobile/Sources/App` - app entry point, root flow, tabs
- `VernissageMobile/Sources/Core` - models, networking, persistent account state, utilities
- `VernissageMobile/Sources/Features` - screens, sheets, view models, feature-specific support code
- `VernissageMobile/Sources/Shared` - shared extensions, UI helpers, reusable utilities
- `VernissageShareExtension` - iOS share extension
- `Resources` - README screenshots and repository assets

## Developer Notes

- The app uses modern SwiftUI, Observation, and Swift Concurrency.
- Networking is grouped by backend domain under `Core/Networking`.
- The app supports multiple accounts stored locally and refreshed through OAuth.
- Related product and protocol details live in the server and documentation repositories linked above.

## Contributing

Contributions are welcome.

1. Fork and clone the repository.
2. Keep changes focused and consistent with the existing project structure.
3. Verify the app builds before opening a pull request.
4. Open a pull request with a clear description of the change.

If you need device builds, remember to update signing for both the main app and the share extension.

## License

This project is licensed under the [Apache License 2.0](LICENSE).
