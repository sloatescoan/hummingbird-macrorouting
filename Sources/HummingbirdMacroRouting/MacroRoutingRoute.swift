import Hummingbird

public protocol MacroRoutingRoute {
    static var method: HTTPRequest.Method {get}
    static var path: String {get}
    static var rawPath: String {get}
}
