# Lessons

- When a widget needs to initialize Riverpod/provider state from incoming props, do not mutate that provider directly in `build()` or `didUpdateWidget()`. Schedule the update after the frame or move the ownership fully into the provider to avoid Flutter's "markNeedsBuild during build" assertions.
