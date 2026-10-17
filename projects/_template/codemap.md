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

## Features → files
| Feature / flow | Main files (entry first) |
|---|---|
| <login, inventory, player movement…> | <path:symbol, path> |

## Data
<database / schema / migrations / save files / ScriptableObjects; where they are defined>

## Tests
<where tests live, naming, how to run one test, what is covered and what is not>

## Conventions
<naming, patterns to follow, state management, error handling>

## Fragile areas / do not touch
<generated code, legacy parts, production scripts, things that broke before>
