import Testing
import Hummingbird
import HummingbirdMacroRouting
import HummingbirdTesting

@Suite("Extension Macro Routing Tests")
struct MacroRoutingTestExtension {
    typealias Context = SimpleMacroRoutingRequestContext
    typealias Controller = ExtensionMacroRoutingController

    @Test("Static Structure")
    func testStructureStatic() {
        // base routes, untouched by the extensions
        #expect(Controller.$Routing.getMain.method == .get)
        #expect(Controller.$Routing.getMain.path == "/main")
        #expect(Controller.$Routing.$prefix == nil)

        // extension routes, via the $Routing typealias
        #expect(Controller.$Routing.$admin.getExtensionId.method == .get)
        #expect(Controller.$Routing.$admin.getExtensionId.path(id: "42") == "/extension/42")

        #expect(Controller.$Routing.$api.getApi.method == .post)
        #expect(Controller.$Routing.$api.getApi.path == "/api")

        #expect(Controller.$Routing.$admin.$prefix == nil)
        #expect(Controller.$Routing.$api.$prefix == nil)

        // $all is complete across the base and both extensions
        #expect(
            Controller.$Routing.$all.map({ $0.prefixedPath }) == [
                Controller.$Routing.getMain.prefixedPath,
                Controller.$Routing.$admin.getExtensionId.prefixedPath,
                Controller.$Routing.$api.getApi.prefixedPath,
            ]
        )
    }

    @Test("Instance Structure")
    func testInSitu() async throws {
        let controller = Controller()

        #expect(type(of: controller.$routes) == RouteCollectionContainer<Context>.self)

        let router = Router(context: Context.self)
        // one call — routes from both extensions are wired in automatically
        router.addRoutes(controller.$routes)
        let app = Application(
            router: router,
            configuration: .init()
        )

        try await app.test(.router) { client in
            try await client.execute(
                uri: Controller.$Routing.getMain.path,
                method: .get
            ) { response in
                #expect(response.status == .ok)
                #expect(String(buffer: response.body) == "Main")
            }
            try await client.execute(
                uri: Controller.$Routing.$admin.getExtensionId.path(id: "42"),
                method: .get
            ) { response in
                #expect(response.status == .ok)
                #expect(String(buffer: response.body) == "Extension item {id} = 42")
            }
            try await client.execute(
                uri: Controller.$Routing.$api.getApi.path,
                method: .get
            ) { response in
                #expect(response.status == .notFound)
            }
            try await client.execute(
                uri: Controller.$Routing.$api.getApi.path,
                method: .post
            ) { response in
                #expect(response.status == .ok)
                #expect(String(buffer: response.body) == "Extension logged out")
            }
        }
    }
}
