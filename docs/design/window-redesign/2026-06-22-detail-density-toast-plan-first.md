# 2026-06-22 Detail Density And Toast Plan First

## Goal

Make the unified InnosDimmer app window feel stable when selecting sidebar detail pages. The outer frame is already fixed; this plan focuses on the internal causes of perceived jumping:

- global header shows `InnosDimmer` even on detail pages
- overview status chips appear on every detail page
- Display page still uses an unnecessary two-column split
- Diagnostics page uses tall boxed rows and a tall log area
- save/copy/export feedback appears as inline status text that takes layout space

## Refined Request

Refactor the native AppKit unified app window so detail pages use compact, consistent one-column content layouts and page-specific headers. Preserve Overview as the operational dashboard, but hide overview-only badges from detail pages. Replace inline save/copy/export status labels with transient popup/toast feedback that auto-dismisses. Verify with focused native UI tests and commit the implementation.

## Evidence Basis

- Research: `/Users/moonsoo/projects/InnosDimmer/docs/design/window-redesign/research.md`
- Main implementation file: `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/UnifiedAppWindowController.swift`
- Component file: `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/DesignSystem/InnosDesignComponents.swift`
- Tests: `/Users/moonsoo/projects/InnosDimmer/InnosDimmerTests/MenuBarStateTests.swift`

## Current Codebase Findings

| Area | Current behavior | Plan decision |
| --- | --- | --- |
| Header title | `renderActivePage()` sets `titleLabel.stringValue = "InnosDimmer"` | Use `activePage.title` so detail pages show `Current status`, `Display`, etc. |
| Header chips | `modeChip` and `loginChip` are always in the header | Keep visible only on Overview. Hide on detail pages. |
| Inline status | `report` makes `statusLabel` visible in `contentStack` | Replace with overlay toast; keep status label hidden. |
| Display layout | `makeDisplayPage()` uses `makeDetailSplit` | Convert to vertical sections: Current state, Target display, Saved selection. |
| Diagnostics matrix | five boxed token rows | Use compact summary table rows. |
| Diagnostics log | scroll view height is `>= 220` | Use fixed compact height with internal scrolling. |

## Skill Routing Manifest

| Phase | Required skills | Optional skills | Evidence |
| --- | --- | --- | --- |
| Commit 1: Header and detail density contracts | `요청개선`, `research`, `plan-first-implementation`, `구현커밋` | `review-all-in-one` | User requested refined scope, research, plan-first, then implementation. Evidence is in `UnifiedAppWindowController.swift` and `MenuBarStateTests.swift`. |
| Commit 2: Popup toast feedback | `요청개선`, `research`, `plan-first-implementation`, `구현커밋` | `review-all-in-one` | Inline `statusLabel` causes layout-space feedback; user requested popup auto-dismiss feedback. |
| Final Gate | `구현커밋` | `테스트`, `review-all-in-one` | Focused native XCTest and stale text/identifier checks. |

## Implementation Plan

### Commit 1: Header and detail density contracts

- 대상 파일:
  - `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/UnifiedAppWindowController.swift`
  - `/Users/moonsoo/projects/InnosDimmer/InnosDimmerTests/MenuBarStateTests.swift`
- 변경:
  - `renderActivePage()`에서 global header title을 `activePage.title`로 설정한다.
  - `.home`이 아닐 때 `modeChip`, `loginChip`을 숨긴다.
  - Display page를 `makeDetailSplit` 대신 vertical stack으로 구성한다.
  - Diagnostics matrix를 `makeSummaryTable`로 바꾼다.
  - Diagnostics log height를 compact fixed height로 낮춘다.
- 코드 스니펫:

```swift
titleLabel.stringValue = activePage.title
modeChip.isHidden = activePage != .home
loginChip.isHidden = activePage != .home
```

```swift
return makeDetailPage(
    title: "Display",
    content: verticalStack([
        makeSection(title: "Current state", ...),
        makeSection(title: "Target display", ...),
        makeSection(title: "Saved selection", ...)
    ])
)
```

- 검증:
  - Detail page visible text should not include overview-only header badges.
  - Display page should no longer expose `app-window-detail-split`.
  - Diagnostics should still expose code-log identifiers and copy/export controls.
- 중단 조건:
  - Display picker save flow breaks.
  - Diagnostics copy/export tests regress.

### Commit 2: Popup toast feedback

- 대상 파일:
  - `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/UnifiedAppWindowController.swift`
  - `/Users/moonsoo/projects/InnosDimmer/InnosDimmerTests/MenuBarStateTests.swift`
- 변경:
  - `statusLabel` inline display를 사용하지 않는다.
  - `report(_:, isError:)`는 root content view에 toast view를 띄운다.
  - toast는 성공/오류 톤을 구분하고 몇 초 뒤 자동으로 사라진다.
  - 새 report가 들어오면 기존 toast를 제거하고 최신 toast만 표시한다.
- 코드 스니펫:

```swift
private func report(_ message: String, isError: Bool = false) {
    statusLabel.isHidden = true
    showToast(message, isError: isError)
}
```

```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { [weak self, weak toast] in
    guard self?.toastView === toast else { return }
    toast?.removeFromSuperview()
    self?.toastView = nil
}
```

- 검증:
  - save/copy action tests can observe `app-window-toast`.
  - inline status label remains hidden.
  - focused `MenuBarStateTests` passes.
- 중단 조건:
  - toast blocks controls or causes constraint warnings in tests.

## Operator Decision Needed

- 없음. The user gave concrete defaults: page title in the global header, overview chips only on Overview, Display one-column vertical sections, compact Diagnostics table/log, popup auto-dismiss feedback.

## Review Artifact

- Primary review surface: native InnosDimmer app window.
- HTML artifact: omitted for this pass because the user explicitly requested immediate implementation after research and plan, and the defects are native AppKit runtime/layout issues rather than a new mockup direction.
- Existing mockup reference: `/Users/moonsoo/projects/InnosDimmer/docs/design/window-redesign/app-window-componentized-mockup.html`

## Verification Plan

```bash
xcodebuild test -scheme InnosDimmer -only-testing:InnosDimmerTests/MenuBarStateTests CODE_SIGNING_ALLOWED=NO
git diff --check
```

Additional focused checks:

```bash
rg -n "titleLabel.stringValue = \"InnosDimmer\"|statusLabel.isHidden = false|makeDetailSplit\\(" InnosDimmer/UI/UnifiedAppWindowController.swift InnosDimmerTests/MenuBarStateTests.swift
```

## Plan Quality Check

- Alternative considered: keep the fixed outer frame and only reduce window min/max. Rejected because the user reports remaining perceived jumps are caused by internal page density.
- Why this plan: it targets the exact local code paths that cause global header clutter, display split width pressure, diagnostics height pressure, and inline status layout changes.
- Tradeoff: toast feedback is less persistent than inline text, but the user explicitly prefers popup auto-dismiss feedback.
- What this plan may still miss: if a specific page still visually feels too tall after compacting Display and Diagnostics, it may need page-specific component tuning.
- When to stop and revise: if focused tests show display selection, diagnostics export/copy, or launch-at-login side effects break.

## 후행 실행

- `구현커밋`

## Implementation Result

- 완료:
  - Global header title now follows the selected navigation page instead of repeating `InnosDimmer`.
  - Overview-only chips are physically removed from the header stack on detail pages, so `Paused` / `Login item on` no longer consume detail-page space.
  - Display now uses one vertical flow with `Current state`, `Target display`, and `Saved selection` sections instead of the old split layout.
  - Diagnostics now uses a compact verification summary table plus a short scrollable code-style log area.
  - `report(_:)` now routes save/copy/export feedback through an auto-dismissing toast and keeps the inline status label hidden.
- 검증:
  - `xcodebuild test -scheme InnosDimmer -only-testing:InnosDimmerTests/MenuBarStateTests CODE_SIGNING_ALLOWED=NO` passed.
  - `git diff --check` passed.
