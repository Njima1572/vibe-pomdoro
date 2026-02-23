---
description: Create a release archive (.xcarchive) for distribution
---

# Archive Workflow

Create a timestamped release archive of the Pomodoro app.

## Steps

// turbo-all

1. Create the archive:

```bash
cd /Users/kochi/Development/Pomodoro && ./build.sh archive
```

1. The archive will be saved to:

```
build/archives/Pomodoro_YYYYMMDD_HHMMSS.xcarchive
```

## Notes

- Archives are always built with the Release configuration
- The project is regenerated from `project.yml` before archiving
- Use `--skip-gen` if the project is already up to date
