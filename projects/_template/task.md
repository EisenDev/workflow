# Task: none

No active task. Claude writes the next one here from this layout:

```
# Task: T-NNN <short title>

Status: draft            (draft | building | checking | waiting-ok | approved | dropped)
Priority: P2             (P1 urgent | P2 normal | P3 when free)
Size: M                  (S tiny: no writer | M normal | L split into M tasks)
Branch: tNNN-<slug>
Orca: run=<id> task=<id> dispatch=<id> worktree=<path>
Started: YYYY-MM-DD HH:MM

## Goal
<1-2 sentences: what the owner wants and why>

## Change
<behaviour before -> after; concrete>

## May edit
- <path or dir/>

## Acceptance
- <test command> passes
- <observable check>
- Owner checks: <visuals/feel, or none>

## Docs
- <docs/FILE.md from the codemap's docs column; "index" if a new doc must be linked; or "none (why)">

## Notes
<file:symbol pointers from the codemap, constraints, what not to do>

## Rework
<Claude appends short notes here when sending work back>
```
