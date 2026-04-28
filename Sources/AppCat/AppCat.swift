/**
 * AppCat iOS SDK — attribution and deferred deep link resolution.
 *
 * Open-source thin wrapper around the closed-source AppCatCoreKit.xcframework.
 *
 * Usage:
 *   let response = try await AppCat.configure(apiKey: "...", appId: "...")
 *   if let params = response.deepLinkParams { /* handle deep link */ }
 *   let identity = try await AppCat.identify(["userId": "123", "email": "user@example.com"])
 *   AppCat.sendEvent("Purchase", params: ["value": 9.99, "currency": "USD", "eventId": "purchase_\(orderId)"])
 *   let attribution = AppCat.getAttribution()
 */

import Foundation
import AppCatCoreKit

// MARK: - Public types

/// Geo data resolved from the device's IP during attribution.
public struct AppCatGeoResponse {
  /// City name, or nil if unavailable.
  public let city: String?
  /// ISO country code, or nil if unavailable.
  public let country: String?
  /// State/region/province, or nil if unavailable.
  public let state: String?
}

/// Structured response from configure().
public struct AppCatInitResponse {
  /// Deep link query params from the matched ad click URL, or nil if no match.
  public let deepLinkParams: [String: String]?
  /// Geo data resolved from the device's IP, or nil if unavailable.
  public let geo: AppCatGeoResponse?
}

/// Structured response from identify().
public struct AppCatIdentifyResponse {
  /// Geo data from the attribution profile, or nil if unavailable.
  public let geo: AppCatGeoResponse?
  /// Deep link params from the attribution profile, or nil if none.
  public let deepLinkParams: [String: String]?
}

/// Log verbosity level.
public enum AppCatLogLevel: Int {
  case debug = 0
  case info = 1
  case warn = 2
  case error = 3
}

public enum AppCatSDKError: Error, LocalizedError {
  case notConfigured
  case invalidConfig(String)
  case identifyFailed(String)

  public var errorDescription: String? {
    switch self {
    case .notConfigured: return "AppCat SDK not configured. Call AppCat.configure() first."
    case .invalidConfig(let msg): return "Invalid config: \(msg)"
    case .identifyFailed(let msg): return "Identify failed: \(msg)"
    }
  }
}

// MARK: - Public API

public final class AppCat {

  private static var isConfigured = false
  private static var cachedDeepLinkParams: [String: String]? = nil

  /// Initialize the SDK and create the attribution profile.
  ///
  /// Configures credentials, resolves attribution (matches this device to
  /// a stored ad click), and returns a response with `deepLinkParams` —
  /// the query params from the original ad click URL, or `nil` if no match.
  ///
  /// - Parameters:
  ///   - apiKey: API key for authenticating with the AppCat server.
  ///   - appId: App ID — resolved automatically from API key if omitted.
  ///   - isDebug: Enable debug logging (default: false).
  ///   - logLevel: Log verbosity level (default: .info).
  ///   - customerUserId: Optional customer user ID to associate with this device/session.
  @discardableResult
  public static func configure(
    apiKey: String,
    appId: String = "",
    isDebug: Bool = false,
    logLevel: AppCatLogLevel = .info,
    customerUserId: String? = nil,
    options: [String: Any] = [:]
  ) async throws -> AppCatInitResponse {
    var mergedOptions = options
    mergedOptions["isDebug"] = isDebug
    mergedOptions["logLevel"] = logLevel.rawValue
    if let uid = customerUserId {
      mergedOptions["customerUserId"] = uid
    }

    // Step 1: Configure
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
      AppCatCore.shared.configure(
        appId: appId,
        apiKey: apiKey,
        options: mergedOptions
      ) { result in
        switch result {
        case .success(let value):
          isConfigured = true
          continuation.resume(returning: value)
        case .failure(let error):
          continuation.resume(throwing: AppCatSDKError.invalidConfig(error.localizedDescription))
        }
      }
    }

    // Step 2: Auto-resolve attribution
    do {
      let resolveResult: [String: Any] = try await withCheckedThrowingContinuation { continuation in
        AppCatCore.shared.resolve(ddlToken: nil) { result in
          switch result {
          case .success(let dict):
            continuation.resume(returning: dict)
          case .failure(let error):
            continuation.resume(throwing: error)
          }
        }
      }
      let params = resolveResult["deepLinkParams"] as? [String: String]
      let deepLinks: [String: String]?
      if let params, !params.isEmpty {
        deepLinks = params
      } else {
        deepLinks = nil
      }
      cachedDeepLinkParams = deepLinks
      let rawGeo = resolveResult["geo"] as? [String: Any]
      let geo = rawGeo != nil
        ? AppCatGeoResponse(city: rawGeo?["city"] as? String, country: rawGeo?["country"] as? String, state: rawGeo?["state"] as? String)
        : nil
      return AppCatInitResponse(deepLinkParams: deepLinks, geo: geo)
    } catch {
      // Resolve failure is non-fatal — SDK is still configured
    }

    return AppCatInitResponse(deepLinkParams: nil, geo: nil)
  }

  /// Enrich the user profile with additional data.
  ///
  /// Call after login/signup or when you have more user data.
  /// Recognized keys: `userId`, `email`, `phone`, `name`, `revenueCatIds` (array of strings), `geo`, `customAttributes`.
  ///
  /// Returns geo and deepLinkParams from the attribution profile.
  public static func identify(_ data: [String: Any]) async throws -> AppCatIdentifyResponse {
    guard isConfigured else { throw AppCatSDKError.notConfigured }

    let raw: [String: Any]? = try await withCheckedThrowingContinuation { continuation in
      AppCatCore.shared.identify(data: data) { result in
        switch result {
        case .success(let profile):
          continuation.resume(returning: profile)
        case .failure(let error):
          continuation.resume(throwing: AppCatSDKError.identifyFailed(error.localizedDescription))
        }
      }
    }

    let serverData = raw?["data"] as? [String: Any]
    let rawGeo = serverData?["geo"] as? [String: Any]
    let geo = rawGeo != nil
      ? AppCatGeoResponse(city: rawGeo?["city"] as? String, country: rawGeo?["country"] as? String, state: rawGeo?["state"] as? String)
      : nil
    let dlp = serverData?["deepLinkParams"] as? [String: String]
    return AppCatIdentifyResponse(geo: geo, deepLinkParams: dlp)
  }

  /// Track a conversion event. Fire-and-forget — never throws.
  ///
  /// Pass all event data in a single flat dictionary. Reserved keys
  /// (`eventId`, `value`, `currency`, `testEventCode`) are forwarded as
  /// options; all other keys become `custom_data` on the event.
  public static func sendEvent(
    _ eventName: String,
    params: [String: Any]? = nil
  ) {
    #if DEBUG
    let revenueEvents: Set<String> = ["Purchase", "InitiateCheckout"]
    if revenueEvents.contains(eventName) {
      let hasValue = params?["value"] != nil
      let hasCurrency = params?["currency"] != nil
      if !hasValue || !hasCurrency {
        print("[AppCat] Warning: '\(eventName)' is missing value or currency. Meta and TikTok will silently drop this event without both fields.")
      }
    }
    #endif
    let reserved: Set<String> = ["eventId", "value", "currency", "testEventCode"]
    var customData: [String: Any] = [:]
    var options: [String: Any] = [:]
    for (key, val) in (params ?? [:]) {
      if reserved.contains(key) {
        options[key] = val
      } else {
        customData[key] = val
      }
    }
    AppCatCore.shared.sendEvent(
      eventName: eventName,
      params: customData.isEmpty ? nil : customData,
      options: options.isEmpty ? nil : options
    )
  }

  /// Get cached attribution data. Sync — no API call.
  /// Returns nil if configure/identify hasn't run yet.
  public static func getAttribution() -> [String: Any]? {
    return AppCatCore.shared.getAttribution()
  }

  /// Get cached device context.
  public static func getDeviceContext() -> [String: Any]? {
    return AppCatCore.shared.getDeviceContext()
  }

  /// Whether the SDK has been configured.
  public static func isInitialized() -> Bool {
    return isConfigured
  }

  /// Get the stable AppCat device identifier.
  /// Returns IDFV on iOS.
  public static func getAppCatId() -> String {
    return AppCatCore.shared.getAppCatId()
  }

  /// Check if the SDK has been remotely disabled (e.g. invalid API key,
  /// server kill switch, compliance hold).
  public static func isDisabled() -> Bool {
    return AppCatCore.shared.isDisabled()
  }

  /// Set log verbosity level.
  public static func setLogLevel(_ level: AppCatLogLevel) {
    AppCatCore.shared.setLogLevel(level.rawValue)
  }

  /// Update the user's tracking consent choice.
  ///
  /// Call after the user makes a tracking-consent decision (e.g. Apple's ATT
  /// prompt, a GDPR banner, or an in-app settings toggle). When consent is
  /// denied, the server strips certain PII (like email/phone) from downstream
  /// ad-network payloads. Default behavior (no call) is "granted".
  public static func setTrackingConsent(_ granted: Bool) async throws {
    guard isConfigured else { throw AppCatSDKError.notConfigured }

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      AppCatCore.shared.setTrackingConsent(granted: granted) { result in
        switch result {
        case .success:
          continuation.resume(returning: ())
        case .failure(let error):
          continuation.resume(throwing: error)
        }
      }
    }
  }
}
