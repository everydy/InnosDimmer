# Action Row Contract

## Purpose

Group related commands such as quick disable, restore previous, pause/resume automation, settings, and app-window entry.

## Non-Purpose

Do not mix unrelated navigation and destructive actions in the same row without visual separation.

## API

```swift
InnosComponentFactory.actionRow([
    InnosCommandButton(title: "Quick disable", tone: .warning, target: self, action: #selector(quickDisablePressed)),
    InnosCommandButton(title: "Restore previous", target: self, action: #selector(restorePreviousPressed))
])
```

## Tones

- `neutral`: routine command
- `primary`: main continuation or entry point
- `warning`: disruptive temporary command
- `danger`: reserved for destructive actions

## Token Dependencies

- `InnosDesignTokens.background(for:tone:)`
- `InnosDesignTokens.border(for:tone:)`
- `InnosDesignTokens.foreground(for:tone:)`
- `InnosDesignTokens.Size.buttonMinHeight`

## Accessibility

Buttons must expose precise labels. Symbol-only buttons need explicit accessibility labels.

## Route Override Boundary

Routes may choose horizontal or vertical placement at narrow widths. Routes must not redefine tone meanings.

## Guard

Compile shared token/component files and verify action labels appear in the shared specimen.
