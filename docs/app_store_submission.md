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

Use the current project version:

- Version: `1.1.1`
- Build: `6`
- Copyright: `2026 SenderWho`
- Support URL: `https://senderwho.com/support`
- Marketing URL: `https://senderwho.com/`
- Keywords: `email,inbox,cleanup,unsubscribe,sender,security,organizer,newsletter,productivity`

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
> - Export your SenderWho data, disconnect an account, or permanently delete your account
>
> SenderWho accesses mail only after you grant permission through your provider. It does not ask for or store your mailbox password. Some unsubscribe requests depend on the sender's own unsubscribe service.

## 5. Screenshots

The app currently supports iPhone and iPad, so provide both sets:

- 6.9-inch iPhone portrait: `1260 x 2736`, `1290 x 2796`, or
  `1320 x 2868` pixels.
- 13-inch iPad portrait: `2048 x 2732` or `2064 x 2752` pixels.

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
flutter build ipa --release --build-name=1.1.1 --build-number=6
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

> SenderWho is a client for the specific third-party email services shown in the app. Users must authorize their own mailbox through the provider's OAuth page; SenderWho never requests or stores the mailbox password. This falls under the client-for-a-specific-third-party-service exception in App Review Guideline 4.8, so Sign in with Apple is not used. To review: launch the app, choose a supported provider, complete OAuth with the review account supplied below, and return to SenderWho. The app then synchronizes that account and enables the visible inbox, sender, cleanup, unsubscribe, trust/block, archive, Trash, and restore features. Account deletion is available in Settings > Privacy & Data > Delete Account. Support: senderwho.app@gmail.com.

Supply a dedicated review mailbox and its login details in App Store Connect's
secure review-information fields. Do not put credentials in public description
or marketing text. If provider MFA is enabled, provide a stable review method or
a clearly explained demo path.

## Release gate

Do not submit the production App Store review until all of these are true:

- Google OAuth data-access verification is approved for `gmail.modify`.
- Yahoo production access is enabled if Yahoo is advertised in the listing.
- OAuth redirects return to the installed iOS app.
- The production API and database are healthy and stay available to reviewers.
- Account deletion, data export, disconnect, and sign-out work in the uploaded
  TestFlight build.
- No private email, OAuth secret, API key, or test credential appears in the
  binary, screenshots, review notes, or repository.
