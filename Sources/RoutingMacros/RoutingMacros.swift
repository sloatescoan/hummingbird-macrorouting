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
        ParamMacro.self,
    ]
}

// Freestanding expression macro used inside a route path: `\(#param("id", UUID.self))`.
// It expands to the string literal "{id}" so the surrounding path type-checks as a String and
// its runtime value is the Hummingbird placeholder. RoutingMacro reads the (unexpanded) call
// out of the path's syntax to recover both the parameter name and its Swift type.
public struct ParamMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        guard
            let name = node.arguments.first?.expression.as(StringLiteralExprSyntax.self)?
                .segments.first?.as(StringSegmentSyntax.self)?.content.text
        else {
            return "\"{}\""
        }
        return "\"{\(raw: name)}\""
    }
}
enum Method: String, CaseIterable {
    case get, post, put, delete, head, patch
    static var allValues: [String] { Self.allCases.map { "\($0)".uppercased() } }
}

// The spellings RoutingMacro recognizes as the path-parameter macro. Gated by the same package
// traits that gate the declarations, so a disabled name is no longer claimed as ours.
let paramMacroNames: Set<String> = {
    var names: Set<String> = ["HummingbirdMacroRoutingParam"]
    #if !ExplicitParamNameOnly
    names.insert("hbParam")
    #endif
    #if !ExplicitParamNameOnly && !LongParamNamesOnly
    names.insert("p")
    names.insert("param")
    #endif
    return names
}()

struct CapturedRoute {
    let method: Method
    let path: String
    let handler: String
    let name: String
    let function: FunctionDeclSyntax
    // param name -> explicit Swift type from a `#param(…)` in the path (defaults to String when absent)
    let paramTypes: [String: String]

    static func stripped(_ val: String) -> String {
        var val = val
        if val.first == "`" {
            val = String(val.dropFirst())
        }
        if val.last == "`" {
            val = String(val.dropLast())
        }
        return val
    }

    init(method: Method, path: String, handler: String, name: String, function: FunctionDeclSyntax, paramTypes: [String: String] = [:]) {
        self.method = method
        self.path = Self.stripped(path)
        self.handler = Self.stripped(handler)
        self.name = Self.stripped(name)
        self.function = function
        self.paramTypes = paramTypes
    }
}

/// Reconstruct the inner text of a string literal, preserving every segment —
/// including `\(…)` interpolations, which are emitted verbatim (e.g. `\(API.version)`).
/// Reading only `segments.first` (the old approach) silently dropped everything
/// after the first interpolation. The reconstructed text is spliced back between
/// quotes in the generated code, so the Swift compiler evaluates the interpolation.
private func reconstructedLiteral(_ literal: StringLiteralExprSyntax) -> String {
    literal.segments.map { $0.description }.joined()
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
                prefix = reconstructedLiteral(stringLiteral)
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
                    let method = Method(rawValue: methodName.lowercased())
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
                    let nameExpr = arguments.first(where: { $0.label?.text == "name" })?.expression.as(StringLiteralExprSyntax.self)
                {
                    // Reconstruct fully: an interpolated name isn't a valid
                    // identifier, so it should fail the check below rather than
                    // be truncated to a passing prefix.
                    let nameValue = reconstructedLiteral(nameExpr)
                    let isValid = nameValue.range(of: #"^[A-Za-z_][A-Za-z0-9_]*$"#, options: .regularExpression) != nil
                    guard isValid else {
                        context.diagnose(
                            Diagnostic(
                                node: member.decl,
                                message: MsgNameError(name: nameValue)
                            )
                        )
                        return nil
                    }
                    name = nameValue
                } else {
                    name = function.name.text
                }

                // Reconstruct the path from the string literal's segments. A `#param("name", Type.self)`
                // interpolation contributes a `{name}` placeholder (what Hummingbird sees) and records
                // the Swift type for the synthesized `path(…)`. Every other segment — plain text and any
                // other `\(…)` interpolation, e.g. `\(API.version)` — is emitted verbatim so it passes
                // through to the generated code (matching `reconstructedLiteral`).
                var path = ""
                var paramTypes: [String: String] = [:]
                for segment in firstArg.segments {
                    if
                        let expr = segment.as(ExpressionSegmentSyntax.self),
                        let call = expr.expressions.first?.expression.as(MacroExpansionExprSyntax.self),
                        paramMacroNames.contains(call.macroName.text),
                        let paramName = call.arguments.first?.expression.as(StringLiteralExprSyntax.self)?
                            .segments.first?.as(StringSegmentSyntax.self)?.content.text
                    {
                        // The name becomes both a `{name}` path placeholder and a `path(name:)` argument
                        // label, so it must be a plain identifier — reject spaces, braces, slashes, etc.
                        guard paramName.range(of: #"^[A-Za-z_][A-Za-z0-9_]*$"#, options: .regularExpression) != nil else {
                            context.diagnose(Diagnostic(node: call, message: MsgParamNameError(name: paramName)))
                            return nil
                        }
                        // The second argument is a `Type.self` metatype; take its base as the type name.
                        let typeName: String
                        if
                            let typeExpr = call.arguments.dropFirst().first?.expression.as(MemberAccessExprSyntax.self),
                            typeExpr.declName.baseName.text == "self",
                            let base = typeExpr.base
                        {
                            typeName = base.trimmedDescription
                        } else {
                            typeName = call.arguments.dropFirst().first?.expression.trimmedDescription ?? "String"
                        }
                        // A repeated parameter collapses into one path(…) argument, so its type must
                        // agree across occurrences.
                        if let existing = paramTypes[paramName], existing != typeName {
                            context.diagnose(Diagnostic(node: call, message: MsgParamTypeConflict(name: paramName, existing: existing, new: typeName)))
                            return nil
                        }
                        path += "{\(paramName)}"
                        paramTypes[paramName] = typeName
                    } else {
                        path += segment.description
                    }
                }

                return CapturedRoute(method: method, path: path, handler: function.name.text, name: name, function: function, paramTypes: paramTypes)
            }
        }

        // make sure we don't have more than one route with the same name.
        // Diagnose each collision *and* drop the duplicate from codegen (first
        // occurrence wins) — otherwise we'd emit two `struct <name>` declarations
        // and the compiler would pile an "invalid redeclaration" error, pointing
        // into generated code, on top of our clear diagnostic.
        var routeNames: Set<String> = []
        var uniqueRoutes: [CapturedRoute] = []
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
                uniqueRoutes.append(route)
            }
        }

        // this is kind of ugly, but it works…
        var code = """
            var $routes: RouteCollectionContainer<Context> {
                let routes = RouteCollection(context: Context.self)
        """
        for route in uniqueRoutes {
            code += """
                _ = routes.on(
                    "\(prefix ?? "")\(route.path)",
                    method: .\(route.method.rawValue.lowercased()),
                    use: `\(route.handler)`
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
                    \(uniqueRoutes.map({ "`" + $0.name + "`" + ".self" }).joined(separator: ", "))
                ]
                static let $prefix: String? = \(prefix == nil ? "nil" : "\"\(prefix!)\"")
        """

        for route in uniqueRoutes {
            var captured: [String] = []
            var out: [String] = []

            let prefixedPath = "\(prefix ?? "")\(route.path)"

            for component in prefixedPath.split(separator: "/") {
                let comp = String(component)
                if comp.first == "{", let close = comp.firstIndex(of: "}") {
                    // `{name}` optionally followed by a literal suffix — Hummingbird's prefix-capture,
                    // e.g. `{id}.jpg` (param `id`, literal `.jpg`).
                    let name = String(comp[comp.index(after: comp.startIndex)..<close])
                    let suffix = String(comp[comp.index(after: close)...])
                    captured.append(name)
                    out.append("\\(`" + name + "`)" + suffix)
                } else if comp.last == "}", let open = comp.lastIndex(of: "{"), open != comp.startIndex {
                    // A literal prefix followed by `{name}` — Hummingbird's suffix-capture, e.g. `file{ext}`.
                    let prefixLiteral = String(comp[..<open])
                    let name = String(comp[comp.index(after: open)..<comp.index(before: comp.endIndex)])
                    captured.append(name)
                    out.append(prefixLiteral + "\\(`" + name + "`)")
                } else if comp.first == ":" {
                    let name = String(comp.dropFirst())
                    captured.append(name)
                    out.append("\\(`" + name + "`)")
                } else {
                    // literal component, including wildcards (*, **, *.jpg, file.*) which bind no argument
                    out.append(comp)
                }
            }

            // A parameter may appear more than once in a path (e.g. `/x/{foo}/y/{foo}`). Those
            // occurrences collapse into a single path(…) argument that fills every position, so the
            // signature uses each name once (first-occurrence order) while `out` keeps every position.
            var seenCapture: Set<String> = []
            let uniqueCaptured = captured.filter { seenCapture.insert($0).inserted }

            // Resolve each captured parameter's declared type, defaulting to String.
            func typeFor(_ param: String) -> String { route.paramTypes[param] ?? "String" }

            code += """
                struct `\(route.name)`: MacroRoutingRoute {
                    private init() {}
                    static let method: HTTPRequest.Method = .\(route.method.rawValue.lowercased())
                    static let handler: String = "\(route.handler)"
                    static let name: String = "\(route.name)"
                    static let prefixedPath: String = "\(prefixedPath)"
                    static let rawPath: String = "\(route.path)"
            """

            if uniqueCaptured.count > 0 {
                // for routes that have captured arguments, provide path(…) (formerly resolvedPath(…))
                code += """
                    @available(*, deprecated, renamed: "path", message: "resolvedPath(…) has been renamed to path(…)")
                    static func resolvedPath(\(uniqueCaptured.map({ "\($0): \(typeFor($0))"}).joined(separator: ", "))) -> String {
                        path(\(uniqueCaptured.map({
                            ReservedWord(rawValue: $0) == nil ?
                                "\($0): \($0)"
                                :
                                "`\($0)`: `\($0)`"
                        }).joined(separator: ", ")))
                    }
                    static func path(\(uniqueCaptured.map({ "\($0): \(typeFor($0))"}).joined(separator: ", "))) -> String {
                        "/\(out.joined(separator: "/"))"
                    }
                """
            } else {
                // this is for routes *without* captured arguments
                code += """
                    static let path: String = "\(prefixedPath)"
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
