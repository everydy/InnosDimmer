# InnosDimmer App Window Redesign Feedback

## Target

Redesign only the standalone app/settings window. The menu bar popover remains the quick-control surface.

## Current Issues

1. The current `SettingsWindowController` uses a single vertical `NSScrollView` form inside a 500x620 window. It works functionally, but every feature has the same visual weight.
2. The window mixes target display, schedule summary, shortcut editing, startup, diagnostics, verification, export, and transient status in one long stack.
3. The user has to read section labels instead of recognizing destinations. This makes the window feel like a debug form rather than a personal utility app.
4. The schedule and shortcut sections are dense enough that scrolling becomes the primary navigation model.
5. Diagnostics are present, but they are not positioned as a first-class troubleshooting page, even though runtime failures are important for this app.

## Coverage Audit

The revised mockup was checked against the current popover and the current settings window.

| Source surface | Existing function or pattern | Revised mockup coverage |
| --- | --- | --- |
| Popover quick controls | Brightness value, slider track, `-` and `+` step controls | Home and `Current controls` page reuse the same control group pattern |
| Popover quick controls | Blue reduction value, slider track, `-` and `+` step controls | Home and `Current controls` page reuse the same control group pattern |
| Popover actions | `Quick disable`, `Restore previous`, `Pause automation` / `Resume automation` | Home, `Current controls`, and `Automation` pages include these actions |
| Popover status | Display, mode, brightness/blue line, automation status | Home current snapshot and detail-page side summaries include these lines |
| Popover schedule | Schedule summary and next boundary chip | Home status and `Automation` page include summary plus schedule rows |
| Popover diagnostics dashboard | Recent diagnostic log | `Diagnostics` page includes readable recent log |
| Settings window | Target display picker | `Display` page includes selected display, resolved display, and save/use automatic actions |
| Settings window | `Open schedule editor` | `Automation` page includes `Open schedule editor` |
| Settings window | Shortcut table and save/reset | `Shortcuts` page includes full table and save/reset actions |
| Settings window | `Launch at login` and status summary | Renamed `Startup` to `Settings`; launch-at-login lives there |
| Settings window | Diagnostics summary, verification matrix, export | `Diagnostics` page includes verification matrix and `Export diagnostics` |
| Settings window | Transient `statusLabel` | `Settings` page includes a status-label row; footer also carries page status |
| Current code change | `ShortcutAction.openPopover` | `Shortcuts` page now includes `Open popover` as the seventh shortcut |

The previous mockup missed or underweighted:

- the reusable popover `Quick controls` component language
- the current snapshot as a real control area
- `Open popover` shortcut
- the existing settings `statusLabel`
- the idea that `Startup` is only one setting, not a full top-level category

## Recommended Information Architecture

Use a page hub instead of a scroll form.

```text
App Window
  Home
    Current controls
    Display
    Automation
    Shortcuts
    Settings
    Diagnostics
  Detail Page
    Back
    Compact current-state summary where useful
    Local summary
    Primary controls
    Footer status
```

The home screen should put the current snapshot first, then show a stable icon-card grid. Each card is a destination, not a collapsible section. Detail pages should show one task family at a time and return through a predictable Back button.

## Why This Fits InnosDimmer

- The app is a small macOS utility, not a dashboard. A hub-and-page model keeps the surface compact.
- The user usually knows the category they want: display, automation, shortcuts, startup, or diagnostics.
- A no-scroll preferred window is more reliable for AppKit than trying to cram every state into one stack.
- Diagnostics can become a readable page with recent failure logs instead of being a single export button.

## Proposed Window Shape

- Preferred window size: `760x560`
- Minimum window size: `700x520`
- Default theme: dark utility surface
- Radius: `8px` or less
- Navigation model: one root page plus one active detail page
- Back behavior: visible on all detail pages, hidden on home
- Scrolling: avoid vertical scrolling at the preferred size; use compact rows and summaries

## Page-Level Feedback

### Home

The home page should answer: "What needs attention, and where do I go?"

Recommended content:

- Current snapshot with brightness and blue-reduction controls
- Quick disable, restore previous, and pause/resume automation
- 6 destination cards
- One compact recent status strip
- No long tables

### Current controls

This page should reuse the popover's most familiar UI:

- `Quick controls` section title
- Automation status chip
- brightness control group
- blue-reduction control group
- `Quick disable`
- `Restore previous`
- pause/resume automation

### Display

Keep this page narrow in scope, but do not make it feel visually unrelated to the popover:

- selected display
- detection mode
- last resolved display
- refresh/rescan action
- compact current-state summary

Do not place schedule or shortcuts here.

### Automation

This page should show the automation state, not the entire editor.

Recommended content:

- automation status
- next scheduled change
- 3 compact schedule rows
- pause/resume control
- open full schedule editor action if the full editor remains separate

### Shortcuts

Use a compact table, but only here. The home page should not show shortcut internals.

Recommended content:

- enabled count
- conflicts/missing state
- six shortcut rows
- save/reset actions

### Startup

Startup should not be a top-level page name. It is a setting inside `Settings` because macOS login behavior is only one durable app preference.

Recommended content:

- Launch at login toggle
- current status string
- System Settings approval hint when needed
- last update message
- saved settings summary
- transient settings status label

### Diagnostics

Make diagnostics readable, not just exportable.

Recommended content:

- current health summary
- recent failure log
- verification matrix summary
- export button
- copy latest issue action

## Implementation Direction

Keep the existing actions, but change the view model from one stacked form to a page enum.

```swift
private enum SettingsPage: CaseIterable {
    case home
    case current
    case display
    case automation
    case shortcuts
    case settings
    case diagnostics
}
```

The controller can keep the existing `SettingsActions`, but `installContent()` should build a root container whose content is replaced when the active page changes.

```swift
private var activePage: SettingsPage = .home {
    didSet {
        renderActivePage()
    }
}

private func renderActivePage() {
    pageContainer.subviews.forEach { $0.removeFromSuperview() }
    let nextView: NSView
    switch activePage {
    case .home:
        nextView = makeHomePage()
    case .current:
        nextView = makeCurrentControlsPage()
    case .display:
        nextView = makeDisplayPage()
    case .automation:
        nextView = makeAutomationPage()
    case .shortcuts:
        nextView = makeShortcutsPage()
    case .settings:
        nextView = makeSettingsPage()
    case .diagnostics:
        nextView = makeDiagnosticsPage()
    }
    pageContainer.addSubview(nextView)
    pin(nextView, to: pageContainer)
}
```

Each detail page should share the same header pattern.

```swift
private func makePageHeader(title: String, subtitle: String) -> NSView {
    let backButton = NSButton(title: "Back", target: self, action: #selector(backToHome))
    backButton.bezelStyle = .rounded

    let titleLabel = NSTextField(labelWithString: title)
    titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)

    let subtitleLabel = NSTextField(labelWithString: subtitle)
    subtitleLabel.textColor = .secondaryLabelColor
    subtitleLabel.maximumNumberOfLines = 2

    return horizontalHeader(backButton, titleLabel, subtitleLabel)
}
```

The popover control group should become a shared construction pattern in the AppKit implementation rather than being visually re-created differently for each page.

```swift
private func makeDimmingControlGroup(
    title: String,
    valueLabel: NSTextField,
    trackView: ProgressTrackView,
    decrement: NSButton,
    increment: NSButton
) -> NSView {
    // Same visual pattern as MenuBarPopoverView.makeControlGroup.
    // The app window can use wider columns, but the meaning and control order should match.
}
```

## Mockup

Review artifact:

`docs/design/window-redesign/mockup.html`

This mockup is intentionally static except for page switching and theme preview. It is not wired to real app data.

## Remaining Decisions

1. Whether the app window should replace the old settings window entirely or open as a new "Dashboard" while settings stays separate.
2. Whether schedule editing should remain in `ScheduleEditorWindowController` or move into the Automation page.
3. Whether diagnostics should show in-memory recent events, exported JSON preview, or both.
4. Whether the popover and app window should share AppKit view helpers for control groups, status chips, action rows, and summary rows.
