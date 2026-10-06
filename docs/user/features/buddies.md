# Buddies & Certifications

Track dive buddies, their certifications, and your own training history.

## Buddy Management

### Buddy Database

Build a contact list of your dive partners:

<div class="screenshot-placeholder">
  <strong>Screenshot: Buddy List</strong><br>
  <em>List of dive buddies with certification badges</em>
</div>

### Adding a Buddy

1. Go to **Settings** > **Buddies** (or from dive entry)
2. Tap **+ Add Buddy**
3. Fill in details
4. Save

### Buddy Fields

| Field | Description |
|-------|-------------|
| **Name** | Buddy's name |
| **Email** | Contact email |
| **Phone** | Contact phone |
| **Certification Level** | Highest cert level |
| **Certification Agency** | PADI, SSI, etc. |
| **Photo** | Profile picture |
| **Notes** | Additional info |

### Importing from Contacts

Tap **Import from Contacts** to:

1. Select a contact
2. Pre-fill name, email, phone
3. Add diving-specific info

## Buddy Roles

When linking buddies to dives, assign roles:

| Role | Description |
|------|-------------|
| **Buddy** | Dive partner |
| **Guide** | Dive guide |
| **Instructor** | Diving instructor |
| **Dive Master** | Divemaster |
| **Student** | Student diver |
| **Solo** | No buddy (solo diving) |

### Assigning Roles

1. In dive entry, go to **Buddies** section
2. Tap **+ Add Buddy**
3. Select buddy from list
4. Choose role
5. Repeat for additional buddies

## Buddy Statistics

Each buddy page shows:

| Stat | Description |
|------|-------------|
| **Total Dives Together** | Number of shared dives |
| **First Dive** | First dive with this buddy |
| **Last Dive** | Most recent dive together |
| **Favorite Sites** | Common dive locations |
| **Depth Range** | Min/max depths together |

### Social Statistics

In the main Stats section, view:

- **Top Buddies** - Most frequent partners
- **Dives by Buddy** - Breakdown chart
- **Solo Dives** - Percentage solo
- **Training Dives** - With instructors

## Digital Signatures

Buddies and instructors can add digital signatures to verify dives. Signatures are hand-drawn on the device screen and stored as PNG images alongside the dive record.

### Signature Types

| Type | Purpose |
|------|---------|
| **Instructor** | Instructor signs off on a training dive or course dive |
| **Buddy** | Dive buddy signs to verify participation |

### Requesting a Buddy Signature

From the dive detail page, the **Signatures** section lists all buddies assigned to the dive along with their signing status:

1. Tap **Request** next to an unsigned buddy
2. A handoff screen prompts you to pass the device to your buddy
3. The buddy taps **Ready to Sign** and draws their signature on the canvas
4. Tap **Done** to save, or **Clear** to redraw

A counter badge (e.g., "2/3") shows how many buddies have signed out of the total.

### Adding an Instructor Signature

For training dives, an instructor signature can be captured separately:

1. Open the dive detail page
2. In the signature section, tap **Add Instructor Signature**
3. Enter the instructor's name
4. The instructor draws their signature on the canvas
5. Tap **Save Signature** to store it

### Viewing Signatures

- Tap a signed buddy's card to view the full signature in a dialog
- Signed entries show a small signature preview thumbnail and the date signed
- A green **Signed** badge appears on dives that have signatures

### Storage

Signature image data is stored directly in the database as PNG bytes within the media table. Each signature record tracks the signer's name, an optional link to their buddy record, the signature type, and a timestamp.

## Certification Tracking

### Your Certifications

Track your diving certifications:

1. Go to **Settings** > **Certifications**
2. Tap **+ Add Certification**
3. Fill in details
4. Save

### Certification Fields

| Field | Description |
|-------|-------------|
| **Name** | Certification name |
| **Agency** | Certifying agency |
| **Level** | Certification level |
| **Card Number** | C-card number |
| **Issue Date** | When earned |
| **Expiry Date** | If applicable |
| **Instructor** | Instructor name/number |
| **Card Photos** | Front/back images |
| **Notes** | Additional info |

### Supported Agencies

| Agency | Full Name |
|--------|-----------|
| **PADI** | Professional Association of Diving Instructors |
| **SSI** | Scuba Schools International |
| **NAUI** | National Association of Underwater Instructors |
| **SDI/TDI** | Scuba Diving International / Technical Diving International |
| **GUE** | Global Underwater Explorers |
| **RAID** | Rebreather Association of International Divers |
| **BSAC** | British Sub-Aqua Club |
| **CMAS** | Confederation Mondiale des Activites Subaquatiques |
| **IANTD** | International Association of Nitrox and Technical Divers |
| **PSAI** | Professional Scuba Association International |
| **Other** | Other agencies |

### Certification Levels

Common certification progressions:

| Level | Description |
|-------|-------------|
| **Open Water** | Entry-level certification |
| **Advanced Open Water** | Intermediate level |
| **Rescue Diver** | Rescue skills |
| **Dive Master** | Leadership level |
| **Instructor** | Teaching certification |
| **Technical** | Tech diving certs |
| **Specialty** | Specific skills (nitrox, wreck, etc.) |

## Expiry Tracking

### Expiring Certifications

Some certifications expire:

- CPR/First Aid (typically 2 years)
- Instructor status (annual renewal)
- Some agency memberships

### Expiry Warnings

Submersion shows:

- **Yellow badge** - Expiring within 60 days
- **Red badge** - Expired

### Renewal Reminders

Set up reminders:

1. Open certification
2. Note expiry date
3. Submersion tracks automatically

## Dive Centers

### Center Database

Track dive operators you've dived with:

1. Go to **Settings** > **Dive Centers**
2. Tap **+ Add Center**
3. Fill in details

### Center Fields

| Field | Description |
|-------|-------------|
| **Name** | Center/shop name |
| **Location** | City/region |
| **Country** | Country |
| **GPS** | Coordinates |
| **Phone** | Contact number |
| **Email** | Contact email |
| **Website** | Web address |
| **Affiliations** | PADI, SSI, etc. |
| **Rating** | Your rating |
| **Notes** | Comments |

### Center Statistics

Each center page shows:

- Total dives with this center
- Sites visited through them
- Date range of dives

## Training Dives

### Marking Training Dives

For certification courses:

1. Set dive type to "Training"
2. Assign instructor as buddy
3. Add course notes

### Skill Tracking

Track skills learned:

- Use notes field for skills practiced
- Link to certification earned
- Reference training materials
