import Foundation
import SwiftCompilerPlugin
import SwiftSyntaxMacros
import SwiftSyntax
import SwiftDiagnostics

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

        let routes: [(method: Method, path: String, handler: String)] = structDecl.memberBlock.members.compactMap { member in
            guard let function = member.decl.as(FunctionDeclSyntax.self) else { return nil }
            
            // Find HTTP method attributes (@GET, @POST, etc.)
            let httpAttribute = function.attributes.first { attr in
                let attrName = attr.as(AttributeSyntax.self)?.attributeName.as(IdentifierTypeSyntax.self)?.name.text ?? ""
                return Method.allValues.contains(attrName)
            }?.as(AttributeSyntax.self)
            
            // guard against malformed macro placement, etc.
            guard
                let httpAttribute = httpAttribute,
                let arguments = httpAttribute.arguments?.as(LabeledExprListSyntax.self),
                let firstArg = arguments.first?.expression.as(StringLiteralExprSyntax.self),
                let methodName = httpAttribute.attributeName.as(IdentifierTypeSyntax.self)?.name.text,
                let method = Method(rawValue: methodName.lowercased()),
                let path = firstArg.segments.first?.as(StringSegmentSyntax.self)?.content.text
            else {
                return nil
            }
            return (method: method, path: path, handler: function.name.text)
        }

        // this is kind of ugly, but it works…
        var code = """
            var $routes: RouteCollectionContainer<Context> {
                let routes = RouteCollection(context: Context.self)
        """
        for route in routes {
            code += """
                _ = routes.on(
                    "\(route.path)",
                    method: .\(route.method.rawValue.lowercased()),
                    use: \(route.handler)
                )
            """
        }
        code += """
                return RouteCollectionContainer(routeCollection: routes)
            }
        """

        code += "public enum $Routing: Equatable, CaseIterable {\n"
        for route in routes {
            code += "    case \(route.handler)\n"
        }
        code += """
            var method: HTTPRequest.Method {
                switch self {
        """
        for route in routes {
            code += """
                case .\(route.handler):
                    return .\(route.method.rawValue.lowercased())
            """
        }
        code += """
                }
            }

            var path: String {
                switch self {
        """
        for route in routes {
            code += """
                case .\(route.handler):
                    return "\(route.path)"
            """
        }
        code += """
                }
            }
        }
        """

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
