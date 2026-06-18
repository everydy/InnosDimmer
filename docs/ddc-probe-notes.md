# DDC Probe Notes

Status: archived internal reference. The current user-facing MVP is software-overlay only and does not expose DDC probing or hardware brightness control in normal operation.

The app implements the hardware DDC probe strategy as a testable state machine. It does not yet include a real reviewed IOKit DDC adapter for the INNOS 27QA100M.

## Safety Policy

- Probe only VCP brightness behavior.
- Read current brightness first.
- Choose a reversible probe value one step away from the current value.
- Write the probe value.
- Read back and require the probe value to match.
- Restore the original brightness.
- Enable `hardwareDDC` only after write/readback succeeds and restore succeeds.

## Failure Classification

| Failure | Capability |
| --- | --- |
| Brightness read fails | `unsupported(reason: "brightness read failed")` |
| Write/readback fails after a successful read | `failedWithError(message: "write/readback failed")` |
| Original brightness restore fails | `failedWithError(message: "restore original brightness failed")` |

## Current Adapter

`NoopDDCAdapter` is the default adapter and always fails reads/writes. This prevents accidental monitor writes before a real IOKit adapter is implemented and reviewed.

`HardwareDDCController.applyHardware(_:)` writes through the injected adapter only after policy has classified the display as write/readback supported. With the default adapter, real hardware writes still fail safely and route back through the software fallback policy.

## M1 Direct HDMI Notes

- Treat DDC as unverified until the local probe succeeds on the actual HDMI connection.
- A failed read means hardware mode is unsupported for the current run.
- A failed write/readback or failed restore means hardware mode is exhausted and software dimming may activate with an explicit reason.
- Never mark hardware control as verified based only on the display name or vendor/model identifiers.
