# API Reference: sticks_markdown

Source file: `agent/dart/lib/src/sticks/presentation/sticks_markdown.dart`

## Classes

### class `SticksMarkdown`

Shows a Markdown file the way it is meant to read (Ray, 2026-11-08: "If
a file is MD can't we give ability to open it formated?"): headings,
bold, italics, strikethrough, code (with a copy button), lists, quotes,
rules and tables. Links, web and email addresses and phone numbers can
be tapped. Anything it doesn't know shows as plain text.

## Whitelisted API Endpoints

### `SticksMarkdown`

```dart
const SticksMarkdown(
  this.text,
  {super.key, this.fontSize = 14, this.selectable = true, this.keepLineBreaks =
      false, this.onSelected, this.onPath}
)
```

*No documentation provided (generation failed).*

### `plainText(String text)`

The words of [text] without the Markdown marks, as they read on screen:
for reading aloud, copying the words and quoting.

### `isMarkdown(String name, String type)`

Whether a file is Markdown, by its name or type.

### `build(BuildContext context)`

*No documentation provided (generation failed).*

### `flush()`

*No documentation provided (generation failed).*

### `cells(String l)`

*No documentation provided (generation failed).*

### `row(List<String> c, {bool bold = false})`

*No documentation provided (generation failed).*

### `inlineForTest(String s, {ValueChanged<String>? onPath})`

[_inline] for tests.
