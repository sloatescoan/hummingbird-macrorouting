import Hummingbird

public protocol MacroRoutingRoute: Sendable {
    static var method: HTTPRequest.Method {get}
    static var prefixedPath: String {get}
    static var rawPath: String {get}
    static var name: String {get}
    static var handler: String {get}
}
