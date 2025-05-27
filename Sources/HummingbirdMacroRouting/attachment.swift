@attached(extension, names: arbitrary)
public macro MacroRouting(prefix: String? = nil) = #externalMacro(module: "RoutingMacros", type: "RoutingMacro")

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
