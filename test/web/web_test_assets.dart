/// Where `flutter test --platform chrome` serves the compiled workers and
/// sqlite3.wasm that scripts/web/compile_workers.sh stages under
/// test/web/assets/. The runner mounts the project's test/ directory as the
/// server root, so the directory's path starts below it.
const String kWebTestAssetBase = '/web/assets/';
