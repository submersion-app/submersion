# Inline Appcast Release Notes

**Date:** 2026-04-03
**Issue:** https://github.com/submersion-app/submersion/issues/131
**Status:** Approved

## Problem

When macOS/Windows users receive an update notification via Sparkle/WinSparkle, the release notes window is empty and a `release-notes.html` file downloads in their browser instead of displaying inline.

The root cause is that `appcast.xml` uses `<sparkle:releaseNotesLink>` pointing to a GitHub release asset URL (`https://github.com/.../releases/download/.../release-notes.html`). GitHub serves release assets with `Content-Disposition: attachment`, which forces a download rather than inline rendering.

## Solution

Replace `<sparkle:releaseNotesLink>` with `<description><![CDATA[...]]></description>` containing the release notes HTML directly in the appcast XML. Both Sparkle 2 (macOS) and WinSparkle (Windows) support inline HTML descriptions natively.

## Changes

### 1. `scripts/generate_appcast.sh`

- Replace the 6th argument (`release_notes_url`) with `release_notes_html_file` (path to the generated HTML file)
- Read the HTML file content at script execution time
- Replace both `<sparkle:releaseNotesLink>` lines with `<description><![CDATA[ ... ]]></description>` blocks containing the HTML content
- Update the usage comment at the top of the file

### 2. `.github/workflows/release.yml`

- Line ~918-919: Pass the path to `release-notes.html` instead of constructing a URL
- `release-notes.html` can optionally remain as a release asset for reference, but it is no longer required by the appcast

### Resulting appcast.xml structure

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Submersion Updates</title>
    <item>
      <title>Version 1.4.1.86</title>
      <sparkle:version>86</sparkle:version>
      <sparkle:shortVersionString>1.4.1.86</sparkle:shortVersionString>
      <description><![CDATA[
        <!DOCTYPE html>
        <html lang="en">
        <head>...</head>
        <body>...release notes...</body>
        </html>
      ]]></description>
      <pubDate>Thu, 03 Apr 2026 12:00:00 -0400</pubDate>
      <enclosure url="..." sparkle:os="macos" ... />
    </item>
    <item>
      ...windows item with same inline description...
    </item>
  </channel>
</rss>
```

## Files unchanged

- `scripts/generate_release_notes_html.sh` -- still generates the HTML, now consumed by `generate_appcast.sh` directly
- Native platform code (macOS Sparkle, Windows WinSparkle)
- Dart auto-update services
- Linux/Android update path (uses GitHub API body, not appcast)

## Testing

- Generate a test appcast locally with sample release notes and verify the `<description>` block contains valid CDATA-wrapped HTML
- Verify the appcast XML is well-formed (no unescaped `]]>` in release notes content)
- On macOS: confirm Sparkle renders the inline notes in the update dialog
- On Windows: confirm WinSparkle renders the inline notes
