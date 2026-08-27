# Debug Mode

Debug Mode turns on a built-in log recorder that captures what the app is doing
behind the scenes. Use it when you want to send useful information to support
for a bug report, or when troubleshooting a dive-computer download, Bluetooth
connection, or import problem.

<div class="tip">
<strong>Tip:</strong> Logs are only recorded while Debug Mode is on. If you want to
capture a problem, enable Debug Mode <em>before</em> you try to reproduce it.
</div>

## What Gets Logged

While Debug Mode is enabled, Submersion appends timestamped entries to a single
log file (`submersion.log`) on the device. Each entry has a category and a
severity level so you can filter what you see.

| Category | What it covers |
|----------|----------------|
| **App** | General app events, navigation, errors |
| **Bluetooth** | BLE discovery, pairing, and data transfer |
| **Serial** | USB / serial dive-computer connections |
| **libdc** | Output from the libdivecomputer engine |
| **Database** | Local database queries and migrations |

| Severity | When it's used |
|----------|----------------|
| **DEBUG** | Verbose, step-by-step detail |
| **INFO** | Routine progress and milestones |
| **WARN** | Something unexpected, but recoverable |
| **ERROR** | Something failed |

The log file is capped at 5 MB. When it gets larger than that, Submersion
trims the oldest entries automatically so the file never grows without bound.

## Enable Debug Mode

Debug Mode is intentionally hidden so it doesn't get turned on by accident.

1. Open the **Settings** tab (gear icon in the navigation bar).
2. Scroll to the very bottom of the Settings page, where the Submersion app
   icon, name, and version number are shown.
3. **Tap the version number five times** in quick succession.
4. A "Debug mode enabled" notification appears at the bottom of the screen,
   confirming that recording has started.

<div class="screenshot-placeholder">
  <strong>Screenshot 1: Enabling Debug Mode</strong><br>
  <em>The Settings page footer showing the version string that needs to be tapped five times.</em>
</div>

Once enabled, a new **Debug** entry appears in the Settings list, just above
**About**. It has a bug icon and the subtitle "Logs & diagnostics."

<div class="screenshot-placeholder">
  <strong>Screenshot 2: Debug section in Settings</strong><br>
  <em>The Settings list with the new "Debug" row visible.</em>
</div>

<div class="tip">
<strong>Persistence:</strong> Debug Mode stays on across app restarts. You will
need to turn it off manually when you are done troubleshooting (see below).
</div>

## Reproduce the Problem

With Debug Mode on, do whatever triggers the issue you want to report &mdash;
download a dive, import a file, sync, etc. The relevant events will be
recorded as they happen.

## View and Filter Logs

Open **Settings &rarr; Debug** to see the captured log entries.

<div class="screenshot-placeholder">
  <strong>Screenshot 3: Debug Log Viewer</strong><br>
  <em>The log viewer showing category chips, the minimum-severity dropdown, and a list of recent entries.</em>
</div>

The viewer offers three ways to narrow down what's shown:

| Control | What it does |
|---------|--------------|
| **Category chips** | Tap a chip (App, Bluetooth, Serial, libdc, Database) to toggle that category on or off. |
| **Min severity** | Hide entries below the selected severity. Set to **WARN** or **ERROR** to focus on problems. |
| **Search** (magnifying-glass icon) | Filter entries that contain a specific word, error message, or device name. |

## Share Logs with Support

The three buttons at the bottom of the Debug Log Viewer let you export the
captured information.

| Button | What it sends | When to use it |
|--------|---------------|----------------|
| **Share** | The **full** log file, attached as `submersion.log`, via your device's share sheet (email, Messages, AirDrop, etc.) | The recommended option when filing a bug report or sending logs to support. |
| **Copy** | Only the **filtered** entries currently visible on screen, as plain text on your clipboard. | When you want to paste a small, relevant slice into a GitHub issue or forum reply. |
| **Save** | The **full** log file, saved to a location you choose, as `submersion-debug-logs.txt`. | When you want a local copy you can attach later. |

<div class="warning">
<strong>Note:</strong> "Copy" respects the active filters &mdash; it copies only
what's visible. "Share" and "Save" always include the entire log file regardless
of filters.
</div>

## Clear the Log

To wipe the log file and start fresh (useful before reproducing a specific
issue):

1. Open **Settings &rarr; Debug**.
2. Tap the **three-dot menu** in the top-right corner.
3. Choose **Clear Logs**.

<div class="screenshot-placeholder">
  <strong>Screenshot 4: Overflow menu</strong><br>
  <em>The three-dot menu in the Debug Log Viewer showing "Disable Debug Mode" and "Clear Logs".</em>
</div>

## Disable Debug Mode

When you are done troubleshooting, turn Debug Mode back off so the app stops
writing to the log file.

1. Open **Settings &rarr; Debug**.
2. Tap the **three-dot menu** in the top-right corner.
3. Choose **Disable Debug Mode**.

You'll be returned to Settings, and the **Debug** section will disappear from
the list.

## Privacy

Submersion's debug logs are stored only on your device until you choose to
share them. They are not uploaded automatically and not transmitted to
Submersion or any third party.

The log file can contain technical details such as dive-computer model names,
Bluetooth identifiers, file names being imported, and database error messages.
Before sharing a log with someone outside your trusted circle, you may want to
open the file in a text editor and review it.

## Troubleshooting Debug Mode

| Problem | What to try |
|---------|-------------|
| Tapping the version doesn't activate Debug Mode | Tap faster &mdash; all five taps need to land in quick succession. |
| No entries appear in the viewer | Debug Mode only records events that happen *after* it's enabled. Reproduce the issue first, then come back. |
| Old entries are missing | The log file is capped at 5 MB; older entries are trimmed automatically. Clear the log and reproduce only the specific scenario you want to capture. |
