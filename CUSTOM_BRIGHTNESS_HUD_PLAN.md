# Custom Brightness HUD Plan

## Goal

Add a custom brightness HUD for `macOS 26+` so MonitorControl still shows visual feedback when brightness changes through keyboard control, even when the native private-framework OSD no longer appears reliably.

## Scope

- Only replace brightness OSD on `macOS 26+`
- Keep the existing private `OSD.framework` path for:
  - macOS versions below 26
  - volume OSD
  - mute OSD
  - contrast OSD
- Do not change brightness control logic itself
- Do not change menu bar UI
- Do not add new preferences in this first version

## Design

### Routing

- Keep `Display.stepBrightness(...)` and `OtherDisplay.stepBrightness(...)` unchanged at the call sites that trigger OSD.
- Update `OSDUtils.showOsd(...)` so that:
  - if `command == .brightness` and the app is running on `macOS 26+`, show the custom HUD
  - otherwise, continue using `OSDManager`

### HUD behavior

- Show one HUD per target display
- Place the HUD in the center of the destination display
- Reuse the same HUD window for repeated key presses on the same display
- Reset the fade-out timer on each update
- Fade out smoothly after a short delay
- Ignore mouse and keyboard interaction

### Visual style

- Use a borderless floating panel/window with a vibrancy background
- Show:
  - brightness symbol
  - horizontal progress bar
  - percentage text
- Keep the look compact and close to the existing Apple-style brightness feedback, without trying to exactly clone private system visuals

## Implementation steps

1. Add a support type to manage brightness HUD windows by `displayID`
2. Add a custom HUD view that renders the symbol, progress bar, and percentage
3. Resolve the effective display and map it to an `NSScreen`
4. Center the HUD in the screen frame and keep it above normal content
5. Route `OSDUtils.showOsd(...)` to the HUD only for brightness on `macOS 26+`
6. Leave all existing OSD code paths intact for non-brightness commands
7. Build the app and verify that brightness changes still work and now show the custom HUD

## Files to add

- `MonitorControl/Support/BrightnessHUDController.swift`

## Files to modify

- `MonitorControl/Support/OSDUtils.swift`
- `MonitorControl.xcodeproj/project.pbxproj`

## Risks

- Window level may need adjustment for some fullscreen or Mission Control situations
- Multi-display mirror and virtual display behavior may still need tuning after first pass
- The first version will prefer reliability over pixel-perfect imitation of Apple's old OSD

## Acceptance criteria

- On `macOS 26+`, brightness key presses show a custom HUD
- The HUD appears on the correct display
- Repeated brightness changes update the same HUD without flicker
- Volume and contrast continue using the existing OSD behavior
