# NexInsightCore (iOS)

## Installation

The pod lives in a private spec repo, so add that source alongside the CDN in
your `Podfile`:

```ruby
source 'git@gitlab.adtelligent.com:nexinsight/sdk/podspecs.git'
source 'https://cdn.cocoapods.org/'

platform :ios, '13.0'

target 'MyApp' do
  pod 'NexInsightCore', '~> 0.1'
end
```

Then run `pod install`. The first time on a machine, register the spec repo:

```sh
pod repo add nexinsight-specs git@gitlab.adtelligent.com:nexinsight/sdk/podspecs.git
```

The pod ships a static `xcframework` (device `arm64`, simulator
`arm64`/`x86_64`) and links `libsqlite3` for you.

## Usage

### Swift (iOS)

```swift
import NexInsightCore

let dbPath = FileManager.default
    .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("nexinsight.db").path

let cfg = EventsdkConfig("APP-UUID", databasePath: dbPath)!
cfg.setDeviceInfo("iOS", osVersion: UIDevice.current.systemVersion, deviceModel: deviceModel())
cfg.setAppInfo("MyApp", version: appVersion, build: appBuild)
cfg.flushIntervalSeconds = 15

guard let tracker = EventsdkTracker(cfg) else { return }   // nil if the queue cannot be opened
try? tracker.trackView("home")
tracker.onBackground()      // hook to UIApplication.didEnterBackgroundNotification
try? tracker.close(3000)
```

Methods that return an error in Go are imported as throwing Swift methods
(`trackView`, `track`, `identify`, `flush`, `close`); the rest are plain calls.


## API

| Method                                  | Purpose                                                        |
|-----------------------------------------|----------------------------------------------------------------|
| `TrackView(screen)`                     | screen view; also starts the visibility timer                   |
| `TrackClose(screen, seconds)`           | screen/app close with visibility time                           |
| `TrackHide(screen, seconds)`            | screen/app backgrounded with visibility time                    |
| `TrackHideAuto()`                       | hide for the current screen, visibility time computed           |
| `Identify(otp)`                         | identity sync event                                             |
| `NewEvent(type)` + `Track(event)`        | full control, incl. `cp1`–`cp7` custom parameters               |
| `SetScreen(name)` / `CurrentScreen()`   | track the screen without emitting an event                      |
| `SetUserID(uid)` / `UserID()`           | the `uid` parameter                                             |
| `SessionID()` / `ResetSession()`        | current session; force a new one (e.g. on logout)               |
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

| Field                                        | Default                        | Notes                                            |
|----------------------------------------------|--------------------------------|--------------------------------------------------|
| `Endpoint`                                   | `https://a.nexinsight.com.ua/` | must be an absolute http(s) URL                  |
| `BatchEndpoint`                              | `Endpoint` path + `batch`      | override for a proxy with its own routing        |
| `UserAgent`                                  | synthesised                    | pass the platform WebView UA when possible       |
| `UserAgentSuffix`                            | from `AppName`/`AppVersion`    | appended verbatim                                |
| `OSName`, `OSVersion`, `DeviceModel`         | empty                          | used to synthesise the UA and platform version   |
| `SessionTimeoutSeconds`                      | `1800`                         | inactivity window before a new session           |
| `BatchSize`                                  | `50`                           | events picked up per delivery cycle              |
| `MaxBatchEvents`                             | `50`                           | events per batch request, capped at `100`        |
| `UseBatchEndpoint`                           | on                             | `DisableBatchEndpoint()` sends one per request   |
| `CompressBatchThresholdBytes`                | `1024`                         | `0` disables gzip                                |
| `FlushIntervalSeconds`                       | `15`                           | background delivery cadence                      |
| `IngestBufferSize`                           | `512`                          | in-memory hand-off capacity                      |
| `MaxQueueSize`                               | `10000`                        | oldest events dropped past the cap               |
| `MaxAttempts`                                | `12`                           | `0` means retry until `MaxEventAgeSeconds`        |
| `BaseBackoffSeconds` / `MaxBackoffSeconds`   | `2` / `300`                    | exponential, ±20% jitter                         |
| `MaxEventAgeSeconds`                         | `86400` (24 hours)             | the collector's own event time window; `0` disables it |
| `RequestTimeoutSeconds`                      | `15`                           | per HTTP attempt                                 |
| `MaxViewabilityTime`                         | `1800`                         | matches the collector's own limit                |
| `SendEventTime`                              | on                             | `DisableEventTime()` turns it off                |
| `Debug`, `DebugKey`, `DevKey`                | off                            | collector debug/dev mode                         |
| `UserID`, `SendInstallIDAsUID`               | empty, off                     | see below                                        |
| `AutoHideOnBackground`                       | on                             | `DisableAutoHideOnBackground()` turns it off      |

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