# Research

## Goal

하드웨어 DDC/CI 밝기 제어 시도에서 소프트웨어 디밍 방식으로 방향을 바꾼 뒤, active codebase에 남아 있는 하드웨어-era 흔적을 찾아 안전한 삭제/정리 범위를 정한다.

이번 조사는 삭제 구현 전 근거 수집이다. 코드는 수정하지 않았고, 현재 소스/테스트/Xcode project/docs에서 DDC, hardware probe, hardware routing, forced software fallback, legacy persistence 흔적을 분류했다.

## Scope And Entry Points

조사 범위:

- Active source tree: `/Users/moonsoo/projects/InnosDimmer/InnosDimmer`
- Tests: `/Users/moonsoo/projects/InnosDimmer/InnosDimmerTests`
- Xcode project: `/Users/moonsoo/projects/InnosDimmer/InnosDimmer.xcodeproj/project.pbxproj`
- Current user-facing docs:
  - `/Users/moonsoo/projects/InnosDimmer/README.md`
  - `/Users/moonsoo/projects/InnosDimmer/docs/operator-guide.md`
  - `/Users/moonsoo/projects/InnosDimmer/docs/qa-matrix.md`
  - `/Users/moonsoo/projects/InnosDimmer/docs/release-notes-local.md`
- Historical/plan docs:
  - `/Users/moonsoo/projects/InnosDimmer/docs/ddc-probe-notes.md`
  - `/Users/moonsoo/projects/InnosDimmer/docs/2026-06-18-software-only-dimming-plan.md`
  - `/Users/moonsoo/projects/InnosDimmer/docs/2026-06-18-completion-plan-first.md`
  - `/Users/moonsoo/projects/InnosDimmer/docs/2026-06-19-overlay-reliability-plan-first.md`
  - `/Users/moonsoo/projects/InnosDimmer/docs/2026-06-19-gamma-blue-reduction-plan-first.md`
  - `/Users/moonsoo/projects/InnosDimmer/docs/research/project-overview/research.md`

Search terms used:

- DDC/CI path: `DDC`, `ddc`, `DDCAdapter`, `HardwareDDCController`, `hardwareDDC`, `hardwareProbe`, `diagnosticsProbe`, `ProbeStep`, `ProbeResult`, `CapabilityProbe`, `HardwareCapability`, `hardwareStrategy`, `HardwareBrightnessStrategy`, `runDDCProbe`, `probeExportNote`, `pendingCommand`, `applyPendingPreview`
- Adjacent leftovers: `forcedSoftwareTest`, `isForcedSoftwareModeForTesting`, `SoftwareActivationReason`, `forcedForDiagnostics`, `Gamma active`, `warmOpacity`, `warm tint`

## Relevant Files

Active runtime files with remaining cleanup candidates:

- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Domain/BrightnessCommand.swift`
  - Contains `BrightnessCommandSource.forcedSoftwareTest`.
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Domain/BrightnessState.swift`
  - Contains persisted/test-facing `isForcedSoftwareModeForTesting`.
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Domain/DimmingMode.swift`
  - Contains `.gamma`, which is not hardware DDC but is currently not exposed as a separate user path.
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/BrightnessController.swift`
  - Contains `forcedSoftwareActivationReason(for:)` and passes `SoftwareActivationReason` into the software strategy.
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/SoftwareDimmingController.swift`
  - Defines `SoftwareActivationReason`; concrete implementation ignores `reason`.
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/OverlayWindowManager.swift`
  - Still accepts `warmth`, returns `warmOpacity: 0`, creates an `InnosDimmer.warm` layer, and sets warm layer color with zero alpha.
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/MenuBarController.swift`
  - Treats `.forcedSoftwareTest` as non-manual automation source and labels it `forced software`.
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/StatusBadgeView.swift`
  - Still has visible copy for `.gamma`.

Tests/docs with remaining historical references:

- `/Users/moonsoo/projects/InnosDimmer/InnosDimmerTests/SettingsSnapshotTests.swift`
  - Keeps legacy JSON with `hardwareCapability`, `lastHardwareProbeResult`, and `isForcedSoftwareModeForTesting`.
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmerTests/BrightnessControllerTests.swift`
  - Has test name `testSoftwareOnlyModeDoesNotQueueWhenHardwareIsNotProbed`.
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmerTests/SoftwareDimmingControllerTests.swift`
  - Has test name `testRegularCommandsApplySoftwareOnlyEvenWhenHardwareIsUnsupported`.
  - Tests `isForcedSoftwareModeForTesting` and `.forcedSoftwareTest`.
- `/Users/moonsoo/projects/InnosDimmer/docs/qa-matrix.md`
  - Says diagnostics can force software mode through `forcedSoftwareTest`.
  - Says overlay computes separate black dimming and warm tint opacity, but current warm opacity is always zero.
- `/Users/moonsoo/projects/InnosDimmer/docs/ddc-probe-notes.md`
  - Tracked archived DDC reference; not runtime source.
- `/Users/moonsoo/projects/InnosDimmer/docs/2026-06-18-completion-plan-first.md`
  - Historical hardware-first plan with many DDC references.
- `/Users/moonsoo/projects/InnosDimmer/docs/2026-06-18-software-only-dimming-plan.md`
  - Historical plan that describes DDC removal stages; useful as evidence of already-completed cleanup.

## Current Behavior

Confirmed current source state:

- No active Swift source file named `HardwareDDCController`, `HardwareCapability`, `ProbeStep`, `CapabilityProbe`, `IOKitDDCAdapter`, or `DDCAdapter` exists under `InnosDimmer` or `InnosDimmerTests`.
- `git ls-files | rg -i 'Hardware|DDC|Probe|Capability|Adapter|pendingCommand|applyPendingPreview'` returns only `docs/ddc-probe-notes.md`.
- Xcode project search for old DDC/probe symbols returns no active project references.
- Current brightness commands always go through `BrightnessController -> SoftwareDimmingController`.
- Current software dimming means:
  - CoreGraphics gamma table blue reduction via `GammaDimmingController`;
  - black click-through AppKit overlay via `OverlayWindowManager`;
  - no monitor-backlight DDC/CI write path.
- README and operator guide correctly state that hardware DDC/CI monitor brightness control is not attempted in normal operation.

Confirmed legacy compatibility behavior:

- `SettingsSnapshotTests` intentionally decode JSON that contains old `hardwareCapability` and `lastHardwareProbeResult` keys.
- These old JSON keys are not present on the current `BrightnessState`; Swift `Decodable` ignores unknown keys, so the test protects old settings from falling back to defaults.
- Removing current fields such as `isForcedSoftwareModeForTesting` is easier than removing enum cases, because unknown object keys are ignored but unknown enum raw values can break decoding.

## Data Flow And Control Flow

Current command path:

```text
Menu / hotkey / schedule
  -> MenuBarController.makeCommand(...)
  -> BrightnessCommand
  -> BrightnessController.apply(...)
  -> BrightnessController.applySoftware(...)
  -> SoftwareDimmingStrategy.apply(command, reason)
  -> SoftwareDimmingController.apply(...)
  -> GammaDimmingController.apply(...)
  -> OverlayWindowManager.apply(...)
```

Current forced-software diagnostic path:

```text
BrightnessState.isForcedSoftwareModeForTesting == true
or BrightnessCommandSource.forcedSoftwareTest
  -> BrightnessController.forcedSoftwareActivationReason(...)
  -> SoftwareActivationReason.forcedForDiagnostics
  -> SoftwareDimmingStrategy.apply(command, reason)
```

Important observation: `SoftwareDimmingController.apply` discards the `reason` parameter with `_ = reason`. The reason is only observable through tests/fakes that record `activationReasons`.

Current legacy decode path:

```text
UserDefaults JSON
  -> DisplayTargetStore.load()
  -> JSONDecoder.decode(SettingsSnapshot.self, from: data)
  -> DisplayTargetStore.validated(...)
  -> schemaVersion upgraded to SettingsSnapshot.currentSchemaVersion
```

Unknown object keys such as `hardwareCapability` and `lastHardwareProbeResult` are ignored by current decoding. Unknown raw enum values, such as a removed `BrightnessCommandSource` or `DimmingMode`, would not be ignored without custom decoding or migration.

## Existing Abstractions And Boundaries

Boundaries to preserve:

- `BrightnessController` remains the only command policy owner.
- `SoftwareDimmingController` remains the software strategy boundary.
- `GammaDimmingController` is current software blue-reduction behavior, not DDC hardware control.
- `OverlayWindowManager` is current software brightness behavior.
- `DisplayInventory`/`DisplayTargetResolver` hardware identifiers are display identity matching, not monitor brightness control.
- `platformBlocked` is still needed to disclose OS/surface limitations and should not be removed as a hardware remnant.
- `SettingsSnapshotTests` legacy hardware JSON tests protect user settings after the DDC pivot and should not be deleted casually.

Boundaries that can be simplified:

- `SoftwareActivationReason` no longer drives runtime behavior.
- `isForcedSoftwareModeForTesting` and `BrightnessCommandSource.forcedSoftwareTest` appear to be test/diagnostic leftovers from the period when commands could choose between hardware and software paths.
- `OverlayAppearance.warmOpacity`, `OverlayWindowManager.apply(... warmth:)`, and the warm layer are adjacent cleanup candidates from the pre-gamma warmth overlay design. They are not DDC hardware code, but they are now no-op residue.

## Side Effects And Integration Points

Cleanup side effects to account for:

- Removing `SoftwareActivationReason` changes the `SoftwareDimmingStrategy` protocol, so every test fake implementing `apply(_:reason:)` must be updated.
- Removing `BrightnessCommandSource.forcedSoftwareTest` changes a `Codable` enum. If any persisted `lastAppliedCommandSource` contains `"forcedSoftwareTest"`, default decoding would fail unless a migration/fallback is added.
- Removing `BrightnessState.isForcedSoftwareModeForTesting` changes persisted state shape, but old JSON with that key should decode because it becomes an unknown key.
- Removing `.gamma` from `DimmingMode` changes a `Codable` enum and can break persisted active mode if any settings have `"activeMode": "gamma"`.
- Removing warm overlay layer/parameters changes tests and possibly layer-inspection assumptions, but visible behavior should remain unchanged because `warmOpacity` is already always zero.
- Deleting historical docs can reduce search noise, but can also remove the rationale for why DDC was abandoned.

## Risk To Surrounding Systems

High-risk cleanup mistakes:

- Removing legacy decode tests because they mention hardware. Those tests are protective, not dirty runtime code.
- Removing display hardware identity matching because it contains `hardware` in method names. That logic is needed to match the same physical display after reconnect.
- Removing `platformBlocked`. It is active product semantics for OS/surface limitations.
- Removing `DimmingMode.gamma` without a persistence fallback. Even though gamma-only mode is not exposed, the enum is Codable.
- Removing `BrightnessCommandSource.forcedSoftwareTest` without checking persisted source decode behavior. It is probably not user-reachable now, but enum removal is still a decode boundary.
- Treating `GammaDimmingController` as hardware code. It mutates display gamma through CoreGraphics, but current product policy treats it as software blue reduction.

Lower-risk cleanup targets:

- Rename tests that say hardware is unsupported/not probed, once their assertions remain software-only.
- Remove or simplify `SoftwareActivationReason` if no product logic depends on reason.
- Remove forced-software diagnostic state/source if no user/debug command uses it.
- Update `docs/qa-matrix.md` after forced-software removal.
- Correct `docs/qa-matrix.md` warm-tint wording because current overlay warmth is disabled.
- Optionally archive or delete old hardware-first plan docs, but only after deciding whether historical planning context is still useful.

## Do Not Duplicate Or Bypass

Do not bypass these while cleaning:

- Do not delete `SettingsSnapshotTests` legacy JSON coverage; extend it if enum fallback is added.
- Do not bypass `DisplayTargetResolver` when touching hardware identity naming.
- Do not replace software dimming with direct gamma/overlay calls outside `BrightnessController` and `SoftwareDimmingController`.
- Do not remove DDC documentation from `docs/ddc-probe-notes.md` unless the desired cleanup includes deleting historical rationale, not just dirty runtime code.
- Do not remove `GammaDimmingController` as part of DDC cleanup; it is current functionality.
- Do not remove `platformBlocked`; it is required by QA/product wording.

## Open Questions

- Should historical DDC documentation stay as archived rationale, or should the repo remove it for maximum cleanliness?
- Is `forcedSoftwareTest` still useful as an internal diagnostics hook, or can it be removed now that there is no hardware/software routing choice?
- If `BrightnessCommandSource.forcedSoftwareTest` is removed, should `BrightnessCommandSource` get custom decoding that maps unknown/legacy command sources to `.startupRestore` or `nil`?
- Should `.gamma` remain as a future diagnostic/display mode, or should the mode model be reduced to current user-visible states only?
- Should adjacent no-op warmth overlay code be included in the same cleanup, or kept separate from DDC/hardware cleanup?

## Plan Implications

Recommended cleanup sequence:

1. Remove the low-value forced-software routing reason layer.
   - Delete `SoftwareActivationReason`.
   - Change `SoftwareDimmingStrategy.apply(_:, reason:)` to `apply(_:)`.
   - Update `BrightnessController`, `SoftwareDimmingController`, and test fakes.
   - Preserve behavior: all commands still apply software immediately.

2. Remove forced-software test state/source if no longer needed.
   - Delete `BrightnessState.isForcedSoftwareModeForTesting`.
   - Delete `BrightnessCommandSource.forcedSoftwareTest`.
   - Delete `BrightnessController.forcedSoftwareActivationReason(for:)`.
   - Update tests that assert forced activation reason.
   - Add or preserve decode coverage for old settings. Consider custom enum decoding if old persisted `lastAppliedCommandSource` could contain `forcedSoftwareTest`.

3. Rename stale hardware-era test names and docs.
   - Rename tests to describe software-only behavior without referring to hardware probing.
   - Update `docs/qa-matrix.md` to remove `forcedSoftwareTest` if step 2 removes it.
   - Keep legacy JSON test names explicit enough to explain why old hardware fields remain in fixtures.

4. Keep archived DDC docs by default.
   - `docs/ddc-probe-notes.md` is the only tracked DDC file and is clearly marked archived.
   - If a cleaner repo is preferred, move/delete it as a separate documentation decision.

5. Treat gamma mode and warm overlay residue as separate cleanup decisions.
   - `.gamma` is not DDC hardware code; removing it needs persistence review.
   - `warmOpacity`/warm layer is no-op software residue; it can be cleaned after deciding whether to keep internal `warmth` storage names for compatibility.

Verification commands for the future cleanup implementation:

```bash
rg -n "HardwareBrightnessStrategy|hardwareStrategy|runDDCProbe|probeExportNote|hardwareDDCController|HardwareDDCController|DDCAdapter|HardwareCapability|ProbeStep|CapabilityProbe|hardwareDDC|diagnosticsProbe|pendingCommand|applyPendingPreview" InnosDimmer InnosDimmerTests InnosDimmer.xcodeproj
rg -n "SoftwareActivationReason|forcedSoftwareTest|isForcedSoftwareModeForTesting|forcedForDiagnostics" InnosDimmer InnosDimmerTests docs
xcodebuild -scheme InnosDimmer -configuration Debug build-for-testing CODE_SIGNING_ALLOWED=NO
```

Expected first command after cleanup: no matches in active source/tests/project.

Expected second command after forced-software cleanup: no matches, except intentional historical docs if retained.

## Evidence

Commands run on 2026-06-19 from `/Users/moonsoo/projects/InnosDimmer`:

- `git status --short`
  - Existing untracked files were present before this research:
    - `docs/design/popover-redesign/captures/*.png`
    - `docs/research/` from prior research artifacts.
- `find . -maxdepth 4 -type f \( -name '*DDC*' -o -name '*ddc*' -o -name '*Hardware*' -o -name '*hardware*' -o -name '*Probe*' -o -name '*probe*' \) -print | sort`
  - Found `docs/ddc-probe-notes.md`; initial broad search also hit `.git/objects`, which was ignored as repository internals.
- `rg -n -i "\bddc\b|ddc/ci|i2c|iokit|io_service|ioiterator|hardwareCapability|lastHardwareProbeResult|hardwareDDC|hardwareProbe|diagnosticsProbe|pendingCommand|hardware brightness|hardware-era|hardware|monitor backlight|backlight|probe" README.md docs InnosDimmer InnosDimmerTests --glob '!docs/design/popover-redesign/captures/**'`
- `rg -n "HardwareDDC|DDCAdapter|CapabilityProbe|HardwareCapability|ProbeStep|hardwareDDC|diagnosticsProbe|pendingCommand|HardwareBrightnessStrategy|hardwareStrategy|runDDCProbe|probeExportNote|hardwareDDCController" InnosDimmer.xcodeproj InnosDimmer InnosDimmerTests README.md docs/ddc-probe-notes.md docs/qa-matrix.md docs/release-notes-local.md docs/2026-06-18-software-only-dimming-plan.md docs/2026-06-19-overlay-reliability-plan-first.md`
  - Confirmed no active source/test/project matches; matches are in historical docs and archived DDC note.
- `git ls-files | rg -i 'Hardware|DDC|Probe|Capability|Adapter|pendingCommand|applyPendingPreview'`
  - Result: `docs/ddc-probe-notes.md`
- `rg -n "SoftwareActivationReason|activationReasons|forcedSoftwareTest|isForcedSoftwareModeForTesting|forcedForDiagnostics" InnosDimmer InnosDimmerTests docs/qa-matrix.md docs/2026-06-19-overlay-reliability-plan-first.md docs/research/project-overview/research.md`
  - Confirmed forced-software diagnostic remnants exist in source/tests/docs.
- `rg -n "case gamma|Gamma active|activeMode.*gamma|\.gamma" InnosDimmer InnosDimmerTests README.md docs --glob '!docs/design/popover-redesign/captures/**'`
  - Confirmed `.gamma` is present but not user-exposed as a separate path.
- `rg -n "warmOpacity|warm tint|warmth|Blue reduction" README.md docs/qa-matrix.md InnosDimmer/Services/OverlayWindowManager.swift InnosDimmerTests/SoftwareDimmingControllerTests.swift docs/research/project-overview/research.md`
  - Confirmed current warm overlay opacity is zero while some docs still describe warm tint behavior.

Insufficient evidence:

- No build/test command was run in this research turn.
- No live app/manual QA was run.
- No user decision was made about deleting archived DDC docs versus keeping them as rationale.
