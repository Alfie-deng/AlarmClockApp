# AlarmClockApp

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

## Current Features

- Dark bedside visual system with iOS 26 Liquid Glass panels.
- Alarm list, add/edit alarm flow, home next-alarm card, and stats tab.
- Repeat-day scheduling is backed by local notification weekday triggers.
- Notification authorization status is surfaced on the home screen when it blocks delivery.
- Challenge types:
  - Math: supported
  - Shake: supported with CoreMotion on device and a simulator mock button
  - Speak: supported with Speech recognition and a simulator mock button
  - Photo / Memory game: not opened yet
- Math challenge supports a 3-question flow.
- Completed challenges create wake session records.
- Success screen records mood/note feedback.
- Stats screen is driven by stored wake session data.
- Local notification callbacks trigger challenges by `alarmId`.
- Unit tests cover repeat scheduling, challenge availability, and wake-session streak stats.

## Debug Launch Args

```text
--showChallenge --showChallengeType math
--showChallenge --showChallengeType shake
--showChallenge --showChallengeType speak
--showChallenge --showChallengeType photo
--showChallenge --showChallengeType memory
--debugShakeRequiredCount 3
--debugSpeechMock
--debugSpeechNoAutoStart
--showNoChallenge
--debugScheduleWeekdays
--debugTriggerStoredAlarm
--debugScreen math
--debugScreen success
```

## Notes

This repository is intended as a private source backup and development repo.
Do not publish it publicly.
