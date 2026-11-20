# API Reference: report_screen

Source file: `agent/dart/lib/src/sticks/presentation/screens/report_screen.dart`

## Classes

### class `ReportScreen`

The weekly report: what the team finished in the last seven days.

## Whitelisted API Endpoints

### `ReportScreen({super.key})`

*No documentation provided (generation failed).*

### `build(BuildContext context)`

Its tip shows the first time the tab is seen.

### `reportTitle(int? weekday)`

"This week" for a rolling week, else the chosen day's name, such as
"Friday report".

### `reportSpan(DateTime today)`

The seven days the report counts, ending on [today], in plain words:
"1 to 7 Nov", or "28 Oct to 3 Nov" across a month.
