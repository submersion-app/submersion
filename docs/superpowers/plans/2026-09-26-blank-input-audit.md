# Blank-input audit (#1900)

Every migrated field keeps today's blank meaning, written explicitly at the
call site. The rows below are the ones whose blank meaning looks questionable.
None was changed; each is for the maintainer to decide.

| Site | Field | Blank today | Why questionable |
|---|---|---|---|
| dive_edit_page.dart, weight row amount | weight amount | 0 kg (row kept) | An empty amount records a weight entry of 0 kg rather than no amount. |
