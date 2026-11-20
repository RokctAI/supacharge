# API Reference: sticks_haptics

Source file: `agent/dart/lib/src/sticks/presentation/sticks_haptics.dart`

## Whitelisted API Endpoints

### `sticksBuzz(BuildContext context, {bool strong = false})`

A small buzz on a tap that does something (send, answer, switch tab,
open a message's menu), unless Profile > Advanced > Vibrate on tap is
off (Ray, 2026-11-11). Blind mode has its own buzzes and ignores this.
