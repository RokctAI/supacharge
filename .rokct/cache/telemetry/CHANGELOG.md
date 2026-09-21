# Changelog

## 1.0.0

* Bootstrap `telemetry_sdk` as a real composable package (the directory was a `.gitignore`-only placeholder). It is the delivery-policy owner for the telemetry lane: `TelemetrySdkDependencies.register` (called from the composed shell's generated sdk-di block) applies `TelemetryBootstrap.configure()`, the formal owner of base_sdk's new `TelemetryClient.configure`/`TelemetryTransport` injection seam. No client, pages, routes, or HTTP of its own — base_sdk's `TelemetryClient` remains the single client, and the default policy keeps its platform-gateway delivery unchanged.
