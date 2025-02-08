@attached(extension, names: arbitrary)
public macro MacroRouting() = #externalMacro(module: "RoutingMacros", type: "RoutingMacro")

@attached(peer, names: arbitrary)
public macro GET(_ path: String) = #externalMacro(module: "RoutingMacros", type: "GETMacro")

@attached(peer, names: arbitrary)
public macro POST(_ path: String) = #externalMacro(module: "RoutingMacros", type: "POSTMacro")

@attached(peer, names: arbitrary)
public macro PUT(_ path: String) = #externalMacro(module: "RoutingMacros", type: "PUTMacro")

@attached(peer, names: arbitrary)
public macro DELETE(_ path: String) = #externalMacro(module: "RoutingMacros", type: "DELETEMacro")

@attached(peer, names: arbitrary)
public macro HEAD(_ path: String) = #externalMacro(module: "RoutingMacros", type: "HEADMacro")

@attached(peer, names: arbitrary)
public macro PATCH(_ path: String) = #externalMacro(module: "RoutingMacros", type: "PATCHMacro")
