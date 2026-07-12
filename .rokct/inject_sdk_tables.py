
"""Inject SDK-declared Drift tables into the cached base_sdk AppDatabase.

Reads each cached SDK's manifest.json "database" section and patches
.rokct/cache/base/lib/src/database/app_database.dart at its
@sdk-database-* markers (the cache copy is fully editable by design),
then reruns build_runner inside the cached base package so the drift
accessors exist before the host app compiles.
"""
import json, os, re, subprocess, sys

CACHE = os.path.join(os.getcwd(), ".rokct", "cache")
DB = os.path.join(CACHE, "base", "lib", "src", "database", "app_database.dart")

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
adds = ""
for pkg in pkgs:
    clean = pkg[:-4] if pkg.endswith("_sdk") else pkg
    if ("  %s:" % pkg) not in pt and os.path.isdir(os.path.join(CACHE, clean)):
        adds += "  %s:
    path: ../%s
" % (pkg, clean)
if adds:
    pt = pt.replace("dependencies:
", "dependencies:
" + adds, 1)
    open(pub, "w", encoding="utf-8", newline="
").write(pt)
    print("[*] added table-owning SDK path deps to cached base pubspec:", pkgs)

t = open(DB, encoding="utf-8-sig").read()
t = t.replace("// @sdk-database-table-imports",
              "// @sdk-database-table-imports\n" + "\n".join(sorted(imports)))
t = t.replace("    // @sdk-database-tables",
              "\n".join(tables) + "\n    // @sdk-database-tables")
t = t.replace("        // @sdk-database-migrations",
              "\n".join(steps) + "\n        // @sdk-database-migrations")
t = re.sub(r"int get schemaVersion => \d+;",
           "int get schemaVersion => %d;" % max_ver, t)
open(DB, "w", encoding="utf-8", newline="\n").write(t)
print("[*] injected %d tables from SDK manifests, schemaVersion=%d" % (len(tables), max_ver))

base_dir = os.path.join(CACHE, "base")
subprocess.run(["flutter", "pub", "get"], cwd=base_dir, shell=True, check=True)
r = subprocess.run(["dart", "run", "build_runner", "build",
                    "--delete-conflicting-outputs"], cwd=base_dir, shell=True)
sys.exit(r.returncode)
