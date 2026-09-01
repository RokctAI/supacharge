# supacharge

A new Flutter project.

<!-- @generated-store-description-start -->
<!-- @generated-store-description-end -->

<!-- @generated-tour-gallery-start -->
## App tour

Styled stills from the committed guided tour - regenerated on every
tour run, so new screens appear here automatically.

| Welcome | Grade Prompt | Schedule |
| :---: | :---: | :---: |
| ![Welcome][s01] | ![Grade Prompt][s05] | ![Schedule][s06] |
| **Courses** | **Tutors** | **Library** |
| ![Courses][s07] | ![Tutors][s08] | ![Library][s09] |
| **Practice** | **League** | **My Plan** |
| ![Practice][s10] | ![League][s11] | ![My Plan][s12] |
| **Profile** | **Partner Dashboard** | **Partner Add Student** |
| ![Profile][s13] | ![Partner Dashboard][s14] | ![Partner Add Student][s15] |
| **Partner Sponsor Reports** | **Partner Profile** | **Admin Lesson Review** |
| ![Sponsor Reports][s16] | ![Partner Profile][s17] | ![Lesson Review][s18] |
| **Admin Homework Queue** | **Admin Announcements** | **Wallet Topup** |
| ![Homework Queue][s19] | ![Admin Announcements][s20] | ![Wallet Topup][s21] |

The full tour lives in the [feature guide](marketing/tour/feature-guide.md),
with walkthrough videos alongside it in [`marketing/tour/`](marketing/tour).

[s01]: marketing/tour/store/01-welcome.png
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
[s21]: marketing/tour/store/21-wallet_topup.png
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
