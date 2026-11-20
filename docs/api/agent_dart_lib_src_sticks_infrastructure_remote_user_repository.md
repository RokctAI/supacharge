# API Reference: remote_user_repository

Source file: `agent/dart/lib/src/sticks/infrastructure/remote_user_repository.dart`

## Classes

### class `RemoteUserRepository`

The app's generic profile page, reading the person from a remote Sticks
server: the name and email in its user card come from the server's `me`,
the edit pencil renames them there, and Sign out ends that session.
The rest of the account surface (addresses, wallet, referrals) is not on
this server, so those calls answer with a plain failure the page hides.
While [client] gives no client (a demo or the guided tour), every call
goes to [fallback], the platform's own repository, as before.

## Whitelisted API Endpoints

### `RemoteUserRepository(this.client, {this.fallback})`

*No documentation provided (generation failed).*

### `profileFrom(Map<String, dynamic> me)`

The server's `me` as the platform's profile.

### `getProfileDetails()`

*No documentation provided (generation failed).*

### `editProfile({required EditProfile? user})`

*No documentation provided (generation failed).*

### `logoutAccount({required String fcm})`

*No documentation provided (generation failed).*

### `getReferralDetails()`

*No documentation provided (generation failed).*

### `deleteAccount()`

Deleting the account is done from the Sticks Account section.
