import Testing
import Hummingbird
import HummingbirdMacroRouting
import HummingbirdTesting

@Suite("Prefixed Macro Routing Tests")
struct MacroRoutingTestPrefix {
    typealias Context = SimpleMacroRoutingRequestContext
    typealias Controller = PrefixedMacroRoutingController

    @Test("Static Structure")
    func testStructureStatic() {
        #expect(Controller.$Routing.prefix == "/api")

        #expect(Controller.$Routing.auth.method == .get)
        #expect(Controller.$Routing.auth.path == "/api/auth")
        #expect(Controller.$Routing.deauth.path == "/api/deauth")
        #expect(Controller.$Routing.auth.rawPath == "/auth")
        #expect(Controller.$Routing.deauth.rawPath == "/deauth")
    }

    @Test("Instance Structure")
    func testInSitu() async throws {
        let controller = Controller()
        let router = Router(context: Context.self)
        router.addRoutes(controller.$routes)
        let app = Application(
            router: router,
            configuration: .init()
        )

        try await app.test(.router) { client in
            try await client.execute(
                uri: "/api/auth",
                method: .get
            ) { response in
                #expect(response.status == .ok)
                #expect(String(buffer: response.body) == "Authed")
            }
            try await client.execute(
                uri: "/api/deauth",
                method: .get
            ) { response in
                #expect(response.status == .ok)
                #expect(String(buffer: response.body) == "Deauthed")
            }
        }
    }
}
