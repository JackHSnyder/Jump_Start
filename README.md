# JumpStart — iPhone jumping-jack alarm

An experimental personal alarm for iOS 26+ built with SwiftUI, Apple's AlarmKit and on-device Vision body-pose detection. No video leaves the phone.

## What is implemented

- A polished dark-mode settings screen with configurable daily wake time and enable/disable switch.
- AlarmKit daily alarms using the system alarm sound; both the system Stop intent and the secondary **Open** intent attempt to launch the jumping-jack challenge.
- A live front-camera practice challenge, counting a full open/closed body-pose cycle as one jumping jack.
- Adjustable exercise target (5–50), progress indicator, lost-tracking status, and accessible emergency exit.
- Settings persistence in UserDefaults.
- Continuous in-app siren audio in the challenge with three synthesized sound presets and a volume control. Background audio is enabled so playback can continue when locking the screen or switching apps.
- Siren pauses after one second of reliable tracking and resumes if the body is lost or the app becomes inactive.
- Incomplete challenges and repetition counts are saved locally. On returning to the app, the unfinished challenge reopens automatically.
- A GitHub Actions macOS workflow for building an **unsigned** IPA without owning a Mac.

## Honest limitations

1. **The system's Stop button remains available.** AlarmKit automatically offers this control. JumpStart now attaches an intent that *attempts* to open the challenge when Stop is pressed, but iOS still stops the system alarm and is not obliged to keep JumpStart alive or bring it to the foreground.
2. Opening the app via the system alarm's secondary button requires physical-device validation. No background camera use is attempted.
3. The volume slider and sound picker control **only the challenge siren**. AlarmKit uses its default system sound in this version; the slider does not control system volume.
4. The camera challenge **does not control the system AlarmKit sound itself**. After opening the challenge, a separate in-app siren provides the pause/resume behavior. Background audio is best effort: **force-quitting the app stops it**, and iOS may interrupt playback.
5. The app has **not yet been compiled on Apple's SDK or tested on a real iPhone**. Expect a first-build validation cycle and possible Swift/AlarmKit adjustments.
6. Free Apple-ID sideloading expires in roughly seven days; this is not suitable as your only important alarm. Always retain a backup alarm in the built-in Clock app.

## Build without a Mac

1. Create a GitHub repository and upload **the contents of this folder** to its root. The repository can be public (standard macOS Actions minutes free) or private (within plan quotas). Do not add Apple credentials to GitHub.
2. In the repository, open **Actions → Build unsigned iOS IPA → Run workflow**. The workflow generates an Xcode project using XcodeGen, compiles for iPhone, and packages `JumpStart.app` into `JumpStart-unsigned.ipa`.
3. If the build fails, download/view the Actions log and correct the first compiler error; no claim of a successful compilation is made until the workflow turns green.
4. Download the `JumpStart-unsigned-ipa` workflow artifact. Unzip the artifact once to find the actual `.ipa`.
5. On Windows, download Sideloadly from https://sideloadly.io/. Install Apple's required device drivers/iTunes if Sideloadly requests them.
6. Connect your iPhone via USB, unlock and trust the PC. Drag the unsigned IPA into Sideloadly, select the iPhone, and sign using your own free Apple account. **Never share your Apple password with the developer or this chat.**
7. Enable Developer Mode and trust your developer profile if prompted by iOS. Launch JumpStart, grant camera and alarm permission, run the practice challenge, then schedule a test alarm a few minutes ahead.
8. Refresh the app before its free provisioning expires (approximately every seven days). Keep the same bundle identifier and Apple account when overwriting to preserve local settings.

**When updating an installed app:** install the new IPA over the existing app, using the same Apple account and bundle identifier. Avoid uninstalling first or you may erase saved challenge progress and settings.

## Test checklist

- [ ] Build compiles on macOS with the iOS 26 SDK.
- [ ] Unsigned IPA is signed/installed by Sideloadly on the target phone.
- [ ] Camera authorization and front-camera preview work in portrait.
- [ ] 20 open/closed jumping-jack cycles are counted accurately under different lighting.
- [ ] Body tracking loss is reflected promptly.
- [ ] A scheduled AlarmKit alarm rings when the device is locked / in silent mode.
- [ ] AlarmKit secondary action opens the camera challenge on the target device.
- [ ] Alarm can be disabled from settings and rescheduled after changing wake time.
- [ ] Emergency exit remains accessible regardless of tracking or permissions.
- [ ] The challenge siren continues sounding when the screen locks or another app opens.
- [ ] Siren pauses after one second of continuous pose tracking and resumes on tracking loss.
- [ ] Leaving and returning to JumpStart restores an unfinished challenge and its repetition count.
- [ ] Both system Stop and Open buttons attempt to open the challenge on this iOS version.

## Technical notes

The pose counter observes wrists, shoulders, hips and ankles with Vision's `VNDetectHumanBodyPoseRequest`. Repetitions only count after a distinct arms-up/feet-apart phase followed by arms-down/feet-together, with a short transition cooldown. The algorithm intentionally needs calibration on a real device. The app never saves or transmits camera frames.

The **Try the challenge** button is a live audio-and-camera test: it starts the siren immediately. Be mindful of phone volume before pressing it. The emergency exit requires typing `DISMISS` and clears the saved challenge.

The project is generated from `project.yml` using [XcodeGen](https://github.com/yonaskolb/XcodeGen). Deployment target is iOS 26.1, which supports the modern AlarmKit alert initializer.
