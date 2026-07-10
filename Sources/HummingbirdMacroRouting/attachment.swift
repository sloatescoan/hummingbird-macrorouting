@attached(extension, names: arbitrary)
public macro MacroRouting(prefix: String? = nil) = #externalMacro(module: "RoutingMacros", type: "RoutingMacro")

// Used inside a route path to give a captured parameter a Swift type:
//   @GET("/user/\(#p("id", UUID.self))")
// It expands to the Hummingbird placeholder "{id}" and drives the type of the synthesized
// `path(id: UUID)` builder. The type must conform to `CustomStringConvertible`.
//
// Four spellings are provided so a project can avoid a name collision. All are enabled by
// default; the `LongParamNamesOnly` and `ExplicitParamNameOnly` package traits progressively
// disable the shorter ones (see README).

#if !ExplicitParamNameOnly && !LongParamNamesOnly
@freestanding(expression)
public macro p(_ name: String, _ type: any CustomStringConvertible.Type) -> String = #externalMacro(module: "RoutingMacros", type: "ParamMacro")

@freestanding(expression)
public macro param(_ name: String, _ type: any CustomStringConvertible.Type) -> String = #externalMacro(module: "RoutingMacros", type: "ParamMacro")
#endif

#if !ExplicitParamNameOnly
@freestanding(expression)
public macro hbParam(_ name: String, _ type: any CustomStringConvertible.Type) -> String = #externalMacro(module: "RoutingMacros", type: "ParamMacro")
#endif

@freestanding(expression)
public macro HummingbirdMacroRoutingParam(_ name: String, _ type: any CustomStringConvertible.Type) -> String = #externalMacro(module: "RoutingMacros", type: "ParamMacro")

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
