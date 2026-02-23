---
description: Clean build artifacts and do a fresh build
---

# Clean Build Workflow

Remove all build artifacts and perform a fresh build from scratch.

## Steps

// turbo-all

1. Clean all build artifacts:

```bash
cd /Users/kochi/Development/Pomodoro && ./build.sh clean
```

1. Rebuild from scratch:

```bash
./build.sh release
```

## Notes

- This removes the `build/` directory and runs `xcodebuild clean`
- Use this when builds are failing due to stale artifacts or cache issues
- The project will be regenerated from `project.yml` automatically
