# Portal, builds and signing status

Audit date: 2026-10-31.

## Public portal

- URL: https://xlightxt.github.io/AutoRenew/
- The portal is public and reads GitHub Releases and Actions metadata dynamically.
- Latest deployment verified after the portal and CI policy merges: run [#41243799895](https://github.com/xlightxt/AutoRenew/actions/runs/41243799895), success, main commit e927776.
- The live portal now filters Alpha/Beta/Official by exact branch, labels unsigned and unverified releases, restricts dynamic links to GitHub HTTPS, and includes keyboard skip/focus and screen-reader status support.

## Release catalog observed

- Stable: no Release.
- Beta: no Release.
- Alpha: one public pre-release, [alpha-2026.10.31-c1feeb6](https://github.com/xlightxt/AutoRenew/releases/tag/alpha-2026.10.31-c1feeb6).
- The Alpha release contains AutoRenew.ipa and AutoRenew-Installer.ipa. The release notes and artifacts identify them as unsigned. They are not directly installable.
- No signed IPA, physical installation or first launch has been validated.
- This audit did not create, modify or delete any Release or asset.

## Build status is not installation status

| Channel | Verified Actions run | Result | What it proves |
|---|---|---|---|
| Alpha | [#41237485558](https://github.com/xlightxt/AutoRenew/actions/runs/41237485558) | Success; 23 Swift tests passed | Alpha app/Installer build and test pipeline ran on Xcode 16.4; produced unsigned test packages |
| Beta | [#41181299910](https://github.com/xlightxt/AutoRenew/actions/runs/41181299910) | Success | Workflow ran on the actual beta branch; no Beta Release exists |
| Beta PR | [#41182023247](https://github.com/xlightxt/AutoRenew/actions/runs/41182023247) | Success | This was a PR branch (codex/ipa-packaging-validation), not the beta branch; it must not be shown as the Beta channel's latest build |
| Official CI | [#41243799862](https://github.com/xlightxt/AutoRenew/actions/runs/41243799862) | Success on Xcode 26.6 / iOS Simulator SDK 26.5; 9 Python regression/policy tests passed | Simulator compile plus repository policy tests; no XCTest target on main |
| Official IPA | [#41243799878](https://github.com/xlightxt/AutoRenew/actions/runs/41243799878) | Success on Xcode 26.6 / iOS SDK 26.5 | Uploaded `AutoRenew-Official-unsigned-IPA` (61,596 bytes); no signature or installation validation |
| Main build | [#41243799918](https://github.com/xlightxt/AutoRenew/actions/runs/41243799918) | Success on Xcode 16.4 / iOS SDK 18.5 | Uploaded `AutoRenew-ipa-unsigned` (93,605 bytes); legacy runner remains older than Official CI |
| Portal deploy | [#41243799895](https://github.com/xlightxt/AutoRenew/actions/runs/41243799895) | Success | GitHub Pages deployment completed for main commit e927776 |

An Actions artifact is a temporary CI output. An IPA is only an archive. An unsigned IPA has no valid Apple code signature and embedded provisioning profile, so it is not an installable deliverable. A signed IPA still needs a valid certificate/profile/entitlement match and device eligibility. An installation is validated only after installation on a physical iPhone/iPad. First launch is a separate validation step: the app must open successfully on that device. None of the current runs proves the last three states.

The portal only reads release/build metadata. It does not inspect code signatures, install apps, or observe first launch.

The latest Xcode 26.6 build logs also emitted `All interface orientations must be supported unless the app requires full screen`. This PR adds explicit portrait/landscape support for iPhone and all four orientations for iPad. The benign `AppIntents` metadata-skipped warning is expected because the app does not link AppIntents; Node `punycode`/`url.parse` deprecation warnings originate in the GitHub Actions artifact action runtime, not AutoRenew source.

## Repository shape

- Main currently defines one iOS application target (AutoRenew) through XcodeGen.
- Main has no Installer app target, no app extension target and no XCTest target; its current regression coverage is Python policy tests plus a simulator compile.
- The Alpha feature branch codex/alpha-installer-download-hardening-20261031 contains the separate AutoRenewInstaller app target and AutoRenewTests. Its latest successful run reports 23 Swift tests. Installer UI-specific end-to-end tests and physical device tests remain outstanding.
- PacketTunnelProvider.swift is excluded from the project; no Network Extension target or entitlement is configured.
- The Projects/ folders in the Alpha feature branch are architecture/readme placeholders, not independently buildable Swift packages. No Package.swift dependency graph is present in AutoRenew.
- Main's build.yml produces an unsigned app archive; this PR changes its filename/artifact to `AutoRenew-unsigned.ipa` / `AutoRenew-ipa-unsigned` and adds a regression assertion. The separate Beta/Official workflows already use explicit unsigned labels.

## External architecture and policy research

### Apple signing and provisioning

- [Apple TN3125 — Inside Code Signing: Provisioning Profiles](https://developer.apple.com/documentation/technotes/tn3125-inside-code-signing-provisioning-profiles) says the exact provisioning-profile format is not a documented product API. The traditional plist view is not the source of truth on modern systems; DER-Encoded-Profile is. Apple advises using Xcode/codesign and supported signing services rather than encoding profile internals into a product.
- [Apple provisioning profile updates](https://developer.apple.com/help/account/provisioning-profiles/provisioning-profile-updates/) documents DER profiles and the first-launch PPQ check for development/ad-hoc apps from teams created after 2021-06-06. Internet access may be required on first launch. A successful build or CMS decode does not prove that first launch will succeed.
- The draft signing pipeline currently performs XML/plist-based profile inspection. Keep it Draft until the DER/source-of-truth limitation is explicitly addressed and signing is validated with supported tooling. Do not treat metadata parsing as a trust verdict.

### SideStore, SideSign, SideInstaller and AltServer

- [SideStore installation guide](https://docs.sidestore.io/docs/installation/install) describes iLoader for initial setup, a pairing file, LocalDevVPN, an Apple Account and the seven-day refresh flow. AutoRenew does not implement LocalDevVPN, pairing or SideStore authentication.
- [SideStore source](https://github.com/SideStore/SideStore) is AGPLv3 and describes EM Proxy, LocalDevVPN entitlements and Minimuxer. No source or binary was copied.
- [SideSign source](https://github.com/SideStore/SideSign) describes CMS/PKCS#7, PKCS#12, Mach-O and nested-bundle signing, plus Apple GSA/SRP and Developer Portal clients. Its README claims GPL-3.0, but the current repository tree has no LICENSE file to verify the grant. Its Apple authentication/Developer Portal path is not adopted because this project must not use undocumented/private Apple endpoints. No source or binary was copied.
- [SideInstaller source and license](https://github.com/FrizzleM/SideInstaller) describe on-device installation on iOS 27+, and pairing-file requirements on older supported releases. Its custom license allows non-commercial source study/modification with attribution but prohibits redistributing official builds and commercial use without written permission. The app also handles Apple credentials locally; AutoRenew will not collect or proxy those credentials. No source or binary was copied.
- [AltServer documentation](https://faq.altstore.io/altstore-classic/altserver) describes the computer companion workflow over the same Wi-Fi network or USB. [AltStore's app guide](https://faq.altstore.io/altstore-classic/your-altstore) documents the seven-day expiry and three-active-app limit for Classic sideloading.

### Current toolchain gap

Apple released iOS 27.2 on 2026-10-26 and Xcode 27.2 (27B52) on 2026-10-29; Xcode 27.2 includes Swift 6.4 and the iOS 27.2 SDK. The current main Official CI and Official IPA runs report Xcode 26.6 / iOS SDK 26.5; the legacy main Build IPA and the Alpha Installer run still use Xcode 16.4 / iOS 18.5. GitHub's macOS 26 image currently lists Xcode 26.6, while `xcode-27` remains a public-preview image; no hosted Xcode 27.2 final runner was verified in this audit. The current CI therefore does not validate iOS 27.2. Keep stable CI on Xcode 26.6 until a supported final Xcode 27.2 runner is available, then add a separate compatibility build before claiming iOS 27.2 support. [Apple iOS 27.2 release](https://developer.apple.com/news/releases/), [Xcode 27.2 release](https://developer.apple.com/news/releases/?id=10292026a), [Xcode 27.2 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_2-release-notes), [GitHub macOS 26 image](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md), [GitHub Xcode 27 preview image](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md).

## Safety gates still open

- No signed IPA has been validated.
- No installation or first launch has been tested on a physical device.
- No Beta or Stable release is authorized.
- The signing pipeline remains Draft pending DER/profile validation and physical-device checks.
- The AI central workflow remains Draft; provider secrets cannot be verified from this audit, and no Claude/Gemini API calls were made.
- Social content was not published.
