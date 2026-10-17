# Profile: Unity

Rules added to `taskflow.md` for Unity projects. Codex follows them while building; Gemini checks
them in its summary; `wf.sh check` enforces May edit and the tests.

## Repo requirements

- Git repo with Git LFS: `git lfs install` done, `.gitattributes` tracks binaries
  (`*.png *.psd *.fbx *.wav *.mp3 *.ogg *.tga *.exr *.unitypackage` etc.).
- Unity `.gitignore`: at least `Library/ Temp/ Obj/ Build/ Builds/ Logs/ UserSettings/ MemoryCaptures/`.
- Editor settings: Asset Serialization = **Force Text**, Version Control = **Visible Meta Files**.
- `ProjectSettings/ProjectVersion.txt` matches an installed editor; Unity CLI present (`unity --version`).

## `projects/<name>/directory.md`

`wf.sh new <name> <path> unity` fills in the default test command:

```
test: ~/workspace/Agent-Workflow/scripts/resource-gate.sh run heavy -- unity test . --mode EditMode --output Logs/test-editmode.xml --timeout 3600 -- -nographics
```

## Worktrees and the Editor

- One Editor per folder (Unity locks it via `Temp/UnityLockfile`). The owner may keep the Editor
  open on the main folder; workers and tests run only in the task worktree.
- A new worktree has no `Library/`; the first import is slow and memory-heavy. Put it in the
  repo's `orca.yaml` so it happens once, through the gate, when Orca creates the worktree:

  ```yaml
  scripts:
    setup: |
      ~/workspace/Agent-Workflow/scripts/resource-gate.sh run heavy -- \
        unity run . --timeout 3600 --log-file Logs/setup-import.log --no-tail -- -nographics
  ```

  `orca.yaml` lives in the project repo, so agree on it with the other maintainer first. Without
  it, Codex's first test run does the import instead. Verify on the first real task.
- Do not copy `Library/` between folders; a stale Library causes odd errors.

## May edit rules

- Scenes (`*.unity`) and prefabs (`*.prefab`) merge badly: list them by exact path in May edit;
  only one open task may own a given scene/prefab. Never use a directory entry that covers scenes
  unless the task is about them.
- Prefer code and ScriptableObject changes over scene edits. Scene setup that is hard as text →
  the task says so and the owner does it in the Editor.
- Every asset moves with its `.meta` (`wf.sh check` allows `<file>.meta` next to an allowed file).
  Never delete, regenerate or hand-edit GUIDs.
- Gemini never touches `Assets/` except text/data files the task names (dialogue, localisation).

## Never in May edit (unless the task is about it)

```
Library/  Temp/  Obj/  Logs/  UserSettings/  Build/  Builds/
ProjectSettings/  Packages/manifest.json  Packages/packages-lock.json  Assets/Plugins/
```

## Tests

Unity Test Framework through the Unity CLI (skill `unity-cli`), always through the gate (one heavy
job at a time, capped). Never pass `-batchmode`, `-quit` or `-projectPath` after `--`.

- Exit codes: **0** passed, **8** tests failed, **6** no verdict (compile error, license, crash,
  timeout). 6 is never a pass.
- While building, Codex can add `--filter <TestClass>` for quick runs; `wf.sh check` runs the full
  command from `directory.md`.
- PlayMode: `--mode PlayMode --output Logs/test-playmode.xml`. Display/graphics failures (exit 6)
  are reported, not skipped silently.
- New logic gets EditMode tests in the project's test assembly.

## QA (Codex)

- EditMode/PlayMode tests for behaviour; scripted checks via `unity run . --command <name>` where
  the project has CLI commands.
- Workers cannot see the Game view: visuals, feel, animation, UI layout and audio go in the report
  under "Needs human check" with scene and steps.

## Gemini's summary must flag

1. Files outside May edit or in the "never" list.
2. Assets added/moved/deleted without their `.meta`; any changed GUID.
3. Binaries not stored as LFS pointers (`git lfs ls-files`).
4. Large unexplained scene/prefab YAML churn.
5. New `Debug.Log` spam or editor-only code in runtime paths.
