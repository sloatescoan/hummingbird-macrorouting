import Testing
import Hummingbird
import HummingbirdMacroRouting
import HummingbirdTesting

@Suite("Simple Macro Routing Tests")
struct MacroRoutingTestSimple {
    typealias Context = SimpleMacroRoutingRequestContext
    typealias Controller = SimpleMacroRoutingController

    @Test("Static Structure")
    func testStructureStatic() {
        #expect(Controller.$Routing.logIn.method == .get)
        #expect(Controller.$Routing.logIn.path == "/login")

        #expect(Controller.$Routing.logOutHandler.method == .post)
        #expect(Controller.$Routing.logOutHandler.path == "/logout")

        #expect(Controller.$Routing.prefix == nil)

        // digging into paths in $all is easier than comparing the structs directly
        #expect(
            Controller.$Routing.$all.map({ $0.path }) == [
                Controller.$Routing.logIn.path,
                Controller.$Routing.logOutHandler.path
            ]
        )
    }

    @Test("Instance Structure")
    func testInSitu() async throws {
        let controller = Controller()

        #expect(type(of: controller.$routes) == RouteCollectionContainer<Context>.self)

        let router = Router(context: Context.self)
        router.addRoutes(controller.$routes)
        let app = Application(
            router: router,
            configuration: .init()
        )

        try await app.test(.router) { client in
            try await client.execute(
                uri: Controller.$Routing.logIn.path,
                method: .get
            ) { response in
                #expect(response.status == .ok)
                #expect(String(buffer: response.body) == "Logged in")
            }
            try await client.execute(
                uri: Controller.$Routing.logOutHandler.path,
                method: .get
            ) { response in
                #expect(response.status == .notFound)
            }
            try await client.execute(
                uri: Controller.$Routing.logOutHandler.path,
                method: .post
            ) { response in
                #expect(response.status == .ok)
                #expect(String(buffer: response.body) == "Logged out")
            }
        }
    }

}
