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
    "MacroRoutingExtension": RoutingExtensionMacro.self,
    "GET": GETMacro.self,
    "POST": POSTMacro.self,
]

final class RoutingExtensionMacroTests: XCTestCase {

    /// Declaring `extensions: ["admin"]` on the base must add exactly three things
    /// to the base expansion: the `addRoutes($adminRoutes)` merge inside `$routes`,
    /// the `+ C.$admin.$all` / `typealias $admin` surface inside `$Routing`, and the
    /// `$admin_is_listed_in_MacroRouting_extensions` marker.
    func testBaseWithExtensionNamespace() {
        assertMacroExpansion(
            """
            @MacroRouting(extensions: ["admin"])
            struct C {
                @GET("/main")
                func getMain() {}
            }
            """,
            expandedSource: """
            struct C {
                func getMain() {}
            }

            extension C {
                    var $routes: RouteCollectionContainer<Context> {
                    let routes = RouteCollection(context: Context.self)
                    _ = routes.on(
                            "/main",
                            method: .get,
                            use: `getMain`
                        )
                    routes.addRoutes($adminRoutes)
                    return RouteCollectionContainer(routeCollection: routes)
                }
                    struct $Routing {
                            private init() {
                    }
                            static let $all: [any MacroRoutingRoute.Type] = [
                                `getMain`.self
                            ] + C.$$admin.$all
                            static let $prefix: String? = nil
                    struct `getMain`: MacroRoutingRoute {
                            private init() {
                    }
                            static let method: HTTPRequest.Method = .get
                            static let handler: String = "getMain"
                            static let name: String = "getMain"
                            static let prefixedPath: String = "/main"
                            static let rawPath: String = "/main"
                    static let path: String = "/main"
                    }
                    typealias $admin = C.$$admin
                    }
                    enum $admin_is_listed_in_MacroRouting_extensions {
                    }
            }
            """,
            macros: testMacros
        )
    }

    /// `@MacroRoutingExtension("admin")` on an extension must emit the namespaced
    /// routes property, the namespaced route-struct container, and the typealias
    /// that references the base's declaration marker.
    func testExtensionExpansion() {
        assertMacroExpansion(
            """
            @MacroRoutingExtension("admin")
            extension C {
                @POST("/extension")
                func logOutHandler() {}
            }
            """,
            expandedSource: """
            extension C {
                func logOutHandler() {}

                var $adminRoutes: RouteCollectionContainer<Context> {
                        let routes = RouteCollection(context: Context.self)
                        _ = routes.on(
                                "/extension",
                                method: .post,
                                use: `logOutHandler`
                            )
                        return RouteCollectionContainer(routeCollection: routes)
                    }

                struct $$admin {
                        private init() {
                        }
                        static let $all: [any MacroRoutingRoute.Type] = [
                            `logOutHandler`.self
                        ]
                        static let $prefix: String? = nil
                        struct `logOutHandler`: MacroRoutingRoute {
                                private init() {
                        }
                                static let method: HTTPRequest.Method = .post
                                static let handler: String = "logOutHandler"
                                static let name: String = "logOutHandler"
                                static let prefixedPath: String = "/extension"
                                static let rawPath: String = "/extension"
                        static let path: String = "/extension"
                        }
                }

                private typealias $MacroRoutingDeclared_admin = $admin_is_listed_in_MacroRouting_extensions
            }
            """,
            macros: testMacros
        )
    }

    /// A reserved namespace ("routes"/"Routing" would collide with the base's own
    /// generated members) must be diagnosed and dropped from codegen.
    func testReservedNamespaceIsDiagnosed() {
        assertMacroExpansion(
            """
            @MacroRouting(extensions: ["routes"])
            struct C {
            }
            """,
            expandedSource: """
            struct C {
            }

            extension C {
                    var $routes: RouteCollectionContainer<Context> {
                    let routes = RouteCollection(context: Context.self)
                    return RouteCollectionContainer(routeCollection: routes)
                }
                    struct $Routing {
                            private init() {
                    }
                            static let $all: [any MacroRoutingRoute.Type] = [

                            ]
                            static let $prefix: String? = nil
                    }
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "Extension namespace 'routes' is reserved", line: 1, column: 28)
            ],
            macros: testMacros
        )
    }

    /// A namespace that isn't a valid Swift identifier must be diagnosed and
    /// dropped; valid ones on either side of it survive.
    func testInvalidAndDuplicateNamespacesAreDiagnosed() {
        assertMacroExpansion(
            """
            @MacroRouting(extensions: ["ok", "not ok", "ok"])
            struct C {
            }
            """,
            expandedSource: """
            struct C {
            }

            extension C {
                    var $routes: RouteCollectionContainer<Context> {
                    let routes = RouteCollection(context: Context.self)
                    routes.addRoutes($okRoutes)
                    return RouteCollectionContainer(routeCollection: routes)
                }
                    struct $Routing {
                            private init() {
                    }
                            static let $all: [any MacroRoutingRoute.Type] = [

                            ] + C.$$ok.$all
                            static let $prefix: String? = nil
                    typealias $ok = C.$$ok
                    }
                    enum $ok_is_listed_in_MacroRouting_extensions {
                    }
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "Extension namespace 'not ok' must be a valid Swift identifier", line: 1, column: 34),
                DiagnosticSpec(message: "Extension namespace 'ok' is already declared", line: 1, column: 44),
            ],
            macros: testMacros
        )
    }

    /// @MacroRoutingExtension attached to anything but an extension must be
    /// diagnosed and emit nothing.
    func testExtensionMacroOnStructIsDiagnosed() {
        assertMacroExpansion(
            """
            @MacroRoutingExtension("admin")
            struct C {
            }
            """,
            expandedSource: """
            struct C {
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@MacroRoutingExtension can only be attached to an extension", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }
}
