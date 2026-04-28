# AppCat iOS SDK

Track events and attribute installs across Meta, TikTok, Google Ads, and Apple Search Ads from native iOS apps. Resolve deferred deep links to route users to the right content after install.

## Overview

- Track standard and custom events across ad platforms
- Track revenue events with currency and value
- Resolve deferred deep links after install to route users to the right screen
- Support Apple Search Ads attribution signals when available
- Retrieve the AppCat device ID and attribution data

## Features (with examples)

### Getting Started

Store your credentials in Xcode scheme environment variables or Info.plist, then read them at runtime.

#### 1. Init

Initialize the SDK with your credentials. This automatically creates the attribution profile and resolves any deferred deep links.

```swift
import AppCat

try await AppCat.configure(
    apiKey: ProcessInfo.processInfo.environment["APPCAT_API_KEY"] ?? "",
    appId: ProcessInfo.processInfo.environment["APPCAT_APP_ID"] ?? ""
)
```

#### 2. Deep Links

`configure()` returns a response with deep link params from the matched ad click URL. Use this to route users to the right screen on first open.

```swift
let response = try await AppCat.configure(
    apiKey: ProcessInfo.processInfo.environment["APPCAT_API_KEY"] ?? "",
    appId: ProcessInfo.processInfo.environment["APPCAT_APP_ID"] ?? ""
)
if let params = response.deepLinkParams {
    // route user based on params
    print(params)
}
```

**Response:**

| Field | Type | Description |
|-------|------|-------------|
| `deepLinkParams` | `[String: String]?` | Query params from the matched ad click URL, or `nil` if no match |
| `geo` | `AppCatGeoResponse?` | Geo data. e.g. `.city = "San Francisco"`, `.country = "US"`, `.state = "CA"` |

### Event Tracking

```swift
AppCat.sendEvent("Purchase", params: ["item": "premium_plan"])
AppCat.sendEvent("ViewContent", params: ["category": "shoes", "productId": "SKU-100"])
AppCat.sendEvent("CompleteRegistration")
```

### Revenue Tracking

```swift
AppCat.sendEvent("Purchase", params: [
    "item": "annual_plan",
    "value": 49.99,
    "currency": "USD"
])
```

### Tracking Consent

```swift
try await AppCat.setTrackingConsent(false)
```

Call this after ATT, GDPR, or an in-app privacy choice. When consent is denied, AppCat avoids forwarding certain PII fields to ad networks on your behalf.

### Installation ID and Attribution

```swift
let deviceId = AppCat.getAppCatId()
let attribution = AppCat.getAttribution()
```

### Apple Ads Attribution

Apple Search Ads attribution signals are collected when available during SDK initialization. No app-side setup is required.

## Installation

### Swift Package Manager

In Xcode, go to **File > Add Package Dependencies** and enter:

```
https://github.com/AppCat-AI/appcat-ios-sdk.git
```

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/AppCat-AI/appcat-ios-sdk.git", from: "0.1.0"),
]
```

Then add `"AppCat"` to your target's dependencies.

### CocoaPods

Add the following to your `Podfile`:

```ruby
pod 'AppCat', :git => 'https://github.com/AppCat-AI/appcat-ios-sdk.git', :tag => '0.1.0'
```

Then run `pod install`.

## Platform Configuration

| Requirement | Minimum Version |
|-------------|----------------|
| iOS | 13.0+ |
| Swift | 5.10+ |
| Xcode | 16+ |

The Swift package and CocoaPods pod wrap the closed-source `AppCatCoreKit.xcframework` binary.

## Quick Start

```swift
import SwiftUI
import AppCat

@main
struct MyApp: App {
    init() {
        Task {
            do {
                let response = try await AppCat.configure(
                    apiKey: ProcessInfo.processInfo.environment["APPCAT_API_KEY"] ?? "",
                    appId: ProcessInfo.processInfo.environment["APPCAT_APP_ID"] ?? ""
                )
                if let params = response.deepLinkParams {
                    // Route the user based on params.
                }
                _ = response.geo
            } catch {
                // Handle setup failure.
            }
        }
    }

    // Identify — call post-login when PII becomes available
    func onLogin(userId: String, email: String) {
        Task {
            try await AppCat.identify([
                "userId": userId,
                "email": email,
                // "revenueCatIds": ["rc_user_123"],
            ])
        }
    }

    func onPurchase() {
        AppCat.sendEvent("Purchase", params: [
            "item": "premium_plan",
            "value": 9.99,
            "currency": "USD"
        ])
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

## API

### `AppCat.configure(apiKey:appId:isDebug:logLevel:customerUserId:options:)`

Initialize the SDK and create the attribution profile. Automatically resolves deferred deep links and returns any matched query params. Must be called before any other method.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `apiKey` | `String` | Yes | API key for your AppCat project |
| `appId` | `String` | No | Your AppCat application ID (resolved from API key if omitted) |
| `isDebug` | `Bool` | No | Enable debug logging (default: `false`) |
| `logLevel` | `AppCatLogLevel` | No | Log verbosity: `.debug`, `.info`, `.warn`, `.error` (default: `.info`) |
| `customerUserId` | `String?` | No | User ID to associate with this session |
| `options` | `[String: Any]` | No | Additional configuration options |

**Returns:** `async throws -> AppCatInitResponse` — `{ deepLinkParams: [String: String]?, geo: AppCatGeoResponse? }`.

**Response:**

| Field | Type | Description |
|-------|------|-------------|
| `deepLinkParams` | `[String: String]?` | Query params from the matched ad click URL, or `nil` if no match |
| `geo` | `AppCatGeoResponse?` | Geo data. e.g. `.city = "San Francisco"`, `.country = "US"`, `.state = "CA"` |

**Example:**

```swift
let response = try await AppCat.configure(
    apiKey: ProcessInfo.processInfo.environment["APPCAT_API_KEY"] ?? "",
    appId: ProcessInfo.processInfo.environment["APPCAT_APP_ID"] ?? "",
    isDebug: true,
    logLevel: .debug
)
```

---

### `AppCat.identify(_:)`

Enrich the user profile with additional information. Call after login, signup, or whenever new user data is available.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `data` | `[String: Any]` | Yes | Dictionary with user data (`userId`, `email`, `phone`, `name`, `geo`, `revenueCatIds`, `customAttributes`) |
| `data["revenueCatIds"]` | `[String]` | No | RevenueCat app user IDs to associate with this profile |

**Returns:** `async throws -> AppCatIdentifyResponse`

**Response:**

| Field | Type | Description |
|-------|------|-------------|
| `geo` | `AppCatGeoResponse?` | Geo data. e.g. `.city = "San Francisco"`, `.country = "US"`, `.state = "CA"` |
| `deepLinkParams` | `[String: String]?` | Deep link params from the attribution profile |

**Example:**

```swift
let result = try await AppCat.identify([
    "userId": "user_123",
    "email": "user@example.com",
    "name": "Jane Smith",
    "revenueCatIds": ["rc_user_123"]
])
```

---

### `AppCat.sendEvent(_:params:)`

Track a conversion event. This method never throws.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `eventName` | `String` | Yes | Event name (see available events below) |
| `params` | `[String: Any]?` | No | Event parameters including reserved keys (`eventId`, `value`, `currency`, `testEventCode`) and custom data |

**Returns:** `Void`

**Example:**

```swift
AppCat.sendEvent("Subscribe", params: [
    "plan": "annual",
    "value": 99.99,
    "currency": "USD",
    "eventId": "order-abc-123"
])
```

---

### `AppCat.getAttribution()`

Get cached attribution data. Returns `nil` if neither `configure()` nor `identify()` has been called.

**Returns:** `[String: Any]?`

---

### `AppCat.getDeviceContext()`

Get cached device context.

**Returns:** `[String: Any]?`

---

### `AppCat.getAppCatId()`

Get the stable AppCat device identifier.

**Returns:** `String`

---

### `AppCat.isDisabled()`

Check if the SDK has been remotely disabled.

**Returns:** `Bool`

---

### `AppCat.isInitialized()`

Check whether the SDK has been configured.

**Returns:** `Bool`

---

### `AppCat.setLogLevel(_:)`

Set log verbosity at runtime.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `level` | `AppCatLogLevel` | Yes | `.debug`, `.info`, `.warn`, or `.error` |

**Returns:** `Void`

---

### `AppCat.setTrackingConsent(_:)`

Record the user's tracking-consent choice.

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `granted` | `Bool` | Yes | Whether tracking consent is granted |

**Returns:** `async throws -> Void`

## Privacy

Apple Search Ads attribution signals are collected when available during SDK initialization. If you request ATT or collect user consent elsewhere, call `setTrackingConsent(_:)` with the user's choice. Do not log raw attribution, deep-link params, email, or phone in production.

## Available Event Types

| Event Name | Description |
|------------|-------------|
| `MobileAppInstall` | App installed |
| `ViewContent` | User viewed content |
| `AddToCart` | Item added to cart |
| `InitiateCheckout` | Checkout started |
| `StartTrial` | Free trial started |
| `Subscribe` | Subscription started |
| `Purchase` | Purchase completed |
| `CompleteRegistration` | Registration completed |
| `Search` | Search performed |

Custom event names are also supported as any string value.

## License

MIT -- see [LICENSE](./LICENSE) for details.
