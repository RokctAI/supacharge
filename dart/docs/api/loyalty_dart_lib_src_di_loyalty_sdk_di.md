# API Reference: loyalty_sdk_di

Source file: `loyalty/dart/lib/src/common/di/loyalty_sdk_di.dart`

## Classes

### class `LoyaltySdkDependencies`

## Whitelisted API Endpoints

### `register(GetIt getIt)`

Registers the offline default. Hosts backed by a loyalty service
register their own [LoyaltyRepositoryFacade] BEFORE calling this (an
existing registration is left untouched).
