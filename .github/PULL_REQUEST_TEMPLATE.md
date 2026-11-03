## Related Issue

<!--
Required: every PR must relate to an issue. The "PR Issue Link" check fails
until this description links one. Write one line per issue:

  Closes #123        this PR fully resolves the issue (Fixes/Resolves also work)
  Refs #123          related, but the issue stays open
  Part of #123       one step of a larger issue that stays open
  Related to #123    same as Refs

Only a closing keyword directly before the number closes the issue on merge,
and each issue needs its own keyword ("Closes #1, closes #2", not
"Closes #1, #2"). A number in the title does nothing.
-->

## Summary

<!-- What does this PR do and why? -->

## Changes

<!-- Bullet list of key changes -->

-

## Test Plan

- [ ] `flutter test` passes
- [ ] `flutter analyze` passes
- [ ] Manual testing on: <!-- list platforms tested -->

## Browser

<!--
The web app builds from the same code as the installed apps. CI checks that
it compiles and that its main flows run, not that a new feature behaves in
a browser. Tick the first box, or tick each check below it that you made and
delete the ones that do not apply. Details: docs/developer/web.md, "Platform
seams".
-->

- [ ] Nothing device-only: no hardware, local files, background work, new plugin, media write or database swap
- [ ] Gated on a `DeviceCapabilities` field that is false in `DeviceCapabilities.web`; a screen of its own is in `webUnavailableRoutePrefixes`, or a `?selected=` section in `webUnavailableSections`
- [ ] No plugin call without a web implementation, and no `dart:io` file or `path_provider` use that a browser reaches
- [ ] Media writes check `mediaAttach`
- [ ] A swap or wipe of the database runs under `SyncCoordinator.joinAcrossTabs`
- [ ] Opened in a browser (`scripts/build_web.sh`, then `scripts/web/serve_bundle.py`)

## Screenshots

<!--
Required when the PR changes anything a user can see. That covers any change
under:

  lib/**/presentation/
  lib/shared/widgets/, lib/core/theme/, lib/core/ui/, lib/core/icons/
  UI resources in android/, ios/, macos/, windows/ or linux/
  (launch screens, app icons, window chrome)

Drag the images into this description on github.com, or from the command line
attach them through a secret gist (see docs/contributing/pull-requests.md). Show
before and after (only the after for a brand-new screen), light and dark mode
when colours change, and phone and desktop widths when the layout changes.

Touched those paths but nothing looks different (a refactor, a provider
change)? Tick the box below and say why in the Summary. Touched none of them?
Delete this section.
-->

- [ ] No visible UI change
