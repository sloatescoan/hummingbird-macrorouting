import Testing
import Hummingbird
import HummingbirdMacroRouting
import HummingbirdTesting

@Suite("Name Macro Routing Tests")
struct MacroRoutingTestName {
    typealias Context = SimpleMacroRoutingRequestContext
    typealias Controller = NameMacroRoutingController

    @Test("Renamed Routes Structure")
    func testStructure() {
        #expect(Controller.$Routing.welcomeRoute.method == .get)
        #expect(Controller.$Routing.welcomeRoute.path == "/welcome")

        #expect(Controller.$Routing.welcomeRoute.handler == "welcomeRouteHandler")
        #expect(Controller.$Routing.welcomeRoute.name == "welcomeRoute")
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
                uri: Controller.$Routing.welcomeRoute.path,
                method: .get
            ) { response in
                #expect(response.status == .ok)
                #expect(String(buffer: response.body) == "Welcome!")
            }
            try await client.execute(
                uri: "/welcome",
                method: .get
            ) { response in
                #expect(response.status == .ok)
                #expect(String(buffer: response.body) == "Welcome!")
            }

            try await client.execute(
                uri: Controller.$Routing.welcomeRouteHandler3.path,
                method: .get
            ) { response in
                #expect(response.status == .ok)
                #expect(String(buffer: response.body) == "Welcome 3!")
            }
            try await client.execute(
                uri: Controller.$Routing.postWelcomeRouteHandler3.path,
                method: .post
            ) { response in
                #expect(response.status == .ok)
                #expect(String(buffer: response.body) == "Welcome 3!")
            }
        }
    }
}
