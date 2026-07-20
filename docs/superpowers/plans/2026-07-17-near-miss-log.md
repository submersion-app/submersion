# Near-Miss Log (Safety Phase 4) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans.

**Goal:** ASRS-inspired personal incident log: standalone entries, optionally dive-linked, structured taxonomy, private by default.

**Architecture:** New HLC parent table `incidents` (schema v127, renumbered from v119 as main advanced past it at merge time) with an `IncidentRepository`, list/edit pages under `/incidents` (reached from Settings > Manage; there is no separate `/safety` hub route), a "Log near-miss" action in the dive detail overflow, and a linked-incidents row in the dive's safety review area. Privacy: incidents sync between the user's own devices and ride encrypted backups, but are touched by NO outbound exporter (UDDF/CSV/Subsurface never reference the table). Branch `safety-phase4-near-miss` stacked on phase 3.

## Global Constraints

Same as phases 1-3. Schema claims **v127** (renumbered from v119 at merge time). Non-punitive tone: the form asks what happened and what helped, never who failed.

## Tasks

1. **Domain + schema v127** (renumbered from v119). `Incident` entity; `IncidentCategory` enum (buoyancy, gasSupply, equipment, buddySeparation, marineLife, boatSurface, medical, planning, other); `IncidentSeverity` (minor, moderate, serious). Table `Incidents` (id PK, diverId nullable FK cascade, diveId nullable FK setNull — an incident must survive dive deletion, occurredAt, category, severity, narrative, contributingFactors?, lessonsLearned?, createdAt, updatedAt, hlc). Migration + backstop + tripwire (126→127) + migrationVersions. Full sync registration (hlcTargets, mergeOrder hasUpdatedAt:true, entityHasUpdatedAt, 13 serializer sites, parity seed).
2. **Repository + providers.** `IncidentRepository` (list newest-first, forDive, create/update/delete with markRecordPending/logDeletion, watchChanges) + tests. `incidentsProvider`, `incidentsForDiveProvider(diveId)`.
3. **UI.** `IncidentsListPage` (`/incidents`), `IncidentEditPage` (`/incidents/new?diveId=`, `/incidents/:id`): category chips, severity segmented control, occurredAt date picker, narrative (required), contributing factors, lessons learned. Settings > Manage entry point. Dive detail overflow "Log near-miss" (prefills diveId). Linked-incidents row appended to dive detail safety review section area. Widget tests.
4. **l10n sweep + verification.** en + 10 locales; format/analyze; affected sweep; commit; push; stacked PR.
