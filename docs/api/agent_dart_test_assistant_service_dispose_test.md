# API Reference: assistant_service_dispose_test

Source file: `agent/dart/test/assistant_service_dispose_test.dart`

## Whitelisted API Endpoints

### `noSuchMethod(Invocation invocation)`

*No documentation provided (generation failed).*

### `main()`

AssistantService.dispose must not close the chat controllers it was
handed: they belong to the host's comms transport, and closing them
broke every other listener and any later service bound to them.
