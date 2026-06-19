# Dimming Control Group Contract

## Purpose

Represent brightness and blue reduction as adjustable values with consistent order and affordance.

## Non-Purpose

Do not use paired text buttons as the primary representation for dimming values when the current value is known.

## API

```swift
InnosDimmingControlGroupView(
    title: "Brightness",
    value: "45%",
    fraction: 0.45,
    decrementAction: #selector(brightnessDownPressed),
    incrementAction: #selector(brightnessUpPressed),
    target: self
)
```

## Required Order

```text
Label -> Value -> Track -> Decrement -> Increment
```

## Variants

Brightness and blue reduction share the same component. The label and accessibility text change; layout does not.

## Token Dependencies

- `InnosDesignTokens.Size.dimmingLabelWidth`
- `InnosDesignTokens.Size.dimmingValueWidth`
- `InnosDesignTokens.Size.trackHeight`
- `InnosDesignTokens.trackBackground`
- `InnosDesignTokens.accent`
- `InnosDesignTokens.Font.value`

## Accessibility

The group exposes a combined label such as `Brightness 45%`. Step buttons need specific labels when inserted into a real surface.

## Route Override Boundary

Routes may widen the track through surrounding layout. Routes must not reorder label, value, track, and step controls.

## Guard

Compile shared token/component files and verify `Brightness` and `Blue reduction` appear in the shared specimen.
