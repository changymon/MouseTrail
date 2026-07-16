# Publishing Mouse Trail to the Mac App Store

Everything technical is already done: the app is sandboxed (required for the
App Store), has an icon, store-compliant metadata, and a packaging script.
This checklist covers the parts that need your Apple ID.

## One-time setup

1. **Join the Apple Developer Program** — https://developer.apple.com/programs/enroll/
   - US$99/year. Required even for free apps.
   - Enroll as an individual (fastest; your name appears as the seller).

2. **Install Xcode** (free, Mac App Store) and sign in:
   Xcode → Settings → Accounts → add your Apple ID.
   Then point the command line at it:
   ```
   sudo xcode-select -s /Applications/Xcode.app
   ```

3. **Create signing certificates** — Xcode → Settings → Accounts →
   (your team) → Manage Certificates → "+" → create both:
   - **Apple Distribution**
   - **Mac Installer Distribution**

4. **Register the app ID** — https://developer.apple.com/account →
   Certificates, Identifiers & Profiles → Identifiers → "+" →
   App IDs → App → Bundle ID (explicit): `au.changy.mousetrail`.
   No capabilities needed.

5. **Create a provisioning profile** — same site → Profiles → "+" →
   Distribution → **Mac App Store Connect** → select the app ID and your
   distribution certificate → download it → save it as
   `MouseTrail.provisionprofile` in this folder.

## Create the App Store listing

At https://appstoreconnect.apple.com → My Apps → "+" → New App:

- **Platform:** macOS
- **Name:** must be unique across the store. "Mouse Trail" may be taken —
  have backups ready (e.g. "Mouse Trail — Cursor Effects", "TrailCursor",
  "Comet Cursor"). The store name doesn't have to match the bundle name.
- **Bundle ID:** au.changy.mousetrail
- **SKU:** anything, e.g. `mousetrail-1`
- **Price:** Free (Pricing and Availability → price tier Free)

Fill in (drafts in `store-listing.md`):
- Description, keywords, support URL, promotional text
- **Privacy policy URL** — required. `privacy-policy.md` has the text;
  host it anywhere public (a GitHub Pages page or a page on changy.au).
- **App Privacy questionnaire:** select **"Data is not collected"** —
  true for this app; it has no network access at all.
- **Screenshots:** at least one, sized 1280×800, 1440×900, 2560×1600, or
  2880×1800. Take one with the trail visible: wave the mouse and press
  ⇧⌘3 (full screen), then crop/resize to 2560×1600 in Preview.
  Tip: a colorful wallpaper + rainbow comet reads well as a thumbnail.
- **Category:** Entertainment (already set in the app's Info.plist).

## Build and upload

```
cd ~/MouseTrail
./dist.sh        # produces dist/MouseTrail.pkg, signed for the store
```

Upload `dist/MouseTrail.pkg` with the **Transporter** app (free on the
Mac App Store — sign in with the same Apple ID, drag the pkg in, Deliver).

Back in App Store Connect: wait a few minutes for the build to process,
attach it to the 1.0 version, answer the export-compliance question
(already answered in the plist: uses no encryption), and **Submit for
Review**.

## Review notes (paste into the "Notes for Review" box)

> Mouse Trail is a menu bar app (no Dock icon, no main window). After
> launch, a welcome dialog appears, then the app lives in the menu bar
> as a cursor icon. Move the mouse to see the trail effect. All settings
> (style, color, thickness, trail length) are in the menu bar menu.

## After approval

- Updates: bump `CFBundleVersion` and `CFBundleShortVersionString` in
  Info.plist, run `./dist.sh`, upload, submit the new version.
- If review rejects something, it arrives as a message in App Store
  Connect — usually fixable in one round trip.

## Alternative: free distribution outside the App Store

If you'd rather skip the store entirely you still need the $99 membership
to notarize, but there's no review: sign with a "Developer ID Application"
certificate, notarize with `xcrun notarytool`, and share the .app as a
zip/dmg from GitHub or your site. Ask Claude to set this up if you prefer.
