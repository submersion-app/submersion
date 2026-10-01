# Matching Photos and Videos to Dives

When you import photos or videos, Submersion reads the time each one was
taken and links it to the dive whose time window contains it. That window runs
from 30 minutes before entry to 60 minutes after exit. This page lists which
date Submersion reads from each kind of file, and what happens when a file
has none.

## Times Are Local Clock Times

Dive times are the digits your dive computer showed, in the local time where
you dived. Media times are compared in the same frame, so a capture time has
to be the local clock time where the photo or video was taken.

## Photos

A photo is dated from its EXIF data, first match wins:

| Order | Field | Notes |
|-------|-------|-------|
| 1 | **DateTimeOriginal** | When the shutter fired |
| 2 | **DateTimeDigitized** | When the image was digitized |
| 3 | **DateTime** | The file's general EXIF date |
| 4 | File modified date | Only when the photo has no EXIF date |

## Videos

MP4, MOV and M4V files can hold several dates. Submersion tries these in
order and uses the first one that gives a local clock time:

| Order | Field | Written by | How it is read |
|-------|-------|------------|----------------|
| 1 | **QuickTime creationdate** (`com.apple.quicktime.creationdate`) | iPhone, recent Apple software | Local time with its UTC offset, used as is |
| 2 | **Content created** (`©day`) | Some cameras and editing tools | Local time with its UTC offset, used as is |
| 3 | **Movie header creation time** (`mvhd`) | Every MP4 and MOV | See below |
| 4 | File modified date | Every file | Only when none of the above is present |

A creationdate or `©day` value written in UTC (ending in `Z`) carries no local
clock, so Submersion skips it and moves on to the next field.

### The movie header creation time

The MP4 format defines the movie header time as UTC, and phones follow that.
GoPro and some other cameras write their local clock there instead. The file
itself does not say which, so Submersion compares it with the file's
modified date, which the camera sets when it finishes recording:

- If the header time, read as UTC, agrees with the modified date at the start
  or end of the recording, the header is UTC. Submersion converts it to the
  local time of this computer, as Windows does for its **Media created**
  column. Import while you are in the timezone where you dived, or use
  **Shift capture times by** on the Files tab, described below.
- Otherwise the header is read as the camera's local clock. This is the GoPro
  case, and also what happens when the modified date is only the time the file
  was copied, which says nothing about the header.

### What Windows shows

Windows Explorer lists several dates for a video:

| Explorer column | Where it comes from | Used by Submersion |
|-----------------|---------------------|--------------------|
| **Media created** | The movie header time, converted from UTC | Yes, as described above |
| **Date modified** | The file system | Only as the last fallback, and to check the header |
| **Date created** | When this copy of the file was made | No |

## When a File Has No Capture Date

AVI, MKV and WEBM videos, PNG screenshots and files whose metadata was
stripped carry no date Submersion can read. Those are dated by their modified
date, which is often when they were copied rather than when they were
recorded.

The import review says so instead of reporting only that nothing matched:

- **No capture date found** means the file had no date at all.
- **No matching dive by the file date; the file has no capture date** means
  the only date was the modified date, and it fell outside every dive.

Either way, use **Choose dive** in the row's menu. On the **Files** tab, each
file also shows where its time came from, and **Shift capture times by** moves
every file at once when a camera clock was set wrong.
