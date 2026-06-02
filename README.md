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
- Challenge types:
  - Math
  - Shake
  - Speak
  - Photo
  - Memory game
- Math challenge supports a 3-question flow.
- Completed challenges create wake session records.
- Success screen records mood/note feedback.
- Stats screen is driven by stored wake session data.
- Local notification callbacks trigger challenges by `alarmId`.

## Debug Launch Args

```text
--showChallenge --showChallengeType math
--showChallenge --showChallengeType shake
--showChallenge --showChallengeType speak
--showChallenge --showChallengeType photo
--showChallenge --showChallengeType memory
--debugScreen math
--debugScreen success
```

## Notes

This repository is intended as a private source backup and development repo.
Do not publish it publicly.
