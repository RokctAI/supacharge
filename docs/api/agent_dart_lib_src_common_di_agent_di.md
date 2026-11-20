# API Reference: agent_di

Source file: `agent/dart/lib/src/common/di/agent_di.dart`

## Classes

### class `AgentSdkDependencies`

## Whitelisted API Endpoints

### `register(GetIt getIt, [Dio? dio])`

Installer convention is `register(GetIt.instance)`; the authorized Dio
client defaults to base_sdk's [HttpService] (registered by
BaseSdkDependencies before any feature SDK). Pass [dio] explicitly only
in tests or non-standard hosts.
