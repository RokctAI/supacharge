## 1.2.0

* **`/term` and `/policy` are routes again.** The pre-fork `paas_customer`
  router served TermPage/PolicyPage at those paths (customer route map
  rows 41-42); after the fork only auth's login footer could reach them,
  through `EmbeddedWidgets.I.termPage()/policyPage()`. The manifest now
  declares both routes at top level (no flavour blocks; the legal pages
  are right in every persona), importing the new
  `templates/routes/corporate_route_pages.dart` shell that the manifest
  installs into the host's `lib/presentation/routes/` — the ADR-005 shape
  auth_sdk's `auth_route_pages.dart` uses, because a composed app's
  auto_route codegen only generates route classes for `@RoutePage`
  widgets in the host's own `lib/`. Path strings are the pre-fork ones so
  deep links and push payloads keep working. The embedded-widget seam is
  untouched.
* No `app_routes` entry: `AppRoutes` declares no seam method for either
  page and no caller pushes by path today; add one when a caller wants it.
* New `test/manifest_wiring_test.dart` (radio pattern) pins the
  routes <-> `@RoutePage(name:)` shell <-> installs triangle and the
  `termPage`/`policyPage` embedded widgets.

## 1.1.4

* **Opening a blog now reaches the server.** `BlogsRepository.getBlogDetails`
  sent `{'uuid': ...}` to `api.blog.get_blog`, whose signature is
  `get_blog(name)` (base `tenant/api/blog/blog.py`, an alias of
  `get_blog_details` → `frappe.get_doc("Blog", name).as_dict()`). Frappe
  drops unknown kwargs silently, so every open raised "missing argument:
  name". The payload key is now `name`; the facade keeps its `uuid`
  parameter so callers are untouched.
* **The list rows now carry that docname.** The `Blog` doctype has no
  `uuid` field — `get_blogs` answers rows keyed by `name` — while
  base_sdk's `BlogData.fromJson` still reads the pre-fork Laravel key
  `uuid`, so every list row had a null `uuid` and the details call was
  handed nothing. `BlogsRepository.withBlogDocnames` mirrors `name` into
  the `uuid` slot on list rows and on the details `data` map (rows already
  carrying a `uuid` are left alone; any other shape passes through).
* New `test/blogs_repository_payload_test.dart` (first test in this
  package): a network-free `HttpService` stub pins the gateway path, the
  `api.blog.get_blog` / `api.blog.get_blogs` cmds, the `name` payload key
  (and the absence of `uuid`), and the docname mirror.
* `get_it` is now a declared dependency (`corporate_di.dart` already
  imported it, reaching it only transitively through base_sdk); `dio` is a
  dev dependency for the stub.
