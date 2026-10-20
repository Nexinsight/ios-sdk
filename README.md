# nexinsight (iOS)

## Installation

The pod lives in a private spec repo, so add that source alongside the CDN in
your `Podfile`:

```ruby
source 'git@github.com:Nexinsight/ios-sdk.git'
source 'https://cdn.cocoapods.org/'

platform :ios, '13.0'

target 'MyApp' do
  pod 'Nexinsight', '~> 0.2'
end
```

Then run `pod install`. The first time on a machine, register the spec repo:

```sh
pod repo add nexinsight-podspecs git@github.com:Nexinsight/ios-sdk.git
```

The pod ships a static `xcframework` (device `arm64`, simulator `arm64`) and links `libsqlite3` for you.

## Usage

### Swift (iOS)

```swift
import Nexinsight

let dbPath = FileManager.default
    .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("nexinsight.db").path

let cfg = EventsdkConfig("APP-UUID", databasePath: dbPath)!
cfg.setDeviceInfo("iOS", osVersion: UIDevice.current.systemVersion, deviceModel: deviceModel())
cfg.setAppInfo("MyApp", version: appVersion, build: appBuild)
cfg.flushIntervalSeconds = 15

guard let tracker = EventsdkTracker(cfg) else { return }   // nil if the queue cannot be opened
if let url = launchURL { tracker.setDeepLink(url.absoluteString) }   // before the first view
try? tracker.trackView("home")
tracker.onBackground()      // hook to UIApplication.didEnterBackgroundNotification
try? tracker.close(3000)
```

Methods that return an error in Go are imported as throwing Swift methods
(`trackView`, `track`, `identify`, `flush`, `close`); the rest are plain calls.

### Deep links

Call `setDeepLink` with the URL the app was opened with before the first
`trackView` of the launch, and again whenever a URL arrives while the app is
running. The next event carries it as `ref`; see the changelog for the session
rules.

Scene-based apps (`SceneDelegate`):

```swift
func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
           options connectionOptions: UIScene.ConnectionOptions) {
    if let url = connectionOptions.urlContexts.first?.url
        ?? connectionOptions.userActivities.first?.webpageURL {
        tracker.setDeepLink(url.absoluteString)
    }
    try? tracker.trackView("home")
}

func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    URLContexts.first.map { tracker.setDeepLink($0.url.absoluteString) }
}

func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    userActivity.webpageURL.map { tracker.setDeepLink($0.absoluteString) }
}
```

`AppDelegate`-only apps:

```swift
func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    if let url = launchOptions?[.url] as? URL {
        tracker.setDeepLink(url.absoluteString)
    }
    try? tracker.trackView("home")
    return true
}

func application(_ app: UIApplication, open url: URL,
                 options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    tracker.setDeepLink(url.absoluteString)
    return true
}

func application(_ application: UIApplication, continue userActivity: NSUserActivity,
                 restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    userActivity.webpageURL.map { tracker.setDeepLink($0.absoluteString) }
    return true
}
```

SwiftUI:

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in tracker.setDeepLink(url.absoluteString) }
        }
    }
}
```

## API

| Method                                  | Purpose                                                         |
|-----------------------------------------|-----------------------------------------------------------------|
| `TrackView(screen)`                     | screen view; also starts the visibility timer                   |
| `TrackClose(screen, seconds)`           | screen/app close with visibility time                           |
| `TrackHide(screen, seconds)`            | screen/app backgrounded with visibility time                    |
| `TrackHideAuto()`                       | hide for the current screen, visibility time computed           |
| `Identify(otp)`                         | identity sync event                                             |
| `NewEvent(type)` + `Track(event)`       | full control, incl. `cp1`–`cp7` custom parameters               |
| `SetScreen(name)` / `CurrentScreen()`   | track the screen without emitting an event                      |
| `SetUserID(uid)` / `UserID()`           | the `uid` parameter                                             |
| `SessionID()` / `ResetSession()`        | current session; force a new one (e.g. on logout)               |
| `SetDeepLink(uri)` / `DeepLink()`       | URI the app was opened with; sent as `ref` on the next event    |
| `SessionOrigin()`                       | `ref` of the current session's first event                      |
| `OTP()`                                 | MyGaru token held by auto identification, if any                |
| `InstallID()`                           | stable pseudonymous installation id                             |
| `OnForeground()` / `OnBackground()`     | lifecycle hooks                                                 |
| `FlushAsync()` / `Flush(timeoutMillis)` | trigger delivery; the blocking form waits and reports leftovers |
| `PendingCount()` / `Stats()`            | diagnostics                                                     |
| `Close(timeoutMillis)`                  | final flush, then release the database                          |

Only `Flush` and `Close` block; everything else returns immediately and does no
network or disk I/O on the calling thread. All methods are safe to call from any
thread.

## Configuration

`NewConfig(appUUID, databasePath)` fills in the defaults below; override the
fields you need. `DatabasePath` must be in the app's private storage
(`context.getFilesDir()` / Application Support).

| Field                                      | Default                        | Notes                                                  |
|--------------------------------------------|--------------------------------|--------------------------------------------------------|
| `Endpoint`                                 | `https://a.nexinsight.com.ua/` | must be an absolute http(s) URL                        |
| `BatchEndpoint`                            | `Endpoint` path + `batch`      | override for a proxy with its own routing              |
| `UserAgent`                                | synthesised                    | pass the platform WebView UA when possible             |
| `UserAgentSuffix`                          | from `AppName`/`AppVersion`    | appended verbatim                                      |
| `OSName`, `OSVersion`, `DeviceModel`       | empty                          | used to synthesise the UA and platform version         |
| `SessionTimeoutSeconds`                    | `1800`                         | inactivity window before a new session                 |
| `BatchSize`                                | `50`                           | events picked up per delivery cycle                    |
| `MaxBatchEvents`                           | `50`                           | events per batch request, capped at `100`              |
| `UseBatchEndpoint`                         | on                             | `DisableBatchEndpoint()` sends one per request         |
| `CompressBatchThresholdBytes`              | `1024`                         | `0` disables gzip                                      |
| `FlushIntervalSeconds`                     | `15`                           | background delivery cadence                            |
| `IngestBufferSize`                         | `512`                          | in-memory hand-off capacity                            |
| `MaxQueueSize`                             | `10000`                        | oldest events dropped past the cap                     |
| `MaxAttempts`                              | `12`                           | `0` means retry until `MaxEventAgeSeconds`             |
| `BaseBackoffSeconds` / `MaxBackoffSeconds` | `2` / `300`                    | exponential, ±20% jitter                               |
| `MaxEventAgeSeconds`                       | `86400` (24 hours)             | the collector's own event time window; `0` disables it |
| `RequestTimeoutSeconds`                    | `15`                           | per HTTP attempt                                       |
| `MaxViewabilityTime`                       | `1800`                         | matches the collector's own limit                      |
| `SendEventTime`                            | on                             | `DisableEventTime()` turns it off                      |
| `Debug`, `DebugKey`, `DevKey`              | off                            | collector debug/dev mode                               |
| `UserID`, `SendInstallIDAsUID`             | empty, off                     | see below                                              |
| `AutoHideOnBackground`                     | on                             | `DisableAutoHideOnBackground()` turns it off           |
| `DeepLinkStartsNewSession`                 | on                             | `DisableDeepLinkSessionRotation()` turns it off        |
| `AutoIdentify`                             | on                             | `DisableAutoIdentify()` turns it off                   |
| `MyGaruPartnerID`                          | collector's partner id         | `p` parameter of the identification request            |
| `MyGaruIdentURL`                           | `https://ident.mygaru.com/v2/id` | must be an absolute http(s) URL; override for staging |
| `IdentifyTimeoutSeconds`                   | `5`                            | bound of one token fetch                               |
| `IdentifyAfterIdleSeconds`                 | `600`                          | idle gap after which a fresh token is fetched; `0` disables |

## Behaviour worth knowing

**Sessions.** The session id is generated on device and rotates after
`SessionTimeoutSeconds` of inactivity, including inactivity while the app was
not running — it is persisted, so a relaunch inside the window continues the
same session. A queued event keeps the session it was tracked in, even if it is
delivered days later.

**Delivery order.** Events are delivered in insertion order — within a batch, and
across the batches a delivery cycle sends — because the collector keeps
per-session last-event timestamps and a `close` arriving before its `view` would
distort the session.

**Drops.** Events are discarded only when the collector rejects them permanently
(`400`, or an individual rejection inside a batch), the attempt budget is spent,
they exceed `MaxEventAgeSeconds`, the queue is over `MaxQueueSize` (oldest
first), or the ingest buffer overflows because the writer cannot keep up. Every
drop increments `Stats().Dropped` and, if a logger is attached, is logged.
A tracker that is temporarily disabled server-side is retried, not dropped,
whether that arrives as a `423` or as a per-event rejection in a batch.

**Event time.** Each event reports when it happened on the device (`et`), so an
event queued offline keeps its own timestamp instead of being recorded with its
delivery time. The collector only accepts event times within its own window (24
hours back, five minutes forward), which is why `MaxEventAgeSeconds` defaults to
the same 24 hours — an older event would be rejected anyway.

A device with a badly wrong clock would have every event refused on its
timestamp. Those events are kept rather than dropped, and after a handful of
fresh events are refused the SDK stops sending `et` for the rest of the process:
a wrong clock then costs the on-device timestamp instead of the whole event
stream. `DisableEventTime()` makes that the starting point.

**Install id.** `InstallID()` is a random, persisted, pseudonymous id. It is
never sent unless `SendInstallIDAsUID` is enabled, and an explicit `SetUserID`
always wins over it.

## Changelog

### 0.2.0

**Deep links.** `setDeepLink(uri)` records the URI the app was opened with
(open-URL or universal link). The next event carries it as `ref` instead of the
previous screen, so the collector records it as the session origin. Exactly one
event carries it. Because the collector locks a session's origin from its first
event, a deep link that arrives after the current session already sent an event
starts a new session; disable this with `disableDeepLinkSessionRotation()` to
keep the session and still send the link as `ref`. Empty or blank URIs are
ignored. New accessors: `deepLink()` returns the link still waiting to be sent,
`sessionOrigin()` returns the `ref` of the current session's first event.

Call it before the first `trackView` of the launch, and again whenever the app
receives a URL while running; see [Deep links](#deep-links) for examples.

**Automatic MyGaru identification.** Enabled by default. The SDK fetches a
MyGaru one-time token in the background and attaches it once as `otp` to the
next regular event (`view`/`close`/`hide`); no `ident` event is emitted. Fetches
happen on tracker start, on every session rotation (inactivity, `resetSession`,
deep link) and when an event or `onForeground` follows more than
`identifyAfterIdleSeconds` of inactivity. The fetch never blocks the caller, is
bounded by `identifyTimeoutSeconds`, and is cancelled by `close`. The token lives
in memory only. A failure is logged once and events simply carry no `otp`; this
is typical over Wi-Fi, where the endpoint lacks carrier data. An explicit
`Event.setOTP` wins for that event, and `identify(otp)` remains the manual
route. `otp()` returns the token currently held. Opt out with
`cfg.disableAutoIdentify()` before creating the tracker.

New `Config` fields: `deepLinkStartsNewSession`, `autoIdentify`,
`myGaruPartnerID`, `myGaruIdentURL`, `identifyTimeoutSeconds`,
`identifyAfterIdleSeconds` (see Configuration above).

**Session origin persistence.** Whether the current session already has an
origin is now persisted, so a restart within the session window does not forget
it.