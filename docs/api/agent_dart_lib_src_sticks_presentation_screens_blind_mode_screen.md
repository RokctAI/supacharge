# API Reference: blind_mode_screen

Source file: `agent/dart/lib/src/sticks/presentation/screens/blind_mode_screen.dart`

## Classes

### class `BlindEars`

Turns speech into words for blind mode. The phone's own recognizer by
default; tests put in their own.

### class `PhoneEars`

### class `BlindModeScreen`

Blind mode (Ray, 2026-11-11): one Stick, no typing. The person using it
cannot see, so everything is said aloud and felt as buzzes; the screen
is for a sighted helper. Volume down talks (or cancels), volume up sends
(or repeats the last reply); holding both for three seconds leaves.
A tap anywhere also talks, so it works with TalkBack's double tap.

### class `BlindModeScreenState`

### class `BlindFace`

Just the face, as in the render: two eyes and a smile; a flat mouth
while listening or working; closed eyes asleep.

## Whitelisted API Endpoints

### `start(void Function(String words) heard)`

False when the phone cannot listen (no recognizer, microphone refused).

### `finish()`

Stops listening and gives back everything heard.

### `cancel()`

*No documentation provided (generation failed).*

### `BlindModeScreen({super.key, required this.stickId})`

*No documentation provided (generation failed).*

### `createState()`

*No documentation provided (generation failed).*

### `didChangeDependencies()`

*No documentation provided (generation failed).*

### `dispose()`

*No documentation provided (generation failed).*

### `talk()`

*No documentation provided (generation failed).*

### `send()`

*No documentation provided (generation failed).*

### `says(List<String> any)`

*No documentation provided (generation failed).*

### `repeat()`

*No documentation provided (generation failed).*

### `leave()`

*No documentation provided (generation failed).*

### `build(BuildContext context)`

*No documentation provided (generation failed).*

### `paint(Canvas c, Size z)`

*No documentation provided (generation failed).*

### `shouldRepaint(BlindFace old)`

*No documentation provided (generation failed).*
