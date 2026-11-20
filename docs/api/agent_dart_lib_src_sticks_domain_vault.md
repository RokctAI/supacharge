# API Reference: vault

Source file: `agent/dart/lib/src/sticks/domain/vault.dart`

## Classes

### class `VaultProblem`

A value the server would turn down, said in plain words.

### class `VaultDraft`

One item to add: its kind, a title the owner knows it by, the website
it is for (logins and keys), and the field values from [vaultInputs].

## Whitelisted API Endpoints

### `vaultKindWords(VaultKind k)`

*No documentation provided (generation failed).*

### `VaultProblem(this.message)`

*No documentation provided (generation failed).*

### `toString()`

*No documentation provided (generation failed).*

### `vaultInputs(VaultKind k)`

The fields each kind asks for, in order. The same fields answer a
Stick's card or address ask in a chat.

### `cardValue(List<String> v, {int? thisYear})`

A card as the server stores it, from the fields of [vaultInputs] in
order. Throws [VaultProblem] when the server would turn it down.

### `at(int i)`

*No documentation provided (generation failed).*

### `contactValue(List<String> v)`

An address as the server stores it, from the fields of [vaultInputs] in
order; at least one must be filled.

### `vaultSite(String typed)`

A website as the server keeps it: a bare "sars.gov.za" becomes
"https://sars.gov.za"; a pasted page address is kept for the server to
reduce to its site.

### `VaultDraft`

```dart
const VaultDraft({
  required this.kind,
  this.title = '',
  this.site = '',
  this.values = const [],
})
```

*No documentation provided (generation failed).*

### `check()`

Throws [VaultProblem] when something is missing or wrong.
