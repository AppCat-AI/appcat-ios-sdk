import XCTest
@testable import AppCat

final class AppCatPublicTypesTests: XCTestCase {
  func testLogLevelRawValues() {
    XCTAssertEqual(AppCatLogLevel.debug.rawValue, 0)
    XCTAssertEqual(AppCatLogLevel.info.rawValue, 1)
    XCTAssertEqual(AppCatLogLevel.warn.rawValue, 2)
    XCTAssertEqual(AppCatLogLevel.error.rawValue, 3)
  }

  func testErrorDescriptionsMatchCurrentCases() {
    XCTAssertEqual(
      AppCatSDKError.notConfigured.errorDescription,
      "AppCat SDK not configured. Call AppCat.configure() first."
    )
    XCTAssertEqual(
      AppCatSDKError.invalidConfig("missing API key").errorDescription,
      "Invalid config: missing API key"
    )
    XCTAssertEqual(
      AppCatSDKError.identifyFailed("server error").errorDescription,
      "Identify failed: server error"
    )
  }

  func testResponseModelsHoldDeepLinkAndGeoData() {
    let geo = AppCatGeoResponse(city: "San Francisco", country: "US", state: "CA")
    let initResponse = AppCatInitResponse(
      deepLinkParams: ["screen": "promo", "code": "ABC"],
      geo: geo
    )
    let identifyResponse = AppCatIdentifyResponse(
      geo: geo,
      deepLinkParams: ["screen": "promo"]
    )

    XCTAssertEqual(initResponse.deepLinkParams?["screen"], "promo")
    XCTAssertEqual(initResponse.geo?.country, "US")
    XCTAssertEqual(identifyResponse.deepLinkParams?["screen"], "promo")
    XCTAssertEqual(identifyResponse.geo?.city, "San Francisco")
  }

  func testCurrentPublicApiSignaturesCompile() {
    let configure: (String, String, Bool, AppCatLogLevel, String?, [String: Any]) async throws -> AppCatInitResponse = {
      apiKey,
      appId,
      isDebug,
      logLevel,
      customerUserId,
      options in
      try await AppCat.configure(
        apiKey: apiKey,
        appId: appId,
        isDebug: isDebug,
        logLevel: logLevel,
        customerUserId: customerUserId,
        options: options
      )
    }
    let identify: ([String: Any]) async throws -> AppCatIdentifyResponse = { data in
      try await AppCat.identify(data)
    }
    let sendEvent: (String, [String: Any]?) -> Void = { name, params in
      AppCat.sendEvent(name, params: params)
    }
    let setConsent: (Bool) async throws -> Void = { granted in
      try await AppCat.setTrackingConsent(granted)
    }

    _ = configure
    _ = identify
    _ = sendEvent
    _ = setConsent
  }
}
