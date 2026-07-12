"""Post-compose step for the refork SDK set. Run from the app root after
sdk_composer.py, before the host's build_runner.

Injects every cached SDK's manifest-declared Drift tables into the cached
base_sdk AppDatabase (@sdk-database-* markers; the cache copy is fully
editable by design) and reruns codegen inside cached base so the drift
accessors exist before the host app compiles.

Note: this used to also generate a `core_sdk` compatibility shim in
.rokct/cache/core for productivity_sdk, which still depended on the retired
core_sdk. productivity_sdk has since been repointed to depend on base_sdk
directly (2026-07-13), so the shim is no longer needed and was removed here.
If a future untouched SDK is found still importing package:core_sdk/...,
repoint that SDK's own pubspec/imports to base_sdk rather than reintroducing
the shim.
"""
import json
import os
import re
import subprocess
import sys

CACHE = os.path.join(os.getcwd(), ".rokct", "cache")
DB = os.path.join(CACHE, "base", "lib", "src", "database", "app_database.dart")

# ---- table injection ----
imports, tables, steps, max_ver = set(), [], [], 1
for name in sorted(os.listdir(CACHE)):
    mp = os.path.join(CACHE, name, "manifest.json")
    if not os.path.exists(mp):
        continue
    m = json.load(open(mp, encoding="utf-8-sig"))
    db = m.get("database")
    if not db:
        continue
    for t in db.get("tables", []):
        if t.get("import"):
            imports.add("import '%s';" % t["import"])
        if t.get("class"):
            tables.append("    %s," % t["class"])
    mig = db.get("migration", {})
    if mig.get("step"):
        steps.append("        " + mig["step"])
        try:
            max_ver = max(max_ver, int(mig.get("version", 1)))
        except Exception:
            pass

# cached base must resolve the table-owning SDK packages for its own codegen
pkgs = sorted({i.split("package:")[1].split("/")[0] for i in imports})
pub = os.path.join(CACHE, "base", "pubspec.yaml")
pt = open(pub, encoding="utf-8-sig").read()
adds = []
for pkg in pkgs:
    clean = pkg[:-4] if pkg.endswith("_sdk") else pkg
    if ("  %s:" % pkg) not in pt and os.path.isdir(os.path.join(CACHE, clean)):
        adds.append("  %s:\n    path: ../%s\n" % (pkg, clean))
if adds:
    pt = pt.replace("dependencies:\n", "dependencies:\n" + "".join(adds), 1)
if "dependency_overrides:" not in pt:
    # arbitrate version drift between kernel pins and newer untouched SDKs
    pt += ("\ndependency_overrides:\n"
           "  get_it: ^8.0.0\n"
           "  intl: ^0.20.2\n"
           "  share_plus: ^12.0.1\n"
           "  freezed_annotation: ^2.4.4\n"
           "  google_fonts: ^6.3.0\n"
           "  http: ^1.2.0\n"
           "  sqlite3: 2.9.4\n")
open(pub, "w", encoding="utf-8", newline="\n").write(pt)
print("[*] cached base pubspec updated (path deps + overrides):", pkgs)

t = open(DB, encoding="utf-8-sig").read()
already = tables and (tables[0] + "\n") in t
if already:
    print("[*] tables already injected; skipping marker patch")
else:
    t = t.replace("// @sdk-database-table-imports",
                  "// @sdk-database-table-imports\n" + "\n".join(sorted(imports)))
    t = t.replace("    // @sdk-database-tables",
                  "\n".join(tables) + "\n    // @sdk-database-tables")
    t = t.replace("        // @sdk-database-migrations",
                  "\n".join(steps) + "\n        // @sdk-database-migrations")
    t = re.sub(r"int get schemaVersion => \d+;",
               "int get schemaVersion => %d;" % max_ver, t)
    open(DB, "w", encoding="utf-8", newline="\n").write(t)
    print("[*] injected %d tables from SDK manifests, schemaVersion=%d"
          % (len(tables), max_ver))

base_dir = os.path.join(CACHE, "base")
subprocess.run(["flutter", "pub", "get"], cwd=base_dir, shell=True, check=True)
r = subprocess.run(["dart", "run", "build_runner", "build",
                    "--delete-conflicting-outputs"], cwd=base_dir, shell=True)
sys.exit(r.returncode)
