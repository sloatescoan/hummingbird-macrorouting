import Hummingbird

// this container (and the RouterMethods extension) is to compiler-hint
// that atPath is unavailable for this type of routing
public struct RouteCollectionContainer<Context: RequestContext> {
    public let routeCollection: RouteCollection<Context>

    // explicitly use a public init since the synthesized one is internal
    public init(routeCollection: RouteCollection<Context>) {
        self.routeCollection = routeCollection
    }
}
