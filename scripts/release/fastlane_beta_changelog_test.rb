#!/usr/bin/env ruby
# frozen_string_literal: true

# Tests the release-note helpers in the platform Fastfiles without booting
# fastlane. Each Fastfile is loaded against stubs for the handful of fastlane
# DSL methods it calls at load time, which leaves the helper methods defined at
# top level where they can be exercised directly.
#
# What these guard: the beta pipeline feeds "What to Test" from an environment
# variable. Ruby's `||` only falls back on nil, so a blank value would have been
# published verbatim, and a tester reads empty notes as "the previous build's
# notes still apply" - the confusion this whole change set exists to fix.

require 'fileutils'
require 'tmpdir'

ROOT = File.expand_path('../..', __dir__)

$failures = []

def check(condition, message)
  $failures << message unless condition
end

# --- Minimal fastlane DSL stubs ---------------------------------------------

module UI
  def self.important(_msg); end
  def self.message(_msg); end
  def self.success(_msg); end
  def self.user_error!(msg)
    raise ArgumentError, msg
  end
end

def default_platform(_name); end
def desc(_text); end

# Lane bodies are recorded rather than run. Most are never invoked, but the Play
# beta lane is executed against stubs further down, because the wiring between
# the changelog helper and the upload action is what broke in production.
LANES = {}
def lane(name, &block)
  LANES[name] = block
end

# Platform blocks are yielded so the `def`s inside them land at top level.
def platform(_name)
  yield
end

def with_env(vars)
  previous = vars.keys.to_h { |k| [k, ENV[k]] }
  vars.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  yield
ensure
  previous.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
end

# --- TestFlight changelog (iOS Fastfile) ------------------------------------

load File.join(ROOT, 'ios', 'fastlane', 'Fastfile')

with_env('BETA_CHANGELOG' => nil) do
  check(!beta_changelog.to_s.strip.empty?, 'unset BETA_CHANGELOG produced blank notes')
end

with_env('BETA_CHANGELOG' => '') do
  check(!beta_changelog.to_s.strip.empty?, 'empty BETA_CHANGELOG produced blank notes')
end

with_env('BETA_CHANGELOG' => '   ') do
  check(!beta_changelog.to_s.strip.empty?, 'whitespace BETA_CHANGELOG produced blank notes')
end

with_env('BETA_CHANGELOG' => "New in this build\n- a real change") do
  check(beta_changelog.include?('a real change'), 'real notes were not passed through')
  check(beta_changelog.include?("\n"), 'multi-line notes were flattened')
end

with_env('BETA_CHANGELOG' => 'x' * 5000) do
  check(beta_changelog.length <= 4000,
        "notes were #{beta_changelog.length} chars, over Apple's 4000 limit")
end

with_env('BETA_CHANGELOG' => 'x' * 4000) do
  check(beta_changelog.length == 4000, 'notes exactly at the limit were altered')
end

# --- File-based notes -------------------------------------------------------
# The pipeline passes a path rather than the text itself, so nothing derived
# from commit subjects is ever written to GITHUB_ENV (CodeQL: environment
# variable built from user-controlled sources).

Dir.mktmpdir do |tmp|
  notes_file = File.join(tmp, 'beta-notes-apple.txt')
  File.write(notes_file, "New in this build\n- a change from a file\n")

  with_env('BETA_CHANGELOG_FILE' => notes_file, 'BETA_CHANGELOG' => nil) do
    check(beta_changelog.include?('a change from a file'), 'notes were not read from the file')
    check(beta_changelog.include?("\n"), 'file notes were flattened')
  end

  # The file wins when both are present: the env var is the legacy path.
  with_env('BETA_CHANGELOG_FILE' => notes_file, 'BETA_CHANGELOG' => 'from the env var') do
    check(beta_changelog.include?('a change from a file'), 'the file did not take precedence')
    check(!beta_changelog.include?('from the env var'), 'the env var overrode the file')
  end

  # A missing file must not blank the notes; it degrades to the generic line
  # rather than failing a 45-minute upload job.
  with_env('BETA_CHANGELOG_FILE' => File.join(tmp, 'nope.txt'), 'BETA_CHANGELOG' => nil) do
    check(!beta_changelog.to_s.strip.empty?, 'a missing notes file produced blank notes')
  end

  # A file that exists but is empty is the same failure mode as a blank env var.
  empty_file = File.join(tmp, 'empty.txt')
  File.write(empty_file, "\n  \n")
  with_env('BETA_CHANGELOG_FILE' => empty_file, 'BETA_CHANGELOG' => nil) do
    check(!beta_changelog.to_s.strip.empty?, 'an empty notes file produced blank notes')
  end

  over_limit = File.join(tmp, 'huge.txt')
  File.write(over_limit, 'x' * 5000)
  with_env('BETA_CHANGELOG_FILE' => over_limit, 'BETA_CHANGELOG' => nil) do
    check(beta_changelog.length <= 4000, 'file notes were not truncated to Apple\'s limit')
  end
end

# --- The Apple lanes must not publish another platform's name ----------------
# Notes handed straight to fastlane via BETA_CHANGELOG never pass through
# sanitize_apple_store_notes.py, so the Fastfile carries a last-resort sweep
# over the same shared term list.
#
# This has to stay ABOVE the android Fastfile load below: that file defines its
# own read_beta_notes, which overrides the iOS one at top level, and these
# checks would then silently exercise the Play helper instead.

with_env('BETA_CHANGELOG_FILE' => nil,
         'BETA_CHANGELOG' => 'Fixed the Android USB download and the Windows updater.') do
  notes = beta_changelog
  check(!notes.match?(/Android/i), 'Android reached the TestFlight changelog')
  check(!notes.include?('Windows'), 'Windows reached the TestFlight changelog')
  check(notes.include?('USB download'), 'the backstop ate the rest of the note')
end

# Already-sanitized text from the pipeline must survive unchanged.
with_env('BETA_CHANGELOG_FILE' => nil,
         'BETA_CHANGELOG' => 'Fixed the other platforms USB download.') do
  check(beta_changelog == 'Fixed the other platforms USB download.',
        'the backstop is not idempotent over already-sanitized notes')
end

# --- Already-uploaded build detection (iOS/macOS Fastfiles) -----------------
# The beta lanes upload the binary and distribute it as two steps, because a
# build number can only ever be uploaded once. When distribution fails, the
# re-run has to recognise "this build is already up there" and carry on to
# distribution instead of failing on the duplicate.
#
# The message below is copied verbatim from the run where this broke
# (actions/runs/31522488646): the distribution failed on Apple's beta review
# submission limit, then every retry re-uploaded the same pkg and reported the
# duplicate instead, which stranded the build with no recovery path.

altool_duplicate_error = <<~ERROR
  Error uploading pkg file:#{' '}
   [Application Loader Error Output]: [altool.60000369C1C0] [ContentDelivery.Uploader.60000369C1C0] The provided entity includes an attribute with a value that has already been used (-19232) The bundle version must be higher than the previously uploaded version: 5829. (ID: 1d3ed621-6c27-4215-b1d0-0b96fbd95ea7)
  [Application Loader Error Output]: The call to the altool completed with a non-zero exit status: 1. This indicates a failure.
ERROR

check(duplicate_build_error?(altool_duplicate_error),
      'the duplicate-build message from App Store Connect was not recognised, so a ' \
      're-run would fail on the duplicate instead of distributing the uploaded build')

# The other shape of the same rejection, straight from the API error body.
check(duplicate_build_error?('ENTITY_ERROR.ATTRIBUTE.INVALID.DUPLICATE'),
      'the App Store Connect duplicate error code was not recognised')

# Anything else has to keep failing. Swallowing a genuine upload failure would
# send the run on to distribute a build that was never uploaded.
[
  'The call to the altool completed with a non-zero exit status: 1.',
  'Could not find the certificate in the keychain',
  'Submission limit has been reached. - Submission limit has been reached.',
  '',
  nil,
].each do |unrelated|
  check(!duplicate_build_error?(unrelated),
        "#{unrelated.inspect} was treated as an already-uploaded build, which would " \
        'let a real upload failure through')
end

# The macOS Fastfile carries its own copy of these helpers, the way it already
# does for the changelog ones, and only the iOS file is loaded here (loading
# both would redefine the same top-level methods). Compare the source text
# instead, so the platform that actually hit this cannot quietly lose the
# protection while the iOS tests keep passing.
macos_fastfile = File.read(File.join(ROOT, 'macos', 'fastlane', 'Fastfile'))

check(macos_fastfile.include?('def duplicate_build_error?'),
      'the macOS Fastfile no longer defines duplicate_build_error?, so a macOS beta ' \
      're-run would fail on the duplicate instead of distributing the uploaded build')

DUPLICATE_BUILD_MARKERS.each do |marker|
  check(macos_fastfile.include?(marker),
        "the macOS Fastfile is missing the #{marker.inspect} marker that the iOS one has")
end

# --- Play changelog (Android Fastfile) --------------------------------------

load File.join(ROOT, 'android', 'fastlane', 'Fastfile')

# Where the notes have to land, derived the way *supply* derives it rather than
# the way the Fastfile does, so this check keeps its value if the writer moves.
#
# fastlane runs lane bodies and helper methods in the `fastlane` directory, but
# wraps every action in Dir.chdir("..") to reach the project directory. supply
# resolves its default metadata_path from there, by globbing
# "./fastlane/metadata/android". A helper writing to that same relative path
# therefore landed one directory deeper than supply looked, supply resolved
# metadata_path to nil, and every Play beta uploaded successfully with no release
# notes at all - the Android half of the gap this file exists to close.
supply_metadata_path =
  File.expand_path(File.join(ROOT, 'android', 'fastlane', 'metadata', 'android'))

check(PLAY_METADATA_ROOT == supply_metadata_path,
      "notes are written to #{PLAY_METADATA_ROOT}, but supply reads #{supply_metadata_path}")
check(File.absolute_path(PLAY_METADATA_ROOT) == PLAY_METADATA_ROOT,
      'PLAY_METADATA_ROOT is relative, so which directory fastlane happens to be ' \
      'in decides whether supply finds the notes')

Dir.mktmpdir do |tmp|
  changelog_path = lambda do |code|
    File.join(tmp, 'en-US', 'changelogs', "#{code}.txt")
  end

  # Missing inputs must not write a file, and must report that the upload
  # should skip changelogs rather than blanking the notes already on Play.
  with_env('PLAY_BETA_CHANGELOG' => nil, 'PLAY_VERSION_CODE' => '123') do
    check(write_beta_changelog(tmp).nil?, 'missing notes did not disable changelog upload')
    check(!File.exist?(changelog_path.call(123)), 'missing notes still wrote a changelog file')
  end

  with_env('PLAY_BETA_CHANGELOG' => 'something', 'PLAY_VERSION_CODE' => nil) do
    check(write_beta_changelog(tmp).nil?, 'missing version code did not disable changelog upload')
  end

  with_env('PLAY_BETA_CHANGELOG' => '  ', 'PLAY_VERSION_CODE' => '123') do
    check(write_beta_changelog(tmp).nil?, 'blank notes did not disable changelog upload')
  end

  # A non-numeric version code would silently produce a file supply never
  # reads, so it fails loudly instead.
  with_env('PLAY_BETA_CHANGELOG' => 'notes', 'PLAY_VERSION_CODE' => 'v1.2.3') do
    raised = begin
      write_beta_changelog(tmp)
      false
    rescue ArgumentError
      true
    end
    check(raised, 'a non-numeric PLAY_VERSION_CODE was accepted')
  end

  with_env('PLAY_BETA_CHANGELOG' => "New in this build\n- a real change",
           'PLAY_VERSION_CODE' => '5163') do
    check(write_beta_changelog(tmp) == tmp, 'valid inputs did not report the metadata root')
    written = File.read(changelog_path.call(5163))
    check(written.include?('a real change'), 'notes were not written to the changelog file')
  end

  # Same file-based contract as the TestFlight lanes, so the workflow never
  # interpolates commit-derived text into a shell or environment assignment.
  Dir.mktmpdir do |notes_dir|
    notes_file = File.join(notes_dir, 'beta-notes-play.txt')
    File.write(notes_file, "New in this build\n- a change from a file\n")

    with_env('PLAY_BETA_CHANGELOG_FILE' => notes_file, 'PLAY_BETA_CHANGELOG' => nil,
             'PLAY_VERSION_CODE' => '5165') do
      check(write_beta_changelog(tmp) == tmp, 'file-based notes did not report the metadata root')
      check(File.read(changelog_path.call(5165)).include?('a change from a file'),
            'file-based notes were not written to the changelog file')
    end

    with_env('PLAY_BETA_CHANGELOG_FILE' => File.join(notes_dir, 'nope.txt'),
             'PLAY_BETA_CHANGELOG' => nil, 'PLAY_VERSION_CODE' => '5166') do
      check(write_beta_changelog(tmp).nil?, 'a missing notes file did not disable changelog upload')
      check(!File.exist?(changelog_path.call(5166)), 'a missing notes file still wrote a changelog')
    end
  end

  with_env('PLAY_BETA_CHANGELOG' => 'y' * 900, 'PLAY_VERSION_CODE' => '5164') do
    write_beta_changelog(tmp)
    written = File.read(changelog_path.call(5164))
    check(written.length <= 500,
          "Play changelog was #{written.length} chars, over Google's 500 limit")
  end
end

# --- Play lane wiring -------------------------------------------------------
# Writing the notes is only half of it: the lane also has to tell supply where
# they are. It did not, and nothing failed - supply uploaded the AAB, reported
# success, and left the release notes empty. Run the real lane body against
# stubs so the helper and the action cannot drift apart again.

$upload_params = nil
$stub_changelog_root = nil

def find_aab
  '/nonexistent/Submersion-test-Android.aab'
end

def upload_to_play_store(params)
  $upload_params = params
end

def write_beta_changelog(_metadata_root = nil)
  $stub_changelog_root
end

# Runs the recorded lane body and returns the params it handed the upload action,
# or nil. Guarded rather than called bare: this file collects failures and prints
# them together at the end, so a renamed lane or a lane that never reaches the
# upload has to be reported as a failure, not raised as a NoMethodError that
# aborts the run and takes every earlier failure's message with it.
def run_upload_beta_lane
  $upload_params = nil
  lane_body = LANES[:upload_beta]
  unless lane_body
    check(false, 'the android Fastfile no longer defines an upload_beta lane to check')
    return nil
  end

  lane_body.call
  check(!$upload_params.nil?, 'the upload_beta lane never called upload_to_play_store')
  $upload_params
end

$stub_changelog_root = '/somewhere/else/metadata/android'
params = run_upload_beta_lane
if params
  check(params[:metadata_path] == $stub_changelog_root,
        "the lane pointed supply at #{params[:metadata_path].inspect} " \
        "instead of #{$stub_changelog_root.inspect}, where the notes were written")
  check(params[:skip_upload_changelogs] == false,
        'the lane skipped changelog upload even though notes were written')
end

# With nothing written, the upload must still name a metadata path (nil is not a
# value supply accepts) while leaving the notes already on Play untouched.
$stub_changelog_root = nil
params = run_upload_beta_lane
if params
  check(params[:skip_upload_changelogs] == true,
        'the lane uploaded changelogs when there were no notes to upload')
  check(!params[:metadata_path].nil?, 'the lane passed a nil metadata_path')
end

# --- Report -----------------------------------------------------------------

if $failures.empty?
  puts 'PASS: all fastlane beta changelog tests passed'
else
  $failures.each { |f| puts "FAIL: #{f}" }
  exit 1
end
