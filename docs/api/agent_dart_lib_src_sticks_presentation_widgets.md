# API Reference: widgets

Source file: `agent/dart/lib/src/sticks/presentation/widgets.dart`

## Classes

### class `SticksBack`

The back control at the top of a page: a round arrow and the place it
goes back to, sized to sit with the page titles rather than as a small
grey link.

### class `SticksStatusTint`

The colour drawn behind the status bar, so a page whose top is a tinted
band runs edge to edge. [SticksPage] provides it; [SticksBandBackground]
sets it while it is on screen.

### class `StickTop`

A screen's title block: optional back link, heading, one soft line.

### class `StickRing`

A Stick's head on a disc tinted with its colour; [live] adds the solid
ring of a Stick at work, [faded] greys out one that is off duty.

### class `SticksCard`

### class `SticksButton`

### class `SticksTag`

A small uppercase label with a Remixicon glyph: what kind of page this is.

### class `SticksSlip`

A paper slip with an ink edge and a hard drop: the thing on the desk the
owner is being asked about (a draft, a request, a new task).

### class `SticksBandPainter`

Paints a band: the tint fades to the solid page colour toward the bottom
edge, with a few thin low-contrast scene lines (a skyline and a desk) in a
darker shade of the band colour. Subtle on purpose; the Stick stands on top.

### class `SticksBandBackground`

A band background that fades into the page colour. While it is on screen
the status bar above it takes the band's colour ([SticksStatusTint]), so
the page runs edge to edge.

### class `SticksStage`

The profile-style band at the top of a page: tinted with a Stick's colour,
the Stick standing on its bottom edge, a back link, a tag and a title.

### class `SticksIconLine`

One soft line with a Remixicon glyph in front.

### class `SticksChip`

### class `SticksBar`

### class `SticksSectionLabel`

### class `SticksFuture`

A screen body with a loading and an error state, so no screen shows a
blank page while the data source answers.

### class `CoveredSheet`

A sheet that rises over a Stick, so only the head peeks above it.

### class `Party`

Who a message is from or to: a Stick, the owner, or reception.

### class `OwnerAvatar`

The owner as the profile page's user card draws them: their picture,
else their initials, else a person glyph (never a "Y" for "You").

### class `BubblePoint`

The little point on a chat bubble, toward its sender's head, drawn as
the guide's arrow is.

### class `PartyAvatar`

A round head for a [Party]: the Stick's head, or a plain disc for the owner.

### class `LivingStickFigure`

A Stick's whole body, gently breathing and swaying from its feet. Still
where the system asks for less motion.

### class `SticksShimmer`

What a page shows while it loads: grey shapes of what is coming, with
a light sweeping across them, in place of a spinner. The same shimmer
package and colours as the marketplace home, so every app matches.
[chat] draws message bubbles (left and right) instead of list rows.

### class `SticksLive`

Builds [builder] again when the app comes back to the front, so an open
Tasks, Asks or Reports page shows what changed meanwhile. While it is in
front, the team check (already running, one small call) reloads the page
whenever a Stick changes; there is no timed reload of its own, to save
data (Ray, 2026-11-11).

## Whitelisted API Endpoints

### `sticksHead(BuildContext context, double size, {Color? color})`

*No documentation provided (generation failed).*

### `TextStyle`

```dart
TextStyle(
  fontFamily: sticksHeadFamily,
  package: sticksFontPackage,
  fontSize: size,
  fontWeight: FontWeight.w900,
  height: 1.1,
  color: color ?? StickPalette.of(context).ink
)
```

*No documentation provided (generation failed).*

### `sticksLabel(BuildContext context, double size, {Color? color})`

*No documentation provided (generation failed).*

### `TextStyle`

```dart
TextStyle(
  fontFamily: sticksHeadFamily,
  package: sticksFontPackage,
  fontSize: size,
  fontWeight: FontWeight.w800,
  color: color ?? StickPalette.of(context).ink
)
```

*No documentation provided (generation failed).*

### `sticksBody`

```dart
TextStyle sticksBody(
  BuildContext context,
  double size,
  {Color? color, FontWeight weight = FontWeight.w400, double? height}
)
```

Body text in Nunito. Plain `TextStyle`s on a Sticks page get Nunito from
[SticksPage]'s default style; this is for the ones that set a weight.

### `TextStyle`

```dart
TextStyle(
  fontFamily: sticksBodyFamily,
  package: sticksFontPackage,
  fontSize: size,
  fontWeight: weight,
  height: height,
  color: color ?? StickPalette.of(context).ink
)
```

*No documentation provided (generation failed).*

### `SticksBack(this.label, {super.key})`

*No documentation provided (generation failed).*

### `build(BuildContext context)`

*No documentation provided (generation failed).*

### `SticksStatusTint({super.key, required this.color, required super.child})`

*No documentation provided (generation failed).*

### `maybeOf(BuildContext context)`

*No documentation provided (generation failed).*

### `updateShouldNotify(SticksStatusTint old)`

*No documentation provided (generation failed).*

### `StickTop`

```dart
const StickTop({
  super.key,
  required this.title,
  this.sub,
  this.back,
  this.trailing,
})
```

*No documentation provided (generation failed).*

### `StickRing`

```dart
const StickRing({
  super.key,
  required this.stick,
  this.size = 56,
  this.live = false,
  this.faded = false,
  this.mood,
})
```

*No documentation provided (generation failed).*

### `SticksCard`

```dart
const SticksCard({
  super.key,
  required this.child,
  this.padding = const EdgeInsets.all(12),
  this.radius = 16,
})
```

*No documentation provided (generation failed).*

### `SticksButton`

```dart
const SticksButton(
  this.label,
  {super.key, this.onTap, this.filled = true, this.quiet = false, this.icon}
)
```

*No documentation provided (generation failed).*

### `SticksTag(this.icon, this.label, {super.key, this.color})`

*No documentation provided (generation failed).*

### `SticksSlip`

```dart
const SticksSlip({
  super.key,
  required this.child,
  this.padding = const EdgeInsets.all(14),
})
```

*No documentation provided (generation failed).*

### `SticksBandPainter`

```dart
const SticksBandPainter({
  required this.band,
  required this.paper,
  required this.dark,
})
```

*No documentation provided (generation failed).*

### `paint(Canvas canvas, Size size)`

*No documentation provided (generation failed).*

### `shouldRepaint(SticksBandPainter o)`

*No documentation provided (generation failed).*

### `SticksBandBackground`

```dart
const SticksBandBackground({
  super.key,
  required this.tint,
  required this.child,
  this.alpha,
})
```

*No documentation provided (generation failed).*

### `createState()`

*No documentation provided (generation failed).*

### `didChangeDependencies()`

*No documentation provided (generation failed).*

### `dispose()`

*No documentation provided (generation failed).*

### `SticksStage`

```dart
const SticksStage({
  super.key,
  required this.tint,
  required this.back,
  required this.title,
  this.tag,
  this.sub,
  this.figure,
  this.figureWidth = 104,
})
```

*No documentation provided (generation failed).*

### `SticksIconLine`

```dart
const SticksIconLine(
  this.icon,
  this.text,
  {super.key, this.color, this.size = 13}
)
```

*No documentation provided (generation failed).*

### `SticksChip(this.label, {super.key, this.on = false, this.onTap})`

*No documentation provided (generation failed).*

### `SticksBar(this.value, {super.key, this.color = StickPalette.working})`

*No documentation provided (generation failed).*

### `SticksSectionLabel(this.text, {super.key})`

*No documentation provided (generation failed).*

### `SticksFuture({super.key, required this.future, required this.builder})`

*No documentation provided (generation failed).*

### `CoveredSheet`

```dart
const CoveredSheet({
  super.key,
  required this.stick,
  required this.child,
  this.mood,
})
```

*No documentation provided (generation failed).*

### `Party(this.name, this.stick, {this.isOwner = false})`

*No documentation provided (generation failed).*

### `of(String id, List<Stick> team)`

*No documentation provided (generation failed).*

### `BubblePoint({super.key, required this.color, this.right = false})`

*No documentation provided (generation failed).*

### `shouldRepaint(_PointPainter old)`

*No documentation provided (generation failed).*

### `PartyAvatar(this.party, {super.key, this.size = 44})`

*No documentation provided (generation failed).*

### `clockTime(DateTime? t)`

*No documentation provided (generation failed).*

### `shortDate(DateTime? t)`

*No documentation provided (generation failed).*

### `dayMonth(DateTime? t)`

"31 Oct": a date without the time.

### `LivingStickFigure`

```dart
const LivingStickFigure({
  super.key,
  required this.look,
  this.mood = StickMood.neutral,
  this.dark,
  this.onTap,
})
```

*No documentation provided (generation failed).*

### `SticksShimmer`

```dart
const SticksShimmer({
  super.key,
  this.chat = false,
  this.rows = 7,
  this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
})
```

*No documentation provided (generation failed).*

### `box(double w, double h, {double r = 8})`

*No documentation provided (generation failed).*

### `Container`

```dart
Container(
  width: w,
  height: h,
  decoration: BoxDecoration(color: block, borderRadius:
      BorderRadius.circular(r))
)
```

*No documentation provided (generation failed).*

### `row(int i)`

*No documentation provided (generation failed).*

### `SticksLive({super.key, required this.builder})`

*No documentation provided (generation failed).*

### `initState()`

*No documentation provided (generation failed).*

### `didChangeAppLifecycleState(AppLifecycleState state)`

*No documentation provided (generation failed).*
