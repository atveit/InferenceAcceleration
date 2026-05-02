# TLA+ Toolchain Pin (Track T, 2026-05-01)

This file pins the exact toolchain used for every TLC run captured under
`theory/reports/tlc_runs/`. Anyone reproducing a run must use this exact
combination — the system default `/usr/bin/java` on this Mac does **not**
work (no JRE configured) and was the proximate cause of "couldn't run
TLC" reports during the audit.

## Pinned versions

| Component | Path / version |
|---|---|
| `tla2tools.jar` | `/Users/amund/.tla/tla2tools.jar` |
| TLC version | TLC2 **v2.19** (8 Aug 2024) |
| Java runtime | `/opt/homebrew/opt/openjdk@21/bin/java` |
| OpenJDK version | OpenJDK **21.0.10** (Homebrew, 2026-01-20) |
| OS | macOS Darwin 25.4.0 (arm64, M3 Ultra) |

## Verification commands

```bash
ls -la /Users/amund/.tla/tla2tools.jar
/opt/homebrew/opt/openjdk@21/bin/java -version
/opt/homebrew/opt/openjdk@21/bin/java -cp /Users/amund/.tla/tla2tools.jar tlc2.TLC -h | head -3
```

Expected output for the third command starts with:

```
TLC2 Version 2.19 of Day Month 20?? (rev: ...)
```

## Canonical run pattern

For a spec at `theory/phase<N>/walk/<spec>.tla` with a config at
`theory/phase<N>/walk/<spec>.cfg`:

```bash
cd /Users/amund/research/gemma4dflashpapertheory/theory/phase<N>/walk
/opt/homebrew/opt/openjdk@21/bin/java -cp /Users/amund/.tla/tla2tools.jar \
    tlc2.TLC -config <spec>.cfg <spec>.tla \
    2>&1 | tee /Users/amund/research/gemma4dflashpapertheory/theory/reports/tlc_runs/<spec>.log
```

`-cp` (classpath) is mandatory — the jar isn't a runnable jar wrapper.

## What "checked" means here

A green TLC run with this toolchain explores **finite, bounded** state
spaces. We never write "proved"; we write "no counter-example found at
bounds X". The bounds for each spec are recorded in
`tla_remediation_notes.md` and in each `<spec>.log`.

## Why these pins

- `tla2tools.jar` v2.19: latest stable as of audit time. Earlier
  versions drop or rename modules, e.g. `FiniteSets` ⇄ `Sets`.
- OpenJDK 21: the system `java` symlink on this Mac points at a
  non-functional location (`Unable to locate a Java Runtime`). Homebrew
  `openjdk@21` is the working JRE.
