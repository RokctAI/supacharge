# supacharge

A new Flutter project.

## App tour

Live lessons, tutors, practice and partner reporting — captured straight
from the app.

| Welcome | Schedule | Subjects |
| :---: | :---: | :---: |
| ![Welcome screen][s01] | ![Schedule screen][s06] | ![Subjects][s07] |
| **Tutors** | **Library** | **Practice** |
| ![Tutors screen][s08] | ![Library screen][s09] | ![Practice][s10] |
| **Streak & League** | **Partner dashboard** | |
| ![League screen][s11] | ![Partner dashboard][s14] | |

The full tour lives in the [feature guide](marketing/tour/feature-guide.md),
with walkthrough videos alongside it in [`marketing/tour/`](marketing/tour).

[s01]: marketing/tour/screenshots/01-welcome.png
[s06]: marketing/tour/screenshots/06-schedule.png
[s07]: marketing/tour/screenshots/07-courses.png
[s08]: marketing/tour/screenshots/08-tutors.png
[s09]: marketing/tour/screenshots/09-library.png
[s10]: marketing/tour/screenshots/10-practice.png
[s11]: marketing/tour/screenshots/11-league.png
[s14]: marketing/tour/screenshots/14-partner_dashboard.png

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

<!-- @generated-recompose-start -->
## Recomposing this app

`lib/` is fully installer-generated and disposable - it is safe to delete
and is gitignored. Anything app-specific lives in tracked manifests
(`app_routes`, or `host_routes` in `composer.json`), never in `lib/` itself.

To regenerate it:

```sh
python3 .rokct/initiate.py   # provisions the composer under .rokct/skills/
python3 .rokct/skills/.rok/flutter/scripts/compose.py
```

Session cleanup (`python3 .rokct/end_protocol.py`) wipes the provisioned
tools again.
<!-- @generated-recompose-end -->
