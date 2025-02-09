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
- route lookup with `Controller.$Routing.routeName` where `routeName` is the function name
  - If you have a `@MacroRouting` controller, a `$Routing` property is synthesized (this is a controller-specific `enum` type, which includes `.path` and `.method` for each case), so you can look up routes progrmamatically, and at compile time (so you also get code completion, and you can change route paths by changing the value in `@GET("/login")`, seamlessly, if you don't change the name of `AuthController.logIn`, and you'll get help from the compiler if you *do* rename the `logIn` function.
- you can still use the normal routing methods, including the documented [`RouteCollection`](https://docs.hummingbird.codes/2.0/documentation/hummingbird/routerguide#Route-Collections) + `addRoutes(…)` based approach
  - `hummingbird-macroroutes` provides a `RouteCollectionContainer` that wraps these to help hint that you shouldn't use the `atPath` signature (see below)
  - a `.$routes` var is synthesized on the controller to contain this `RouteCollectionContainer`

## Installation

In your `Package.swift`, put this into your `.dependencies`:

```swift
    .package(url: "https://github.com/sloatescoan/hummingbird-macrorouting.git", from: "0.1.0")
```

…and in your `.target`/`.executableTarget`:

```swift
    .product(name: "HummingbirdMacroRouting", package: "hummingbird-macrorouting")
```

To use the macros in a controller, you need to `import HummingbirdMacroRouting`; this provides the needed types and the macros themselves.

## Drawbacks

Everything is not perfect in MacroRouting land…

- you can no longer use `atPath` with `addRoutes(…)`. Technically you can (if you dig into `RouteCollectionContainer`'s `.routeCollection` property), but you'll lose the ability to look up definitive route paths in `UserController.$Routing`.
- it's more difficult to use one function for more than one route/path


> NOTE: this is a very early version of the code, and frankly [my](https://github.com/scoates) first macros, so use with caution and please be nice. This is by no means *done*; it's just usable in its first form.

> Obviously-missing things: wide testing, unit tests, handling of misplaced macro calls, diagnostics.
