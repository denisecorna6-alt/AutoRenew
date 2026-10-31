# Portal, builds and signing status

Audit date: 2026-10-31.

## Public portal

- URL: https://xlightxt.github.io/AutoRenew/
- The portal is public and reads GitHub Releases and Actions metadata dynamically.
- Last deployment verified before this portal correction: run [#41241899920](https://github.com/xlightxt/AutoRenew/actions/runs/41241899920), success, main commit 600fa50.
- This branch adds exact branch filtering for Alpha/Beta/Official, explicit unsigned labels, safe GitHub-only download links, keyboard focus/skip navigation and screen-reader status regions. It is not live until its PR is merged and the Pages deployment succeeds.

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
| Official | [#41241899913](https://github.com/xlightxt/AutoRenew/actions/runs/41241899913) | Success | Main branch generated an unsigned Actions artifact; no Official Release was published |
| Main build | [#41241899850](https://github.com/xlightxt/AutoRenew/actions/runs/41241899850) | Success | Main build workflow ran; its artifact name still needs an explicit unsigned suffix |

An Actions artifact is a temporary CI output. An IPA is only an archive. An unsigned IPA has no valid Apple code signature and embedded provisioning profile, so it is not an installable deliverable. A signed IPA still needs a valid certificate/profile/entitlement match and device eligibility. An installation is validated only after installation on a physical iPhone/iPad. First launch is a separate validation step: the app must open successfully on that device. None of the current runs proves the last three states.

The portal only reads release/build metadata. It does not inspect code signatures, install apps, or observe first launch.

## Repository shape

- Main currently defines one iOS application target (AutoRenew) through XcodeGen.
- Main has no Installer app target, no app extension target and no XCTest target; its current regression coverage is Python policy tests plus a simulator compile.
- The Alpha feature branch codex/alpha-installer-download-hardening-20261031 contains the separate AutoRenewInstaller app target and AutoRenewTests. Its latest successful run reports 23 Swift tests. Installer UI-specific end-to-end tests and physical device tests remain outstanding.
- PacketTunnelProvider.swift is excluded from the project; no Network Extension target or entitlement is configured.
- The Projects/ folders in the Alpha feature branch are architecture/readme placeholders, not independently buildable Swift packages. No Package.swift dependency graph is present in AutoRenew.
- Main's build.yml produces an unsigned app archive. The separate Beta/Official workflows also produce unsigned Actions artifacts after the release-policy correction.

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

Apple's current release notes identify Xcode 27.2 / iOS 27.2 SDK and Swift 6.4. The current main and Alpha build logs still report Xcode 16.4 / iOS Simulator SDK 18.5. The current CI therefore does not yet validate the latest iOS SDK. A separate latest-Xcode compatibility job should be added and tested before claiming iOS 27 compatibility.

## Safety gates still open

- No signed IPA has been validated.
- No installation or first launch has been tested on a physical device.
- No Beta or Stable release is authorized.
- The signing pipeline remains Draft pending DER/profile validation and physical-device checks.
- The AI central workflow remains Draft; provider secrets cannot be verified from this audit, and no Claude/Gemini API calls were made.
- Social content was not published.
