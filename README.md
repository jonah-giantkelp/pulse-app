# Pulse iOS app

SwiftUI client for the Pulse gig-tracking API. Dark, monospaced, outline-styled —
palette matches the daily digest email (`#0A0A0A` background, `#C8FF00` accent).

## Tabs

- **Concerts** — upcoming events for tracked artists, list or calendar view
- **Favourites** — hearted gigs (stored on-device; no API support yet)
- **Artists** — tracked artists; contact-book A–Z index appears past 20 artists;
  newly-tracked artists show at the top with a syncing spinner
- **Search** — MusicBrainz search with TRACK button (buffers while the API
  resolves platforms, ~5–10s for new artists)
- **Settings** — digest email + toggle, city/country filters, sign out

## Setup

1. Open `Pulse.xcodeproj` in Xcode 16+.
2. In `Pulse/Config.swift`:
   - paste the Supabase **anon** key (never service_role)
   - point `apiBaseURL` at the deployed Flask API (defaults to
     `http://localhost:3000` for local dev)
3. Set your signing team on the Pulse target, build & run (iOS 17+).

Auth is Supabase email/password via raw REST (no SPM dependencies); the session
lives in the Keychain. All data goes through the Flask API with a Bearer JWT.
