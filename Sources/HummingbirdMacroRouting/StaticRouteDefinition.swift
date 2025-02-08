import Hummingbird

// static definition has no responder (responder is on the instance)
public struct StaticRouteDefinition {
    public let path: RouterPath
    public let method: HTTPRequest.Method
}
