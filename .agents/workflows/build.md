---
description: Build the Pomodoro app (debug or release)
---

# Build Workflow

Build the Pomodoro macOS app from the command line.

## Steps

// turbo-all

1. Generate the Xcode project from `project.yml`:

```bash
cd /Users/kochi/Development/Pomodoro && xcodegen generate
```

1. Build in Debug mode (default):

```bash
./build.sh build
```

Or for a Release build:

```bash
./build.sh release
```

1. The built app bundle will be at:

```
build/DerivedData/Build/Products/{Debug|Release}/Pomodoro.app
```

## Notes

- Use `--skip-gen` to skip xcodegen if the project is already generated
- Use `./build.sh clean` to remove all build artifacts before a fresh build
- The build script automatically targets `arm64` (Apple Silicon)
