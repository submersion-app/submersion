# Copilot instructions for Submersion

Submersion is a Flutter dive-logging app (Material 3, Drift ORM, Riverpod,
go_router), targeting iOS, Android, macOS, Windows, and Linux.

## Language version: Dart 3 (SDK ^3.10.0)

Review all Dart code with Dart 3.0+ semantics. The following Dart 2.x rules were
removed in Dart 3.0 and must NOT be raised as review findings:

- **Switch cases have an implicit break.** A non-empty `case` does not require a
  trailing `break;`/`return;`/`continue;`/`throw;`, and control does not fall
  through C-style into the next case. Never flag a "missing break" or "fall-through".
- Pattern matching, records, switch expressions, sealed/`final`/`base`/`interface`
  class modifiers, and if-case are all available.
- Sound null-safety promotion includes promotion via a final local boolean whose
  initializer null-checks a variable; treat such code as type-safe.

CI (`Analyze & Format` plus the six platform builds) is the source of truth for
whether code compiles. If green CI contradicts a proposed compile-error comment,
the comment is wrong.

## Conventions

- Anything displaying units must respect the active diver's unit settings.
- Prefer immutability and `copyWith` over mutation; no emojis in code or docs.
