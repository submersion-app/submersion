#!/usr/bin/env ruby
# frozen_string_literal: true

# Checks every option the Android Fastfile hands a fastlane action against the
# options that action accepts in the fastlane version android/Gemfile.lock pins.
#
# The other fastlane tests in this directory stub the whole DSL, so they cannot
# notice an option the real gem no longer accepts. Every job that runs these
# lanes (the Play beta upload, the beta mirror, production promotion) runs after
# merge, so a renamed or removed supply option would otherwise first surface as
# a failed Play upload or promotion. This runs the real lane bodies with only
# the fastlane actions intercepted, and looks each action up in the real gem.
#
# Needs the Android bundle:
#   cd android && bundle exec ruby ../scripts/release/fastlane_play_options_test.rb
#
# An optional argument names a different Fastfile to check.

require 'fastlane'

# Registers the built-in actions; without it action_class_ref finds none.
Fastlane.load_actions

ROOT = File.expand_path('../..', __dir__)
FASTFILE = ARGV[0] || File.join(ROOT, 'android', 'fastlane', 'Fastfile')

$failures = []

def check(condition, message)
  $failures << message unless condition
end

# Environment the lanes read. Cleared so every run takes the defaults the beta
# and promote workflows get, and nothing is written to the metadata folder.
LANE_ENV_KEYS = %w[
  PLAY_BETA_TRACK
  PLAY_BETA_MIRROR_TRACK
  PLAY_BETA_CHANGELOG
  PLAY_BETA_CHANGELOG_FILE
  PLAY_VERSION_CODE
].freeze

# Lane options such as version_code are required by some lanes. Any key reads
# back as a placeholder, so each lane runs its full path to its actions.
LANE_OPTIONS = Hash.new('1').freeze

# Evaluates the Fastfile the way fastlane does, as code run on an object, but
# with lane declarations recorded and fastlane actions intercepted rather than
# performed. Helpers the Fastfile defines become singleton methods here, so the
# lanes call the real ones.
class LaneSandbox
  class UserError < StandardError; end

  # Lane code logs through UI. The real one prints, and user_error! must still
  # raise, so a lane that rejects its own defaults reports rather than passes.
  module UI
    def self.message(_msg); end
    def self.important(_msg); end
    def self.success(_msg); end

    def self.user_error!(msg)
      raise UserError, msg
    end
  end

  attr_reader :lanes, :calls

  def initialize
    @lanes = {}
    @calls = []
    @current_lane = nil
  end

  def default_platform(_name); end
  def desc(_text); end

  def platform(_name)
    yield
  end

  def lane(name, &block)
    @lanes[name] = block
  end

  def run_lane(name)
    @current_lane = name
    instance_exec(LANE_OPTIONS, &@lanes.fetch(name))
  ensure
    @current_lane = nil
  end

  # Anything the Fastfile does not define itself is a fastlane action. It is
  # recorded with its options instead of run; a name fastlane does not know
  # falls through to NoMethodError, which is reported for the lane.
  def method_missing(name, *args, &block)
    action = Fastlane::Actions.action_class_ref(name)
    return super unless action

    options = args.first.is_a?(Hash) ? args.first : {}
    @calls << { lane: @current_lane, action: name, class: action, options: options }
    nil
  end

  def respond_to_missing?(name, include_private = false)
    !Fastlane::Actions.action_class_ref(name).nil? || super
  end
end

def with_env(vars)
  previous = vars.keys.to_h { |k| [k, ENV[k]] }
  vars.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  yield
ensure
  previous.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
end

sandbox = LaneSandbox.new
sandbox.instance_eval(File.read(FASTFILE), FASTFILE)

# The one helper that needs a real file: it looks for a built AAB and fails the
# lane when there is none.
if sandbox.respond_to?(:find_aab)
  sandbox.define_singleton_method(:find_aab) { '/nonexistent/Submersion-test-Android.aab' }
end

check(!sandbox.lanes.empty?, "#{FASTFILE} defines no lanes")

with_env(LANE_ENV_KEYS.to_h { |k| [k, nil] }) do
  sandbox.lanes.each_key do |name|
    sandbox.run_lane(name)
  rescue StandardError => e
    check(false, "lane #{name} raised #{e.class}: #{e.message}")
  end
end

# A lane that stops calling any action would make every check below vacuous.
check(!sandbox.calls.empty?, 'no lane called a fastlane action, so no option was checked')

sandbox.calls.each do |call|
  items = call[:class].available_options || []
  accepted = items.to_h { |item| [item.key, item] }
  where = "lane #{call[:lane]} calls #{call[:action]}"

  call[:options].each_key do |key|
    item = accepted[key]
    check(!item.nil?,
          "#{where} with :#{key}, which fastlane #{Fastlane::VERSION} does not accept")
    next unless item&.deprecated

    # Still accepted, so not a failure, but the next upgrade may remove it.
    puts "::warning::#{where} with :#{key}, deprecated in fastlane " \
         "#{Fastlane::VERSION}: #{item.deprecated}"
  end
end

# --- Report -----------------------------------------------------------------

if $failures.empty?
  checked = sandbox.calls.map { |c| "#{c[:lane]}:#{c[:action]}" }.join(', ')
  puts "PASS: every action option is accepted by fastlane #{Fastlane::VERSION} (#{checked})"
else
  $failures.each { |f| puts "FAIL: #{f}" }
  exit 1
end
