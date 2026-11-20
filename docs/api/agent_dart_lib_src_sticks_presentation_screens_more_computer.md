# API Reference: more_computer

Source file: `agent/dart/lib/src/sticks/presentation/screens/more_computer.dart`

## Classes

### class `ComputerFilesScreen`

The files on a Stick's computer: open a folder, preview or save a file,
or put one of yours there.

## Whitelisted API Endpoints

### `createState()`

*No documentation provided (generation failed).*

### `initState()`

*No documentation provided (generation failed).*

### `didUpdateWidget(_TakeOver old)`

*No documentation provided (generation failed).*

### `dispose()`

*No documentation provided (generation failed).*

### `build(BuildContext context)`

*No documentation provided (generation failed).*

### `ComputerFilesScreen({super.key, required this.stickId})`

*No documentation provided (generation failed).*

### `openStickFile(BuildContext context, String stickId, String path)`

One file from the computer: a preview when it is text or a picture, and
Save a copy.
Opens [path] on a Stick's computer in a sheet. A stopped computer is
started first, as a file that is not text cannot be read from it asleep.

### `load()`

*No documentation provided (generation failed).*
