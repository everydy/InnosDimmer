# 2026-06-19 Gamma Blue Reduction Plan First

## Goal

Replace the artificial orange `Warmth` overlay with a more direct blue-light reduction path for the external `27QA100M` display.

Brightness dimming stays software-overlay based. The second control keeps the existing internal `warmth` storage field for compatibility, but user-facing copy now treats it as `Blue reduction`.

## Probe Evidence

The standalone CoreGraphics probe confirmed that the target display exposes and accepts a gamma table:

```text
display=2 name=27QA100M capacity=1024 main=false
getGammaStatus=0 sampleCount=1024
applyStatus=0 blueScale=0.92 holdSeconds=1.5
restoreStatus=0 restoreAttempted=true
```

This justified moving from orange overlay warmth to gamma-based blue channel scaling.

## Implemented Shape

- `GammaDimmingController` owns CoreGraphics gamma table read, blue-channel scaling, baseline storage, and restore.
- `SoftwareDimmingController` applies gamma blue reduction from `command.warmth`, then applies the black brightness overlay with neutral warmth.
- `OverlayWindowManager` keeps the black dimming overlay and disables the orange warmth opacity in the primary path.
- Menu bar, dashboard, settings, diagnostics, schedule, docs, and tests now use `Blue reduction` visible copy.
- `MenuBarController.stop()` and `AppDelegate.applicationWillTerminate` clear the current software state so normal app quit attempts to restore the saved gamma baseline.

## Verification

- Focused tests passed:

```text
xcodebuild test -scheme InnosDimmer \
  -only-testing:InnosDimmerTests/BrightnessControllerTests \
  -only-testing:InnosDimmerTests/SoftwareDimmingControllerTests \
  -only-testing:InnosDimmerTests/MenuBarStateTests \
  -only-testing:InnosDimmerTests/ScheduleEngineTests
```

Result: 48 tests, 0 failures.

- Debug test build passed:

```text
xcodebuild -scheme InnosDimmer -configuration Debug build-for-testing CODE_SIGNING_ALLOWED=NO
```

- Release build passed:

```text
xcodebuild -scheme InnosDimmer -configuration Release build CODE_SIGNING_ALLOWED=NO
```

## Remaining Risks

- Long-running visual comfort is not verified yet; the current scale maps 20% blue reduction to about `blueScale=0.91`.
- Night Shift, ColorSync profile changes, sleep/wake, HDMI reconnect, and force quit recovery still need manual QA.
- Full unfiltered XCTest remains a separate isolation problem because several older tests still depend on real display/time/UserDefaults state.
- A visible emergency ColorSync restore action is still deferred.
