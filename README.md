# tt [![tests](https://github.com/gaborbata/tt/workflows/tests/badge.svg)](https://github.com/gaborbata/tt/actions/workflows/ruby.yml) [![Gem Version](https://badge.fury.io/rb/time-tracker-cli.svg)](https://badge.fury.io/rb/time-tracker-cli)

⏱️ simple time tracker app on the command-line

```
Usage:
  tt [command] [params]     execute the given command

Commands:
  rep|report                show report for the last 7 days, grouped by activity
  ls|list [filter]          list the last 20 entries
  start   [message]         start tracking time of a given activity
  break   [message]         start break activity
  stop    [message]         stop tracking time of the current activity
  edit                      edit entries in text editor (defined by $EDITOR environment variable)
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
