# supacharge

A new Flutter project.

<!-- @generated-store-description-start -->
<!-- @generated-store-description-end -->

<!-- @generated-tour-gallery-start -->
## App tour

Styled stills from the committed guided tour - regenerated on every
tour run, so new screens appear here automatically.

| Welcome | Auth Login | Auth Register |
| :---: | :---: | :---: |
| ![Welcome][s01] | ![Auth Login][s02] | ![Auth Register][s03] |
| **Grade Prompt** | **Schedule** | **Courses** |
| ![Grade Prompt][s05] | ![Schedule][s06] | ![Courses][s07] |
| **Tutors** | **Library** | **Practice** |
| ![Tutors][s08] | ![Library][s09] | ![Practice][s10] |
| **League** | **My Plan** | **Profile** |
| ![League][s11] | ![My Plan][s12] | ![Profile][s13] |
| **Partner Dashboard** | **Partner Add Student** | **Sponsor Reports** |
| ![Partner Dashboard][s14] | ![Add Student][s15] | ![Sponsor Reports][s16] |
| **Partner Profile** | **Admin Lesson Review** | **Admin Homework Queue** |
| ![Partner Profile][s17] | ![Lesson Review][s18] | ![Homework Queue][s19] |
| **Admin Announcements** | | |
| ![Admin Announcements][s20] | | |

The full tour lives in the [feature guide](marketing/tour/feature-guide.md),
with walkthrough videos alongside it in [`marketing/tour/`](marketing/tour).

[s01]: marketing/tour/store/01-welcome.png
[s02]: marketing/tour/store/02-auth_login.png
[s03]: marketing/tour/store/03-auth_register.png
[s05]: marketing/tour/store/05-grade_prompt.png
[s06]: marketing/tour/store/06-schedule.png
[s07]: marketing/tour/store/07-courses.png
[s08]: marketing/tour/store/08-tutors.png
[s09]: marketing/tour/store/09-library.png
[s10]: marketing/tour/store/10-practice.png
[s11]: marketing/tour/store/11-league.png
[s12]: marketing/tour/store/12-my_plan.png
[s13]: marketing/tour/store/13-profile.png
[s14]: marketing/tour/store/14-partner_dashboard.png
[s15]: marketing/tour/store/15-partner_add_student.png
[s16]: marketing/tour/store/16-partner_sponsor_reports.png
[s17]: marketing/tour/store/17-partner_profile.png
[s18]: marketing/tour/store/18-admin_lesson_review.png
[s19]: marketing/tour/store/19-admin_homework_queue.png
[s20]: marketing/tour/store/20-admin_announcements.png
<!-- @generated-tour-gallery-end -->

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
