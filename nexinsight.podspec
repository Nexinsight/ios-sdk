Pod::Spec.new do |s|
  s.name     = 'nexinsight'
  s.version  = '0.1.0'
  s.summary  = 'NexInsight analytics event SDK for iOS.'

  s.description = <<~DESC
    The iOS build of the NexInsight event SDK: a persistent,
    offline-tolerant queue for screen view, session and identity events that
    batches them and delivers them to the NexInsight collector.

    Events are written to a local SQLite queue and delivered in insertion order
    on a background cadence, so nothing is lost while the device is offline and
    each event keeps the timestamp of when it actually happened. Only `Flush`
    and `Close` block; every other call returns immediately and does no network
    or disk I/O on the calling thread.
  DESC

  s.homepage = 'https://gitlab.adtelligent.com/nexinsight/sdk/ios'
  s.author   = { 'Adtelligent' => 'a.budyak@adtelligent.com' }
  s.license  = {
    :type => 'Commercial',
    :text => 'Copyright (c) Adtelligent. All rights reserved. ' \
             'Use of this software is subject to the NexInsight license agreement.',
  }

  s.source = {
    :git => 'git@gitlab.adtelligent.com:nexinsight/sdk/ios.git',
    :tag => s.version.to_s,
  }

  # The binary reports minos 13.0 for both the device and the simulator slice.
  # (The framework's own Info.plist claims MinimumOSVersion 100.0 — a gomobile
  # artefact; it is inert because the framework is static and never embedded.)
  s.ios.deployment_target = '13.0'

  s.vendored_frameworks = 'NexInsightCore.xcframework'

  # The module name is baked into the xcframework by gomobile and does not
  # follow the pod name: consumers depend on `nexinsight` but write
  # `import NexInsightCore`. Declaring it keeps CocoaPods' import validation
  # honest about which module this pod actually exposes.
  s.module_name = 'NexInsightCore'

  # gomobile emits a static framework, so the consumer's link step has to
  # resolve the framework's own externals. CFNetwork/CoreFoundation/Foundation/
  # Security are auto-linked via LC_LINKER_OPTION and listed here only to be
  # explicit; sqlite3 carries no such hint and must be declared, otherwise the
  # app fails to link with ~77 undefined _sqlite3_* symbols.
  s.frameworks = 'CFNetwork', 'CoreFoundation', 'Foundation', 'Security'
  s.libraries  = 'sqlite3'
end
