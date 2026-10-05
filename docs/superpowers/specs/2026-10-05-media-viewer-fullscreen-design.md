# Media viewer fullscreen mode: design

Issue: #1087 (Provide a full-screen media viewer). Release: v1.8.2.

## Problem

On a phone, the app's bottom navigation bar (Home, Dives, Sites, ...) stays on
screen while a photo is open in the media viewer, even after a tap hides the
viewer's own controls. There is no way to see a photo with nothing else on
screen.

The cause: every launch site except the dashboard media ribbon pushes the
viewer onto the shell route's nested navigator, so the viewer renders inside
`MainScaffold`'s body and the scaffold's `NavigationBar` (or `NavigationRail`
on wide screens) stays visible. The viewer already hides the OS status and
navigation bars (`SystemUiMode.immersiveSticky`).

## Goals

- Keep today's viewer behaviour as the default, unchanged.
- Add an explicit fullscreen mode, entered from a new toolbar button, that
  shows only the photo or video.
- Fix the existing toolbar overflow on narrow phones, which the new button
  would otherwise make common.

## Non-goals

- Putting the desktop OS window into fullscreen. Fullscreen fills the app
  window only; OS-level fullscreen would need a new window-manager plugin.
- Remembering fullscreen between viewer openings. There is no new setting and
  no schema change.
- The document viewer and the fullscreen dive profile page.
- Changing how any launch site pushes the viewer. The viewer stays on the
  shell navigator, so "Go to dive" keeps returning to the photo on Back
  (commit 974117683d3).

## Behaviour

### Normal mode (default)

Exactly as today: the app's navigation is visible, a tap on a photo toggles
the viewer's overlays (toolbar, previous/next arrows, mini dive profile,
bottom metadata, video controls), and the Perdix face follows its own
setting. Every viewer opens in normal mode.

### Entering fullscreen

A new "Full screen" button (`Icons.fullscreen`) sits in the top toolbar
directly after the close button. Pressing it enters fullscreen.

### Fullscreen mode

Hidden:

- The app shell's chrome: bottom `NavigationBar` on phones,
  `NavigationRail` and its divider on wide screens, the `UpdateBanner`, the
  `GpsRecordingStrip`, and the wide layout's `SafeArea` inset.
- The viewer's chrome: top toolbar, previous/next arrows, mini dive profile,
  bottom metadata, video controls, and the centre play indicator on a paused
  video.
- The Perdix face, even when the Perdix setting is on.

Still working: swiping between items (fullscreen stays on across swipes),
pinch-zoom on photos, left/right arrow keys, and swipe-down, which closes the
viewer as it does today.

### Revealed controls in fullscreen

A tap reveals fullscreen controls. They fade out about 3 seconds after the
last tap, and a tap while they are showing on a photo hides them straight
away.

- **Photo:** the tap reveals an "Exit full screen" button
  (`Icons.fullscreen_exit`) in the top-left corner, inside the safe area.
- **Video:** the tap also toggles play/pause, as a tap on a video does today,
  and reveals the exit button together with the video controls bar
  (play position, tap-to-seek progress bar, duration), drawn at the bottom
  edge inside the safe area because the metadata panel is not there. While
  the video is paused the revealed controls stay up; the 3-second fade only
  runs while it is playing.

Pressing the exit button leaves fullscreen.

### Leaving fullscreen

The exit button, Android Back, or Esc leaves fullscreen and returns to normal
mode with all overlays showing. Back and Esc close the viewer only when it is
not in fullscreen.

### Toolbar overflow

The toolbar measures its width. After the close button, the fullscreen
button, and a minimum width reserved for the page indicator ("12 / 345"),
the remaining actions fit as icons in priority order, and the rest move into
a trailing overflow menu (`Icons.more_vert`) that lists each with its icon
and label, in toolbar order. No overflow menu appears when everything fits.

Priority (first stays visible longest):

1. Go to dive (cross-dive viewers only)
2. Share
3. Info
4. Perdix toggle (when available)
5. Species tag
6. Write dive data (when available)
7. Open in Lightroom (when available; currently hidden behind
   `lightroomUiEnabled`)
8. Re-upload (when a media store is connected)

Visible icons keep today's left-to-right order. From the menu, Share anchors
its iPad popover to the overflow button, and Re-upload opens its upload
quality picker anchored to the overflow button.

## Architecture

### `ShellChromeScope` (new, `lib/shared/widgets/shell_chrome_scope.dart`)

Two pieces in one file:

- `ShellChromeController`, a `ChangeNotifier` holding a `Set<Object>` of
  hide tokens, with `isHidden`, `requestHidden(Object token)` and
  `releaseHidden(Object token)`.
- `ShellChromeScope`, an `InheritedWidget` that `MainScaffold` places around
  its layout, with `static ShellChromeController? maybeOf(BuildContext)`.

`MainScaffold` owns the controller, listens to it, and renders the hidden
layout (`GlobalDropTarget` around the page, nothing else) while it reports
`isHidden`. A change made while the tree is locked (a holder requesting from
`didChangeDependencies` or releasing from `dispose`) is announced after the
frame, so a descendant never triggers `setState` on the scaffold during
build. Releasing a token that was never requested does nothing, so two
holders can never clear each other's request. The shell navigator keeps its
pages across the layout change because go_router builds it with a
`GlobalKey`.

A viewer pushed on the root navigator (the dashboard media ribbon) sits above
the shell, finds no scope, and skips the call; the shell is already covered
there.

The scope knows nothing about media, so another full-screen page can use it
later.

### Viewer (`media_viewer_page.dart`)

- New state: `_isFullscreen` and `_fullscreenControlsVisible`, plus a
  `Timer` for the 3-second fade, cancelled on exit and dispose.
- Entering fullscreen requests a hidden shell with the page state as its
  token; leaving or disposing releases it.
- In fullscreen, the overlay block and the Perdix mount are skipped, and the
  photo tap target reveals or hides the exit button instead of toggling
  overlays.
- `_VideoItem` takes the video controls' visibility from the page:
  `_showOverlay` in normal mode, `_fullscreenControlsVisible` in fullscreen,
  plus a flag that moves the controls bar to the bottom edge. Its tap still
  toggles play/pause and calls back so the page can reveal the controls and
  restart or stop the fade timer.
- A `PopScope` with `canPop: !_isFullscreen` turns Android Back into "leave
  fullscreen"; the Esc branch of `_handleKeyEvent` does the same when
  fullscreen is on.

The file is already 1,726 lines. The new toolbar and the fullscreen controls
go in their own files under `lib/features/media/presentation/widgets/`
(`media_viewer_toolbar.dart`, `media_fullscreen_controls.dart`), with
`_TopOverlay` moving into the toolbar file, so the page file shrinks.

### Toolbar (`media_viewer_toolbar.dart`)

Each action is described by a small value (`key`, icon, label, callback,
priority). A `LayoutBuilder` computes how many 48 px icon buttons fit in the
width left after the fixed buttons, the indicator minimum, and the overflow
button when it is needed. The rest render as `PopupMenuItem`s. Re-upload's
existing `MediaReuploadButton` is itself a menu, so it is replaced by
`mediaReuploadAvailable(ref)` and `showMediaReuploadMenu(anchorContext, ref,
item)` in `media_reupload_menu.dart`; the page passes an `onReupload`
callback (null when no store is connected) that both the icon and the menu
item call with their own context as the anchor.

## Strings

New ARB keys (English, plus the existing translation workflow):

- `media_viewer_enterFullscreen`: "Full screen"
- `media_viewer_exitFullscreen`: "Exit full screen"
- `media_viewer_moreOptions`: "More options" (the wording the app already
  uses for overflow menus, `diveCenters_tooltip_moreOptions` and others)

Overflow menu labels reuse each action's existing tooltip string.

## Testing (TDD)

- **`ShellChromeScope`:** a request hides and a release restores; two tokens
  are independent; releasing an unknown token is a no-op; `maybeOf` returns
  null outside a scaffold.
- **`MainScaffold`** inside a real `ShellRoute` router at 390 px and 1024 px:
  with a request active, no `NavigationBar`, `NavigationRail`,
  `UpdateBanner` or `GpsRecordingStrip` is in the tree; after release they
  are back.
- **Viewer:**
  - the fullscreen button hides every overlay and the Perdix face, and the
    shell's nav;
  - a tap reveals the exit button, which fades after 3 s (fake async) and
    hides on a second tap;
  - the exit button, Esc, and Back each leave fullscreen without closing the
    viewer, and Back and Esc close it outside fullscreen;
  - a swipe keeps fullscreen on;
  - a viewer opened again starts in normal mode;
  - on a video, a tap toggles playback and reveals the controls bar, which
    stays while paused.
- **Toolbar** with the full action set at 360, 412 and 1024 px: no overflow
  error; at 360 px the low-priority actions are in the overflow menu and
  each still fires its callback from there; at 1024 px there is no overflow
  button.

## Screenshots for the PR

The viewer at phone width in normal mode (before and after, showing the new
button), fullscreen with nothing showing, fullscreen with the exit button
revealed, the overflow menu open at 360 px, and the same fullscreen view at
desktop width with the rail gone.
