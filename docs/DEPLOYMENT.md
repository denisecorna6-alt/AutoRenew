# Portal, builds and signing status

Audit date: 2026-10-31.

## Public portal

- URL: https://xlightxt.github.io/AutoRenew/
- The portal is public and reads GitHub Releases and Actions metadata dynamically.
- Latest verified portal deployment: Pages run [#41249248696](https://github.com/xlightxt/AutoRenew/actions/runs/41249248696), success, main commit `7cc75b6`. The live page was fetched after deployment and contains no direct IPA download links.
- Before this policy change, the portal filtered Alpha/Beta/Official by exact branch, labeled unsigned and unverified releases, restricted dynamic links to GitHub HTTPS, and included keyboard skip/focus and screen-reader status support, but still exposed direct links to unsigned Alpha assets. The policy below removes those links.

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
| Alpha | [#41242635812](https://github.com/xlightxt/AutoRenew/actions/runs/41242635812) | Success; 23 Swift tests passed | Alpha app/Installer build ran on Xcode 16.4 / iOS 18.5; produced two unsigned Actions artifacts |
| Beta | [#41181299910](https://github.com/xlightxt/AutoRenew/actions/runs/41181299910) | Success | Workflow ran on the actual beta branch; no Beta Release exists |
| Beta PR | [#41182023247](https://github.com/xlightxt/AutoRenew/actions/runs/41182023247) | Success | This was a PR branch (codex/ipa-packaging-validation), not the beta branch; it must not be shown as the Beta channel's latest build |
| Official CI before artifact gate | [#41247464230](https://github.com/xlightxt/AutoRenew/actions/runs/41247464230) | Success on Xcode 26.6 / iOS Simulator SDK 26.5; 13 Python regression/policy tests passed | Last completed pre-gate main build; main still has no XCTest target |
| Official IPA before artifact gate | [#41247464281](https://github.com/xlightxt/AutoRenew/actions/runs/41247464281) | Success on Xcode 26.6 / iOS SDK 26.5 | Uploaded `AutoRenew-Official-unsigned-IPA` (81,541 bytes); last automatic Official artifact before manual-only gate |
| Main Build IPA before artifact gate | [#41247464233](https://github.com/xlightxt/AutoRenew/actions/runs/41247464233) | Success on Xcode 16.4 / iOS SDK 18.5 | Uploaded `AutoRenew-ipa-unsigned` (117,386 bytes); last automatic main build artifact before Alpha-only gate |
| Official CI after policy + background fix | [#41249248695](https://github.com/xlightxt/AutoRenew/actions/runs/41249248695) | Success on Xcode 26.6 / iOS Simulator SDK 26.5; 14 Python regression/policy tests passed | Current main simulator build; no IPA artifact generated |
| Portal deploy after policy + background fix | [#41249248696](https://github.com/xlightxt/AutoRenew/actions/runs/41249248696) | Success | GitHub Pages deployed main commit 7cc75b6; portal fetch confirmed no direct IPA download links |

An Actions artifact is a temporary CI output. An IPA is only an archive. An unsigned IPA has no valid Apple code signature and embedded provisioning profile, so it is not an installable deliverable. A signed IPA still needs a valid certificate/profile/entitlement match and device eligibility. An installation is validated only after installation on a physical iPhone/iPad. First launch is a separate validation step: the app must open successfully on that device. None of the current runs proves the last three states.

The portal only reads release/build metadata. It does not inspect code signatures, install apps, or observe first launch. After PR #45, it exposes no direct IPA asset URLs; it links to the Actions run page for logs, where any Alpha artifact remains explicitly unsigned.

The `All interface orientations must be supported unless the app requires full screen` warning is absent from the post-merge Xcode 26.6/26.5 archive and simulator logs after explicit iPhone/iPad orientation declarations. The app asks for notification permission only when a real app is registered and the user taps **Ativar lembretes**, respects current authorization, caps reminders at 60, and excludes demo records. Since main still has no manual app registration, no real-app reminder is scheduled. Settings contains an informational Shortcuts guide for SideStore's public `Refresh All Apps` App Intent; AutoRenew does not invoke SideStore APIs or handle Apple credentials. Background task completion now reflects actual refresh outcomes: failure, deferred work or cancellation reports unsuccessful completion to iOS; the backend remains unavailable and fail-closed. Remaining benign warnings: Xcode selects the first of multiple matching simulator destinations; AppIntents metadata extraction is skipped because the app does not link AppIntents; after the Node 24 action upgrade, the `url.parse` warning is gone, but `actions/deploy-pages@v5.0.1` still emits Node DEP0040 `punycode` from a transitive dependency (upstream issue #413), not AutoRenew source.

## Repository shape

- Main currently defines one iOS application target (AutoRenew) through XcodeGen.
- Main has no Installer app target, no app extension target and no XCTest target; its current regression coverage is Python policy tests plus a simulator compile.
- The Alpha feature branch codex/alpha-installer-download-hardening-20261031 contains the separate AutoRenewInstaller app target and AutoRenewTests. Its latest successful run reports 23 Swift tests. Installer UI-specific end-to-end tests and physical device tests remain outstanding.
- PacketTunnelProvider.swift is excluded from the project; no Network Extension target or entitlement is configured.
- The Projects/ folders in the Alpha feature branch are architecture/readme placeholders, not independently buildable Swift packages. No Package.swift dependency graph is present in AutoRenew.
- The artifact policy restricts automatic `build.yml` runs to Alpha branches and names the file `AutoRenew-unsigned.ipa` / artifact `AutoRenew-ipa-unsigned`. Beta/Official IPA workflows are manual-only and branch-guarded. No main-branch IPA artifact was produced after the policy merge; the post-merge main runs were Official CI and Pages deploy only.

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

Apple released iOS 27.2 on 2026-10-26 and Xcode 27.2 (27B52) on 2026-10-29; Xcode 27.2 includes Swift 6.4 and the iOS 27.2 SDK. The current main Official CI uses Xcode 26.6 / iOS SDK 26.5. The last automatic main Build IPA before the artifact gate used Xcode 16.4 / iOS 18.5; the Alpha-only workflow now uses macOS 26 / Xcode 26.6. The legacy Installer Alpha branch still uses Xcode 16.4 / iOS 18.5. GitHub's macOS 26 image currently lists Xcode 26.6, while `xcode-27` remains a public-preview image; no hosted Xcode 27.2 final runner was verified in this audit. The current CI therefore does not validate iOS 27.2. Keep stable CI on Xcode 26.6 until a supported final Xcode 27.2 runner is available, then add a separate compatibility build before claiming iOS 27.2 support. [Apple iOS 27.2 release](https://developer.apple.com/news/releases/), [Xcode 27.2 release](https://developer.apple.com/news/releases/?id=10292026a), [Xcode 27.2 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_2-release-notes), [GitHub macOS 26 image](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md), [GitHub Xcode 27 preview image](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md).

## Safety gates still open

- No signed IPA has been validated.
- No installation or first launch has been tested on a physical device.
- No Beta or Stable release is authorized.
- The signing pipeline remains Draft pending DER/profile validation and physical-device checks.
- The AI central workflow remains Draft; provider secrets cannot be verified from this audit, and no Claude/Gemini API calls were made.
- Social content was not published.


## Current artifact and portal policy

- Automatic `build.yml` runs are restricted to `codex/alpha-*`; manual dispatch is accepted only when the selected ref is Alpha. It runs regression/safety tests before building on macOS 26 / Xcode 26.6, disables signing, verifies the IPA ZIP and uploads the unsigned artifact only after all prior steps pass.
- `beta-ipa.yml` and `official-ipa.yml` become manual-only and require exact `beta` or `main` refs. No automatic Beta/Official IPA artifacts are produced on push or PR.
- The portal no longer exposes direct IPA `browser_download_url` links. It will show metadata and asset names but block downloads until signing, physical installation and first launch are validated. Existing GitHub Release assets are preserved; this PR does not delete history.
- The existing Alpha Release remains unsigned. No signed IPA, Beta/Stable Release, installation or first launch is created by this change.
- The Alpha Installer branch's artifact names include `unsigned`, but the IPA filenames inside those older artifacts do not. They must be renamed before any future Alpha artifact is offered.

## Additional blockers found in open Alpha proposals

- The separate Installer chain still contains PKCS#12 import/storage and an Anisette transport; keep it Draft and do not execute or merge those flows.
- The AI implementation proposal executes Python tests from `Tests/` while provider keys and a write-capable GitHub token are present in the same environment. Generated tests could exfiltrate those variables; a diff allowlist is not a sandbox.
- The Anisette V3 `/get_headers` proposal sends ADI/Anisette state to a configurable remote service and is not a documented public Apple API; it is blocked by the no-private-endpoints/no-auth-material rule.


## Background task reporting correction

PR #48 adds a structured refresh summary. iOS background tasks are now marked successful only when no refresh failed, was deferred or was cancelled. An overlapping run is reported as deferred; a backend-unavailable run with due apps is reported as failed. A confirmed refresh result is recorded before cancellation is applied to remaining work. This changes scheduler reporting only; it does not add a signing backend or claim that an app was renewed. Main CI #41249248695 passed all 14 Python regression/policy tests and the Xcode 26.6 / iOS Simulator SDK 26.5 build.
