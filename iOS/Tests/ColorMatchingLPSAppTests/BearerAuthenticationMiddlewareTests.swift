#if canImport(OpenAPIRuntime)
import ColorMatchingLPSAppCore
import Foundation
import OpenAPIRuntime
import XCTest

/// `swift-openapi-generator` does not translate OpenAPI security schemes
/// into generated code, so the app must attach the bearer token declared as
/// `bearerAuth` in the spec via a `ClientMiddleware` living in
/// `ColorMatchingLPSAppCore` (contract in `docs/openapi-generated-client.md`).
///
/// These tests run the middleware directly against a capturing `next`
/// closure — no live server.
final class BearerAuthenticationMiddlewareTests: XCTestCase {
    func testInterceptAddsBearerAuthorizationHeader() async throws {
        let captured = RequestBox()
        let middleware = BearerAuthenticationMiddleware(token: "token-1")

        let (request, _) = try await middleware.intercept(
            Self.get(path: "/api/v1/test_sheets/sheet_123/manifest"),
            body: nil,
            baseURL: Self.baseURL,
            operationID: "ColorMatchingWeb.TestSheetController.manifest"
        ) { intercepted, _, _ in
            captured.request = intercepted
            return (HTTPResponse(status: .init(code: 200)), HTTPBody())
        }

        XCTAssertEqual(captured.request?.headerFields[.authorization], "Bearer token-1")
        XCTAssertEqual(request.headerFields[.authorization], "Bearer token-1")
    }

    func testInterceptLeavesOtherHeadersIntact() async throws {
        let captured = RequestBox()
        let middleware = BearerAuthenticationMiddleware(token: "token-1")
        var outgoing = Self.get(path: "/api/v1/test_sheets/recent")
        outgoing.headerFields[.accept] = "application/json"

        let (request, _) = try await middleware.intercept(
            outgoing,
            body: nil,
            baseURL: Self.baseURL,
            operationID: "ColorMatchingWeb.TestSheetController.recent"
        ) { intercepted, _, _ in
            captured.request = intercepted
            return (HTTPResponse(status: .init(code: 200)), HTTPBody())
        }

        XCTAssertEqual(request.headerFields[.accept], "application/json")
        XCTAssertEqual(request.headerFields[.authorization], "Bearer token-1")
        XCTAssertEqual(captured.request?.headerFields[.accept], "application/json")
    }

    func testInterceptWithBlankTokenAddsNoAuthorizationHeader() async throws {
        let middleware = BearerAuthenticationMiddleware(token: "")

        let (request, _) = try await middleware.intercept(
            Self.get(path: "/api/v1/test_sheets/recent"),
            body: nil,
            baseURL: Self.baseURL,
            operationID: "ColorMatchingWeb.TestSheetController.recent"
        ) { _, _, _ in (HTTPResponse(status: .init(code: 200)), HTTPBody()) }

        XCTAssertNil(request.headerFields[.authorization])
    }
}

// MARK: - Helpers

private extension BearerAuthenticationMiddlewareTests {
    static var baseURL: URL { URL(string: "https://color-matching.example.test")! }

    static func get(path: String) -> HTTPRequest {
        HTTPRequest(method: .get, scheme: nil, authority: nil, path: path)
    }
}

/// Captures the request handed to the transport by the middleware from a
/// `@Sendable` next closure.
private final class RequestBox: @unchecked Sendable {
    var request: HTTPRequest?
}
#else
import XCTest

/// Red-phase marker: the bearer-token middleware from issue #5 does not exist
/// yet (or `swift-openapi-runtime` is not linked into this test target).
final class BearerAuthenticationMiddlewareAvailabilityTests: XCTestCase {
    func testBearerAuthenticationMiddlewareIsAvailable() {
        XCTFail(
            """
            BearerAuthenticationMiddleware is not available: \
            OpenAPIRuntime is not importable and/or ColorMatchingLPSAppCore does not yet provide \
            the middleware. See docs/openapi-generated-client.md (issue #5).
            """
        )
    }
}
#endif
