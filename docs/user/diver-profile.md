# Diver Profile

Your diver profile stores the personal and safety details that belong to you as a diver, and Submersion supports more than one profile on the same device so families, instructors, or anyone who shares a device each get their own independent log.

> [!NOTE]
> **Where to find it:** Settings → Diver Profile

<!-- screenshot: images/diver-profile/profile.png — diver profile hub showing the active diver card and section tiles -->

## Profile sections

The profile is organised into five focused sections. Tap any tile to open its editor; unsaved changes are caught before you navigate away.

### Personal info

Name (required), email address, and phone number. The name appears everywhere in the app — on dive cards, stats, and the diver-switcher sheet. Email and phone are stored locally only; they are never sent to Submersion.

### Emergency contacts

Primary and secondary emergency contacts, each with a name, phone number, and relationship. The app flags the hub tile when no contact is set, so you know at a glance if this safety information is missing.

### Medical information

| Field | What to enter |
|-------|---------------|
| Blood type | e.g. A+, O− |
| Allergies | Relevant allergies, one per line or comma-separated |
| Medications | Ongoing medications relevant to diving |
| Medical clearance expiry | Date your dive-medical certificate expires |
| Medical notes | Free text for anything else a rescue team should know |

The app warns you on the hub tile when a medical clearance date is expired or within 30 days of expiry.

### Insurance

Dive-insurance provider name, policy number, and policy expiry date. An "Expired" badge appears on the hub tile when the policy has lapsed, and the tile subtitle turns red so you cannot miss it.

### Notes

A free-text field for anything that does not fit the structured sections — travel preferences, dive-agency membership numbers, or personal reminders.

## Prior dive experience

If you logged dives before you started using Submersion, you can enter those totals so your lifetime statistics reflect your full history:

- **Prior dives** — total number of dives before you started logging here.
- **Prior hours / minutes** — total bottom time from those dives.
- **Diving since** — the year you started diving.

These offsets appear in [Statistics](statistics.md) alongside your Submersion-logged dives, labelled so the two figures stay distinct.

> [!TIP]
> Prior experience is stored on the diver profile, not on individual dive entries. Edit it via **Settings → Diver Profile**, then open the legacy edit form with the pencil icon (accessible from the Divers list at `/divers`).

## Multiple divers on one device

You can keep more than one diver profile on the same device. Each profile has its own:

- Dive log
- Certifications and courses
- Settings and unit preferences (depth, temperature, pressure, weight, volume, SAC rate, time and date format, theme, language, decompression defaults, and display preferences)

Dive sites and trips are shared across divers on the same device because they describe the physical world rather than a person's experience.

### Adding a diver

From the Diver Profile hub, tap **Add New Diver**. You are taken to the Personal Info editor in create mode. Enter a name (required) and, optionally, email and phone, then tap **Create**. The new profile is set as the active diver immediately.

### Switching divers

Tap **Switch Diver** on the hub to open a bottom sheet listing every profile on the device. The currently active diver is marked with a check. Tap any other name to switch — the entire app updates instantly to show that diver's data.

<!-- screenshot: images/diver-profile/switch-diver.png — diver-switcher bottom sheet with multiple profiles listed -->

> [!TIP]
> On supported platforms you can also switch divers with the keyboard shortcut Cmd+Shift+D (macOS) without opening Settings at all.

### Deleting a diver

Open the Diver Profile hub and tap the overflow menu (⋮) in the top-right corner. **Delete Diver** appears only when two or more profiles exist — you cannot delete the only profile on a device. Dive logs belonging to the deleted diver are unassigned; trips and sites shared with other divers are reassigned to the remaining diver rather than deleted.

## See also

- [Settings](settings.md) — units, decompression defaults, theme, and all per-diver preferences
- [Statistics](statistics.md) — lifetime dive totals, including prior-experience offsets
- [Certifications and Courses](certifications-and-courses.md) — certifications tied to a diver profile
- [Multi-Device Sync](multi-device-sync.md) — how multiple-diver profiles are kept in sync across devices
- [Safety](safety.md) — the offline emergency card built from these medical and contact details
