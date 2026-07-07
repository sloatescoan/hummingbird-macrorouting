import Testing
import Hummingbird
import HummingbirdMacroRouting
import HummingbirdTesting

@Suite("Interpolation Macro Routing Tests")
struct MacroRoutingTestInterpolation {
    typealias Context = SimpleMacroRoutingRequestContext
    typealias Controller = InterpolatedMacroRoutingController

    @Test("Interpolated Paths Structure")
    func testStructure() {
        // Literal interpolation must pass through, not truncate to "/api/build/".
        #expect(Controller.$Routing.build.path == "/api/build/1")

        // Static-member interpolation must resolve, not truncate to "/api/".
        #expect(Controller.$Routing.status.path == "/api/v2/status")

        // Interpolation and a captured `{userId}` argument in the same route:
        // the interpolation resolves and the argument is substituted.
        #expect(Controller.$Routing.logs.prefixedPath == "/api/v2/logs/{userId}")
        #expect(Controller.$Routing.logs.path(userId: "42") == "/api/v2/logs/42")
    }
}
