# hummingbird-macrorouting

Improved Swift Macro based routing for [Hummingbird](https://hummingbird.codes) controllers.

## Usage

```swift
import Hummingbird
import HummingbirdMacroRouting

@MacroRouting
struct AuthController<Context: RequestContext> {

    @GET("/login")
    @Sendable func logIn(request: Request, context: Context) async throws -> Response {
        return templatedResponse("login.html")
    }

    @POST("/login")
    @Sendable func logInHandler(request: Request, context: Context) async throws -> Response {
        if checkLogin(request) {
            session.userLoggedIn(getUsername(from: request))
            return redirectResponse(to: UserController.$routes.dashboard.path)
        } else {
            session.flash(message: Localization.logInFailed)
            return redirectResponse(to: $Routes.login.path)
        }
    }

    @POST("/logout")
    @Sendable func logOut(request: Request, context: Context) async throws -> Response {
        session.clear()
        return redirectResponse(to: HomeController.$Routes.root.path)
    }

}
```

Here's how you'd do the same thing without `MacroRouting`:


```swift
import Hummingbird

struct AuthController<Context: RequestContext> {
    var routes: RouteCollection<Context> {
        let routes = RouteCollection()
        routes.get("/login", use: logIn)
        routes.post("/login", use: logInHandler)
        // …
        routes.post("/logout", use: logOutHandler)
        return routes
    }

    @Sendable func logIn(request: Request, context: Context) async throws -> Response {
        return templatedResponse("login.html")
    }

    @Sendable func logInHandler(request: Request, context: Context) async throws -> Response {
        if checkLogin(request) {
            session.userLoggedIn(getUsername(from: request))
            return redirectResponse(to: "/dashboard")
        } else {
            session.flash(message: Localization.logInFailed)
            return redirectResponse(to: "/login")
        }
    }

    @Sendable func logOut(request: Request, context: Context) async throws -> Response {
        session.clear()
        return redirectResponse(to: "/")
    }

}
```

Both approaches get added to your router in a similar way.

`MacroRouting` method:

```swift
router.addRoutes(AuthController().$routes)
```
Traditional method:

```swift
router.addRoutes(AuthController().routes)
```

## Benefits

The main benefits to this approach are:

- less boilerplate (no need to compose a bespoke `var routes: RouteCollection<Context>`)
- a direct relationship/link between your route functions and the `@VERB("/path")` annotations (no need to look elsewhere in the file to track down the logic in `.routes`)
- route lookup with `Controller.$Routing.routeName` where `routeName` is the function name (or declared route name)
  - If you have a `@MacroRouting` controller, a `$Routing` property is synthesized (this is a controller-specific struct, which includes routing info for each of your declared routes), so you can look up routes progrmamatically, and at compile time (so you also get code completion, and you can change route paths by changing the value in `@GET("/login")`, seamlessly, if you don't change the name of `AuthController.logIn`, and you'll get help from the compiler if you *do* rename the `logIn` function.
- you can still use the normal routing methods, including the documented [`RouteCollection`](https://docs.hummingbird.codes/2.0/documentation/hummingbird/routerguide#Route-Collections) + `addRoutes(…)` based approach
  - `hummingbird-MacroRouting` provides a `RouteCollectionContainer` that wraps these to help hint that you shouldn't use the `atPath` signature (see below)
  - a `.$routes` var is synthesized on the controller to contain this `RouteCollectionContainer`
- you can construct route paths based on path arguments, all statically, so if anything changes, the compiler will warn you

## Installation

In your `Package.swift`, put this into your `.dependencies`:

```swift
    .package(url: "https://github.com/sloatescoan/hummingbird-macrorouting.git", from: "0.3.0")
```

…and in your `.target`/`.executableTarget`:

```swift
    .product(name: "HummingbirdMacroRouting", package: "hummingbird-macrorouting")
```

To use the macros in a controller, you need to `import HummingbirdMacroRouting`; this provides the needed types and the macros themselves.

## Prefix

You can no longer use `atPath` with `addRoutes(…)`. Technically you can (if you dig into `RouteCollectionContainer`'s `.routeCollection` property), but you'll lose the ability to look up definitive route paths in `UserController.$Routing`.

You can, however, set a `prefix` in the `@MacroRouting` call, so your routes automatically get a prefix. This is not a complete replacement for `atPath`—with `atPath` you can attach the same routes in multiple places, under multiple prefixes—but this approach allows you to avoid repeating the `/users/` part of your UserController routes:

(this code is adapted from the [test suite](https://github.com/sloatescoan/hummingbird-macrorouting/tree/main/Tests))

```swift
@MacroRouting(prefix: "/api")
struct ApiController {
    typealias Context = AppRequestContext

    @GET("/auth")  // actually /api/auth
    @Sendable func auth(request: Request, context: Context) async throws -> Response {
        …
    }

    @GET("/charge/card")  // actually /api/charge/card
    @Sendable func chargeCard(request: Request, context: Context) async throws -> Response {
        …
    }
}
```

## Route Reuse

You can attach more than one `@VERB` declaration to each handler. Consider the above `ApiController`, but you'd want to allow the client to use the `/api/auth` route as both `GET` and `POST`:

```swift
    @GET("/auth")  // actually /api/auth
    @POST("/auth", name: "postAuth")
    @Sendable func auth(request: Request, context: Context) async throws -> Response {
        …
    }
```

(Note: you need to give additional routes (or all routes) `name`s, so the `$Routing` resolution has a structural name.)

In this example, you can use `GET` and `POST` to `/api/auth` to hit the same handler. You could also do something like `@GET("/login", name: "authAsLogin")` to make this handler answer on `/api/login`. This is especially useful for making APIs backward compatible.

## `$Routing`

HummingbirdMacroRouting synthesizes a `$Routing` structure in each `@MacroRouting` controller.

In the above API example, you might want to do something like this:

```swift
let authPath = ApiController.$Routing.auth.path
```

This value is available at compile time (which is development time if your IDE builds macros with the Swift language server or similar), so you get the safety of the compiler, and the convenience of code completion.

![IDE completion of `ApiController.$Routing.auth.path`](https://files.scoat.es/Ur5HUZ0h2p.gif)

### Path Resolution

Additionally, route paths with arguments can be resolved through the synthesized methods. Consider this code in `ApiController`:

```swift
    @GET("/logs/{userId}/{timing}")
    @Sendable func logs(request: Request, context: Context) async throws -> Response {
        …
    }
```

Where you might normally get the logs path with `ApiController.$Routing.logs.path`, here, the path has arguments. If MacroRouting were to supply `.path` as a `String`, it would return `/api/logs/{userId}/{timing}`, which isn't exactly useful for passing to a client if you want them to fetch "my logs for today", for example.

This is where `.path()` comes in:

```swift
let logsPath = ApiController.$Routing.logs.path(userId: "123", timing: "2025-05-27")
```

This will return: `/api/logs/123/2025-05-27`.

The argument names are synthesized by MacroRouting, so they're available to well-behaving editors/IDEs:

![IDE completion of `ApiController.$Routing.logs.path`](https://files.scoat.es/IKYWGNmUCq.gif)

#### Typed path parameters

By default, every synthesized `path(…)` argument is a `String`. You can give an individual parameter a real Swift type with `#p`, right where the parameter appears in the path:

```swift
    @GET("/users/\(#p("id", UUID.self))")
    @Sendable func user(request: Request, context: Context) async throws -> Response {
        …
    }
```

`#p("id", UUID.self)` expands to the Hummingbird placeholder `{id}` (so Hummingbird sees the ordinary path `/users/{id}`), while telling MacroRouting that `id` is a `UUID`. `ApiController.$Routing.user.path(id:)` now takes a `UUID`, so you can pass the value directly instead of stringifying at the call site:

```swift
let path = ApiController.$Routing.user.path(id: someUuid) // -> "/users/00000000-0000-0000-0000-000000000000"
```

The value's string-interpolation form (its `description`) is used to build the path—for `UUID` that is identical to `.uuidString`. This is the outbound mirror of Hummingbird's inbound `context.parameters.get(_:as:)`.

You can mix typed `#p` slots with ordinary `{…}`/`:…` placeholders, which stay `String`:

```swift
    @GET("/orgs/\(#p("orgId", UUID.self))/users/\(#p("userId", Int.self))/tag/{tag}")
    // -> path(orgId: UUID, userId: Int, tag: String)
```

Any type works, so long as it conforms to `CustomStringConvertible`, *including your own project's types*—just conform them and pass them to `#p`:

```swift
struct Slug: CustomStringConvertible {
    let value: String
    var description: String { value.lowercased() }
}

// …
    @GET("/post/\(#p("slug", Slug.self))")
    // -> path(slug: Slug)
```

> **Important:** This does *not* affect how Hummingbird interprets a route/path, but it *does* provide a type-safe way to specify a route with `$Routing.pathHandler.path(…)`.

##### The parameter macro's names, and avoiding collisions

`#p` is short and reads well, but `p` is a common identifier. Because the macro is a *freestanding* macro, it lives in your namespace once you `import HummingbirdMacroRouting`, and Swift offers no way to rename a macro at the import site. To avoid a clash, MacroRouting provides the **same** macro under four spellings—use whichever is free in your project:

| Spelling | Notes |
| --- | --- |
| `#p` | short; used throughout these docs |
| `#param` | |
| `#hbParam` | namespaced-ish |
| `#HummingbirdMacroRoutingParam` | fully explicit; should be collision-proof |

All four are enabled by default. If a shorter spelling still collides with something in your project, two **package traits** progressively disable the shorter names (which removes both the declaration *and* MacroRouting's recognition of that spelling, so your own same-named macro is left untouched):

| Trait | Available spellings |
| --- | --- |
| *(none — default)* | `#p`, `#param`, `#hbParam`, `#HummingbirdMacroRoutingParam` |
| `LongParamNamesOnly` | `#hbParam`, `#HummingbirdMacroRoutingParam` |
| `ExplicitParamNameOnly` | `#HummingbirdMacroRoutingParam` |

Enable a trait where you depend on the package:

```swift
.package(
    url: "https://github.com/sloatescoan/hummingbird-macrorouting.git",
    from: "…",
    traits: ["LongParamNamesOnly"]
)
```

You only need to remove (e.g.) `#p` if you already have a `#p` in scope, and if it has a different signature. MacroRouting will always use its own `#p` because the macro expansion code does not get access to your scope. The freestanding macro(s) that MacroRouting uses to resolve path parameters can't be overridden in your code.


## Tests

There's some useful reference code available in the [test suite](https://github.com/sloatescoan/hummingbird-macrorouting/tree/main/Tests).

## Limitations

MacroRouting runs—as the name implies—as a Swift macro, which means that it is part of the compile phase. This means that it can't "know" about routing that is applied at runtime.

It operates statically, to synthesize the `$Routing` struct.

You can still apply routes with `atPath`, or as [`RouterGroup`](https://docs.hummingbird.codes/2.0/documentation/hummingbird/routergroup) methods, but you won't benefit from MacroRouting's synthesis.
