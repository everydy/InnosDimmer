# DDC Probe Notes

Commit 6 implements the hardware DDC probe strategy as a testable state machine. It does not yet send real IOKit DDC commands to the INNOS 27QA100M.

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
