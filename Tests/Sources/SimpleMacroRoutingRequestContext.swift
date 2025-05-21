import Hummingbird

struct SimpleMacroRoutingRequestContext: RequestContext {
    var coreContext: CoreRequestContextStorage

    init(source: Source) {
        self.coreContext = .init(source: source)
    }
}
