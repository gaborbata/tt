#!/usr/bin/env ruby

# tt.rb - simple time tracker app on the command-line
#
# Copyright (c) 2022 Gabor Bata
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation files
# (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'time'
require 'net/http'
require 'json'
require 'base64'
require 'openssl'

class TimeTracker
  TIME_TRACKER_FILE = "#{Dir.home}/time-tracker.csv"
  SEPARATOR = ','
  BREAK_AMOUNT = 0.0 # break included in work time
  REPORT_DAYS = 7
  LIST_ENTRIES = 20
  DATE_FORMAT = '%Y-%m-%d %H:%M:%S'
  UTC_DATE_FORMAT = '%Y-%m-%dT%H:%M:%S.%L%z'
  TIME_FORMAT = '%H:%M:%S'
  DAY_FORMAT = '%Y-%m-%d (%A)'

  COLOR_CODES = {
    black:   30,
    red:     31,
    green:   32,
    yellow:  33,
    blue:    34,
    magenta: 35,
    cyan:    36,
    white:   37
  }

  JIRA = {
    token: ENV['JIRA_API_TOKEN'],
    user: ENV['JIRA_API_USER'],
    host: ENV['JIRA_API_HOST'],
    issue_pattern: /\w+-\d+/
  }

  def create_jira_worklog(issue, comment, date, duration)
    begin
      raise "Missing Jira environment variables" if JIRA[:token].nil? || JIRA[:user].nil? || JIRA[:host].nil?
      worklog = {
        timeSpentSeconds: duration.to_i,
        comment: {
          type: "doc",
          version: 1,
          content: [
            {
              type: "paragraph",
              content: [
                {
                  text: "#{comment.gsub('"', '\\"')}",
                  type: "text"
                }
              ]
            }
          ]
        },
        started: "#{Time.strptime(date, DATE_FORMAT).strftime(UTC_DATE_FORMAT)}"
      }

      url = URI("#{JIRA[:host]}/rest/api/3/issue/#{issue}/worklog")
      puts colorize("POST #{url} [#{comment}, #{date}, #{duration}s]", :cyan)

      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      request = Net::HTTP::Post.new(url)
      request['Accept'] = 'application/json'
      request['Content-Type'] = 'application/json'
      request['Authorization'] = 'Basic ' + Base64.strict_encode64("#{JIRA[:user]}:#{JIRA[:token]}")
      request.body = JSON.generate(worklog)

      response = http.request(request)
      puts colorize("Status: #{response.code} - #{response.message}", response.kind_of?(Net::HTTPSuccess) ? :green : :red)
    rescue => e
      puts colorize("ERROR: #{e}", :red)
    end
  end

  def list_active_jira_issues
    begin
      raise "Missing Jira environment variables" if JIRA[:token].nil? || JIRA[:user].nil? || JIRA[:host].nil?
      url = URI("#{JIRA[:host]}/rest/api/3/search")
      url.query = URI.encode_www_form({jql: 'assignee=currentuser() AND status!=done'})
      puts colorize("GET #{url}", :cyan)

      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      request = Net::HTTP::Get.new(url)
      request['Accept'] = 'application/json'
      request['Authorization'] = 'Basic ' + Base64.strict_encode64("#{JIRA[:user]}:#{JIRA[:token]}")
      response = http.request(request)
      puts colorize("Status: #{response.code} - #{response.message}", response.kind_of?(Net::HTTPSuccess) ? :green : :red)

      json = JSON.parse(response.body.force_encoding('ISO-8859-1').encode('UTF-8'))
      puts colorize("Active issues (#{json['issues'].size()})", :yellow)
      json['issues'].each do |issue|
        puts "* #{issue['key']}: #{issue['fields']['summary']} [#{issue['fields']['status']['name']}]"
      end
    rescue => e
      puts colorize("ERROR: #{e}", :red)
    end
  end

  def read_entries(days = REPORT_DAYS)
    entries = []
    if File.exist?(TIME_TRACKER_FILE)
      t = Time.now
      report_context = (Time.new(t.year, t.month, t.day) - 60.0 ** 2 * 24.0 * days).to_s
      File.open(TIME_TRACKER_FILE, 'r:UTF-8') do |file|
        file.each_line do |line|
          next if line.strip == ''
          entry = line.strip.split(SEPARATOR)
          entries.push(entry) if entry[0] >= report_context
        end
      end
    end
    entries
  end

  def colorize(text, color)
    "\e[#{COLOR_CODES[color] || 37}m#{text}\e[0m"
  end

  def execute(command, message)
    if command
      command_array = command.split(SEPARATOR)
      command = command_array.first.downcase.gsub(SEPARATOR, '_')
      message = message.gsub(SEPARATOR, '_') if message
      message = (command_array.drop(1).join(' ').gsub(SEPARATOR, '_') + ' ' + message.to_s).strip

      # Create weekly report
      if command == 'rep' || command == 'report'
        report = {}
        entries = read_entries
        (0...entries.size).to_a.each do |idx|
          date = Time.strptime(entries[idx][0], DATE_FORMAT).strftime(DAY_FORMAT)
          activity = entries[idx][1]
          report[date] = {} if report[date].nil?
          if activity != 'stop'
            report[date][activity] = 0.0 if report[date][activity].nil?
            start_time = Time.strptime(entries[idx][0], DATE_FORMAT)
            end_time = idx < entries.size - 1 ? Time.strptime(entries[idx + 1][0], DATE_FORMAT) : Time.now
            report[date][activity] += ([end_time - start_time, 0.0].max) / 60.0 ** 2
          end
        end
        puts colorize("#{' ' * 8}Report for the last #{REPORT_DAYS} days\n", :white)

        week_total = 0.0
        now = Date.today
        week_start_day = (now - (now.wday - 1) % 7).strftime(DAY_FORMAT) # Monday
        report.to_a.last(REPORT_DAYS).each do |day, report|
          total = 0.0
          correction = 0.0
          puts colorize("#{' ' * 8}#{day}", day == week_start_day ? :red : :cyan)
          report.each do |activity, hour|
            total += hour
            correction = [hour - BREAK_AMOUNT, 0].max if activity == 'break'
            formatted = Time.at(hour * 60.0 ** 2).utc.strftime(TIME_FORMAT)
            puts colorize("#{activity.rjust(20)}: #{formatted} (#{sprintf('%2.3f', hour)})", :white)
          end
          formatted = Time.at((total - correction) * 60.0 ** 2).utc.strftime(TIME_FORMAT)
          puts colorize("#{'total'.rjust(20)}: #{formatted} (#{sprintf('%2.3f', total - correction)}) [excl. break #{sprintf('%2.3f', correction)}]\n", :yellow)
          week_total = week_total + total - correction if day >= week_start_day
        end
        puts colorize("#{' ' * 10}Week total: #{sprintf('%2.3f', week_total)}\n", :green)

      # List time tracker entries
      elsif command == 'ls' || command == 'list'
        puts colorize("List of the last #{LIST_ENTRIES} entries#{message.empty? ? '' : ' [filter: ' + message + ']'}\n", :cyan)
        entries = read_entries.last(LIST_ENTRIES)
        (0...entries.size).to_a.each do |idx|
          date = entries[idx][0]
          activity = entries[idx][1]
          msg = entries[idx][2]
          next if !activity.to_s.include?(message) && !msg.to_s.include?(message)
          if activity != 'stop'
            start_time = Time.strptime(entries[idx][0], DATE_FORMAT)
            end_time = idx < entries.size - 1 ? Time.strptime(entries[idx + 1][0], DATE_FORMAT) : Time.now
            puts colorize([
              date, activity, msg || 'n/a', Time.at([end_time - start_time, 0.0].max).utc.strftime(TIME_FORMAT)
            ].map { |e| e.ljust(30) }.join(' '), activity == 'break' ? :blue : :white)
          else
            puts colorize([
              date, activity, msg || 'n/a', '-' * 8
            ].map { |e| e.ljust(30) }.join(' '), :red)
          end
        end

      # Edit entry with text editor
      elsif command == 'edit'
        system('nano', TIME_TRACKER_FILE)

      # Show active jira issues
      elsif command == 'active'
        list_active_jira_issues

      # Upload worklog to jira
      elsif command == 'upload'
        entries = read_entries(message.to_i)
        (0...entries.size).to_a.each do |idx|
          date = entries[idx][0]
          activity = entries[idx][1]
          msg = entries[idx][2]
          if activity != 'stop'
            start_time = Time.strptime(entries[idx][0], DATE_FORMAT)
            end_time = idx < entries.size - 1 ? Time.strptime(entries[idx + 1][0], DATE_FORMAT) : Time.now
            if activity.match(JIRA[:issue_pattern])
              create_jira_worklog(activity, msg || 'n/a', date, [end_time - start_time, 0.0].max)
            end
          end
        end

      # Record an activity
      else
        puts colorize("Record activity [#{command}] with message [#{message.empty? ? 'n/a' : message}]", :green)
        time = Time.now.strftime(DATE_FORMAT)
        File.open(TIME_TRACKER_FILE, 'a:UTF-8') do |file|
          file.write("#{time}#{SEPARATOR}#{command}#{ message ? SEPARATOR + message : ''}\n")
        end
      end

    else
      puts "
        #{colorize('Usage:', :cyan)}
          tt [command]              execute the given command
          tt [activity] [message]   start tracking time of a given activity, with an optional message

        #{colorize('Commands:', :cyan)}
          rep|report                show report for the last #{REPORT_DAYS} days, grouped by activity
          ls|list [filter]          list the last #{LIST_ENTRIES} entries
          break   [message]         start break activity
          stop    [message]         stop tracking time of the current activity
          edit                      edit entries in text editor
          active                    list active jira issues
          upload  [from day offset] upload worklog for jira issues (default offset = 0, which means only today)

        To work with Jira, please provide JIRA_API_USER, JIRA_API_TOKEN, JIRA_API_HOST environment variables.
        To create an API token please visit: https://id.atlassian.com/manage-profile/security/api-tokens

        An activity is considered a Jira ticket if matches the #{JIRA[:issue_pattern].inspect} pattern.
      "
    end
  end
end

TimeTracker.new.execute(ARGV[0], (ARGV[1..-1] || []).join(' '))
