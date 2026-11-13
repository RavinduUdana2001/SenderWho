# SenderWho App Store submission

This checklist matches the current iOS project. Keep the Apple Developer portal,
App Store Connect, and Xcode values identical.

## 1. Register the Apple App ID

From App Store Connect's **New App** window, use the **Certificates,
Identifiers & Profiles** link, or open the Identifiers page in the Apple
Developer portal.

1. Click **Identifiers**, then **+**.
2. Select **App IDs**, then **App**.
3. Enter:
   - Description: `SenderWho`
   - Bundle ID type: **Explicit**
   - Bundle ID: `com.senderwho.app`
4. Keep the default capabilities. SenderWho currently does not require Sign in
   with Apple, push notifications, associated domains, or iCloud.
5. Register the identifier.

The iOS project already uses team `GTWTN34JAK`, bundle ID
`com.senderwho.app`, and automatic signing.

## 2. Create the App Store Connect record

Return to **My Apps**, click **+**, and choose **New App**. Refresh the page if
the newly registered Bundle ID is not shown.

- Platforms: **iOS** only
- Name: `SenderWho`
- Primary Language: **English (U.S.)**
- Bundle ID: select `com.senderwho.app`
- SKU: `SENDERWHO-IOS-001`
- User Access: **Full Access**

The SKU is an internal, permanent identifier and is not shown to customers.
The Bundle ID cannot be changed after the app record is created.

## 3. App information

- Subtitle: `Know and clean your inbox`
- Primary Category: **Productivity**
- Secondary Category: **Utilities**
- Content Rights: select **Yes** when asked whether the app accesses third-party
  content, then confirm that users authorize access to their own mail through
  provider OAuth.
- Privacy Policy URL: `https://senderwho.com/privacy`
- Privacy Choices URL: `https://senderwho.com/delete-account`

Complete Apple's age-rating questionnaire truthfully. SenderWho contains no
advertising, gambling, health content, unrestricted web access, or user-to-user
social features.

## 4. Version information

The latest uploaded iOS binary uses:

- Version: `1.1.3`
- Build: `12`
- Copyright: `2026 SenderWho`
- Support URL: `https://senderwho.com/support`
- Marketing URL: `https://senderwho.com/`
- Keywords: `email,inbox,cleanup,unsubscribe,sender,security,organizer,newsletter,productivity`

The iPhone-only **1.1.3 (12)** binary was uploaded through Xcode. Build 11 was
uploaded before the iPhone-only device-family change.

`senderwho/pubspec.yaml` is now **1.1.4+12**, and the latest signed Android AAB
was rebuilt with version name **1.1.4** and version code **12**. That local
version change does not change the already uploaded iOS binary. Before a new
iOS upload, use an unused build number. Before a Google Play upload, verify
that version code 12 exceeds every previously uploaded version code across
all tracks. Store upload history cannot be inferred from the project file.

What's New / Google Play release notes:

> Clearer error messages and account controls, more consistent wording, and improved handling of sign-in confirmation for sensitive actions.

Promotional text:

> Understand who is emailing you, organize your inbox, review cleanup opportunities, and take control of unwanted mail.

Description:

> SenderWho helps you understand and manage your inbox from one clear, focused app.
>
> Connect a supported email account to review messages and senders, see inbox-health and security indicators, find newsletters and cleanup opportunities, and manage trusted or blocked senders.
>
> Key features:
> - Identify senders and organize messages by useful categories
> - Review inbox-health, cleanup, and security information
> - Mark messages read or unread, archive, restore, or move them to Trash
> - Review supported mailing lists and request unsubscribe actions
> - Trust or block senders and keep those choices synchronized
> - Disconnect a mailbox or permanently delete your SenderWho account
>
> SenderWho accesses mail only after you grant permission through your provider. It does not ask for or store your mailbox password. Some unsubscribe requests depend on the sender's own unsubscribe service.

## 5. Screenshots

This release targets iPhone only (`TARGETED_DEVICE_FAMILY = 1` in Debug,
Profile, and Release). Select the new build 12 in App Store Connect after it
has been uploaded and processed. The previously uploaded build 11 still
declares iPhone and iPad support.

- Required medium Dynamic Island / 6.3-inch iPhone portrait: `1206 x 2622`
  or `1179 x 2556` pixels.
- Additional large Dynamic Island / 6.9-inch iPhone portrait: `1260 x 2736`,
  `1290 x 2796`, or `1320 x 2868` pixels.

iPad screenshots are not needed for the new iPhone-only binary. Do not resize
iPhone captures into iPad screenshot dimensions.

Use real app screens with test data and do not show real user email, tokens, or
private messages. Recommended screens are Home, Inbox, All Senders, Inbox
Health, Cleanup, and Unsubscribe.

## 6. App Privacy answers

The privacy answers must match the live privacy policy and backend behavior.
For the current implementation, disclose the following as **Linked to the
User** and **Not used for tracking**:

- Contact Info: Name, Email Address
- Contacts
- Identifiers: User ID, Device ID
- User Content: Emails or Text Messages; Photos or Videos (provider avatar)
- Usage Data: Product Interaction
- Diagnostics: Other Diagnostic Data

Select **App Functionality** as a purpose for every item. Also select **Product
Personalization** for Name, Email Address, Contacts, Emails or Text Messages,
and Photos or Videos because sender identification and mailbox organization are
personalized to the connected account.

Do not select advertising, third-party advertising, developer advertising,
credit, or cross-app tracking purposes. SenderWho does not use Apple's App
Tracking Transparency framework because it does not track users.

## 7. Build and upload

Before each upload, increment the build number. From the repository:

```sh
cd senderwho
flutter clean
flutter pub get
cd ios
pod install
cd ..
open ios/Runner.xcworkspace
```

In Xcode:

1. Select **Runner** > **Signing & Capabilities**.
2. Select the correct Apple Developer team, keep **Automatically manage
   signing** enabled, and confirm `com.senderwho.app`.
3. Choose **Any iOS Device (arm64)** as the destination.
4. Select **Product > Archive**.
5. In Organizer, choose **Distribute App > App Store Connect > Upload**.

Alternatively, after signing is configured:

```sh
flutter build ipa --release
```

Upload the generated IPA with Xcode Organizer or Apple's Transporter app.

## 8. TestFlight and App Review

1. Wait for the uploaded build to finish processing in App Store Connect.
2. Complete export-compliance questions. The project declares that it uses only
   exempt standard encryption such as HTTPS/TLS and Apple Keychain.
3. Test the processed build first with an internal TestFlight tester.
4. Select the build on the App Store version page.
5. Add a working review account and keep the production backend available.
6. Complete pricing and availability; choose free unless the business model is
   intentionally changed.
7. Submit the version for App Review only after the Google restricted Gmail
   permission is approved and both supported provider sign-in flows work for a
   fresh reviewer account.

Copy-ready App Review notes:

> SenderWho is a client for the specific third-party email services shown in the app. Users must authorize their own mailbox through the provider's OAuth page; SenderWho never requests or stores the mailbox password. This falls under the client-for-a-specific-third-party-service exception in App Review Guideline 4.8, so Sign in with Apple is not used. To review: launch the app, choose a supported provider, complete OAuth with the review account supplied below, and return to SenderWho. The app then synchronizes that account and enables the visible inbox, sender, cleanup, unsubscribe, trust/block, archive, Trash, and restore features. Account deletion is available in Settings > SenderWho account > Delete SenderWho account. Support: senderwho.app@gmail.com.

Supply a dedicated review mailbox and its login details in App Store Connect's
secure review-information fields. Do not put credentials in public description
or marketing text. If provider MFA is enabled, provide a stable review method or
a clearly explained demo path.

For Gmail/Outlook OAuth, the **User name** is the dedicated test mailbox's
email address and **Password** is that provider account's normal sign-in
password, not an app-specific password. Apple enters them on Google's or
Microsoft's authorization page. SenderWho still has no separate password
login. Use a test mailbox with sample messages and no personal correspondence.
Keep **Sign-in required** checked. Test access from a fresh browser/device and
provide a supported review method if the provider requires additional prompts.

Add this instruction to the review notes, choosing the actual test provider:

> The username and password in Sign-In Information belong to a dedicated test mailbox. Select Google for a Gmail mailbox or Microsoft Outlook for an Outlook mailbox, enter those credentials on the provider's sign-in page, authorize SenderWho, and return to the app. SenderWho itself does not request or store the mailbox password.

Apple explicitly asks for the demo provider account details for single-sign-on
apps: [App Review information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information#app-review-information).

## Release gate

Do not submit the production App Store review until all of these are true:

- Google OAuth data-access verification is approved for `gmail.modify`.
- Yahoo production access is enabled if Yahoo is advertised in the listing.
- OAuth redirects return to the installed iOS app.
- The production API and database are healthy and stay available to reviewers.
- Account deletion, disconnect, and sign-out work in the uploaded
  TestFlight build.
- No private email, OAuth secret, API key, or test credential appears in the
  binary, screenshots, review notes, or repository.

## Google Play release

Use the same `pubspec.yaml` version and application ID `com.senderwho.app`.
Configure `senderwho/android/key.properties` with the existing upload key; do
not generate a replacement key for an already published app.

```sh
cd senderwho
flutter analyze
flutter test
flutter build appbundle --release
```

Upload `build/app/outputs/bundle/release/app-release.aab` to an internal test
track first. Complete Data safety, content rating, app access, and account
deletion disclosures for the actual production service. The public deletion
URL is `https://senderwho.com/delete-account`. Advertise only providers enabled
in production; Yahoo was disabled when checked on November 13, 2026.

As checked on November 13, 2026, Google Play requires API 36 for new phone/tablet
apps and updates. The installed Flutter SDK supplies compile/target API 36.
Apple requires Xcode 26 or later with the iOS 26 SDK or later; this machine has
Xcode 27. Keep these requirements under review before later submissions:

- [Google Play target API requirements](https://developer.android.com/google/play/requirements/target-sdk)
- [Apple SDK minimum requirements](https://developer.apple.com/news/upcoming-requirements/?id=04282026a)

Local builds and tests do not verify OAuth verification status, store history,
store disclosures, signing acceptance, or reviewer access. Confirm these in
the provider/store consoles and test the uploaded builds before submitting.

## Local verification — November 13, 2026

Follow-up after the iPhone-only decision: `flutter build ipa --release` passed
for **1.1.3 (12)**. Both archive and exported IPA were inspected and contain
`UIDeviceFamily = [1]`; the IPA contains the code signature. This new IPA is
at `senderwho/build/ios/ipa/SenderWho.ipa`. Xcode confirmed
**SenderWho 1.1.3 (12) uploaded** to App Store Connect on November 13, 2026
at 14:56 local time; Organizer shows **Uploaded to Apple** for build 12.
Select this build after Apple finishes processing it. It has not been
submitted for App Review.
The build 11 results and hashes below record the earlier upload and artifacts.

- `flutter analyze`: no issues.
- `flutter test`: 292 passed; one debug preview test skipped in normal mode.
- `flutter build appbundle --release`: passed. Packaged version `1.1.3` / code
  `11`, target API 36, debugging disabled. JAR signature verified with a
  non-debug certificate. All three ARM64 native libraries have ELF load-segment
  alignment of at least 16 KB.
- `flutter build ios --release --no-codesign`: passed with the iOS 27 SDK.
- `flutter build ipa --release`: signed archive and App Store Connect IPA export
  passed. Exported IPA contains version `1.1.3`, build `11`, bundle ID
  `com.senderwho.app`, and the app privacy manifest. Archive signature verified
  with macOS certificate trust services.
- Production privacy, terms, support, deletion, health, and provider endpoints
  returned HTTP 200. Provider availability: Google and Microsoft enabled;
  Yahoo disabled. This verifies availability, not a complete OAuth sign-in.

Upload status — November 13, 2026: Xcode Organizer confirmed **SenderWho
1.1.3 (11) uploaded** to App Store Connect and shows **Uploaded to Apple**.
Apple processing, TestFlight testing, and App Review submission are separate
steps. The Android bundle has not been uploaded by this review.

Release artifacts:

- Android: `senderwho/build/app/outputs/bundle/release/app-release.aab`
  - SHA-256: `58d7d60a3f0248035b617eca24c168422125a8264bab0c4be379678d215f94dc`
- iOS: `senderwho/build/ios/ipa/SenderWho.ipa`
  - SHA-256: `d0ee05482e2cde0b0aeac56e0724433f3f44d2b259b91e03e5ac5ad9a8339b66`
