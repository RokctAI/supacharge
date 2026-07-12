"""Post-compose step for the refork SDK set. Run from the app root after
sdk_composer.py, before the host's build_runner.

1. Ensures a `core_sdk` compatibility shim in .rokct/cache/core: the kernel
   was renamed to base_sdk, but untouched SDKs (productivity_sdk) still
   depend on `core_sdk` and import its barrel. The shim re-exports base_sdk.
2. Injects every cached SDK's manifest-declared Drift tables into the cached
   base_sdk AppDatabase (@sdk-database-* markers; the cache copy is fully
   editable by design) and reruns codegen inside cached base so the drift
   accessors exist before the host app compiles.
"""
import json
import os
import re
import subprocess
import sys

CACHE = os.path.join(os.getcwd(), ".rokct", "cache")
DB = os.path.join(CACHE, "base", "lib", "src", "database", "app_database.dart")

# ---- 1. core_sdk compat shim ----
shim = os.path.join(CACHE, "core")
os.makedirs(os.path.join(shim, "lib"), exist_ok=True)
with open(os.path.join(shim, "pubspec.yaml"), "w", encoding="utf-8", newline="\n") as f:
    f.write(
        "name: core_sdk\n"
        "description: Compatibility shim - core_sdk was retired; base_sdk is the kernel.\n"
        "version: 0.0.1\n"
        "publish_to: 'none'\n"
        "environment:\n"
        "  sdk: '>=3.5.0 <4.0.0'\n"
        "dependencies:\n"
        "  flutter:\n"
        "    sdk: flutter\n"
        "  base_sdk:\n"
        "    path: ../base\n"
    )
with open(os.path.join(shim, "lib", "core_sdk.dart"), "w", encoding="utf-8", newline="\n") as f:
    f.write(
        "// Compatibility shim: core_sdk was retired in the 2026-07 refork.\n"
        "// Untouched SDKs that still `import 'package:core_sdk/core_sdk.dart'`\n"
        "// get the base_sdk kernel surface until they are rebuilt.\n"
        "export 'package:base_sdk/base_sdk.dart';\n"
    )
print("[*] core_sdk compat shim ensured at .rokct/cache/core")

# ---- 2. table injection ----
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
    open(pub, "w", encoding="utf-8", newline="\n").write(pt)
    print("[*] added table-owning SDK path deps to cached base pubspec:", pkgs)

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
