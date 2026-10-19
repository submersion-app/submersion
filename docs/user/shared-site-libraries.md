# Shared site libraries

A **shared site library** is a set of dive sites kept together by a group of
divers: a dive shop's house reefs, a survey team's transects, or the sites a
group of friends dives every season. Each member sees the same sites, with the
same names, coordinates, depths, hazards and access notes, and changes made by
one member reach everyone on their next sync.

The library lives in a folder of cloud storage the group controls, an
S3-compatible bucket or a WebDAV server. There is no Submersion server and no
Submersion account. You can belong to more than one library, each in its own
folder.

Open **Settings > Data > Shared site libraries** to see your libraries and
connect new ones.

## Roles

Every member has one role in each library:

| Role | Can do |
| --- | --- |
| **Owner** | Everything an editor can, plus review suggestions, change roles, approve members, manage encryption, and make and restore backups. |
| **Editor** | Add sites to the library, and edit or delete library sites directly. |
| **Reader** | See every library site, and suggest changes for an owner to review. Edits a reader's device writes directly do not count. |

A reader who opens a library site and taps edit sees **Suggest changes**: the
changed fields and an optional note are sent as a suggestion when they tap
**Send**, and the site itself is not touched until an owner accepts it.

> [!IMPORTANT]
> Roles in the app decide what each member's edits count for. What stops a key
> from writing files at all is the storage itself, so give each member a key
> with only the rights their role needs. See [Setting Up Storage](#setting-up-storage).

## What Stays Private

Adding a site to a library shares its name, location, depths, description,
hazards, access, entry and exit, mooring, parking, site types, tags, species
and features. Before a site is added, Submersion lists exactly what every
member will see.

Your **notes** and **rating** on a site stay yours, even on library sites:
every member keeps their own, and no other member sees them. They follow you to
your other devices through [Multi-Device Sync](multi-device-sync.md). Your dives
and photos never leave your personal logbook.

## Connecting a Library

1. Tap **Connect a library**.
2. Enter the **library folder**. Each library is a folder inside
   `submersion-sites` at the top of your bucket or server, beside the
   `submersion-sync` and `submersion-media` folders. A folder name cannot start
   with `sites`, `members`, `suggestions` or `backups`.
3. Choose the server the library lives on with **Change** (S3-compatible or
   WebDAV accounts only), or add one with **My own server** and the bucket or
   server details and the key you were given.
4. Tap **Check location**. Submersion looks in the folder and offers to **Join** the
   library that is there. If the folder is empty, it offers to
   **Create library**, or to **Restore from a backup file** (see
   [Backups](#backups)).

### Creating a library

The diver who creates a library is its first owner. Submersion then shows the
library's **recovery code** once. Store it somewhere safe, apart from the
storage keys: it can make whoever holds it an owner of the library, and it
also opens the library if it is encrypted.

### Joining a library

A new member's device writes a signed member card to the library and waits for
an owner's approval. Until then the member reads the library, but nothing they
write counts.

Each member has one **signing key** per profile, which Submersion makes for
you and carries to your other devices through
[Multi-Device Sync](multi-device-sync.md). Every edit, suggestion and role
change is signed, and every device checks the signatures, so a member cannot
pass off an edit as someone else's.

## Approving Members

Owners see new members under **Waiting for approval** on the library's
**Members** page, with the first characters of each member's key. Each member
sees their own key as **Your key** on the library page. Before tapping
**Approve**, compare the two, for example over a call or in person, so you
know the request is from the person you expect. If the card's key changed
since the list was shown, **Approve** says so and shows the new key to compare
instead. **Reject** removes their card, and nothing they write counts. Only new
storage keys stop a rejected member from writing files at all.

Suggestions from a member who is still waiting for approval are held. The
library page and the Suggestions page say how many are waiting, and they reach
the Suggestions page as soon as you approve their author.

A member who leaves keeps their role in the library's records until an owner
taps **Remove role**. When an editor or owner leaves, is made a reader, or has
their role removed, the edits they made until then keep counting for every
member, including members who join later; anything they write afterwards does
not.

### Removing someone

To remove an approved member, for example someone who has left your group, an
owner opens the role menu beside them on the **Members** page and taps
**Remove from library**. Everything they contributed stays in the library: the
sites and edits they made before the removal keep counting, and suggestions
they made before it stay in the Suggestions page for an owner to decide. From
then on they can no longer edit sites or suggest changes, and their own app
shows that an owner removed them. Their app keeps the library's sites but stops
changing them; leaving the library there keeps personal copies of the sites
they dived.

Removing someone does not stop them reading the library: anyone who holds the
storage keys can read its files. To cut off reading too, change the storage
keys, and the passphrase if the library is encrypted.

Removed people are listed under **Removed** on the **Members** page. **Allow
back** lets them return: their app lists them again at its next sync, and they
wait under **Waiting for approval** like anyone new. A removal outlives a
restore from a backup taken before it.

If a device finds the library's roles changed by someone it does not know as an
owner, the library page warns, and the device only reads the library until the
roles are put right. This also happens to a device that was away while
ownership passed to a new owner: leave the library and join it again to bring
it up to date. If more than one profile on the device belongs to the library,
leave it on each of them first, since the device keeps what it knows about a
library until no profile there belongs to it. Until then, owner actions on that device, such as approving a
member or changing a role, are refused, so they cannot undo changes the device
has not seen.

## Encryption

By default anyone with access to the storage folder can read the library.
Owners can turn on **encryption** from the library page:

- **Turn on encryption** asks for a passphrase. Every file in the library is
  rewritten sealed, and a new recovery code is shown. Each member enters the
  passphrase once per profile.
- **Change passphrase** makes a new key and a new recovery code, and rewrites
  every file under the new key. Share the new passphrase only with the members
  who stay: anyone who knew the old one, or kept a copy of its key, can no
  longer read anything written afterwards.
- **Turn off encryption** rewrites every file readable by anyone with storage
  access.

Turning encryption on and changing the passphrase each make a new recovery
code, which replaces the library's old one for every owner: tell the other
owners to keep the new code in place of the old. Only an owner can turn
encryption off. Submersion records it in the owner-signed roles, so someone who
can only change the library's files cannot switch it off.

The passphrase or the recovery code opens an encrypted library. File names,
sizes, and the number of sites and members are not hidden.

> [!NOTE]
> A file left under the old key, for example by a passphrase change that was
> cut short or a member's upload during one, still opens for everyone who has
> the new passphrase, and an owner's next sync re-seals it under the new key.

## If an Owner Is Lost

A library with only one owner shows a warning on its page. Choose a second
owner when you can: either owner can then manage the library alone.

If every owner has lost access, for example after reinstalling without their
synced profile:

1. **Recover ownership** with the library's recovery code makes you an owner.
   An owner can also issue a **New recovery code**, for example if the old one
   may have leaked.
2. If the recovery code is lost too, any member can **Reset ownership** and
   become the only owner. Every other member's device then asks them to accept
   the reset, and stops writing to the library until they do, so a reset
   cannot take a library over unnoticed.

## Backups

Owners can back a library up and restore it, much like the logbook's own
[backups](backup-and-restore.md). Open **Backups** from the library page.

- **Where they are kept.** Each backup is kept on the owner's device, beside
  the logbook backups, and in a `backups` folder beside the library, so every
  owner sees the same list. A backup kept in both places asks which copy to
  delete.
- **Automatic backups.** An owner's device makes one backup a day after a
  successful sync, unless another owner made one in the last 20 hours. The
  last 7 unpinned backups are kept in each place; pin a backup to keep it.
- **Back up now** makes a backup at once, with an optional note.
- **Export** shares a backup file, or saves it where the system has no way to
  share files. **Import a backup** adds one saved elsewhere, pinned so the
  daily pruning keeps it. Every backup is signed by the owner who made it, and
  a file that is not a backup of this library is refused.
- **Restore** puts the library back exactly as it was in the backup. Sites
  added since are removed, roles return as they were (with you kept as an
  owner), and members who joined since wait for approval again. Every member
  gets the restored library on their next sync. Before restoring, Submersion
  makes a pinned backup of the library as it is now, so a restore can be
  undone. Only a backup made by a current owner, with the key the library
  approves for them, can be restored: a backup made by an owner who has since
  left, or before an ownership reset, stays listed but is refused.

A backup made before the passphrase was changed opens with the library's
earlier key, which the library keeps. Only a backup older than that, such as
one from before encryption was turned off and on again, asks for the
passphrase or recovery code of its time.

If the library's storage is lost, or you want to move it, connect to an empty
folder and choose **Restore from a backup file**. The library keeps its
identity, so members only need to connect to the new folder. On a device that
already holds the library, only an owner can do this. The restored roles keep
you as an owner and are signed as the newest, so members whose devices know
later roles still accept them. If the old folder
still holds the library, Submersion says so: members who stay connected there
keep using that copy until they move.

## Setting Up Storage

The connect page links to **How to set up storage**, which shows these
examples filled in with your bucket and folder, with a **Copy** button for
each.

### S3-compatible storage

Make two kinds of keys. Owners and editors get a key that reads and writes the
library folder:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": ["arn:aws:s3:::BUCKET"],
      "Condition": {
        "StringLike": { "s3:prefix": ["submersion-sites/FOLDER/*"] }
      }
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": ["arn:aws:s3:::BUCKET/submersion-sites/FOLDER/*"]
    }
  ]
}
```

Readers get a key that reads the folder and writes only its `members` and
`suggestions` folders:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": ["arn:aws:s3:::BUCKET"],
      "Condition": {
        "StringLike": { "s3:prefix": ["submersion-sites/FOLDER/*"] }
      }
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject"],
      "Resource": ["arn:aws:s3:::BUCKET/submersion-sites/FOLDER/*"]
    },
    {
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:DeleteObject"],
      "Resource": [
        "arn:aws:s3:::BUCKET/submersion-sites/FOLDER/members/*",
        "arn:aws:s3:::BUCKET/submersion-sites/FOLDER/suggestions/*"
      ]
    }
  ]
}
```

Readers need write access to `members` and `suggestions` for their own card
and suggestions, and S3 cannot limit a key to its own files there. A reader's
key could therefore delete another member's card or suggestion. It cannot
change one unnoticed: every card and suggestion is signed, and an altered one
counts for nothing.

Replace `BUCKET` with your bucket and `FOLDER` with the library folder. Other
S3-compatible services (Backblaze B2, Wasabi, MinIO, Cloudflare R2) accept the
same policy or have an equivalent per-key prefix setting.

### WebDAV

Share the library folder read-only with readers, and its `members` and
`suggestions` folders writable, where your server allows per-folder rights
(for example Nextcloud share permissions). Owners and editors need write
access to the whole folder.

## Related

- [Dive Sites](dive-sites.md)
- [Multi-Device Sync](multi-device-sync.md)
- [Encrypted Sync](encrypted-sync.md)
- [Backups](backup-and-restore.md)
