# Review All In One

## Short Implementation Explanation

The latest native window pass moved noisy command buttons out of `Current status`, reused the same current-state table on `Current status` and `Display`, moved `Open popover` into the sidebar, and moved page-specific actions such as `Next 19:00` and `Export diagnostics` into the global header row.

This matches the user's direction: detail pages should be quieter, and commands that are really navigation should not sit inside `Current status`.

## Detailed Review Results

### Important: Sidebar `Open popover` has no route-level test

- Evidence: `InnosDimmer/UI/UnifiedAppWindowController.swift` creates a sidebar `Open popover` button with identifier `app-window-sidebar-action:Open popover`, but `InnosDimmerTests/MenuBarStateTests.swift` only checks that the identifier exists.
- Risk: the button can render while silently losing its `target/action` route to `MenuBarCommand.openPopover`.
- Fix: expose a narrow test hook for the sidebar action button and add a test that `performClick(nil)` emits `.openPopover`.

### Important: Sidebar bottom action is mixed into the navigation stack after a generic spacer

- Evidence: `makeSidebar()` builds `buttonViews + [spacer()]` and then appends `openPopoverButton` to the same stack.
- Risk: `spacer()` only lowers horizontal hugging, so it is not an explicit vertical layout primitive. The button is visually intended as a separate sidebar action, not another navigation tile.
- Fix: introduce a dedicated `app-window-sidebar-action-zone` stack and a vertical spacer with vertical hugging priority.

### Minor: The shared current-state table is correct but weakly documented

- Evidence: `makeCurrentStateTable(identifier:)` is reused by `makeCurrentPage()` and `makeDisplayPage()`.
- Risk: future edits can reintroduce divergent status rows because the test names differ by identifier.
- Fix: keep the current helper and add research/plan notes that this is the intended merge point. No extra production code is required in this pass.

## Next Task

1. Add a `sidebarOpenPopoverButtonForTesting()` hook.
2. Split sidebar navigation and sidebar action zone in `makeSidebar()`.
3. Add tests for sidebar action routing and action-zone identifier.
4. Run the focused AppKit unit tests.
