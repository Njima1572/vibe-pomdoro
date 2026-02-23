---
description: Regenerate app icon PNGs from the source SVG
---

# Regenerate Icons Workflow

After modifying `icon_source.svg`, regenerate all required PNG sizes for the Xcode asset catalog.

## Prerequisites

- `rsvg-convert` must be installed (`brew install librsvg`)

## Steps

// turbo-all

1. Generate all PNG sizes from the SVG source:

```bash
ICON_DIR="/Users/kochi/Development/Pomodoro/Pomodoro/Resources/Assets.xcassets/AppIcon.appiconset"
SVG="/Users/kochi/Development/Pomodoro/icon_source.svg"

rsvg-convert -w 16   -h 16   "$SVG" -o "$ICON_DIR/icon_16.png"
rsvg-convert -w 32   -h 32   "$SVG" -o "$ICON_DIR/icon_16@2x.png"
rsvg-convert -w 32   -h 32   "$SVG" -o "$ICON_DIR/icon_32.png"
rsvg-convert -w 64   -h 64   "$SVG" -o "$ICON_DIR/icon_32@2x.png"
rsvg-convert -w 128  -h 128  "$SVG" -o "$ICON_DIR/icon_128.png"
rsvg-convert -w 256  -h 256  "$SVG" -o "$ICON_DIR/icon_128@2x.png"
rsvg-convert -w 256  -h 256  "$SVG" -o "$ICON_DIR/icon_256.png"
rsvg-convert -w 512  -h 512  "$SVG" -o "$ICON_DIR/icon_256@2x.png"
rsvg-convert -w 512  -h 512  "$SVG" -o "$ICON_DIR/icon_512.png"
rsvg-convert -w 1024 -h 1024 "$SVG" -o "$ICON_DIR/icon_512@2x.png"
```

1. Verify the generated icon:

```bash
file "$ICON_DIR/icon_512@2x.png"
```

1. Rebuild the app to pick up the new icons:

```bash
cd /Users/kochi/Development/Pomodoro && ./build.sh release
```

## Icon Sizes Reference

| Filename        | Pixels  | Usage          |
|-----------------|---------|----------------|
| icon_16.png     | 16×16   | 16pt @1x       |
| <icon_16@2x.png>  | 32×32   | 16pt @2x       |
| icon_32.png     | 32×32   | 32pt @1x       |
| <icon_32@2x.png>  | 64×64   | 32pt @2x       |
| icon_128.png    | 128×128 | 128pt @1x      |
| <icon_128@2x.png> | 256×256 | 128pt @2x      |
| icon_256.png    | 256×256 | 256pt @1x      |
| <icon_256@2x.png> | 512×512 | 256pt @2x      |
| icon_512.png    | 512×512 | 512pt @1x      |
| <icon_512@2x.png> | 1024×1024 | 512pt @2x    |
