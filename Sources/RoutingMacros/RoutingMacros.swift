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
        RoutingExtensionMacro.self,
    ]
}
enum Method: String, CaseIterable {
    case get, post, put, delete, head, patch
    static var allValues: [String] { Self.allCases.map { "\($0)".uppercased() } }
}

/// Valid Swift identifier: used for route names and extension namespaces.
let identifierPattern = #"^[A-Za-z_][A-Za-z0-9_]*$"#

/// Namespaces that would generate members colliding with the base macro's own
/// output (`$routes`, `$Routing`).
let reservedNamespaces: Set<String> = ["routes", "Routing"]

/// The actual name of the route-struct container a `@MacroRoutingExtension`
/// namespace generates. It's deliberately not `$<namespace>` — that name is
/// reserved for the `typealias` inside `$Routing`, so `Controller.$Routing.$admin`
/// is the documented spelling; `Controller.$admin` doesn't exist (`Controller.$$admin`
/// does, but isn't advertised).
private func internalContainerName(_ namespace: String) -> String {
    "$$\(namespace)"
}

struct CapturedRoute {
    let method: Method
    let path: String
    let handler: String
    let name: String
    let function: FunctionDeclSyntax

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

    init(method: Method, path: String, handler: String, name: String, function: FunctionDeclSyntax) {
        self.method = method
        self.path = Self.stripped(path)
        self.handler = Self.stripped(handler)
        self.name = Self.stripped(name)
        self.function = function
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

/// Scan a member block for functions carrying @GET/@POST/… attributes and
/// capture their routes. Shared by `RoutingMacro` (struct body) and
/// `RoutingExtensionMacro` (extension body).
private func captureRoutes(
    in members: MemberBlockItemListSyntax,
    context: some MacroExpansionContext
) -> [CapturedRoute] {
    return members.flatMap { member -> [CapturedRoute] in
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

            // Preserve any `\(…)` interpolation in the path so it passes
            // through to the generated code instead of truncating.
            let path = reconstructedLiteral(firstArg)

            // Extract the route name
            let name: String
            if
                let nameExpr = arguments.first(where: { $0.label?.text == "name" })?.expression.as(StringLiteralExprSyntax.self)
            {
                // Reconstruct fully: an interpolated name isn't a valid
                // identifier, so it should fail the check below rather than
                // be truncated to a passing prefix.
                let nameValue = reconstructedLiteral(nameExpr)
                let isValid = nameValue.range(of: identifierPattern, options: .regularExpression) != nil
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


            return CapturedRoute(method: method, path: path, handler: function.name.text, name: name, function: function)
        }
    }
}

/// Make sure we don't have more than one route with the same name.
/// Diagnose each collision *and* drop the duplicate from codegen (first
/// occurrence wins) — otherwise we'd emit two `struct <name>` declarations
/// and the compiler would pile an "invalid redeclaration" error, pointing
/// into generated code, on top of our clear diagnostic.
private func dedupeRoutes(
    _ routes: [CapturedRoute],
    context: some MacroExpansionContext
) -> [CapturedRoute] {
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
    return uniqueRoutes
}

/// Generate the routes computed property (`$routes` for the base macro,
/// `$<namespace>Routes` for extensions). For the base, each declared extension
/// namespace's collection is merged in — the reference to `$<ns>Routes` doubles
/// as the compile-time check that the matching @MacroRoutingExtension exists.
private func routesVarCode(
    varName: String,
    routes: [CapturedRoute],
    prefix: String?,
    extensionNamespaces: [String]
) -> String {
    // this is kind of ugly, but it works…
    var code = """
        var \(varName): RouteCollectionContainer<Context> {
            let routes = RouteCollection(context: Context.self)
    """
    for route in routes {
        code += """
            _ = routes.on(
                "\(prefix ?? "")\(route.path)",
                method: .\(route.method.rawValue.lowercased()),
                use: `\(route.handler)`
            )
        """
    }
    for namespace in extensionNamespaces {
        code += """
            routes.addRoutes($\(namespace)Routes)
        """
    }
    code += """
            return RouteCollectionContainer(routeCollection: routes)
        }
    """
    return code
}

/// Generate the route-struct container (`$Routing` for the base macro,
/// `$<namespace>` for extensions). For the base, each declared extension
/// namespace contributes to `$all` and gets a `typealias $<ns>` so extension
/// routes are reachable as `<Type>.$Routing.$<ns>.<route>`.
private func routingContainerCode(
    containerName: String,
    typeName: String,
    routes: [CapturedRoute],
    prefix: String?,
    extensionNamespaces: [String]
) -> String {
    let allSuffix = extensionNamespaces.map({ " + \(typeName).\(internalContainerName($0)).$all" }).joined()
    var code = """
        struct \(containerName) {
            private init() {}
            static let $all: [any MacroRoutingRoute.Type] = [
                \(routes.map({ "`" + $0.name + "`" + ".self" }).joined(separator: ", "))
            ]\(allSuffix)
            static let $prefix: String? = \(prefix == nil ? "nil" : "\"\(prefix!)\"")
    """

    for route in routes {
        var captured: [String] = []
        var out: [String] = []

        let prefixedPath = "\(prefix ?? "")\(route.path)"

        for component in prefixedPath.split(separator: "/") {
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
            struct `\(route.name)`: MacroRoutingRoute {
                private init() {}
                static let method: HTTPRequest.Method = .\(route.method.rawValue.lowercased())
                static let handler: String = "\(route.handler)"
                static let name: String = "\(route.name)"
                static let prefixedPath: String = "\(prefixedPath)"
                static let rawPath: String = "\(route.path)"
        """

        if captured.count > 0 {
            // for routes that have captured arguments, provide path(…) (formerly resolvedPath(…))
            code += """
                @available(*, deprecated, renamed: "path", message: "resolvedPath(…) has been renamed to path(…)")
                static func resolvedPath(\(captured.map({ "\($0): String"}).joined(separator: ", "))) -> String {
                    path(\(captured.map({
                        ReservedWord(rawValue: $0) == nil ?
                            "\($0): \($0)"
                            :
                            "`\($0)`: `\($0)`"
                    }).joined(separator: ", ")))
                }
                static func path(\(captured.map({ "\($0): String"}).joined(separator: ", "))) -> String {
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

    for namespace in extensionNamespaces {
        code += """
            typealias $\(namespace) = \(typeName).\(internalContainerName(namespace))
        """
    }

    code += """
        }
    """ // end container struct

    return code
}

/// Extract an optional string-literal argument by label (e.g. `prefix:`).
private func stringArgument(
    labelled label: String,
    in arguments: LabeledExprListSyntax?
) -> String? {
    guard
        let argument = arguments?.first(where: { $0.label?.text == label }),
        let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self)
    else {
        return nil
    }
    return reconstructedLiteral(stringLiteral)
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

        let arguments = node.arguments?.as(LabeledExprListSyntax.self)
        let prefix = stringArgument(labelled: "prefix", in: arguments)

        // extension namespaces, declared once here on the base: validated,
        // reserved names rejected, duplicates dropped (first occurrence wins)
        var extensionNamespaces: [String] = []
        if
            let extensionsArg = arguments?.first(where: { $0.label?.text == "extensions" }),
            let arrayExpr = extensionsArg.expression.as(ArrayExprSyntax.self)
        {
            for element in arrayExpr.elements {
                guard let stringLiteral = element.expression.as(StringLiteralExprSyntax.self) else {
                    context.diagnose(
                        Diagnostic(node: element, message: MsgNamespaceError(name: element.expression.description))
                    )
                    continue
                }
                let namespace = reconstructedLiteral(stringLiteral)
                guard namespace.range(of: identifierPattern, options: .regularExpression) != nil else {
                    context.diagnose(
                        Diagnostic(node: element, message: MsgNamespaceError(name: namespace))
                    )
                    continue
                }
                guard !reservedNamespaces.contains(namespace) else {
                    context.diagnose(
                        Diagnostic(node: element, message: MsgNamespaceReserved(name: namespace))
                    )
                    continue
                }
                guard !extensionNamespaces.contains(namespace) else {
                    context.diagnose(
                        Diagnostic(node: element, message: MsgNamespaceConflict(name: namespace))
                    )
                    continue
                }
                extensionNamespaces.append(namespace)
            }
        }

        let routes = captureRoutes(in: structDecl.memberBlock.members, context: context)
        let uniqueRoutes = dedupeRoutes(routes, context: context)
        let typeName = type.trimmedDescription

        var code = routesVarCode(
            varName: "$routes",
            routes: uniqueRoutes,
            prefix: prefix,
            extensionNamespaces: extensionNamespaces
        )
        code += routingContainerCode(
            containerName: "$Routing",
            typeName: typeName,
            routes: uniqueRoutes,
            prefix: prefix,
            extensionNamespaces: extensionNamespaces
        )

        // Marker types, one per declared namespace: the matching
        // @MacroRoutingExtension references its marker, so an extension whose
        // namespace was never declared here fails to compile with
        // "cannot find type '$<ns>_is_listed_in_MacroRouting_extensions'".
        for namespace in extensionNamespaces {
            code += """
                enum $\(namespace)_is_listed_in_MacroRouting_extensions {}
            """
        }

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

public struct RoutingExtensionMacro: MemberMacro {
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingMembersOf declaration: some SwiftSyntax.DeclGroupSyntax,
        conformingTo protocols: [SwiftSyntax.TypeSyntax],
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.DeclSyntax] {
        guard let extensionDecl = declaration.as(ExtensionDeclSyntax.self) else {
            context.diagnose(Diagnostic(node: node, message: MsgExtensionOnly()))
            return []
        }

        // the namespace is the required, unlabelled first argument
        guard
            let arguments = node.arguments?.as(LabeledExprListSyntax.self),
            let namespaceArg = arguments.first,
            namespaceArg.label == nil,
            let namespaceLiteral = namespaceArg.expression.as(StringLiteralExprSyntax.self)
        else {
            context.diagnose(Diagnostic(node: node, message: MsgNamespaceMissing()))
            return []
        }
        let namespace = reconstructedLiteral(namespaceLiteral)
        guard namespace.range(of: identifierPattern, options: .regularExpression) != nil else {
            context.diagnose(Diagnostic(node: node, message: MsgNamespaceError(name: namespace)))
            return []
        }
        guard !reservedNamespaces.contains(namespace) else {
            context.diagnose(Diagnostic(node: node, message: MsgNamespaceReserved(name: namespace)))
            return []
        }

        // extensions take their own prefix; the base prefix does not cascade
        // (it's statically unknowable from this expansion, and static `path`
        // values must match the runtime paths)
        let prefix = stringArgument(labelled: "prefix", in: arguments)

        let routes = captureRoutes(in: extensionDecl.memberBlock.members, context: context)
        let uniqueRoutes = dedupeRoutes(routes, context: context)

        return [
            DeclSyntax(stringLiteral: routesVarCode(
                varName: "$\(namespace)Routes",
                routes: uniqueRoutes,
                prefix: prefix,
                extensionNamespaces: []
            )),
            DeclSyntax(stringLiteral: routingContainerCode(
                containerName: internalContainerName(namespace),
                typeName: "",
                routes: uniqueRoutes,
                prefix: prefix,
                extensionNamespaces: []
            )),
            // compile-time check that this namespace is declared on the base:
            // @MacroRouting(extensions: ["<ns>"]) emits the referenced marker
            DeclSyntax(stringLiteral: "private typealias $MacroRoutingDeclared_\(namespace) = $\(namespace)_is_listed_in_MacroRouting_extensions"),
        ]
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
