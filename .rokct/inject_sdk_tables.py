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

# Drift 2.x modular analysis only understands table classes defined inside
# the package being generated: importing them across package boundaries
# yields "The referenced element ... is not understood by drift" and a
# silently EMPTY database. So the table-definition files (pure
# package:drift + Table classes by convention) are COPIED into the cached
# base package — exactly the kind of compose-time edit the editable cache
# exists for — and imported relatively.
injected_dir = os.path.join(CACHE, "base", "lib", "src", "database", "injected")
os.makedirs(injected_dir, exist_ok=True)
copied = {}  # source package path -> relative import
rel_imports = set()
for imp in sorted(imports):
    uri = imp.split("'")[1]                    # package:<pkg>/<path>
    pkg, rel = uri[len("package:"):].split("/", 1)
    clean = pkg[:-4] if pkg.endswith("_sdk") else pkg
    src = os.path.join(CACHE, clean, "lib", rel.replace("/", os.sep))
    if not os.path.exists(src):
        print("[!] table import source missing, skipping:", uri)
        continue
    dest_name = "%s__%s" % (pkg, os.path.basename(rel))
    dest = os.path.join(injected_dir, dest_name)
    if uri not in copied:
        content = open(src, encoding="utf-8-sig").read()
        open(dest, "w", encoding="utf-8", newline="\n").write(
            "// Copied at compose time from %s by inject_sdk_tables.py —\n"
            "// drift only understands table classes inside its own package.\n"
            % uri + content)
        copied[uri] = "injected/%s" % dest_name
    rel_imports.add("import '%s';" % copied[uri])
imports = rel_imports

pub = os.path.join(CACHE, "base", "pubspec.yaml")
pt = open(pub, encoding="utf-8-sig").read()
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
print("[*] cached base pubspec overrides ensured; %d table files copied in" % len(copied))

t = open(DB, encoding="utf-8-sig").read()
# Explicit sentinel: probing for a table name false-positives when a
# legitimate name already exists in the bare file.
already = "// @sdk-database-tables [injected]" in t
if already:
    print("[*] tables already injected; skipping marker patch")
else:
    t = t.replace("// @sdk-database-table-imports",
                  "// @sdk-database-table-imports\n" + "\n".join(sorted(imports)))
    t = t.replace("    // @sdk-database-tables",
                  "\n".join(tables) + "\n    // @sdk-database-tables [injected]")
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
if r.returncode != 0:
    sys.exit(r.returncode)

# Hard check: drift silently emits an EMPTY database when any injected table
# class fails to resolve (e.g. a table import pulling in a library with
# compile errors, or a phantom class name in a manifest). Host `flutter
# analyze` cannot see inside this dependency, so catch it here.
gen = DB.replace(".dart", ".g.dart")
gt = open(gen, encoding="utf-8-sig").read() if os.path.exists(gen) else ""
missing = [ln.strip().rstrip(",") for ln in tables
           if ln.strip().rstrip(",") not in gt]
if missing:
    print("[!] Drift codegen produced no accessors for: %s\n"
          "    (empty-database stub — check that each manifest database "
          "import points at a pure drift_tables file, not an SDK barrel)."
          % ", ".join(missing))
    sys.exit(1)
print("[+] Drift database generated with all %d injected tables." % len(tables))
