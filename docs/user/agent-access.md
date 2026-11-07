# Agent Access

Agent access lets an AI agent running on the same computer read and change
your logbook, through the Model Context Protocol (MCP). You can ask an agent
to find dives, tidy imported data, log a refresher, plan a trip's gear or
clean up duplicate sites, and it works through the same saves the app's own
pages use.

It is available in the desktop app on macOS, Windows and Linux. It is off
until you turn it on, and it only listens on this computer: nothing outside
your machine can reach it.

## Turning it on

1. Open **Settings > Data > Advanced > Data tools > Agent access**.
2. Turn on **Enable agent access**. The status shows **Listening** once the
   server is running.
3. Under **Connect a client**, copy the setup for your agent and add it to
   that agent's MCP settings. The setup carries the **Port** and the
   **Access token** the agent needs.

| Setting | What it does |
|---------|--------------|
| **Port** | The port the server listens on, from 1024 to 65535 |
| **Access token** | The secret an agent sends with every request. **Reveal**, **Copy** or **Regenerate** it; regenerating disconnects every agent until it has the new token |
| **Ask before applying changes** | Shows a confirmation in Submersion before an agent changes anything |

Agents can see every diver profile on this computer.

## What an agent can do

An agent reads any record: dives and their profiles, sites, trips, buddies,
gear, certifications, plans and the rest of the logbook. It can also run the
same queries as the app's search.

Changes come in two steps. The agent first previews a change, which shows
exactly what it would do and changes nothing, then applies it. With **Ask
before applying changes** on, Submersion shows the change before anything is
written:

- **New**, **Change** and **Delete** list each record and field.
- **Also adds**, **Also changes**, **Also deletes** and **Also unlinks** list
  what the change does to other records, such as the trip a moved dive
  stretches or the items a template brings to a checklist.
- **Merge into** names the record a duplicate merges into, and **Moves**
  counts the links that follow it.
- **Show every change** opens the full list.

Choose **Allow** or **Deny**. **Allow** becomes active after a moment, so a
stray click meant for another window cannot answer it.

Every applied change is recorded in the [Change Log](change-log.md) with the
agent as its source, and can be reverted from there like any other change.

## What stays in the app

An agent changes your records, not the app or this device. These are only
done in the app:

- **Adding photos and files.** An agent edits a photo's moment, people,
  species and colour, and deletes it, but never attaches one. Document pages
  are added in the app too.
- **Deleting or merging diver profiles.** The app offers to move a profile's
  dives first.
- **Dive profile samples.** A profile is edited in the profile editor.
- **Downloads and imports**, and the values the app works out from them.
- **Settings**, view layouts, backups, sync and storage.

A change that would break one of the app's own rules is refused in the
preview, with the reason, rather than applied halfway. For example, a
checklist keeps at least one section, a finished pre-dive check stays as it
ended, and a dive credits one requirement of a course.
