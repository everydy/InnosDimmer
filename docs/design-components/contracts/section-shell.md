# Section Shell Contract

## Purpose

Frame a related command group without making popover or app-window surfaces feel decorative.

## Non-Purpose

Do not use section shells as marketing cards, metric cards, or nested cards inside other cards.

## API

```swift
InnosSectionView(style: .section, content: content)
InnosComponentFactory.section(title: "Quick controls", trailing: chip, views: rows)
```

## Variants

- `section`: normal grouped controls
- `subtle`: lower emphasis nested status or diagnostics content

## Token Dependencies

- `InnosDesignTokens.surfaceSection`
- `InnosDesignTokens.surfaceSubtle`
- `InnosDesignTokens.border`
- `InnosDesignTokens.Radius.section`
- `InnosDesignTokens.Spacing.sectionPadding`

## Accessibility

The section itself is structural. Interactive children own labels and focus.

## Route Override Boundary

Routes may control placement, width, and ordering. Routes must not redefine base radius, border, padding, or surface colors.

## Guard

Compile shared token/component files and review `docs/design/shared-control-system/specimen.html`.
