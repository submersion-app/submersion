# Privacy Policy

**App:** Submersion
**Last Updated:** 2026-03-06

## Data Collection

Submersion is a local-first dive logging application. All data you enter is stored on your device. The app may collect and store the following types of information based on your usage:

- **Dive logs** — date, time, depth, duration, temperature, notes, and other dive parameters
- **Dive sites** — location names, GPS coordinates, descriptions, and conditions
- **Diver profile** — name, certification information, and dive preferences
- **Gear inventory** — equipment names, serial numbers, purchase dates, and service records
- **Buddies** — names and contact information for dive partners
- **Photos and videos** — media attached to dive entries, selected from your device library
- **Dive computer data** — depth profiles, tank information, and telemetry downloaded via Bluetooth

## Data Storage

All data is stored locally on your device in a SQLite database. Submersion does not operate any remote servers, and your data is not transmitted to any server owned or operated by Submersion.

## Cloud Backup

Submersion offers an optional backup feature using Google Drive. This backup is:

- **User-initiated** — backups only occur when you explicitly choose to create one
- **Stored in your own Google Drive** — the backup file is saved to your personal Google Drive account
- **Transmitted over HTTPS** — all communication with Google Drive uses encrypted connections

Submersion does not have access to your Google Drive beyond the backup files you explicitly create through the app.

## Health Data

On iOS, Submersion can optionally read dive workout data from Apple HealthKit. This data is:

- **Read-only** — Submersion reads existing dive workouts but does not write to HealthKit
- **Never transmitted off device** — HealthKit data stays on your device
- **Never shared with third parties**

This feature is not currently available on Android.

## Data Sharing

Submersion does **not** share your data with third parties. Specifically:

- No analytics or tracking services
- No advertising networks
- No account creation required
- No data transmitted to remote servers (except the optional Google Drive backup to your own account)
- No third-party SDKs that collect user data

## Device Permissions

Submersion requests the following permissions only as needed for specific features:

| Permission | Purpose |
|---|---|
| **Bluetooth** | Discover and communicate with BLE dive computers |
| **Location** | Tag dive sites with GPS coordinates; required for BLE scanning on Android 11 and below |
| **Photos and media** | Attach photos and videos to dive entries |
| **Media location** | Read GPS data from photo EXIF metadata to suggest dive site locations |
| **Contacts** | Select dive buddies from your device contacts |
| **Notifications** | Send gear maintenance service reminders |
| **Exact alarms** | Schedule precise gear maintenance reminders |

All permissions are optional. The app will function without them, though related features will be unavailable.

## Data Deletion

- You can delete any or all of your data from within the app at any time.
- Uninstalling Submersion removes all locally stored data from your device.
- Google Drive backups can be deleted directly from your Google Drive account.

## Children

Submersion is not directed at children under the age of 13. We do not knowingly collect personal information from children under 13. If you believe a child under 13 has provided data through the app, please contact us so we can take appropriate action.

## Changes to This Policy

This privacy policy may be updated from time to time. Changes will be reflected by updating the "Last Updated" date at the top of this document.

## Contact

If you have questions or concerns about this privacy policy, you can reach us at:

- **Email:** privacy@submersion.app
- **GitHub:** Open an issue at [github.com/submersion-app/submersion](https://github.com/submersion-app/submersion)

## Open Source

Submersion is open-source software. The full source code is available at:

[https://github.com/submersion-app/submersion](https://github.com/submersion-app/submersion)
