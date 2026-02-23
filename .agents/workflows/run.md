---
description: Build and run the Pomodoro app locally
---

# Run Workflow

Build and launch the Pomodoro app for local testing.

## Steps

// turbo-all

1. Build and launch:

```bash
cd /Users/kochi/Development/Pomodoro && ./build.sh run
```

1. The app will appear in the menu bar. The web dashboard is available at:
   - **HTTP**: <http://localhost:8094>
   - **WebSocket**: ws://localhost:8095

## Notes

- The `run` command does a Debug build by default
- Use `--skip-gen` if the Xcode project is already up to date
- To stop the app, use Cmd+Q from the menu bar dropdown or `killall Pomodoro`
