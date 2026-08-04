# Sentech Connect — Architecture

Companion to [`../README.md`](../README.md). Three diagrams: the screen-to-screen navigation graph, the Clean Architecture layering used inside every feature, and the request path for a single screen from tap to (mock) data source.

## 1. Navigation graph

Every route in `lib/app/router/app_router.dart`, and what triggers each transition. `MainShell` is drawn as one node with its five tabs expanded underneath it — those tab switches are local widget state (`IndexedStack`), not `go_router` navigation.

```mermaid
flowchart TD
    Splash["/ (Splash)"] -->|"session restored"| Main
    Splash -->|"no session"| Login["/login"]

    Login -->|"onLoggedIn"| Coverage["/coverage"]
    Login -->|"onRegister"| Register["/register"]
    Register -->|"onRegistered"| Coverage

    Coverage -->|"onCovered"| Main["/main (MainShell)"]

    subgraph MainShell["MainShell — bottom nav tabs"]
        direction LR
        TabHome["Home\n(Dashboard)"]
        TabShop["Shop\n(Catalog)"]
        TabScan["Scan\n(Voucher Scanner)"]
        TabSupport["Support"]
        TabAccount["Account"]
    end
    Main --- MainShell

    TabShop -->|"onOpenCart"| Cart["/cart"]
    TabHome -->|"onOpenPromotions"| Promotions["/promotions"]
    TabShop -->|"onFindHotspots\n(from Vouchers category)"| Hotspots["/wifi-hotspots"]
    TabAccount -->|"onLoggedOut"| Login

    Cart -->|"onCheckout"| Checkout["/checkout"]
    Checkout -->|"onPaid(order)"| Rica["/rica"]
    Rica -->|"onVerified(order)\n[context.go, not pushReplacement]"| Confirmation["/confirmation"]
    Confirmation -->|"onDone"| Main

    TabHome -->|"onTopUp → Vouchers category"| TabShop
    TabHome -->|"onUpgrade → Home 5G category"| TabShop
    TabHome -->|"onReportIssue\n(shared ticket dialog)"| TabSupport
```

**Why RICA → Confirmation uses `context.go()` and not `context.pushReplacement()`:** the latter triggered an intermittent Flutter Hero-controller assertion (`manifest.fromHero == newManifest.toHero`) when combined with the always-mounted `MainShell` `IndexedStack` underneath. See the README's "Known gotchas".

## 2. Clean Architecture layering (per feature)

Every feature folder under `lib/features/` follows this shape. `coverage` is used here as the concrete example; every other feature (`catalog_checkout`, `rica`, `wifi_voucher`, `promotions`, `support`, …) is structured identically.

```mermaid
flowchart LR
    subgraph Presentation["presentation/"]
        Page["CoveragePage\n(Flutter widget)"]
        Cubit["CoverageCubit\n(flutter_bloc)"]
        Page -- "reads state,\ndispatches methods" --> Cubit
    end

    subgraph Domain["domain/ — pure Dart, no Flutter imports"]
        Entity["CoverageResult\n(entity)"]
        RepoIface["CoverageRepository\n(abstract interface)"]
    end

    subgraph Data["data/"]
        MockRepo["MockCoverageRepository\nimplements CoverageRepository"]
    end

    Cubit -- "calls" --> RepoIface
    RepoIface -.->|"implemented by"| MockRepo
    MockRepo -- "returns" --> Entity
    RepoIface -- "returns Either&lt;Failure, CoverageResult&gt;\n(fpdart)" --> Cubit

    Locator["get_it locator\n(lib/app/locator.dart)"] -. "registers\nMockCoverageRepository\nagainst CoverageRepository" .-> RepoIface
```

**The seam that matters:** `Cubit` only ever imports `domain/repositories/coverage_repository.dart` (the interface), never the `Mock` class directly. A real `HttpCoverageRepository` slots in by changing one registration line in `lib/app/locator.dart` — see the README's "Swapping a mock for a real backend".

## 3. Request path — tap to (mock) data, using "Check this address"

A concrete sequence for one interaction, showing every layer a single user action passes through.

```mermaid
sequenceDiagram
    participant U as User
    participant W as CoveragePage (widget)
    participant C as CoverageCubit
    participant R as CoverageRepository (interface)
    participant M as MockCoverageRepository

    U->>W: Tap "Check this address"
    W->>C: context.read<CoverageCubit>().checkAddress(address)
    C->>C: emit(status: checking)
    C->>R: checkAddress(address)
    R->>M: (resolved at runtime via get_it)
    M-->>M: Future.delayed(700ms) — simulates network latency
    M-->>R: Right(CoverageResult(isCovered: true, ...))
    R-->>C: Either<Failure, CoverageResult>
    C->>C: emit(status: checked, result: ...)
    C-->>W: BlocBuilder rebuilds
    W-->>U: Shows "5G FWA available" result card
```

Every other Cubit in the app (`CatalogCubit`, `CheckoutCubit`, `FreeWifiCubit`, `SupportCubit`, …) follows this exact same shape: emit a loading state, call the repository interface, `.match()` the `Either<Failure, T>` result (via `fpdart`), emit the new state.

## App-root state vs. per-screen state

Two different lifetimes exist in this app, worth keeping straight when adding a new feature:

```mermaid
flowchart TD
    subgraph Root["Provided once — lib/app/app.dart (MultiBlocProvider)"]
        AuthCubit["AuthCubit\n(persisted session)"]
        CartCubit["CartCubit\n(cart survives Shop→Cart→Checkout)"]
        ThemeCubit["ThemeCubit\n(persisted light/dark/system)"]
    end

    subgraph PerScreen["Created per-route or per-tab"]
        CoverageCubit
        CatalogCubit["CatalogCubit\n(held by MainShell, not per-build,\nso dashboard quick-actions can drive it)"]
        CheckoutCubit
        RicaCubit
        SupportCubit
        PromotionsCubit
        FreeWifiCubit
        WifiHotspotsCubit
        AccountCubit
    end

    CheckoutCubit -- "reads on construction\n(items to charge)" --> CartCubit
    Confirmation["ConfirmationPage"] -. "on pay success" .-> CartCubit
```

`CatalogCubit` is the one exception to "created per-route": it's held as a field on `_MainShellState` (not created inline in the tab list) specifically so the dashboard's "Top up"/"Upgrade" quick actions can call `.selectCategory()` on the *same* instance the Shop tab is displaying, rather than only being able to switch tabs blindly.
