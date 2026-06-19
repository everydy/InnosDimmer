# Summary Row Contract

## Purpose

Show stable key/value information for display, mode, automation, schedule, shortcuts, and diagnostics summaries.

## Non-Purpose

Do not use summary rows for dense editable tables.

## API

```swift
InnosComponentFactory.summaryRow(title: "Display", value: "27QA100M")
```

## Token Dependencies

- `InnosDesignTokens.Size.summaryLabelWidth`
- `InnosDesignTokens.Font.body`
- `InnosDesignTokens.Font.bodyEmphasis`
- `InnosDesignTokens.Spacing.rowGap`

## Accessibility

Value text must wrap instead of clipping or forcing horizontal scroll.

## Route Override Boundary

Routes may change the label column width only when the full surface requires it. They must preserve key/value meaning.

## Guard

Compile shared token/component files and verify summary rows appear in the shared specimen.
