# .agents/project.md

Copy to `<project>/.agents/project.md` and fill in. Claude and the workers read this in every task.

```yaml
profile: unity                # unity | web | software
name: <project name>
main_branch: main
handoff_file: <path, e.g. docs/HANDOFF.md>
changelog: <path or "none">

test_command: <exact command, run from the worktree root>
build_command: <exact command or "none">
test_location: local          # local | ci | both  (see docs/resources.md)

forbidden_paths:              # added to the profile's defaults
  - <path>

docs_paths:                   # what the writer may edit by default
  - <path>
```

## Unity only

```yaml
unity_version: <from ProjectSettings/ProjectVersion.txt>
test_platforms: [EditMode]    # add PlayMode if the project has PlayMode tests
test_assemblies: [<asmdef name>]
scenes:                       # who may touch which scene; tasks must name them in Ownership
  - path: Assets/Scenes/<Main>.unity
    note: <owner edits in Editor only | tasks may edit>
```

## Notes for agents

<Anything a worker must know that is not obvious from the code: conventions, fragile areas, lore docs.>
