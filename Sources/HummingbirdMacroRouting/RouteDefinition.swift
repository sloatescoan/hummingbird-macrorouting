import Hummingbird

// this is fileprivate in Hummingbird's RouteCollection.
// if it's ever separated, we can avoid this definition.
public struct RouteDefinition<Context> {
    let path: RouterPath
    let method: HTTPRequest.Method
    let responder: any HTTPResponder<Context>
}
