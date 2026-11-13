# SenderWho entry and UI polish — 4 November 2026

The supplied onboarding image was used for spacing, hierarchy, and restrained color. SenderWho keeps its own logo, wording, left-aligned sign-in header, and account-card design.

## Changes

- Welcome: a centered introduction, one short message, and a bottom action area. Sign-in: a smaller brand row, clear provider choices, a highlighted remembered account, and full-width account details. The legal links stay near the bottom on normal phones. Both sections scroll together when accessibility text or landscape needs more room.
- Splash: use one decoded logo image across sizes; prepare it before releasing the native launch screen, with a bounded fallback. Wait for the platform to finish its first GPU frame before starting the animation clock. Animate a static, isolated brand layer with a gentle fade/slide/scale, then fade out the old wordmark before the logo moves to the next page. Respect reduced motion.
- Startup: remove the remote-settings request from the startup path. Use the saved device theme first, bound the theme-storage read, and refresh remote profile/settings after the installed destination route actually finishes its transition. Avoid simultaneous launch/theme/content entrance animations.
- Search: allow fields to grow with text size, match keyboard appearance to the theme, dismiss focus on submission and outside taps, and preserve scroll space above the keyboard. Hide bottom navigation while typing.
- Filter sheet: keep Apply above the keyboard; make the title, search, and category options scroll when available height is small. Unsubscribe keeps its profile header pinned while supporting controls can scroll.
- Large text: fix overflowing Unsubscribe actions, section headings/actions, Top Senders rows, message actions and sender links, risk labels, cleanup controls, and settings values. Dialog explanations can scroll. Destructive confirmation buttons use the theme's error/on-error colors in both modes.
- Mailbox navigation: Senders, Inbox, Unsubscribe, and Clean use a short fade for both tab and named navigation, including Back. Their header and navigation remain stationary; detail pages retain platform transitions.
- Category consistency: Inbox applies category and search together from its filter sheet, preserves search when changing quick tabs, and leaves results unchanged when a draft is dismissed. Senders synchronizes People/Newsletters with the quick-tab scope and can reset it from the sheet.

## Verification

The complete Flutter suite passed: **177 tests**, with one preview-only test skipped. The coverage includes:

- All 22 populated named screens in light/dark mode, compact phones, enlarged text, and landscape.
- 320 × 568 at 200% text scaling and 740 × 360 landscape at 130% text scaling in both themes.
- Search focus, keyboard appearance, submission and outside-tap dismissal in Senders, Inbox, Unsubscribe, and Search.
- Sender filters with the keyboard and 200% text, plus readable/cancelable destructive confirmations at the same text size.
- Stationary primary-tab transitions on iOS/Android, Back navigation, equivalent category/search results from sheets and tabs, draft dismissal, resetting the sender scope, and ignoring older in-flight results after a filter change.
- Logo warmup and native-launch release, startup recovery, reduced motion, cancellation of pending sign-in, outgoing wordmark sequencing, and context refresh after the page transition.

Final rendered entry previews are in `senderwho/tmp/entry-polish-2026-11-04/`. Preview data is synthetic. These checks do not exercise live Google/Microsoft/Yahoo authorization or certify mobile frame rate.

## Performance check

A visible-window macOS profile run confirmed a distinct cold GPU setup cost and much lighter warm transitions. This led to the additional first-raster gate: the splash animation clock starts after GPU preparation, with a bounded fallback. The native launch screen is released only after the logo image is decoded. A slow session request shows a progress indicator instead of consuming the intro animation.

The local profile build used temporary macOS deployment/signing overrides; project platform settings were not changed. Desktop profiling does not establish mobile frame rates. Check a signed release/profile build on the target iPhone/Android hardware before making frame-rate guarantees.
