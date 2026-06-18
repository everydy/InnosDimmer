# 2026-06-18 Research - More Reliable Software Dimming Path

## Goal

현재 InnosDimmer의 "소프트웨어로 화면을 어둡게 하는" 작동 방식을 더 확실하게 만들 수 있는지 조사한다.

조사 기준은 다음이다.

- M1 Mac, HDMI 직결 외부 모니터, 개인용 macOS 메뉴바 앱.
- 하드웨어 DDC/CI 밝기 제어는 사용자가 포기한 상태이므로 다시 기본 경로로 되살리지 않는다.
- 모든 디밍은 소프트웨어 디밍 범주에 포함한다.
- 핵심 질문: "새로운 디밍 기술로 바꿔야 하는가, 아니면 현재 오버레이 방식을 강화해야 하는가?"

## Scope And Entry Points

검토한 실행 진입점:

- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/App/InnosDimmerApp.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/App/AppDelegate.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/MenuBarController.swift`

검토한 디밍 경로:

- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/BrightnessController.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/SoftwareDimmingController.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/OverlayWindowManager.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/GammaDimmingController.swift`

검토한 표시 장치/설정/입력 경로:

- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/DisplayInventory.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/DisplayTargetResolver.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/DisplayTargetStore.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/HotkeyManager.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/ScheduleEngine.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/MenuBarPopoverView.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/SettingsWindowController.swift`

검토한 진단/문서:

- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Diagnostics/DiagnosticsExporter.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Diagnostics/VerificationMatrix.swift`
- `/Users/moonsoo/projects/InnosDimmer/README.md`
- `/Users/moonsoo/projects/InnosDimmer/docs/operator-guide.md`
- `/Users/moonsoo/projects/InnosDimmer/docs/qa-matrix.md`
- `/Users/moonsoo/projects/InnosDimmer/docs/release-notes-local.md`

외부 공식 문서 확인:

- Apple `NSWindow.CollectionBehavior`: https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct
- Apple `canJoinAllSpaces`: https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/canjoinallspaces
- Apple `fullScreenAuxiliary`: https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/fullscreenauxiliary
- Apple `stationary`: https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/stationary
- Apple `ignoresCycle`: https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/ignorescycle
- Apple `NSWindow.Level`: https://developer.apple.com/documentation/appkit/nswindow/level-swift.struct
- Apple `screenSaver` level: https://developer.apple.com/documentation/appkit/nswindow/level-swift.struct/screensaver
- Apple `CGSetDisplayTransferByTable`: https://developer.apple.com/documentation/coregraphics/cgsetdisplaytransferbytable(_:_:_:_:_:)
- Apple Quartz Display Services: https://developer.apple.com/documentation/coregraphics/quartz-display-services
- Apple `CGAcquireDisplayFadeReservation`: https://developer.apple.com/documentation/coregraphics/cgacquiredisplayfadereservation(_:_:)
- Apple `NSApplication.didChangeScreenParametersNotification`: https://developer.apple.com/documentation/appkit/nsapplication/didchangescreenparametersnotification
- Apple `NSWorkspace.screensDidWakeNotification`: https://developer.apple.com/documentation/appkit/nsworkspace/screensdidwakenotification
- Apple `NSWorkspace.didWakeNotification`: https://developer.apple.com/documentation/appkit/nsworkspace/didwakenotification

## Relevant Files

현재 코드 기준으로 앱은 하드웨어 DDC 제어를 실행 경로에서 제거하고, `BrightnessController -> SoftwareDimmingController -> OverlayWindowManager` 경로로만 밝기/색감 명령을 처리한다.

중요 파일 역할:

- `BrightnessController.swift`: 현재 디밍 상태를 소유하고, 모든 명령을 소프트웨어 경로로 전달한다.
- `SoftwareDimmingController.swift`: 소프트웨어 디밍 전략의 상위 조합 지점이다. 현재 실질 적용은 오버레이 전략이며, 감마 전략은 clear no-op만 남아 있다.
- `OverlayWindowManager.swift`: 외부 디스플레이 위에 투명한 borderless `NSPanel`을 올리고 black/warm 레이어 opacity로 체감 밝기와 색온도를 조정한다.
- `MenuBarController.swift`: 메뉴바 UI, 단축키, 스케줄, wake/display-change 관찰, 현재 명령 재적용을 묶는다.
- `DisplayInventory.swift`: `NSScreen`/CoreGraphics 기반 활성 디스플레이 목록을 만든다.
- `DisplayTargetStore.swift`: 사용자가 선택한 디스플레이 식별자를 저장한다.
- `DiagnosticsExporter.swift`: 진단 JSON encoder가 존재하지만 UI에 export action이 아직 연결되어 있지 않다.
- `VerificationMatrix.swift`: QA 행 모델과 기본 행이 있지만 `docs/qa-matrix.md`와 자동 동기화되지는 않는다.

## Current Behavior

확인된 현재 실행 흐름:

1. `InnosDimmerApp.main`이 `NSApplication`과 `AppDelegate`를 만들고 `startIfNeeded()`를 호출한다.
2. `AppDelegate.startIfNeeded()`가 accessory activation policy를 설정하고 `MenuBarController`를 시작한다.
3. `MenuBarController.start()`가 설정 로드, 선택 디스플레이 해석, 스케줄 적용, 상태바 아이템 생성, popover 생성, 전역 단축키 등록, wake/display-change observer 등록, 다음 스케줄 타이머 예약을 수행한다.
4. popover, 단축키, 스케줄 명령은 `makeCommand`로 `BrightnessCommand`를 만들고 `BrightnessController.apply`로 전달된다.
5. `BrightnessController.apply`는 현재 구현에서 항상 `applySoftware`를 호출한다.
6. `SoftwareDimmingController.apply`는 `OverlayWindowManager.apply`를 호출한다.
7. `OverlayWindowManager.apply`는 `NSScreenNumber`가 대상 `CGDirectDisplayID`와 일치하는 `NSScreen`을 찾고, 해당 프레임 위에 `NSPanel`을 생성하거나 갱신한다.
8. overlay panel은 `level = .screenSaver`, `collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]`, `ignoresMouseEvents = true`로 설정된다.
9. black layer opacity는 `brightness`를 낮출수록 올라가고, warm layer opacity는 `warmth`를 올릴수록 올라간다.

수동 QA에서 확인된 반복 관찰:

- popover가 외부 `27QA100M` 대상으로 열린다.
- `Brightness down`은 65 -> 60처럼 상태를 바꾸고 실제 체감 dim이 보인다.
- `Warmth up`은 27 -> 32처럼 상태를 바꾸고 warm overlay가 적용된다.
- `Quick disable`은 brightness 100으로 올리고, `Restore previous`는 이전 상태로 되돌린다.
- Finder가 포커스된 상태에서도 기본 단축키 `Option+Shift+Down`이 동작한다.
- Settings 창은 열린다.

## Data Flow And Control Flow

현재 데이터 흐름:

```text
User input / schedule
  -> MenuBarController.makeCommand(...)
  -> BrightnessController.apply(...)
  -> SoftwareDimmingController.apply(...)
  -> OverlayWindowManager.apply(...)
  -> NSPanel + CALayer opacity on target NSScreen frame
```

현재 display 해석 흐름:

```text
DisplayTargetStore.load()
  -> DisplayInventory.activeDisplays()
  -> DisplayTargetResolver.resolve(...)
  -> BrightnessController.state.display
```

현재 wake/display-change 흐름:

```text
NSWorkspace.didWakeNotification
NSWorkspace.screensDidWakeNotification
NSApplication.didChangeScreenParametersNotification
  -> MenuBarController.reconcileDisplaysAndReapply()
  -> stateResolvingSelectedDisplayIfNeeded()
  -> overlayWindowManager.clearStalePanels(activeDisplayIDs:)
  -> reapply current software state
  -> apply schedule decision
```

## Existing Abstractions And Boundaries

잘 잡힌 경계:

- `BrightnessController`는 "무엇을 적용할지" 상태를 관리한다.
- `SoftwareDimmingController`는 "어떤 소프트웨어 전략으로 적용할지"를 숨길 수 있는 경계다.
- `OverlayWindowManager`는 AppKit window/panel 세부 구현을 캡슐화한다.
- `DisplayInventory`/`DisplayTargetResolver`/`DisplayTargetStore`는 디스플레이 선택과 실제 활성 장치 목록을 분리한다.
- `HotkeyManager`는 Carbon hotkey 세부 구현을 UI에서 분리한다.

취약한 경계:

- `OverlayWindowManager.apply`가 대상 screen frame을 찾지 못하면 조용히 return한다. 호출자는 "성공적으로 적용됐다"고 판단할 수 있다.
- `BrightnessController.state.display`가 HDMI 재연결 후 stale display일 수 있다. 현재 `MenuBarController.stateResolvingSelectedDisplayIfNeeded()`는 `state.display == nil`일 때만 재해석한다.
- `SoftwareDimmingController`에는 `platformBlocked`, `applyFailed`, `GammaDimmingController` 같은 미래 확장 흔적이 남아 있지만, 현재 사용자 경로에서는 의미 있는 fallback chain으로 작동하지 않는다.
- `DiagnosticsExporter`는 테스트 가능한 encoder이지만 사용자 UI에서 접근할 수 없다.

## Confirmed Facts

코드베이스에서 확인한 사실:

- 현재 앱은 하드웨어 DDC 제어를 런타임 경로에서 사용하지 않는다.
- `BrightnessController.apply`는 항상 소프트웨어 경로를 호출한다.
- 실질적인 디밍은 `NSPanel` overlay와 `CALayer` opacity로 구현된다.
- overlay panel은 마우스 이벤트를 무시하므로 일반 클릭 흐름을 가로막지 않는다.
- overlay panel은 `.screenSaver` window level과 Spaces/fullscreen 관련 collection behavior를 사용한다.
- display-change/wake observer는 이미 존재한다.
- stale display를 강제로 무효화하거나, frame lookup 실패를 에러로 올리는 처리는 부족하다.
- diagnostics export 구현체는 있지만 Settings/Popover에서 실행하는 UI는 없다.

Apple 공식 문서에서 확인한 사실:

- `NSWindow.CollectionBehavior`는 Mission Control, Spaces, Stage Manager 같은 window management 기술에서 window 표시 특성을 제어하는 설정이다.
- `canJoinAllSpaces`는 window가 모든 Spaces에 나타날 수 있게 하는 옵션이다.
- `fullScreenAuxiliary`는 full-screen window와 같은 Space에 표시되는 보조 window 옵션이다.
- `stationary`는 Mission Control이 window에 영향을 주지 않게 해서 visible/stationary 상태를 유지하게 하는 옵션이다.
- `ignoresCycle`은 window cycle 대상에서 제외하는 옵션이다.
- `NSWindow.Level`은 macOS 표준 window stacking level이며, level stacking은 같은 level 내부 window stacking보다 우선한다.
- `.screenSaver`는 screen saver용 window level이다.
- `CGSetDisplayTransferByTable`은 display의 RGB gamma table 값을 지정해 color gamma function을 설정한다.
- Quartz Display Services는 macOS window server를 통해 display hardware 설정/제어 기능에 직접 접근하는 API 묶음이다.
- `CGAcquireDisplayFadeReservation`은 fade hardware를 일정 시간 예약하는 API이며, 예약이 끝나면 hardware가 normal state로 돌아간다.
- `NSApplication.didChangeScreenParametersNotification`은 연결된 display configuration이 바뀔 때 올라온다.
- `NSWorkspace.screensDidWakeNotification`과 `NSWorkspace.didWakeNotification`은 screen/device wake 시점 재적용 hook으로 사용할 수 있다.

## Repeated Observations

현 코드와 QA에서 반복적으로 보이는 점:

- 현재 오버레이 방식은 일반 desktop, popover, Finder focus, global hotkey에서 동작한다.
- 문제 가능성이 높은 지점은 "디밍 수식"이 아니라 "언제 어느 디스플레이에 overlay를 다시 붙이는지"다.
- HDMI 재연결, sleep/wake, display off/on, full-screen Space 전환 같은 lifecycle 구간에서 stale state와 silent no-op이 가장 큰 실패 원인 후보다.
- Settings/문서에 보이는 진단/검증 문구가 실제 UI wiring보다 앞서 있다.

## Inference

현재 앱을 더 확실하게 만드는 1순위는 다른 디밍 기술로 갈아타는 것이 아니라, 현재 오버레이 방식을 lifecycle-safe하게 만드는 것이다.

이유:

- overlay는 개인용 앱에서 권한 요구가 적고, 하드웨어/케이블/모니터 OSD/DDC 구현에 덜 의존한다.
- Apple의 AppKit window level/collection behavior 모델 안에서 구현되어 있다.
- 사용자가 실제로 원하는 것은 하드웨어 밝기값 변경보다 "체감 밝기 낮추기"다.
- gamma table은 더 시스템 전역적이고 복구 실패 시 부작용이 크다.
- fade hardware API는 일시적 fade용 예약 모델이라 지속 밝기 조절의 기본 엔진으로 맞지 않는다.

## Candidate Methods Ranked

### 1. Keep Overlay As Primary, Harden Target/Lifecycle Handling

추천도: 매우 높음.

목표:

- "적용했다고 상태는 바뀌었는데 화면은 안 어두워짐"을 줄인다.
- HDMI 재연결/wake/display-change 후 대상 display가 바뀌어도 다시 정확히 붙인다.
- overlay frame lookup 실패를 진단 가능한 에러로 만든다.

구체 변경:

- `BrightnessController.state.display`가 현재 `DisplayInventory.activeDisplays()`에 없는 경우 stale로 보고 재해석한다.
- `OverlayWindowManager.apply`가 target screen frame을 못 찾으면 silent return 대신 `SoftwareDimmingError.displayUnavailable(displayID:)`를 throw한다.
- `MenuBarController.reconcileDisplaysAndReapply()`에서 display-change 이벤트를 debounce한다.
- wake/screen wake/display-change 후 현재 상태와 schedule decision을 명확한 순서로 다시 적용한다.
- active display가 없거나 target이 사라지면 UI/diagnostics에 "waiting for display" 상태를 보여준다.

핵심 코드 스니펫:

```swift
private func resolveFreshDisplayForCommand() -> DisplayIdentity? {
    let activeDisplays = displayInventory.activeDisplays()

    if let current = brightnessController.state.display,
       activeDisplays.contains(where: { $0.cgDisplayID == current.cgDisplayID }) {
        return current
    }

    let selected = displayTargetStore.load()
    let resolved = displayTargetResolver.resolve(selected, from: activeDisplays)
    brightnessController.state.display = resolved
    return resolved
}
```

```swift
func apply(command: BrightnessCommand) throws {
    guard let frame = screenFrame(for: command.display.cgDisplayID) else {
        throw SoftwareDimmingError.displayUnavailable(command.display.cgDisplayID)
    }

    let panel = panel(for: command.display.cgDisplayID, frame: frame)
    configure(panel: panel, frame: frame)
    updateLayers(in: panel, command: command)
    panel.orderFrontRegardless()
}
```

예상 부작용:

- display-change가 많이 발생하는 환경에서 재적용이 너무 잦을 수 있다.
- debounce가 필요하다.

검증:

- HDMI 분리/재연결 후 overlay 재생성.
- sleep/wake 후 overlay 재적용.
- full-screen app Space에서 overlay 유지.
- Quick disable/restore가 stale display를 남기지 않는지 확인.

### 2. Add Gamma Table Strategy As Optional Experimental Secondary Strategy

추천도: 중간.

목표:

- overlay가 특정 full-screen/Space 상황에서 보이지 않을 때 보조 수단을 연구할 수 있게 한다.

제약:

- `CGSetDisplayTransferByTable`은 display gamma table을 바꾸므로 overlay보다 시스템 전역 부작용이 크다.
- 색 관리, Night Shift, True Tone, HDR, 다른 보정 앱과 충돌 가능성이 있다.
- 복구 실패 시 화면 색이 이상하게 남을 수 있으므로 snapshot/restore가 필수다.

도입 조건:

- 기본값 off.
- Settings의 Advanced/Experimental 아래에 숨김.
- 적용 전 현재 gamma table을 snapshot한다.
- 앱 종료, quick disable, display change, crash 이후 다음 launch에서 restore 시도한다.
- 실패하면 즉시 overlay-only로 돌아간다.

핵심 코드 스니펫:

```swift
protocol DimmingStrategy {
    func apply(command: BrightnessCommand) throws
    func clear(display: DisplayIdentity) throws
}

final class GammaDimmingController: DimmingStrategy {
    private var snapshots: [CGDirectDisplayID: GammaSnapshot] = [:]

    func apply(command: BrightnessCommand) throws {
        let displayID = command.display.cgDisplayID
        if snapshots[displayID] == nil {
            snapshots[displayID] = try readCurrentGamma(displayID)
        }

        let table = makeGammaTable(brightness: command.brightness, warmth: command.warmth)
        let result = CGSetDisplayTransferByTable(
            displayID,
            UInt32(table.red.count),
            table.red,
            table.green,
            table.blue
        )

        guard result == .success else {
            throw SoftwareDimmingError.applyFailed("gamma table result: \(result)")
        }
    }

    func clear(display: DisplayIdentity) throws {
        guard let snapshot = snapshots[display.cgDisplayID] else { return }
        try restore(snapshot, to: display.cgDisplayID)
        snapshots[display.cgDisplayID] = nil
    }
}
```

권장 판단:

- 지금 당장 기본 방식으로 도입하지 않는다.
- overlay hardening 이후에도 full-screen/Space 한계가 실제 QA에서 반복될 때만 experimental로 넣는다.

### 3. Display Fade APIs As Persistent Dimming

추천도: 낮음.

이유:

- `CGAcquireDisplayFadeReservation`은 fade hardware를 제한 시간 동안 예약하고, 시간이 끝나면 normal state로 돌아가는 모델이다.
- 공식 문서상 지속적인 개인용 밝기 조절 엔진보다는 전환/fade 효과에 가까운 API다.
- per-display brightness slider와 schedule dimming의 기본 엔진으로 맞지 않는다.

권장 판단:

- 기본 구현 후보에서 제외한다.
- 앱 launch/quit 전환 효과 같은 별도 UX가 필요할 때만 검토한다.

### 4. Return To DDC/CI Hardware Brightness

추천도: 매우 낮음.

이유:

- 사용자가 이미 직접 조작 실패를 관찰했고, 방향을 소프트웨어 디밍으로 전환했다.
- HDMI, M1, 모니터 DDC 구현 조합은 실패 가능성이 크다.
- 개인용 앱 목표에는 "체감 밝기 낮추기"가 더 직접적이다.

권장 판단:

- 되살리지 않는다.
- 관련 dead code/doc 흔적은 정리한다.

## Recommended Plan Implications

다음 구현은 "새 디밍 엔진"이 아니라 "overlay primary hardening"으로 잡는 것이 맞다.

우선순위:

1. `OverlayWindowManager.apply`의 silent return 제거.
2. stale display validation 추가.
3. display-change/wake 재적용 debounce 추가.
4. diagnostics에 last apply result, target display, active display IDs, frame lookup result 기록.
5. Settings/문서의 diagnostics export 불일치 해소.
6. dead/future stubs 정리: `pendingCommand`, `applyPendingPreview`, `forcedSoftwareTest`, user-unreachable gamma/platform error enum 등.
7. overlay hardening 이후에도 실제 QA에서 full-screen/Space 한계가 반복되면 gamma strategy를 experimental로 연구한다.

권장 구현 순서:

```text
Unit 1: Overlay apply result를 명시적 성공/실패로 바꾸기
Unit 2: display resolver를 nil-only가 아니라 stale-aware로 바꾸기
Unit 3: wake/display-change debounce와 reapply 순서 안정화
Unit 4: diagnostics export UI 또는 문서 문구 중 하나 정합화
Unit 5: dead/future code cleanup
Unit 6: 수동 QA matrix 재실행
```

## Do Not Duplicate Or Bypass

- `OverlayWindowManager` 밖에서 직접 overlay panel을 만들지 않는다.
- `MenuBarController`에서 AppKit window 구현 세부사항을 늘리지 않는다.
- `BrightnessController`가 직접 `NSScreen` frame을 찾게 하지 않는다.
- `DisplayInventory`를 우회해서 `NSScreen.screens`를 여러 곳에서 직접 읽지 않는다.
- gamma table을 기본 fallback으로 몰래 켜지 않는다.
- DDC/CI 하드웨어 제어를 기본 경로로 되살리지 않는다.

## Risk To Surrounding Systems

오버레이 hardening의 위험:

- `.screenSaver` level overlay가 특정 system UI 위에 표시될 수 있다.
- display-change debounce가 너무 길면 재연결 직후 dim이 늦게 돌아온다.
- debounce가 너무 짧으면 display off/on 상황에서 재적용이 과도하게 반복될 수 있다.
- full-screen/Stage Manager/Spaces 조합은 AppKit behavior 옵션을 써도 실제 OS 정책 영향이 남을 수 있다.

gamma strategy의 위험:

- 시스템 색 보정/Night Shift/True Tone/HDR과 충돌할 수 있다.
- 앱 crash 시 restore가 늦어질 수 있다.
- 복수 모니터 환경에서 per-display table snapshot/restore 실패가 사용자에게 크게 보일 수 있다.

문서/진단 위험:

- "diagnostics export available"이라고 쓰여 있는데 UI가 없으면 사용자가 기능이 있다고 믿고 찾게 된다.
- `VerificationMatrix.defaultRows`와 `docs/qa-matrix.md`가 따로 놀면 QA 상태가 실제와 달라질 수 있다.

## Open Questions

- 사용자가 가장 자주 쓰는 모드가 일반 desktop인지, full-screen 앱인지, Stage Manager인지 추가 확인이 필요하다.
- 실제 HDMI 분리/재연결 QA에서 `NSScreenNumber`가 같은 `CGDirectDisplayID`로 돌아오는지, 새 ID로 바뀌는지 확인해야 한다.
- full-screen Space에서 현재 `.screenSaver + fullScreenAuxiliary` 조합이 사용자 환경에서 항상 보이는지 수동 QA가 필요하다.
- gamma strategy를 실험할 경우 Night Shift/True Tone/HDR이 켜져 있는지 확인해야 한다.

## Evidence

코드 조사:

- `BrightnessController.swift`: `apply`는 현재 software path로만 진입한다.
- `MenuBarController.swift`: display state는 nil일 때만 재해석되는 구조이며, stale display validation은 부족하다.
- `OverlayWindowManager.swift`: target screen frame이 없으면 silent return하는 구조가 관찰됐다.
- `SoftwareDimmingController.swift`: overlay strategy는 실질 구현, gamma clear는 no-op이다.
- `SettingsWindowController.swift`: diagnostics export 가능 문구는 있으나 export button/action은 없다.
- `DiagnosticsExporter.swift`: JSON encoder는 존재한다.
- `VerificationMatrix.swift`: matrix model/default rows는 존재하지만 docs matrix와 자동 동기화되지 않는다.

Apple 공식 문서 조사:

- AppKit window collection behavior는 Spaces/Mission Control/Stage Manager 표시 특성을 제어하는 용도다.
- `canJoinAllSpaces`, `fullScreenAuxiliary`, `stationary`, `ignoresCycle`는 현재 overlay panel에 쓰는 방향과 맞다.
- `NSWindow.Level.screenSaver`는 높은 stacking level을 부여하는 데 적합하지만, 이것만으로 모든 OS 표시 상황을 보장한다고 해석하면 안 된다.
- CoreGraphics gamma table API는 display gamma function을 설정할 수 있으나, persistent user dimming의 기본 엔진으로 쓰기에는 복구/색관리 리스크가 크다.
- fade reservation API는 제한 시간 fade hardware 예약 모델이라 지속 디밍 엔진과 맞지 않는다.
- display-change/wake notification은 이미 앱이 관찰하는 방향과 맞으며, 그 위에 stale validation/debounce를 얹는 것이 자연스럽다.

## Recommendation

결론: 더 확실한 방법은 "DDC나 gamma로 갈아타기"가 아니라 "현재 overlay 방식을 실패 감지 가능하고 display lifecycle에 강하게 만드는 것"이다.

가장 먼저 고칠 부분:

1. `OverlayWindowManager.apply` silent return 제거.
2. `BrightnessController.state.display` stale 여부 검증.
3. HDMI 재연결/wake/display-change 후 target display 재해석.
4. 재적용 결과를 diagnostics에 남김.
5. 문서와 UI의 diagnostics export 불일치 정리.

이 조합이 현재 앱 목표인 "개인용 macOS HDMI 외부 모니터 체감 밝기/색감 조정"에 가장 부작용이 적고 성공 가능성이 높다.
