# API Reference: remote_sign_in

Source file: `agent/dart/lib/src/sticks/presentation/screens/remote_sign_in.dart`

## Classes

### class `RemoteSignInGate`

Shows [child] once [client] has a session; until then an email and
password form that signs in to the remote server.
A host with its own login screen passes [onSignedOut]: then there is no
form here, and the host's login is opened instead whenever the session
is missing or ends.

## Whitelisted API Endpoints

### `RemoteSignInGate`

```dart
const RemoteSignInGate({
  super.key,
  required this.client,
  required this.child,
  this.onSignedOut,
})
```

*No documentation provided (generation failed).*

### `createState()`

*No documentation provided (generation failed).*

### `dispose()`

*No documentation provided (generation failed).*

### `initState()`

*No documentation provided (generation failed).*

### `build(BuildContext context)`

*No documentation provided (generation failed).*
