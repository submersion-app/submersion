# Buddies and Dive Centers

Keep track of the people you dive with and the operators you dive through. Buddies and Dive Centers are two separate sections of the app, covered here together for convenience.

> [!NOTE]
> **Where to find them:** On desktop (800 px wide or more), **Buddies** and **Dive Centers** are separate items in the navigation rail. On a phone they are under **More** unless you move one into the bottom bar (**Settings > Appearance > Navigation layout**).

---

## Buddies

<!-- screenshot: images/buddies-and-dive-centers/buddy-detail.png: buddy detail -->

A buddy record stores everything you want to remember about a fellow diver: contact details, certification info, and a running history of dives you have done together.

### Adding a buddy

Tap the **+** button (or **Add Buddy** on desktop) to open the edit form. The fields available are:

| Field | Notes |
|-------|-------|
| **Name** | Required. |
| **Email** | Optional. Tapping it on the detail page opens your mail app. |
| **Phone** | Optional. Tapping it on the detail page opens your phone dialer. |
| **Certification Level** | Drop-down (e.g., Open Water, Advanced Open Water, Rescue Diver, Divemaster, Instructor). |
| **Certification Agency** | Drop-down (PADI, SSI, NAUI, SDI, TDI, GUE, RAID, BSAC, CMAS, IANTD, PSAI, Other). |
| **Notes** | Free text. |

You can also give a buddy a profile photo.

### Importing from your contacts

Instead of typing a buddy in, choose **Import from Contacts** in the Buddies list and pick a contact. Their name, email, phone and photo come across into a new buddy record you can review before saving.

### Assigning a buddy to a dive

When you log or edit a dive, the **Buddies** section in the dive form shows a buddy picker. Tap **Add** to open a searchable list of your buddies (**Select Buddies**). For each buddy you choose a **role** on this dive, and a person can hold more than one role at once (a divemaster who is also the dive guide, for example). The built-in roles are:

- **Buddy**
- **Dive Guide**
- **Instructor**
- **Divemaster**
- **Student**
- **Solo**

**Add custom role...** creates your own role on the spot; **No role** leaves it blank. Custom roles are managed in **Settings > Manage > Dive Roles**, where you can also hide built-in roles you never use.

Your own role on the dive is set the same way, with **Set my role** (shown as **Me** in the picker).

Selected buddies appear as chips on the dive form, each showing the person's name and roles. Tap a chip to change the roles; tap the X to remove the buddy from the dive. **Add New Buddy** creates a buddy record without leaving the dive form.

> [!TIP]
> Set your role to **Solo** when you dive without a buddy. This keeps the field accurate for your statistics rather than leaving it blank.

### Buddy statistics

The buddy detail page shows a **Dive Statistics** card with the number of dives you have done together, the date of your first and last shared dive, and your most-visited site together. Tap **View all** to jump to the dive list filtered to just those dives.

### Merging duplicate buddies

If the same person has been entered more than once (for example, with slightly different name spellings), you can merge the duplicates into one record without losing any dive history.

1. In the buddy list, choose **Select items** from the overflow menu and select the duplicates you want to combine.
2. Choose **Merge** from the selection action bar.
3. The merge form shows conflicting field values from each duplicate and lets you choose which value to keep by tapping the cycle button next to any field.
4. Confirm to merge. The surviving record absorbs all dive links from the deleted duplicates. If both records were on the same dive, the surviving buddy keeps the roles of both. The merge can be undone immediately after it completes.

### Buddy signatures on training dives

On a dive that has at least one buddy, a **Signatures** section appears on the dive detail page. Any buddy associated with the dive can sign the dive log entry directly on your device:

1. Tap **Request** on the buddy's card.
2. Hand the device to the buddy; the signature canvas opens with a "Hand your device to" prompt naming them.
3. The buddy draws their signature and taps **Done**.
4. The signed card shows a preview of the signature.

On a training dive, **Capture Instructor Signature** collects the instructor's signature the same way.

Signatures (both buddy and instructor signatures) appear inline at the bottom of each dive entry when you export your log as a PDF.

---

## Dive Centers

<!-- screenshot: images/buddies-and-dive-centers/dive-center-detail.png: dive center detail -->

A dive center record stores details about a shop, club, or operator you have dived with or through.

### Adding a dive center manually

Tap **+** (or **Add Center** on desktop) to open the edit form. The fields are:

| Field | Notes |
|-------|-------|
| **Name** | Required. |
| **Street** | Optional. |
| **City** | Optional. |
| **State / Province** | Optional. |
| **Postal Code** | Optional. |
| **Country** | Optional. |
| **Latitude / Longitude** | Optional coordinates, used to pin the center on the map. |
| **Phone** | Optional. |
| **Email** | Optional. |
| **Website** | Optional. |
| **Affiliations** | Free-form tags (e.g., PADI, SSI) shown as chips on the detail page. |
| **Rating** | A numeric score. Map markers are color-coded by rating (green ≥ 4.0, blue ≥ 3.0, orange ≥ 2.0, red below 2.0). |
| **Notes** | Free text. |

### Importing dive centers from the built-in database

Rather than typing everything by hand, use the import tool to pull a center from the bundled global directory.

1. From the Dive Centers list, tap **Import**.
2. Search by name, location, or affiliation. Quick-search chips for common terms (PADI, SSI, Thailand, Indonesia, Egypt, Mexico) appear below the search bar.
3. Results are split into two groups: **My Centers** (centers already in your log that match the query) and **From Database** (external entries from the bundled directory). External results show the center's type (shop, club, or other), affiliations, and a GPS indicator where coordinates are available.
4. Tap a result to preview details, then tap **Import to My Centers** to add it.

### Map view

Switch to the map view to see all your saved dive centers plotted on a world map. Markers are clustered when zoomed out; tap a cluster to zoom in and spread it apart. Tap a marker to select the center and show a summary card at the bottom; tap **Details** on the card to open the full record. Use the **Fit all** button to zoom the map to show every center at once.

Centers without saved coordinates do not appear on the map. Add latitude and longitude to a center's record to make it appear.

> [!TIP]
> When you import a center from the built-in database, GPS coordinates are carried over automatically if the source record has them.

### Linking a dive center to a dive

When logging or editing a dive, the dive form includes a **Dive Center** picker. Select one of your saved centers, or create a new one without leaving the form. The linked center appears on the dive detail page and is counted in the center's dive history.

### Dive center statistics

The dive center detail page shows a list of all the dives you have logged with that center. The dive count also appears in the list and map views (e.g., "12 dives" in the map info card).

---

## How buddies and centers surface in Insights

[Insights](statistics.md) includes breakdowns by buddy and by dive center. You can see which buddies you dive with most frequently, how your activity is distributed across centers, and trends over time. Each entry links back to the corresponding buddy or center record.

## See also

- [Dive Logging](dive-logging.md)
- [Certifications and Courses](certifications-and-courses.md)
- [Statistics](statistics.md)
- [Import and Export](import-export.md)
- [Settings](settings.md)
