# JumpStart — iPhone jumping-jack alarm

An experimental personal alarm for iOS 26+ built with SwiftUI, Apple's AlarmKit and on-device Vision body-pose detection. No video leaves the phone.

## What is implemented

- A polished dark-mode settings screen with configurable daily wake time and enable/disable switch.
- AlarmKit daily alarms using the system alarm sound, with a secondary **Open** action intended to launch the jumping-jack screen.
- A live front-camera practice challenge, counting a full open/closed body-pose cycle as one jumping jack.
- Adjustable exercise target (5–50), progress indicator, lost-tracking status, and accessible emergency exit.
- Settings persistence in UserDefaults.
- A GitHub Actions macOS workflow for building an **unsigned** IPA without owning a Mac.

## Honest limitations

1. **The system's Stop button remains available.** AlarmKit automatically offers this control. The camera challenge cannot make an iOS alarm impossible to dismiss.
2. Opening the app via the system alarm's secondary button requires physical-device validation. No background camera use is attempted.
3. The volume slider and sound picker are **UI preferences only** for a future in-app sound component. AlarmKit uses its default system sound in this version; the slider does not control system volume.
4. The camera challenge **does not currently mute and re-enable system AlarmKit audio** based on tracking. This would need a separate implementation and extensive device tests; do not misinterpret the tracking indicator as alarm muting.
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

## Technical notes

The pose counter observes wrists, shoulders, hips and ankles with Vision's `VNDetectHumanBodyPoseRequest`. Repetitions only count after a distinct arms-up/feet-apart phase followed by arms-down/feet-together, with a short transition cooldown. The algorithm intentionally needs calibration on a real device. The app never saves or transmits camera frames.

The project is generated from `project.yml` using [XcodeGen](https://github.com/yonaskolb/XcodeGen). Deployment target is iOS 26, primarily because AlarmKit was introduced with iOS 26.
