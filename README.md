# 挑战闹钟

Wake challenge alarm app for iOS, built with SwiftUI.

## Project

- Platform: iOS
- UI: SwiftUI
- Project generation: XcodeGen (`project.yml`)
- Bundle ID: `com.alfie.AlarmClockApp`

## Local Setup

Open the checked-in Xcode project:

```bash
open AlarmClockApp.xcodeproj
```

If the Xcode project needs to be regenerated:

```bash
xcodegen generate
```


## Device Build

The app target is configured for Automatic Signing with Alfie's personal development team (`D4SUBHNYW9`). After regenerating the project, a device Debug build should not need command-line signing overrides.

```bash
xcodegen generate
xcodebuild -project AlarmClockApp.xcodeproj -scheme AlarmClockApp -configuration Debug -destination 'platform=iOS,id=00008150-000C296E1420401C' -derivedDataPath /tmp/AlarmClockAppDeviceProjectSigning -allowProvisioningUpdates build
xcrun devicectl device install app --device Alfie /tmp/AlarmClockAppDeviceProjectSigning/Build/Products/Debug-iphoneos/AlarmClockApp.app
xcrun devicectl device process launch --device Alfie --terminate-existing com.alfie.AlarmClockApp
```

If launch fails with `device ... Locked`, unlock the iPhone and rerun only the final launch command.

## Current Features

- Dark bedside visual system with iOS 26 Liquid Glass panels.
- Alarm list, add/edit alarm flow, home next-alarm card, and stats tab.
- Repeat-day scheduling is backed by local notification weekday triggers.
- Notification authorization status is surfaced on the home screen when it blocks delivery.
- Challenge types:
  - Math: supported, with configurable difficulty and question count.
  - Shake: supported with CoreMotion on device and a simulator mock button.
  - Photo: supported with local Apple Vision image classification and a simulator mock button.
  - Speak: code retained, but not exposed as a formal user-facing mode.
  - Memory game: code retained, but not opened yet.
- Math, shake, and photo are the formal challenge modes exposed in setup.
- Completed challenges create wake session records.
- Stats screen is driven by stored wake session data.
- Local notification callbacks trigger challenges by `alarmId`.
- App display name and notification identity are configured as `挑战闹钟`.
- Unit tests cover repeat scheduling, challenge availability, shake tracking, snooze clamping, speech matching, and wake-session streak stats.

## Debug Launch Args

```text
--showChallenge --showChallengeType math
--showChallenge --showChallengeType shake
--showChallenge --showChallengeType photo
--debugShakeRequiredCount 3
--debugPhotoMock
--showNoChallenge
--debugScheduleWeekdays
--debugTriggerStoredAlarm
--debugScreen math
--debugScreen success
```

## Notes

This repository is intended as a private source backup and development repo.
Do not publish it publicly.
