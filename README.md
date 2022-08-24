# tt [![Run tests](https://github.com/gaborbata/tt/workflows/Run%20tests/badge.svg)](https://github.com/gaborbata/tt/actions/workflows/ruby.yml) [![Gem Version](https://badge.fury.io/rb/time-tracker-cli.svg)](https://badge.fury.io/rb/time-tracker-cli)

⏱️ simple time tracker app on the command-line

```
Usage:
  tt [command]              execute the given command
  tt [activity] [message]   start tracking time of a given activity, with an optional message

Commands:
  rep|report                show report for the last 7 days, grouped by activity
  ls|list [filter]          list the last 20 entries
  break   [message]         start break activity
  stop    [message]         stop tracking time of the current activity
  edit                      edit entries in text editor
  active                    list active jira issues
  upload  [from day offset] upload worklog for jira issues (default offset = 0, which means only today)

To work with Jira, please provide JIRA_API_USER, JIRA_API_TOKEN, JIRA_API_HOST environment variables.
To create an API token please visit: https://id.atlassian.com/manage-profile/security/api-tokens

An activity is considered a Jira ticket if matches the /\w+-\d+/ pattern.
```

`time-tracker.csv` file stores time entries which is saved into the `$HOME` folder of the current user.

## How to install

```
gem install time-tracker-cli
```

## Requirements

* Ruby 2.6 or newer, or JRuby
* [nano](https://www.nano-editor.org/) - for editing entries in text editor

> Most of the console applications support ANSI/VT100 escape sequences by default,
> however you might need to enable that in order to have proper colorized output.

