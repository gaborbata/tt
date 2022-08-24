require 'test/unit'
require 'coverage'
require 'stringio'

class Dir
  def self.home
    Dir.pwd
  end
end

class TestTimeTracker < Test::Unit::TestCase
  class << self
    def startup
      Coverage.start if ENV['COVERAGE']
    end

    def shutdown
      if ENV['COVERAGE']
        coverage = Coverage.result.find { |name, result| name.end_with?('bin/tt.rb') }
        coverage = coverage ? coverage[1] : []
        relevant = coverage.select { |line| !line.nil? }.size
        covered = coverage.select { |line| !line.nil? && line > 0 }.size
        printf("\nCoverage: %.2f%% (lines: %d total, %d relevant, %d covered, %d missed)\n",
          covered.to_f / [relevant.to_f, 1.0].max * 100.0, coverage.size, relevant, covered, relevant - covered)
      end
    end
  end

  def setup
    @original_stdout = $stdout
    $stdout = StringIO.new
    require_relative '../bin/tt.rb'
    @time_tracker_file = TimeTracker::TIME_TRACKER_FILE
    File.delete(@time_tracker_file) if File.exist?(@time_tracker_file)
    @time_tracker = TimeTracker.new
  end

  def cleanup
    $stdout = @original_stdout
    File.delete(@time_tracker_file) if File.exist?(@time_tracker_file)
  end

  def test_record_break_entry
    # when
    @time_tracker.execute 'break', 'lunch'

    # then
    assert_match(
      /\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2},break,lunch\r?\n/,
      File.read(@time_tracker_file)
    )
    assert_equal(
      "\e[32mRecord activity [break] with message [lunch]\e[0m",
      $stdout.string.split("\n").last
    )
  end

  def test_record_stop_entry
    # when
    @time_tracker.execute 'stop', nil

    # then
    assert_match(
      /\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2},stop,\r?\n/,
      File.read(@time_tracker_file)
    )
    assert_equal(
      "\e[32mRecord activity [stop] with message [n/a]\e[0m",
      $stdout.string.split("\n").last
    )
  end

  def test_record_start_entry
    # when
    @time_tracker.execute 'meetings,standup', nil

    # then
    assert_match(
      /\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2},meetings,standup\r?\n/,
      File.read(@time_tracker_file)
    )
    assert_equal(
      "\e[32mRecord activity [meetings] with message [standup]\e[0m",
      $stdout.string.split("\n").last
    )
  end

  def test_list_break_entry_format
    # given
    @time_tracker.execute 'break', 'lunch'
    $stdout = StringIO.new

    # when
    @time_tracker.execute 'ls', nil

    # then
    assert_match(
      /\e\[34m\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\s+break\s+lunch\s+\d{2}:\d{2}:\d{2}\s+\e\[0m/,
      $stdout.string.split("\n").last
    )
  end

  def test_list_stop_entry_format
    # given
    @time_tracker.execute 'stop', nil
    $stdout = StringIO.new

    # when
    @time_tracker.execute 'list', nil

    # then
    assert_match(
      /\e\[31m\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\s+stop\s+n\/a\s+--------\s+\e\[0m/,
      $stdout.string.split("\n").last
    )
  end

  def test_list_start_entry_format
    # given
    @time_tracker.execute 'meetings', 'standup'
    $stdout = StringIO.new

    # when
    @time_tracker.execute 'ls', nil

    # then
    assert_match(
      /\e\[37m\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\s+meetings\s+standup\s+\d{2}:\d{2}:\d{2}\s+\e\[0m/,
      $stdout.string.split("\n").last
    )
  end

  def test_list_filter_entry_format
    # given
    @time_tracker.execute 'meetings', 'standup'
    @time_tracker.execute 'break', 'lunch'
    @time_tracker.execute 'stop', nil
    $stdout = StringIO.new

    # when
    @time_tracker.execute 'ls', 'standup'

    # then
    assert_match(
      /\e\[37m\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\s+meetings\s+standup\s+\d{2}:\d{2}:\d{2}\s+\e\[0m/,
      $stdout.string.split("\n").last
    )
  end

  def test_list_filter_not_existing_entry
    # given
    @time_tracker.execute 'meetings', 'standup'
    $stdout = StringIO.new

    # when
    @time_tracker.execute 'ls', 'retrospective'

    # then
    assert_match(/\e\[0m/, $stdout.string.split("\n").last)
  end

  def test_report_format
    # given
    @time_tracker.execute 'meetings', 'standup'
    @time_tracker.execute 'break', 'lunch'
    @time_tracker.execute 'meetings', 'refinement'
    @time_tracker.execute 'STORY-123', 'implementation'
    @time_tracker.execute 'stop', nil
    $stdout = StringIO.new

    # when
    @time_tracker.execute 'rep', nil

    # then
    assert_equal(
      [
        "Report for the last #{TimeTracker::REPORT_DAYS} days",
        "",
        "2022-08-24 (Wednesday)",
        "meetings: 00:00:00 (0.000)",
        "break: 00:00:00 (0.000)",
        "story-123: 00:00:00 (0.000)",
        "total: 00:00:00 (0.000) [excl. break 0.000]",
        "",
        "Week total: 0.000"
      ],
      $stdout.string
        .gsub(/\e\[\d+m/, '')
        .gsub(/\d{2}:\d{2}:\d{2}/, '00:00:00')
        .gsub(/\d\.\d{3}/, '0.000')
        .gsub(/\d{4}-\d{2}-\d{2} \(.+\)/, '2022-08-24 (Wednesday)')
        .gsub(/ {2,}/, '')
        .split("\n")
    )
  end

  def test_report_empty_format
    # when
    @time_tracker.execute 'report', nil

    # then
    assert_equal(
      [
        "Report for the last #{TimeTracker::REPORT_DAYS} days",
        "",
        "Week total: 0.000"
      ],
      $stdout.string
        .gsub(/\e\[\d+m/, '')
        .gsub(/\d\.\d{3}/, '0.000')
        .gsub(/\d{4}-\d{2}-\d{2} \(.+\)/, '2022-08-24 (Wednesday)')
        .gsub(/ {2,}/, '')
        .split("\n")
    )
  end

  def test_show_help_message
    # when
    @time_tracker.execute nil, nil

    # then
    assert_match(/Usage:.+Commands:/m, $stdout.string)
  end
end
