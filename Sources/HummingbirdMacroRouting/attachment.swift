@attached(extension, names: arbitrary)
public macro MacroRouting(prefix: String? = nil, extensions: [String] = []) = #externalMacro(module: "RoutingMacros", type: "RoutingMacro")

// Extension-role macros can't be attached to an `extension`, so routes declared in
// extensions of a controller use this member-role macro instead. Each extension gets
// a namespace, declared once on the base: @MacroRouting(extensions: ["admin"]).
// The base then wires `$adminRoutes` into `$routes` and exposes the extension's
// route structs as `$Routing.$admin` — both directions are compile-checked.
@attached(member, names: arbitrary)
public macro MacroRoutingExtension(_ namespace: String, prefix: String? = nil) = #externalMacro(module: "RoutingMacros", type: "RoutingExtensionMacro")

@attached(peer, names: arbitrary)
public macro GET(_ path: String, name: String? = nil) = #externalMacro(module: "RoutingMacros", type: "GETMacro")

@attached(peer, names: arbitrary)
public macro POST(_ path: String, name: String? = nil) = #externalMacro(module: "RoutingMacros", type: "POSTMacro")

@attached(peer, names: arbitrary)
public macro PUT(_ path: String, name: String? = nil) = #externalMacro(module: "RoutingMacros", type: "PUTMacro")

@attached(peer, names: arbitrary)
public macro DELETE(_ path: String, name: String? = nil) = #externalMacro(module: "RoutingMacros", type: "DELETEMacro")

@attached(peer, names: arbitrary)
public macro HEAD(_ path: String, name: String? = nil) = #externalMacro(module: "RoutingMacros", type: "HEADMacro")

@attached(peer, names: arbitrary)
public macro PATCH(_ path: String, name: String? = nil) = #externalMacro(module: "RoutingMacros", type: "PATCHMacro")
