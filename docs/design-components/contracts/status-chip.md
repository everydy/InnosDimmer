# Status Chip Contract

## Purpose

Show concise status for mode, automation, readiness, warning, or blocked states.

## Non-Purpose

Do not use chips as general buttons or as the only place where critical failure details appear.

## API

```swift
InnosStatusChipView(title: "Automation active", tone: .ready)
chip.update(title: "Paused until 19:00", tone: .warning)
```

## Tones

- `neutral`
- `ready`
- `warning`
- `danger`
- `primary` is reserved for command buttons, not ordinary chips.

## Token Dependencies

- `InnosDesignTokens.foreground(for:tone:)`
- `InnosDesignTokens.background(for:tone:)`
- `InnosDesignTokens.border(for:tone:)`
- `InnosDesignTokens.Radius.chip`

## Accessibility

The chip must expose its text as an accessibility label. Color cannot be the only status signal.

## Route Override Boundary

Routes may decide which chips appear. Routes must not redefine chip color semantics.

## Guard

Compile shared token/component files and verify chip text appears in the shared specimen.
