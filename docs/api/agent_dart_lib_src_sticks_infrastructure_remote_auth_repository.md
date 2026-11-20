# API Reference: remote_auth_repository

Source file: `agent/dart/lib/src/sticks/infrastructure/remote_auth_repository.dart`

## Classes

### class `RemoteAuthRepository`

The app's normal login screen, signing in to a remote Sticks server
instead of the platform: email and password go to the server's own
sign-in, and its session token becomes the app's token, so the Sticks
screens need no second sign-in.
Only email and password sign-in is on this server's side for now.
Signing up, Google and password reset answer with a plain message
pointing to the web app.
The session token expires: [RemoteClient] keeps the server's
`expiresAt` and drops the token once it has passed, and on any 401.

## Whitelisted API Endpoints

### `RemoteAuthRepository(this.client)`

*No documentation provided (generation failed).*

### `login({required String email, required String password})`

*No documentation provided (generation failed).*

### `sigUp({required String email})`

*No documentation provided (generation failed).*
