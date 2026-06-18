# DDC Probe Notes

Status: archived internal reference. The current user-facing app is software-overlay only and does not expose DDC probing or hardware brightness control in normal operation.

This document records the earlier DDC probe design. It is not current runtime policy. The active app should not call DDC probe or hardware brightness paths during normal operation.

## Safety Policy

- Probe only VCP brightness behavior.
- Read current brightness first.
- Choose a reversible probe value one step away from the current value.
- Write the probe value.
- Read back and require the probe value to match.
- Restore the original brightness.
- Historical policy: enable `hardwareDDC` only after write/readback succeeds and restore succeeds.

## Failure Classification

| Failure | Capability |
| --- | --- |
| Brightness read fails | `unsupported(reason: "brightness read failed")` |
| Write/readback fails after a successful read | `failedWithError(message: "write/readback failed")` |
| Original brightness restore fails | `failedWithError(message: "restore original brightness failed")` |

## Current Adapter

`NoopDDCAdapter` was the default adapter for the archived DDC state machine and always failed reads/writes. This prevented accidental monitor writes before a real IOKit adapter could be reviewed.

The active software-only runtime no longer routes brightness commands through `HardwareDDCController`.

## M1 Direct HDMI Notes

- Treat DDC as unverified and outside the current app runtime.
- A failed read previously meant hardware mode was unsupported for the current run.
- A failed write/readback or failed restore previously meant hardware mode was exhausted.
- Never mark hardware control as verified based only on the display name or vendor/model identifiers.
