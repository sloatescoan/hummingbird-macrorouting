import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

// The macro implementations live in the RoutingMacros plugin module.
@testable import RoutingMacros

// NOTE: this uses XCTest rather than Swift Testing on purpose. `assertMacroExpansion`
// reports failures via XCTest's failure handler; under Swift Testing there is no
// XCTest context, so its assertions are silently dropped and every test "passes".

private nonisolated(unsafe) let testMacros: [String: Macro.Type] = [
    "MacroRouting": RoutingMacro.self,
    "GET": GETMacro.self,
    "POST": POSTMacro.self,
    "PUT": PUTMacro.self,
    "DELETE": DELETEMacro.self,
    "HEAD": HEADMacro.self,
    "PATCH": PATCHMacro.self,
]

final class RoutingMacroDiagnosticsTests: XCTestCase {

    /// Two routes resolving to the same `name` must produce exactly one
    /// `MsgNameConflict` diagnostic *and* a well-formed expansion containing a
    /// single `struct` for that name — i.e. the duplicate is dropped from codegen
    /// (first occurrence wins) so the compiler never sees a redeclaration. If the
    /// dedup regressed, a second `struct \`dup\`` would appear here and this would fail.
    func testDuplicateNameIsDeduped() {
        assertMacroExpansion(
            """
            @MacroRouting
            struct C {
                @GET("/a", name: "dup")
                func a() {}
                @GET("/b", name: "dup")
                func b() {}
            }
            """,
            expandedSource: """
            struct C {
                func a() {}
                func b() {}
            }

            extension C {
                    var $routes: RouteCollectionContainer<Context> {
                    let routes = RouteCollection(context: Context.self)
                    _ = routes.on(
                            "/a",
                            method: .get,
                            use: `a`
                        )
                    return RouteCollectionContainer(routeCollection: routes)
                }
                    struct $Routing {
                            private init() {
                    }
                            static let $all: [any MacroRoutingRoute.Type] = [
                                `dup`.self
                            ]
                            static let $prefix: String? = nil
                    struct `dup`: MacroRoutingRoute {
                            private init() {
                    }
                            static let method: HTTPRequest.Method = .get
                            static let handler: String = "a"
                            static let name: String = "dup"
                            static let prefixedPath: String = "/a"
                            static let rawPath: String = "/a"
                    static let path: String = "/a"
                    }
                    }
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "Route named 'dup' is already defined", line: 5, column: 5)
            ],
            macros: testMacros
        )
    }
}
