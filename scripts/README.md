# Scripts and developer tools

Every script in this repository is listed here, grouped by what it is for.

- `scripts/` holds everything that is not Dart (Python, shell, Ruby), in a
  folder named for its purpose. A test sits beside the script it tests
  (`foo.py` and `foo_test.py`), and a data file sits beside the one script
  that reads it.
- `tool/` holds the Dart developer tools, as the Dart package layout expects.
- Only this README, `scripts/setup.sh` and `scripts/requirements.txt` sit at
  the top of `scripts/`.

`scripts/checks/check_scripts_index.py` enforces all of this in CI: it fails
on a script missing from this index, an index entry that points nowhere, a
loose file at the top of `scripts/`, and a workflow or hook path that no
longer exists. When you add a script, put it in the folder below that fits
and add one line here.

## Setup

- `scripts/setup.sh`: first-time development setup (dependencies, git hooks,
  code generation).
- `scripts/requirements.txt`: Python dependencies for the scripts that need
  more than the standard library.

## checks/

Guards that fail CI when a rule is broken. Each one names the issue it
came from in its docstring.

- `scripts/checks/check_16kb_alignment.py`: 64-bit native libraries in an
  Android APK or AAB are 16 KB aligned.
- `scripts/checks/check_apk_signing_cert.py`: a release APK is signed by a
  certificate Google will accept.
- `scripts/checks/check_apt_mirror.py`: every workflow job repoints the apt
  mirror before it installs packages.
- `scripts/checks/check_bundled_native_assets.py`: a desktop app bundle
  contains the native assets it declares.
- `scripts/checks/check_ci_success_gate.py`: every CI job reaches the
  `ci-success` gate.
- `scripts/checks/check_dc_process_isolation.py`: the dive-download service
  stays in its own process.
- `scripts/checks/check_dependabot_gemfiles.py`: Dependabot can parse every
  Gemfile and an update entry covers it.
- `scripts/checks/check_docs_links.py`: links into and within `docs/`
  resolve, and the retired docs folders stay gone.
- `scripts/checks/check_flutter_setup_retried.py`: every workflow sets up
  Flutter through the retrying local action.
- `scripts/checks/check_glibc_floor.py`: a Linux bundle needs no newer glibc
  than the app supports.
- `scripts/checks/check_jni_local_refs.py`: the libdivecomputer JNI
  callbacks free every local reference.
- `scripts/checks/check_native_libs_present.py`: required native libraries
  are bundled in an Android APK or AAB.
- `scripts/checks/check_no_skipped_tests.py`: a `flutter test` JSON report
  shows no skipped tests and at least one test.
- `scripts/checks/check_pr_issue_link.py`: every pull request description
  links its issue.
- `scripts/checks/check_proguard_serial_keep.py`: R8 kept the reflected
  usb-serial-for-android driver methods.
- `scripts/checks/check_ruby_versions.py`: every `ruby/setup-ruby` step pins
  the same Ruby.
- `scripts/checks/check_scripts_index.py`: every script is listed in this
  index and every workflow path exists.
- `scripts/checks/check_web_bundle.py`: a built web bundle is complete
  before it is zipped, served or shipped.

## testing/

Running tests and reporting on them, locally and in CI.

- `scripts/testing/run_all_tests.sh`: runs the whole Flutter suite the
  quickest local way, as bundles that share an isolate.
- `scripts/testing/bundle_tests.py`: groups test files into those bundles,
  for CI and for the runner above.
- `scripts/testing/test_concurrency.sh`: the number of parallel test
  isolates, shared by the runner and the pre-push hook.
- `scripts/testing/pre_push_hook_test.sh`: tests for `hooks/pre-push`.
- `scripts/testing/report_inherited_failures.py`: marks pull-request CI
  failures that `main` is failing too.
- `scripts/testing/filter_trivial_coverage.py`: drops trivial members from
  an lcov report before it is uploaded.
- `scripts/testing/run_perf_tests.sh`: runs the performance benchmarks in
  `test/performance/`.
- `scripts/testing/run_color_encode_it.sh`: the colour-encode integration
  check on macOS, Windows or Android.
- `scripts/testing/generate_scrubber_sample_dives.py`: regenerates
  `test/dives/scrubber-1500-dives.uddf`, 1,500 synthetic rebreather dives.

## ci/

Preparing a CI runner, or fixing a build output before it ships.

- `scripts/ci/apt_mirror.py`: points a hosted runner's apt sources away
  from a slow regional mirror.
- `scripts/ci/fix_macho_symbol_order.py`: sorts the exported symbol table of
  the macOS App.framework so older dyld can resolve it.

## release/

Versioning, changelogs, packaging, signing and publishing a release.

- `scripts/release/release.sh`: runs a release end to end (version bump,
  changelog, tag).
- `scripts/release/bump_version.sh`: bumps the version and build number in
  `pubspec.yaml`.
- `scripts/release/generate_changelog.sh`: builds a changelog from
  conventional commits since the last tag.
- `scripts/release/contributors.sh`: maps each commit in a release range to
  its author and pull request.
- `scripts/release/create_release.sh`: creates and pushes a release tag.
- `scripts/release/delete_release.sh`: deletes a GitHub release and its
  tags.
- `scripts/release/promote.sh`: promotes a published beta to the stable
  channel everywhere.
- `scripts/release/status.sh`: follows a release workflow run.
- `scripts/release/beta_release_notes.sh`: the tester-facing "what to test"
  text for a beta.
- `scripts/release/play_beta_cooldown.py`: decides whether a beta goes on to
  Play open testing.
- `scripts/release/distribute_testflight_beta.sh`: hands an uploaded
  TestFlight build to the Public Beta group.
- `scripts/release/sanitize_apple_store_notes.py`: strips other-platform
  references and credits out of App Store Connect notes.
- `scripts/release/generate_appcast.sh`: writes `appcast.xml` for the
  Sparkle and WinSparkle auto-updaters.
- `scripts/release/generate_appcast_beta.sh`: writes `appcast-beta.xml` for
  the beta update channel.
- `scripts/release/generate_release_notes_html.sh`: turns Markdown release
  notes into the HTML page the updaters show.
- `scripts/release/notarize_dmg.sh`: notarizes a Developer ID DMG and
  staples the ticket.
- `scripts/release/build_nosandbox_macos.sh`: builds the macOS app without
  the sandbox.
- `scripts/release/capture_screenshots.sh`: captures App Store screenshots.
- `scripts/release/organize_screenshots_for_fastlane.sh`: sorts screenshots
  into the folders fastlane expects.
- `scripts/release/build_linux_packages.sh`: builds the Linux `.deb` and
  `.rpm` from a Flutter bundle.
- `scripts/release/stage_linux_package.py`: builds the Linux install tree
  the packages are made from.
- `scripts/release/linux_package_deps.py`: derives a Linux package's runtime
  dependencies from the bundle (reads `linux_soname_map.json`).
- `scripts/release/gen_udev_rules.py`: generates udev rules for the dive
  computers libdivecomputer supports.
- `scripts/release/verify_linux_package.sh`: installs a built Linux package
  and checks that it runs.
- `scripts/release/linux_tarball_extras/install.sh`: installs the Linux
  tarball into the user's home.
- `scripts/release/linux_tarball_extras/uninstall.sh`: removes a tarball
  installation.

## bots/

Scripts that scheduled or event-driven workflows run to raise issues or
update pages outside the app.

- `scripts/bots/beta_failure_alert.py`: raises, updates or clears the beta
  pipeline's failure issue.
- `scripts/bots/dependabot_failure_alert.py`: raises, updates or clears the
  Dependabot failure issue.
- `scripts/bots/demo_package_age_alert.py`: opens an issue when the
  demo-mode sample logbook needs a rebuild.
- `scripts/bots/snapshot_downloads.py`: saves GitHub's download counters for
  submersion.app.
- `scripts/bots/wiki_howto_index.py`: keeps the how-to list on the wiki
  home page current.
- `scripts/bots/export_support_matrix_catalog.py`: exports the dive computer
  support matrix for submersion.app/computers (reads
  `support_matrix_platform_rules.json`).

## codegen/

Generators that write source files under `lib/` or `test/`. Run them from
the repository root.

- `scripts/codegen/gen_embedded_ca_bundle.py`: regenerates
  `lib/core/network/embedded_ca_bundle.dart`.
- `scripts/codegen/gen_query_error_codes.py`: generates the query error
  codes and their messages from one table.
- `scripts/codegen/gen_query_label_lookup.py`: regenerates the label lookup
  the query registry reads.
- `scripts/codegen/generate_eff_wordlist.py`: emits the EFF short wordlist
  as a Dart constant.
- `scripts/codegen/generate_crypto_test_vectors.py`: writes known-answer
  vectors for the SBE1 sync crypto.

## artwork/

Builders for in-app artwork, with the sources they read.

- `scripts/artwork/build_equipment_icon_font.py`: builds
  `assets/fonts/submersion-equipment.ttf` (`--verify` checks it).
- `scripts/artwork/equipment_glyphs.py`: the drawings for the custom
  equipment glyphs.
- `scripts/artwork/build_figure_artwork.py`: compiles the diver figure SVGs
  in `scripts/artwork/figure/` into Dart (`--verify` checks it).

## datasets/

Harvesters for the datasets the app bundles, one folder per dataset, each
with its inputs and fixtures.

- `scripts/datasets/chambers/chamber_harvester.py`: builds the recompression
  chamber directory.
- `scripts/datasets/chambers/chamber_sources.py`: parsers for the national
  hyperbaric registries the harvester reads.
- `scripts/datasets/chambers/chamber_geocode.py`: geocodes chamber addresses
  through Nominatim, with an on-disk cache.
- `scripts/datasets/dive_sites/dive_site_harvester.py`: harvests dive
  centres from OpenStreetMap.
- `scripts/datasets/sea_areas/sea_area_harvester.py`: builds the IHO sea
  area index.
- `scripts/datasets/site_catalogue/site_catalogue_intake.py`: takes a site
  catalogue release into the app.
- `scripts/datasets/geography/generate_country_names.py`: generates the
  country name table for site countries.
- `scripts/datasets/tide/extract_fes_grid.py`: extracts the bundled FES2022
  tide grid ([tide/README.md](datasets/tide/README.md) has the steps).
- `scripts/datasets/tide/fes_grid_format.py`: the binary format of that
  grid.
- `scripts/datasets/tide/write_fes_grid_test_fixtures.py`: writes small FES
  grid fixtures for the Dart tests.
- `scripts/datasets/tide/generate_noaa_station_index.py`: generates the
  bundled NOAA station index.
- `scripts/datasets/tide/fetch_noaa_local_time_fixtures.py`: fetches NOAA
  local-time fixtures for the site-time golden test.

One file stays outside `datasets/` on purpose:
`scripts/site_catalogue/research/sites.json` points to the site catalogue
repository. Built-in sites shipped before catalogue release 2026.11.18 link
to it at this exact path, so moving it would break those links in installed
apps.

## brand/

Brand images and the app icon; see [brand/README.md](brand/README.md).

- `scripts/brand/generate_brand_assets.py`: renders banners, lockups and
  marks.
- `scripts/brand/generate_icon.py`: renders the app icon into
  `assets/icon/`.
- `scripts/brand/layout.py`: banner and lockup geometry.
- `scripts/brand/mark.py`: the logo mark.
- `scripts/brand/presets.py`: every image the brand generator can render.

## deco_golden/

Golden vectors for the decompression engines; see
[deco_golden/README.md](deco_golden/README.md).

- `scripts/deco_golden/generate_vectors.py`: Bühlmann golden vectors.
- `scripts/deco_golden/vpmb_generate.py`: VPM-B golden vectors.

## demo_data/

The demo-mode sample logbook (the Dart side is `tool/demo_data/`).

- `scripts/demo_data/harvest.sh`: step 1, harvest the sample logbook.
- `scripts/demo_data/harvest_in_app.sh`: step 1b, the macOS in-app harvest.
- `scripts/demo_data/pack.sh`: step 2, pack it for publishing.
- `scripts/demo_data/fetch_demo_db.py`: downloads the published logbook for
  store screenshots and web builds.
- `scripts/demo_data/fetch_published_manifest.py`: fetches the published
  manifest into a build's output.

## readme/

- `scripts/readme/import_website_shots.py`: imports the website's
  screenshots into the README assets; see [readme/README.md](readme/README.md).

## web/

Building, serving and testing the browser app.

- `scripts/web/build_web.sh`: builds the browser app into `build/web`.
- `scripts/web/fetch_sqlite3_wasm.sh`: fetches the pinned `sqlite3.wasm`.
- `scripts/web/check_sqlite3_wasm_lock.py`: checks the `sqlite3.wasm` pin.
- `scripts/web/compile_workers.sh`: compiles the browser workers with
  dart2js.
- `scripts/web/serve_bundle.py`: serves a built bundle the way a configured
  host would.
- `scripts/web/stage_hosted_site.py`: stages a release bundle for
  web.submersion.app or beta.web.submersion.app.
- `scripts/web/test_web.sh`: runs the browser test suite under `test/web`.
- `scripts/web/check_junit_ran.py`: fails when a JUnit report ran no tests
  or skipped any.

## tool/

Dart developer tools. Run them with `dart run <path>`.

- `tool/perf/db_bench.dart`: SQL-level benchmarks against a database copy.
- `tool/perf/synth_fixture.dart`: multiplies a small database into a large
  benchmark fixture.
- `tool/perf/vmcap.dart`: VM-service CPU and frame capture for profiling.
- `tool/compute_db_key_vector.dart`: generates the database-key HKDF test
  vector.
- `tool/card_crop_contact_sheet.dart`: contact sheet for tuning the dive
  card photo crop.
- `tool/generate_sql_column_notes.dart`: writes the column notes
  `submersion://schema` shows.
- `tool/generate_freshwater_species.dart`: turns the freshwater species seed
  into catalog rows.
- `tool/generate_species_arb_keys.dart`: adds species name and description
  keys to every ARB file.
- `tool/generate_species_gbif_keys.dart`: resolves the species catalog to
  GBIF taxon keys.
- `tool/generate_species_lookups.dart`: regenerates the species id lookups.
- `tool/species_id/make_fake_onnx_models.py`: writes the fake ONNX models
  the species-ID runtime tests load.
- `tool/demo_data/`: builds the demo-mode sample logbook; see
  [demo_data/README.md](../tool/demo_data/README.md).
