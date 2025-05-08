#!/usr/bin/env bash

Prog=$(basename "$0")   # match what the user called
Version=0.1

read -rd '' Usage <<END
Usage:

  $Prog [OPTIONS] [--] COMMAND

  Commands:

  The following commands run reports:
    cover -- run kcov and record results
    lines -- run scc and record results
    test -- run tesht and record results

    badges -- run all three and create badges from the results

    gif -- create a gif of the tool being run

    code -- run the IDE

  Options (if multiple, must be provided as separate flags):

    -h | --help     show this message and exit
    -v | --version  show the program version and exit
    -x | --trace    enable debug tracing
END

## commands

# cmd.badges renders badges for program version, source lines, tests passed and coverage.
# It updates the latter three statistics beforehand.
cmd.badges() {
  cmd.test
  cmd.cover
  cmd.lines

  makeBadge "version" $(<VERSION) "#007ec6" assets/version.svg
  echo "made version badge"
}

# cmd.code runs the current IDE
cmd.code() {
  (( IN_NIX_DEVELOP )) || runFlake "$0" code
  command -v cursor &>/dev/null && exec cursor .
  code .
}

# cmd.cover runs coverage testing and makes a badge.
# It parses the result from kcov's output directory.
# The badges appear in README.md.
cmd.cover() {
  (( IN_NIX_DEVELOP )) || runFlake "$0" cover
  command -v kcov &>/dev/null || { echo "kcov not found"; exit 1; }   # tool not supported on mac
  kcov --include-path tesht kcov tesht &>/dev/null
  local filenames=( $(mk.Glob kcov/tesht.*/coverage.json) )
  (( ${#filenames[*]} == 1 )) || mk.Fatal 'could not identify report file' 1

  local percent=$(jq -r .percent_covered ${filenames[0]})
  makeBadge coverage "${percent%%.*}%" "#4c1" assets/coverage.svg
  echo "made coverage badge"
}

# cmd.gif creates a gif showing a sample run for README.md.
cmd.gif() {
  (( IN_NIX_DEVELOP )) || runFlake "$0" gif
  command -v asciinema &>/dev/null || { echo "asciinema not found"; exit 1; }   # tool not supported on mac
  asciinema rec -c '/usr/bin/bash -c tesht' tesht.cast
  agg --speed 0.1 tesht.cast assets/tesht.gif
  rm tesht.cast
  echo "made gif"
}

# cmd.lines determines the number of lines of source and makes a badge.
cmd.lines() {
  (( IN_NIX_DEVELOP )) || runFlake "$0" lines
  local lines=$(scc -f csv tesht | tail -n 1 | { IFS=, read -r language rawLines lines rest; echo $lines; })
  makeBadge "source lines" $(addCommas $lines) "#007ec6" assets/lines.svg
  echo "made source lines badge"
}

# cmd.test runs tesht and makes a badge.
cmd.test() {
  local testsPassed=$(tesht | tee /dev/tty | tail -n 1)
  makeBadge tests $testsPassed "#4c1" assets/tests.svg
  echo "made test result badge"
}

## helpers

# addCommas adds commas to a number at every 10^3 place.
#
# Breakdown
#
# :a
# This defines a label called a. Think of it like a named point in the script — we’ll loop back to it later.
#
# s/\B[0-9]\{3\}\>/,&/;
# This is the substitution command. Let's dissect the regex:
#
# \B: Match a position that is not a word boundary.
# Ensures we don’t match at the start of the string.
#
# [0-9]\{3\}: Match exactly 3 digits.
#
# \>: Match the end of a word — which is the end of the number segment (i.e., before a comma or end of string).
#
# So, together: \B[0-9]\{3\}\> matches any group of 3 digits at the end of a longer number that’s not already at a boundary.
#
# Example:
# 1234567 -> matches 567, then 234, then 1
#
# Then we:
#
# Replace it with ,& -- the comma followed by the matched digits.
#
# This adds a comma before that 3-digit group.
#
# ta
# This is a conditional jump:
#
# t checks whether the previous s/// succeeded
#
# If so, it jumps to the label a
#
# This repeats the substitution until no more changes are made, i.e., all commas are inserted.
addCommas() { sed ':a;s/\B[0-9]\{3\}\>/,&/;ta' <<<$1; }

# makeBadge makes an svg badge showing label and value, rendered in color and saved to filename.
makeBadge() {
  local label=$1 value=$2 color=$3 filename=$4

  local dirname=$(dirname "$filename")
  [[ -d $dirname ]] || mkdir -p "$dirname"

  cat >$filename <<END
<svg xmlns="http://www.w3.org/2000/svg" width="200" height="20">
  <rect width="100" height="20" fill="#555"/>
  <rect x="100" width="100" height="20" fill="$color"/>
  <text x="50" y="14" fill="#fff" font-family="Verdana" font-size="11" text-anchor="middle">$label</text>
  <text x="150" y="14" fill="#fff" font-family="Verdana" font-size="11" text-anchor="middle">$value</text>
</svg>
END
}

runFlake() {
  IN_NIX_DEVELOP=1 exec nix develop --command "$@"
}

## globals

## boilerplate

source ~/.local/lib/mk.bash 2>/dev/null ||
  eval "$(curl -fsSL https://raw.githubusercontent.com/binaryphile/mk.bash/develop/mk.bash)" ||
 { echo 'fatal: mk.bash not found' >&2; exit 1; }

# enable safe expansion
IFS=$'\n'
set -o noglob

mk.SetProg $Prog
mk.SetUsage "$Usage"
mk.SetVersion $Version

return 2>/dev/null    # stop if sourced, for interactive debugging
mk.HandleOptions $*   # handle standard options, return how many were handled
mk.Main ${*:$?+1}     # take the arguments except for the ones already handled

