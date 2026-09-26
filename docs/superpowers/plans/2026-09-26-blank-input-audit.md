# Blank-input audit (#1900)

Every migrated field keeps today's blank meaning, written explicitly at the
call site. The rows below are the ones whose blank meaning looks questionable.
None was changed; each is for the maintainer to decide.

| Site | Field | Blank today | Why questionable |
|---|---|---|---|
| dive_edit_page.dart, weight row amount | weight amount | 0 kg (row kept) | An empty amount records a weight entry of 0 kg rather than no amount. |
| ccr_settings_panel.dart, diluent O2 | diluent O2 % | diluent gas dropped (null) | Clearing O2 to retype it reports "no diluent" to the dive until the diver types again. |
| scr_settings_panel.dart, supply O2 | supply O2 % | supply gas dropped (null) | Same shape as the CCR diluent. |
| segment_editor.dart, target depth | segment target depth | 0 m (a surface target) | Saving an emptied depth plans a leg to the surface rather than asking for a depth. |
| segment_editor.dart, duration | segment duration | 0 min (an instantaneous leg) | An emptied duration saves a zero-length leg. |
| body_weight_edit_page.dart, add dialog | body weight | dialog closes, nothing saved, no message | Save with an empty weight looks like it worked. |
| gtr_reserve_dialog.dart | GTR reserve pressure | dialog closes, setting unchanged, no message | Same shape: Save with an empty box does nothing visible. |
