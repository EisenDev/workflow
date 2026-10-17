# Codemap: <project-name>

Mapped: none

<!-- Written once by Claude (one-time read), then updated only for files that changed.
     `wf.sh map-status <name>` says if it is fresh; `wf.sh map-stamp <name>` marks it current.
     Target: 100–250 lines. Paths are relative to the repo root. -->

## What it is
<1–3 lines: what the app/game does, who uses it>

## Stack and commands
<language, framework, key libraries; install / dev / test / build commands>

## Layout
| Path | What lives there |
|---|---|
| <dir/> | <purpose> |

## Features → files → docs
| Feature / flow | Main files (entry first) | Docs |
|---|---|---|
| <login, inventory, player movement…> | <path:symbol, path> | <docs/FILE.md, or —> |

## Docs
- Index: <docs/README.md, or "no docs/ folder">
- Convention: <file naming, where new feature docs go, what must be linked from the index,
  changelog/handoff file if any>
- General docs (update when setup, architecture or operations change): <files>

## Data
<database / schema / migrations / save files / ScriptableObjects; where they are defined>

## Tests
<where tests live, naming, how to run one test, what is covered and what is not>

## Conventions
<naming, patterns to follow, state management, error handling>

## Fragile areas / do not touch
<generated code, legacy parts, production scripts, things that broke before>
