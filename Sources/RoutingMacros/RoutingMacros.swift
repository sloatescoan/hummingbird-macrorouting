import Foundation
import SwiftCompilerPlugin
import SwiftSyntaxMacros
import SwiftSyntax
import SwiftDiagnostics
import Hummingbird

@main
struct RoutingMacros: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        GETMacro.self,
        POSTMacro.self,
        PUTMacro.self,
        DELETEMacro.self,
        HEADMacro.self,
        PATCHMacro.self,
        RoutingMacro.self,
    ]
}
enum Method: String, CaseIterable {
    case get, post, put, delete, head, patch
    static var allValues: [String] { Self.allCases.map { "\($0)".uppercased() } }
}

struct MsgMalformed: DiagnosticMessage {
    let diagnosticID = MessageID(domain: "MacroRouting", id: "malformed")
    let severity: DiagnosticSeverity = .error
    let message = "Malformed @VERB macro placement"
}

struct MsgNameConflict: DiagnosticMessage {
    let diagnosticID = MessageID(domain: "MacroRouting", id: "nameConflict")
    let severity: DiagnosticSeverity = .error
    let message: String
    init(name: String) {
        self.message = "Route named '\(name)' is already defined"
    }
}

struct CapturedRoute {
    let method: Method
    let path: String
    let handler: String
    let name: String
    let function: FunctionDeclSyntax
}

public struct RoutingMacro: ExtensionMacro {
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        attachedTo declaration: some SwiftSyntax.DeclGroupSyntax,
        providingExtensionsOf type: some SwiftSyntax.TypeSyntaxProtocol,
        conformingTo protocols: [SwiftSyntax.TypeSyntax],
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.ExtensionDeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            return []
        }

        let prefix: String?
        if let prefixArg = node.arguments?.as(LabeledExprListSyntax.self)?.first {
            if let stringLiteral = prefixArg.expression.as(StringLiteralExprSyntax.self) {
                prefix = stringLiteral.segments.first?.as(StringSegmentSyntax.self)?.content.text
            } else {
                prefix = nil
            }
        } else {
            prefix = nil
        }

        let routes: [CapturedRoute] = structDecl.memberBlock.members.flatMap { member -> [CapturedRoute] in
            guard let function = member.decl.as(FunctionDeclSyntax.self) else { return [] }

            // Find all HTTP method attributes (@GET, @POST, etc.)
            let httpAttributes = function.attributes.compactMap { attr in
                attr.as(AttributeSyntax.self)
            }.filter { attr in
                let attrName = attr.attributeName.as(IdentifierTypeSyntax.self)?.name.text ?? ""
                return Method.allValues.contains(attrName)
            }

            // this second compactMap is because we might have multiple @VERB attachments for one function
            return httpAttributes.compactMap { httpAttribute in
                // Extract method, path, and name for each attribute
                guard
                    let arguments = httpAttribute.arguments?.as(LabeledExprListSyntax.self),
                    let firstArg = arguments.first?.expression.as(StringLiteralExprSyntax.self),
                    let methodName = httpAttribute.attributeName.as(IdentifierTypeSyntax.self)?.name.text,
                    let method = Method(rawValue: methodName.lowercased()),
                    let path = firstArg.segments.first?.as(StringSegmentSyntax.self)?.content.text
                else {
                    context.diagnose(
                        Diagnostic(
                            node: member.decl,
                            message: MsgMalformed()
                        )
                    )
                    return nil
                }

                // Extract the route name
                let name: String
                if
                    let nameExpr = arguments.first(where: { $0.label?.text == "name" })?.expression.as(StringLiteralExprSyntax.self),
                    let nameValue = nameExpr.segments.first?.as(StringSegmentSyntax.self)?.content.text
                {
                    name = nameValue
                } else {
                    name = function.name.text
                }

                return CapturedRoute(method: method, path: path, handler: function.name.text, name: name, function: function)
            }
        }

        // make sure we don't have more than one route with the same name:
        var routeNames: Set<String> = []
        for route in routes {
            if routeNames.contains(route.name) {
                context.diagnose(
                    Diagnostic(
                        node: route.function,
                        message: MsgNameConflict(name: route.name)
                    )
                )
            } else {
                routeNames.insert(route.name)
            }
        }

        // this is kind of ugly, but it works…
        var code = """
            var $routes: RouteCollectionContainer<Context> {
                let routes = RouteCollection(context: Context.self)
        """
        for route in routes {
            code += """
                _ = routes.on(
                    "\(prefix ?? "")\(route.path)",
                    method: .\(route.method.rawValue.lowercased()),
                    use: \(route.handler)
                )
            """
        }
        code += """
                return RouteCollectionContainer(routeCollection: routes)
            }
        """

        code += """
            struct $Routing {
                private init() {}
                static let $all: [any MacroRoutingRoute.Type] = [
                    \(routes.map({ $0.name + ".self" }).joined(separator: ", "))
                ]
                static let prefix: String? = \(prefix == nil ? "nil" : "\"\(prefix!)\"")
        """

        for route in routes {
            var captured: [String] = []
            var out: [String] = []

            let prefixedPath = "\(prefix ?? "")\(route.path)"

            let rp = RouterPath(route.path)
            for element in rp.components {
                let component = element.description
                if component.first == "{" {
                    let name = String(component.dropFirst().dropLast())
                    captured.append(name)
                    out.append("\\(`" + name + "`)")
                } else if component.first == ":" {
                    let name = String(component.dropFirst())
                    captured.append(name)
                    out.append("\\(`" + name + "`)")
                } else {
                    // there are other types like wildcards, but those are harder to replace
                    out.append(component.description)
                }
            }

            code += """
                struct \(route.name): MacroRoutingRoute {
                    private init() {}
                    static let method: HTTPRequest.Method = .\(route.method.rawValue.lowercased())
                    static let path: String = "\(prefixedPath)"
                    static let rawPath: String = "\(route.path)"
                    static let handler: String = "\(route.handler)"
                    static let name: String = "\(route.name)"
            """

            if captured.count > 0 {
                code += """
                    static func resolvedPath(\(captured.map({ "\($0): String"}).joined(separator: ", "))) -> String {
                        "/\(out.joined(separator: "/"))"
                    }
                """
            }

            code += """
                }
            """
        }

        code += """
            }
        """ // end struct $Routing

        let extensionCode = """
        extension \(type) {
            \(code)
        }
        """

        guard let extDecl = DeclSyntax(stringLiteral: extensionCode).as(ExtensionDeclSyntax.self) else {
            fatalError("Failed to parse extension declaration")
        }
        return [extDecl]
    }
}

private func sharedExpansion(
    method: Method,
    node: AttributeSyntax,
    declaration: some DeclSyntaxProtocol,
    context: some MacroExpansionContext
) throws -> [DeclSyntax] {
    // no-op (we use these macros in RoutingMacro which is attached to the struct)
    return []
}

public struct GETMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        return try sharedExpansion(
            method: .get,
            node: node,
            declaration: declaration,
            context: context
        )
    }
}

public struct POSTMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        return try sharedExpansion(
            method: .post,
            node: node,
            declaration: declaration,
            context: context
        )
    }
}

public struct PUTMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        return try sharedExpansion(
            method: .put,
            node: node,
            declaration: declaration,
            context: context
        )
    }
}

public struct DELETEMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        return try sharedExpansion(
            method: .delete,
            node: node,
            declaration: declaration,
            context: context
        )
    }
}

public struct HEADMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        return try sharedExpansion(
            method: .head,
            node: node,
            declaration: declaration,
            context: context
        )
    }
}

public struct PATCHMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        return try sharedExpansion(
            method: .patch,
            node: node,
            declaration: declaration,
            context: context
        )
    }
}
