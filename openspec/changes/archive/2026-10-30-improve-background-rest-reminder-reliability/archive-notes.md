# Archive record

- Change: `improve-background-rest-reminder-reliability`
- Archive date: 2026-10-30 (Asia/Hong_Kong)
- Schema: `spec-driven`
- The user explicitly requested archiving after the implementation and audit reports. This archive records the current delivery; it does not certify full acceptance.
- Planning artifacts are complete. The task file contains 30 checked and 5 unchecked tasks. Existing checkbox states are preserved.
- Main-spec synchronization is skipped under the user's existing instruction. The three delta specs remain with this archive: `android-rest-delivery` (new capability, five added requirements), `app-diagnostics` (one added requirement), and `workout-session` (two modified and one added requirement). Main specifications remain unchanged.

## Open acceptance work

- 7.2: remaining Android API/platform matrix; existing device evidence is API36 only.
- 7.3: physical Xiaomi HyperOS with default background restrictions.
- 7.4: physical Xiaomi HyperOS with unrestricted background, independently recorded.
- 7.5: remaining release fault/recovery scenarios, including an actual process death after claim commit and before output.
- 7.6: paired 30-minute resource measurements and the actual four-hour lease/resource run.

## Audit findings carried forward

1. The restore-protector callback currently runs for every `DataWriteCoordinator.exclusive` operation. Backup overview and export snapshot reads also use this entry, so a read-only backup operation can stop the training reminder service. This defect remains unresolved; archive does not apply a repair.
2. Task 3.5 is checked in the retained task file, but current evidence does not fully justify its process-death coverage. Replay rejection, a main-thread failure, and a Task Manager stop are recorded; they do not establish the exact post-claim/pre-output process-death and reconstruction case. The completion mark requires reassessment.

## Recorded verification

The retained evidence reports 1263 Flutter tests, 71 Android unit tests and 31 API36 instrumentation tests passing, plus static analysis and strict OpenSpec validation. Release APK installation, foreground-service start, a short lockscreen reminder flow, acknowledgment and cleanup were observed on a read-only API36 emulator. APK and matching symbol hashes are recorded in `docs/qa/background-rest-reliability/release-verification.json`.

These results do not establish Xiaomi delivery, human hearing, long-duration power behavior or strict ten-second delivery. The earlier missed-reminder incident remains without a confirmed root cause. Historical logs retain their original active-change paths as provenance.

No Git commit or publication is performed by this archive operation.
