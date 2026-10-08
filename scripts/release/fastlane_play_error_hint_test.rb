#!/usr/bin/env ruby
# frozen_string_literal: true

# Tests the Play rejection hints in android/fastlane/Fastfile without booting
# fastlane, using the same load-against-stubs approach as
# fastlane_beta_changelog_test.rb.
#
# What these guard (issue #2597): five beta runs in a row failed at the Play
# upload with "your app's package name must be registered to your verified
# developer identity", while the Play Console listed the package as Registered.
# The cause was a third signing key Google holds (internal app sharing) that the
# API error never names; only the Console's manual-release dialog prints the
# missing fingerprint. A re-run after the fix then failed again on "Version code
# ... has already been used": Play never takes a version code twice, and a
# bundle with that code had reached it in the meantime. Neither message says
# what to do, so the lane has to.
#
# And a silent path found while diagnosing #2887: once the Play Console holds a
# change that must be sent for review by hand, Play refuses to send an API edit
# for review automatically, and supply's default
# (rescue_changes_not_sent_for_review: true) quietly re-commits the edit with
# changesNotSentForReview=true. The release then waits in the Console's
# Publishing overview for someone to press Send, and the log reads exactly like
# a release that went out.

require 'stringio'

ROOT = File.expand_path('../..', __dir__)

$failures = []

def check(condition, message)
  $failures << message unless condition
end

# --- Minimal fastlane DSL stubs ---------------------------------------------

$ui_errors = []

module UI
  def self.important(_msg); end
  def self.message(_msg); end
  def self.success(_msg); end
  def self.error(msg)
    $ui_errors << msg
  end
  def self.user_error!(msg)
    raise ArgumentError, msg
  end
end

def default_platform(_name); end
def desc(_text); end

LANES = {}
def lane(name, &block)
  LANES[name] = block
end

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

# A bare `puts` in a Fastfile is not Kernel#puts: fastlane's FastFile overrides
# it with the puts action, which prints through UI.message behind a timestamp.
# Mirror that here, so a workflow command printed with a bare `puts` lands
# mid-line, exactly where GitHub ignores it in a real run.
def puts(*values)
  values.each { |v| $stdout.puts("[00:00:00]: #{v}") }
  nil
end

# Runs the block with $stdout captured, returning what it printed.
def capture_stdout
  original = $stdout
  $stdout = StringIO.new
  yield
  $stdout.string
ensure
  $stdout = original
end

FASTFILE_PATH = File.join(ROOT, 'android', 'fastlane', 'Fastfile')
load FASTFILE_PATH

unless respond_to?(:play_error_hint, true) && respond_to?(:upload_to_play_with_hint, true)
  $stdout.puts 'FAIL: the android Fastfile does not define play_error_hint and upload_to_play_with_hint'
  exit 1
end

# Verbatim from the failed runs, fastlane's "Google Api Error" prefix included.
UNREGISTERED_KEY_ERROR =
  "Google Api Error: Invalid request - To meet Play Console requirements, your app's " \
  'package name must be registered to your verified developer identity. Go to the ' \
  'Android developer verification page to complete the registration process for this app.'
VERSION_CODE_USED_ERROR = 'Google Api Error: Invalid request - Version code 8537 has already been used.'
FOREGROUND_SERVICE_ERROR =
  'Google Api Error: Invalid request - You must let us know whether your app uses any ' \
  'Foreground Service permissions.'
# The commit-time refusal supply used to swallow, as Play words it.
NOT_SENT_FOR_REVIEW_ERROR =
  'Google Api Error: badRequest: Changes cannot be sent for review automatically. Please ' \
  'set the query parameter changesNotSentForReview to true. Once committed, the changes in ' \
  'this edit can be sent for review from the Google Play Console UI.'

# --- Recognising the rejections ---------------------------------------------

hint = play_error_hint(UNREGISTERED_KEY_ERROR).to_s
check(!hint.empty?, 'the unregistered-package rejection got no hint')
check(hint.match?(/app signing key/i), 'the unregistered-package hint does not name the app signing key')
check(hint.match?(/upload key/i), 'the unregistered-package hint does not name the upload key')
check(hint.match?(/internal app sharing/i),
      'the unregistered-package hint does not name the internal app sharing key, the one ' \
      'that was actually missing in #2597')
check(hint.match?(/open testing/i),
      'the unregistered-package hint does not say where the Console prints the missing fingerprint')

hint = play_error_hint(VERSION_CODE_USED_ERROR).to_s
check(!hint.empty?, 'the version-code-already-used rejection got no hint')
check(hint.match?(/re-?run/i), 'the version-code hint does not warn that a re-run cannot succeed')

hint = play_error_hint(FOREGROUND_SERVICE_ERROR).to_s
check(!hint.empty?, 'the foreground service declaration rejection got no hint')
check(hint.match?(/Go to declaration/), 'the foreground service hint does not say how to reach the form')

hint = play_error_hint(NOT_SENT_FOR_REVIEW_ERROR).to_s
check(!hint.empty?, 'the not-sent-for-review rejection got no hint')
check(hint.match?(/Publishing overview/i),
      'the not-sent-for-review hint does not say where the pending changes are')
check(hint.match?(/send .*for review/i), 'the not-sent-for-review hint does not say to send them for review')
check(hint.match?(/re-?run/i), 'the not-sent-for-review hint does not say a re-run then succeeds')
# The same wrapper serves promote_beta and mirror_beta, whose build
# upload_internal has already committed: re-running that job repeats the upload
# into a reused version code.
check(hint.match?(/copy to open or closed testing/i),
      'the not-sent-for-review hint does not warn that a refused copy must not be re-run')

# Anything else must get no hint: a wrong hint sends the reader the wrong way.
[
  'Google Api Error: Invalid request - Precondition check failed.',
  'Could not find the AAB',
  '',
  nil,
].each do |unrelated|
  check(play_error_hint(unrelated).nil?, "#{unrelated.inspect} was given a hint it does not match")
end

# Every hint is a single line, so it survives as one GitHub annotation.
PLAY_ERROR_HINTS.each do |_pattern, text|
  check(!text.include?("\n"), "the hint #{text[0, 40].inspect}... spans several lines")
end

# --- The wrapper re-raises unchanged ----------------------------------------
# beta.yml's retry loop and the job's red status depend on fastlane failing
# exactly as before. The hint is extra output, never a replacement.

class FakePlayError < StandardError; end

$upload_error = nil
$upload_params = nil
def upload_to_play_store(params)
  $upload_params = params
  raise $upload_error if $upload_error
end

def call_wrapper(error)
  $upload_error = error
  $ui_errors = []
  upload_to_play_with_hint(track: 'beta')
  nil
rescue StandardError => e
  e
end

original = FakePlayError.new(UNREGISTERED_KEY_ERROR)
stdout = ''
raised = nil
with_env('GITHUB_ACTIONS' => 'true') do
  stdout = capture_stdout { raised = call_wrapper(original) }
end
check(raised.equal?(original), "the wrapper replaced the Play error with #{raised.inspect}")
check($upload_params.is_a?(Hash) && $upload_params[:track] == 'beta',
      'the wrapper did not pass its params through to the Play action')
check($ui_errors.any? { |m| m.match?(/internal app sharing/i) }, 'the hint was not printed to the fastlane log')

annotations = stdout.lines.select { |l| l.start_with?('::error') }
check(annotations.length == 1,
      "expected one GitHub error annotation on a recognised rejection, got #{annotations.length}")
check(annotations.all? { |l| l.match?(/internal app sharing/i) }, 'the annotation does not carry the hint')

# Outside GitHub Actions the annotation syntax is noise.
with_env('GITHUB_ACTIONS' => nil) do
  stdout = capture_stdout { call_wrapper(FakePlayError.new(UNREGISTERED_KEY_ERROR)) }
end
check(!stdout.include?('::error'), 'a local run printed a GitHub annotation')

# An unrecognised failure is re-raised with nothing added.
unrelated = FakePlayError.new('Google Api Error: Invalid request - Precondition check failed.')
with_env('GITHUB_ACTIONS' => 'true') do
  stdout = capture_stdout { raised = call_wrapper(unrelated) }
end
check(raised.equal?(unrelated), 'an unrecognised Play error was not re-raised unchanged')
check($ui_errors.empty?, 'an unrecognised Play error printed a hint')
check(!stdout.include?('::error'), 'an unrecognised Play error printed an annotation')

# A success stays silent.
raised = call_wrapper(nil)
check(raised.nil?, "a successful upload raised #{raised.inspect}")
check($ui_errors.empty?, 'a successful upload printed a hint')

# --- No release is parked silently -------------------------------------------
# With supply's rescue on, a refused review is committed as "not sent for
# review" and reported as a success. The wrapper turns the rescue off for every
# call, a lane cannot turn it back on, and the refusal then fails the run with
# the hint above.

call_wrapper(nil)
check($upload_params[:rescue_changes_not_sent_for_review] == false,
      'the wrapper left supply free to commit a release that was never sent for review')

$upload_error = nil
upload_to_play_with_hint(track: 'beta', rescue_changes_not_sent_for_review: true)
check($upload_params[:rescue_changes_not_sent_for_review] == false,
      'a lane turned the not-sent-for-review rescue back on')
check(!$upload_params.key?(:changes_not_sent_for_review) || $upload_params[:changes_not_sent_for_review] == false,
      'the wrapper commits edits as not sent for review')

# A draft is never sent for review, and the stable release (release.yml's
# `upload` lane) is finished by hand in the Console, so supply keeps parking it
# there rather than failing the release over an unrelated pending change.
upload_to_play_with_hint(track: 'internal', release_status: 'draft')
check(!$upload_params.key?(:rescue_changes_not_sent_for_review),
      'a draft upload lost supply\'s not-sent-for-review rescue')

with_env('GITHUB_ACTIONS' => 'true') do
  stdout = capture_stdout { raised = call_wrapper(FakePlayError.new(NOT_SENT_FOR_REVIEW_ERROR)) }
end
check(raised.is_a?(FakePlayError), 'a refused review did not fail the call')
check(stdout.lines.any? { |l| l.start_with?('::error') && l.match?(/Publishing overview/i) },
      'a refused review did not annotate the run with where the changes wait')

# --- Every Play call goes through the wrapper -------------------------------
# A lane that calls the action directly would fail with the bare API message
# again. The wrapper itself is the only direct caller.

source = File.read(FASTFILE_PATH)
direct_calls = source.lines.count { |l| l.match?(/^\s*upload_to_play_store\(/) }
check(direct_calls == 1,
      "upload_to_play_store is called directly #{direct_calls} times; every lane should " \
      'call upload_to_play_with_hint so a known rejection is explained')

# And the beta lane, run for real against the stubs, prints the hint.
def find_aab
  '/nonexistent/Submersion-test-Android.aab'
end

def write_beta_changelog(_metadata_root = nil)
  nil
end

lane_body = LANES[:upload_internal]
if lane_body
  $upload_error = FakePlayError.new(UNREGISTERED_KEY_ERROR)
  $ui_errors = []
  begin
    with_env('GITHUB_ACTIONS' => nil) { lane_body.call }
    check(false, 'the upload_internal lane swallowed a Play rejection')
  rescue FakePlayError
    check($ui_errors.any? { |m| m.match?(/internal app sharing/i) },
          'the upload_internal lane failed without the hint')
  end
else
  check(false, 'the android Fastfile no longer defines an upload_internal lane to check')
end

# Each lane that commits a Play edit, run against the stubs, reaches the action
# with the rescue off.
def google_play_track_version_codes(track:)
  track == 'beta' ? [8682] : []
end

$upload_error = nil
{
  upload_internal: -> { LANES[:upload_internal].call },
  promote_beta: -> { with_env('PLAY_VERSION_CODE' => '8682') { LANES[:promote_beta].call({}) } },
  mirror_beta: -> { with_env('PLAY_VERSION_CODE' => '8682') { LANES[:mirror_beta].call({}) } },
  promote_to_production: -> { LANES[:promote_to_production].call(version_code: '8682') },
}.each do |name, run|
  unless LANES.key?(name)
    check(false, "the android Fastfile no longer defines a #{name} lane to check")
    next
  end
  $upload_params = nil
  with_env('GITHUB_ACTIONS' => nil, 'PLAY_BETA_TRACK' => nil, 'PLAY_BETA_MIRROR_TRACK' => nil) { run.call }
  check($upload_params.is_a?(Hash) && $upload_params[:rescue_changes_not_sent_for_review] == false,
        "the #{name} lane can commit a release that was never sent for review")
end

if LANES.key?(:upload)
  $upload_params = nil
  LANES[:upload].call
  check($upload_params.is_a?(Hash) && !$upload_params.key?(:rescue_changes_not_sent_for_review),
        'the upload lane (stable releases, a draft) fails on a pending Console change it never sends')
else
  check(false, 'the android Fastfile no longer defines an upload lane to check')
end

# --- Report -----------------------------------------------------------------

if $failures.empty?
  $stdout.puts 'PASS: all fastlane Play error hint tests passed'
else
  $failures.each { |f| $stdout.puts "FAIL: #{f}" }
  exit 1
end
