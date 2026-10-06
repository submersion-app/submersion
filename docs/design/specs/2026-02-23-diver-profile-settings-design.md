# Diver Profile Settings Redesign

## Problem

The Settings > Diver Profile section is unintuitive and confusing:

1. **Navigation ejects from settings**: On mobile, tapping "Diver Profile" in Settings calls `context.push('/divers')`, leaving the settings context entirely. Users expect to edit their profile within settings.
2. **Monolithic edit form**: `DiverEditPage` is a single 900-line scroll with 16 text fields covering personal info, emergency contacts, medical info, insurance, and notes. Overwhelming.
3. **Desktop/mobile inconsistency**: Desktop shows a simplified inline switcher; mobile navigates away.
4. **No inline editing from settings**: The settings `_ProfileSectionContent` only shows an active diver card and links out.

## Approach: Settings-Integrated Profile Hub

All diver profile management lives within settings navigation. The old `/divers` routes remain for backward compatibility but are no longer the primary path.

## Navigation Structure

```text
Settings tab
  Diver Profile tap -> /settings/diver-profile  [STAYS IN SETTINGS]
    Active Diver Card (avatar + name + Active badge)
    Personal Info        >  -> /settings/diver-profile/personal
    Emergency Contacts   >  -> /settings/diver-profile/emergency
    Medical Information  >  -> /settings/diver-profile/medical
    Insurance            >  -> /settings/diver-profile/insurance
    Notes                >  -> /settings/diver-profile/notes
    [Switch Diver] -> bottom sheet
    [Add New Diver] -> /settings/diver-profile/new
```

## Routes

| Route | Page | Purpose |
|-------|------|---------|
| `/settings/diver-profile` | `DiverProfileHubPage` | Profile hub with sections list |
| `/settings/diver-profile/personal` | `PersonalInfoEditPage` | Name, email, phone |
| `/settings/diver-profile/emergency` | `EmergencyContactsEditPage` | Primary + secondary contacts |
| `/settings/diver-profile/medical` | `MedicalInfoEditPage` | Blood type, allergies, meds, clearance |
| `/settings/diver-profile/insurance` | `InsuranceEditPage` | Provider, policy, expiry |
| `/settings/diver-profile/notes` | `NotesEditPage` | Free text notes |

## Page Designs

### Profile Hub Page (`/settings/diver-profile`)

- Active diver card at top: circle avatar (initials/photo), name, "Active" badge
- Section list tiles with chevrons and subtitle summaries:
  - Personal Info: email or phone or "Not set"
  - Emergency Contacts: "2 contacts set" or "1 contact set" or "Not set"
  - Medical Information: blood type or "Not set"
  - Insurance: provider + expiry or "Not set" (with "Expired" warning badge)
  - Notes: truncated first line or "Not set"
- Switch Diver tile: opens modal bottom sheet
- Add New Diver tile: navigates to create form
- Delete Diver: overflow menu in AppBar, only when >1 diver, with confirmation

### Sub-Pages (Section Editors)

All follow the same pattern:

- AppBar with back arrow + section title + "Save" text button
- Grouped form fields in a Card
- Dirty-check on back navigation (unsaved changes dialog)
- On save: update diver, pop back to hub, show success snackbar

**Personal Info**: Name (required), Email, Phone
**Emergency Contacts**: Primary (name, phone, relationship) + Secondary (same)
**Medical Information**: Blood type (dropdown), Allergies, Medications, Medical clearance expiry (date picker), Medical notes (multi-line)
**Insurance**: Provider, Policy number, Expiry date (date picker)
**Notes**: Multi-line text area

### Diver Switching (Bottom Sheet)

- Lists all divers with avatar, name, dive stats, active indicator
- Tapping a non-active diver switches immediately (updates currentDiverIdProvider)
- Hub page rebuilds to show newly active diver's data
- Bottom sheet dismisses on selection

### Add New Diver

- Navigates to Personal Info sub-page in "create" mode (empty fields, "Create" button)
- After creation, returns to hub with new diver set as active

## Files to Create

```text
lib/features/settings/presentation/pages/
  diver_profile_hub_page.dart         # Main hub page
  personal_info_edit_page.dart        # Personal info editor
  emergency_contacts_edit_page.dart   # Emergency contacts editor
  medical_info_edit_page.dart         # Medical info editor
  insurance_edit_page.dart            # Insurance editor
  notes_edit_page.dart                # Notes editor
```

## Files to Modify

- `lib/core/router/app_router.dart` - Add new settings sub-routes
- `lib/features/settings/presentation/widgets/settings_list_content.dart` - Change Diver Profile navigation target
- `lib/features/settings/presentation/pages/settings_page.dart` - Update `_ProfileSectionContent` for desktop

## What Stays

- `/divers` routes remain for onboarding redirect guard and backward compatibility
- `DiverListPage`, `DiverDetailPage`, `DiverEditPage` remain functional but are no longer primary path
- `DiverRepository`, `Diver` entity, providers unchanged
- Multi-diver support stays prominent (Switch Diver on hub, bottom sheet)

## What Changes

- Settings "Diver Profile" navigates to `/settings/diver-profile` instead of `/divers`
- Profile editing is sectioned into 5 focused sub-pages
- All profile management stays within settings navigation context
- Desktop settings detail pane shows the hub page instead of the old switcher
