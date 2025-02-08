import Hummingbird

extension RouterMethods {
    @discardableResult public func addRoutes(_ collectionContainer: RouteCollectionContainer<Context>) -> Self {
        return self.addRoutes(collectionContainer.routeCollection, atPath: "")
    }
    
    @available(*, unavailable, message: "atPath is not supported when using RouteCollectionContainer")
    @discardableResult public func addRoutes(_ collectionContainer: RouteCollectionContainer<Context>, atPath path: RouterPath = "") -> Self {
        self
    }
}
