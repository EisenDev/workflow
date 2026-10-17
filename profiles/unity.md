# Profile: Unity

Rules added to `taskflow.md` for Unity projects. The project-specific values (Unity version,
test assemblies, scenes) live in the project's `.agents/project.md`.

## Repo requirements (preflight fails without these)

- Git repo with Git LFS: `git lfs install` done, `.gitattributes` tracks binaries
  (`*.png *.psd *.fbx *.wav *.mp3 *.ogg *.tga *.exr *.unitypackage` etc.).
- Unity `.gitignore`: at least `Library/ Temp/ Obj/ Build/ Builds/ Logs/ UserSettings/ MemoryCaptures/`.
- Editor settings: Asset Serialization = **Force Text**, Version Control = **Visible Meta Files**.
- `ProjectSettings/ProjectVersion.txt` matches an editor installed on this machine.

Preflight check:

```
git -C <repo> lfs env >/dev/null && cat <repo>/ProjectSettings/ProjectVersion.txt
unity --version                     # Unity CLI present
grep -q "^Library/" <repo>/.gitignore
```

## `.agents/project.md` must give

```
profile: unity
unity_version: <from ProjectSettings/ProjectVersion.txt>
test_command: unity test . --mode EditMode --output Logs/test-editmode.xml --timeout 1200 -- -nographics
test_platforms: EditMode [, PlayMode]
scenes: list of scenes and who may touch them
forbidden_paths: (defaults below + project extras)
```

## Worktrees and the Editor

- Only one Editor per project folder (Unity locks it via `Temp/UnityLockfile`). The owner may
  keep the Editor open on the main folder; workers and tests run in the task worktree only.
- A new worktree has no `Library/`, so the first open/import is slow (minutes to much longer
  on big projects). Do the import in the repo's `orca.yaml` setup hook so it happens once
  when the worktree is created:

  ```yaml
  scripts:
    setup: |
      unity run . --timeout 3600 --log-file Logs/setup-import.log --no-tail -- -nographics
  ```

  (`unity run` opens the project in batch mode, imports, and quits. Verify on the first test.)
- Do not copy `Library/` between folders unless the owner asks; a stale Library causes odd errors.

## Ownership rules

- Scenes (`*.unity`) and prefabs (`*.prefab`) are YAML but merge badly. A task may only change
  the scenes/prefabs listed by name in its Ownership, and only one open task may own a given
  scene or prefab at a time.
- Prefer code and ScriptableObject changes over scene edits. If a task needs scene setup that is
  hard to do as text, the brief says so and the owner does that part in the Editor.
- Every asset moves with its `.meta`. Never delete, regenerate or hand-edit GUIDs in `.meta` files;
  a changed GUID breaks references silently.
- Gemini (writer) never touches `Assets/` except text/data files explicitly named in its brief
  (e.g. dialogue JSON, localisation tables).

## Default forbidden paths

```
Library/  Temp/  Obj/  Logs/  UserSettings/  Build/  Builds/
ProjectSettings/            # unless the brief names a file
Packages/manifest.json      # unless the brief is about packages
Packages/packages-lock.json
Assets/Plugins/             # third-party
any *.unity / *.prefab not named in Ownership
```

## Tests

Unity Test Framework through the Unity CLI (`unity`, installed; skill `unity-cli`), from the
worktree root. It runs the editor in batch mode itself; never pass `-batchmode`, `-quit` or
`-projectPath` after `--`.

```
unity test . --mode EditMode --output Logs/test-editmode.xml --timeout 1200 -- -nographics
```

- Exit codes: **0** all passed, **8** tests ran and some failed, **6** no verdict (compile error,
  license, editor crash, timeout). 6 is never "pass" — read the log and fix or report.
- A worker reports the exit code and the failing test names, not just "failed".
- PlayMode: `--mode PlayMode --output Logs/test-playmode.xml`. If it fails for display/graphics
  reasons (exit 6, not a test failure), report that instead of skipping silently.
- Fallback without the CLI: `"$UNITY_EDITOR" -batchmode -nographics -projectPath . -runTests
  -testPlatform EditMode -testResults Logs/test-editmode.xml -logFile Logs/test-editmode.log`
  (no `-quit`), then check the XML and `grep -E "error CS[0-9]+"` the log.
- New logic in a brief gets EditMode tests in the project's test assembly; the brief names it.

## What workers cannot check

Codex and Gemini cannot see the Game view. Visuals, feel, animation, UI layout and audio are
listed in Claude's report under "Owner please check in the Editor", with the scene and steps.

## Review checklist (taskflow step 6, additions)

1. No files from forbidden paths; no `Library/`/`Temp/` leaks.
2. Every added/moved/deleted asset has its matching `.meta` change; no existing GUID changed.
3. Binary files are LFS pointers (`git -C <worktree> lfs ls-files` lists them), not raw blobs.
4. Scene/prefab diffs only in owned files, and small and readable; large unexplained YAML
   churn (e.g. every `m_LocalPosition` reordered) -> rework.
5. `unity test` exits 0 for EditMode (and PlayMode if the project has it), run by Claude.
6. No new `Debug.Log` spam, no `#if UNITY_EDITOR` code leaking into runtime paths unguarded.
7. Package or ProjectSettings changes only if the brief allowed them.
