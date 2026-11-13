# SenderWho App Store Connect readiness review

Reviewed the signed-in Chrome session on November 13, 2026. This was a
read-only readiness inspection; no app version was submitted for review.

## Follow-up: iPhone-only release

The owner clarified that this release is intended for iPhone only. The local
iOS project now targets device family 1 in Debug, Profile, and Release, and
`pubspec.yaml` is **1.1.3+12**. The signed build 12 archive was checked and its
packaged `UIDeviceFamily` is `[1]`. The earlier audit below describes the
previously uploaded build 11. Xcode confirmed build 12 uploaded to App Store
Connect on November 13, 2026 at 14:56 local time, and Organizer shows
**Uploaded to Apple**. Select build 12 after processing before reassessing
the iPad screenshot requirement; the last inspected store selection was
build 11. No App Review submission was made.

For reviewer access, provide a dedicated Gmail or Outlook test mailbox's
provider login in the private Sign-In Information fields, plus instructions
for the matching provider's OAuth flow. SenderWho does not need a separate
username/password screen. See the updated submission guide for details.

## Result: hold submission

1. The distribution version is **1.0**, while the selected build is
   **1.1.3 (11)**. Set the distribution version to **1.1.3** to match the
   selected binary's short version string.
2. **Sign-in required** is checked, but **User name** and **Password** are
   blank. Review notes refer to a dedicated account supposedly supplied in
   those fields. Supply a working dedicated review mailbox and provider
   sign-in instructions, and test that Apple can access it without needing an
   unplanned approval or one-time code from the owner.
3. The **iPad 13-inch** screenshot section has **0 of 10 App Screenshots**.
   The selected binary supports both iPhone and iPad. Supply actual iPad app
   screenshots at 2064 × 2752 or 2048 × 2732 portrait (or their landscape
   counterparts), using a physical iPad or iPad simulator.

## Checked and present

- Selected binary: **1.1.3 (11)**, bundle ID **com.senderwho.app**.
- TestFlight Binary State: **Validated**.
- Build declares **App Uses Non-Exempt Encryption: No**.
- Device family: **iPhone, iPad**, minimum iOS **15.0**.
- Build assigned to an internal test group with four testers. Assignment
  alone does not establish that the complete OAuth/action flows were tested.
- Name: SenderWho; subtitle: “Know senders. Organize email.”
- Categories: Productivity and Utilities; age rating: 4+ with regional entries.
- Description, promotional text, keywords, copyright, review contact and
  review notes are populated.
- Price is free; 175 countries or regions configured as available.
- Header: **1 of 1 Header Asset**.
- iPhone medium Dynamic Island slot: **5 of 10 App Screenshots**, original
  captures IMG_3218.PNG, IMG_3222.PNG, IMG_3219.PNG, IMG_3220.PNG and IMG_3221.PNG.
- Privacy policy and privacy choices URLs are filled in. Privacy form lists
  nine linked data types: Name, Email Address, Contacts, Emails or Text
  Messages, Photos or Videos, User ID, Device ID, Product Interaction and
  Other Diagnostic Data. These match the existing project submission guide.

## Improvements and remaining verification

- Put an app-in-use screenshot first; the current first capture IMG_3218.PNG
  is a splash screen. The polished portrait screenshots prepared in this
  thread have not replaced these originals in the inspected slot.
- Search Results Asset is **0 of 1**. It is optional; upload the prepared
  landscape creative if wanted. Portrait screenshots go in the other tab.
- App Privacy shows a **Publish** control. Privacy publication was not
  triggered during this audit; verify the declarations are published before
  submission.
- Release option is **Automatically release this version**. Mac and Vision
  Pro availability are enabled. Mac compatibility is not verified in the
  inspected settings; confirm testing and intended distribution platforms.
- Google and Microsoft production sign-in are enabled; Yahoo is disabled.
  Provider verification approvals and successful fresh-account OAuth were
  not established by this browser inspection.
- Complete an on-device TestFlight pass for sign-in, synchronization, mailbox
  switching, email actions and SenderWho account deletion before submitting.

## Live availability checks

All returned HTTP 200 during this review:

- https://senderwho.com/privacy
- https://senderwho.com/terms
- https://senderwho.com/support
- https://senderwho.com/delete-account
- https://senderwho.com/api/v1/health
- https://senderwho.com/api/v1/auth/providers

Health returned status `ok`; the provider endpoint reported Google and
Microsoft enabled and Yahoo disabled. This confirms endpoint availability,
not end-to-end functionality.

## References

- [SenderWho submission page](https://appstoreconnect.apple.com/apps/6798110288/distribution/ios/version/inflight)
- [Apple version-number guidance](https://developer.apple.com/help/glossary/version-number/)
- [Provide information for a complete review](https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review/)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
