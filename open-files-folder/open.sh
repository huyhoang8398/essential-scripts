#!/bin/bash

function open() {
  if [ "$#" -lt 1 ]; then
    echo "You must enter 1 or more command line arguments";
  elif [ "$#" -eq 1 ]; then
    xdg-open "$1" &> /dev/null & disown;
  else
    for file in "$@"; do
      xdg-open "$file" &> /dev/null & disown;
    done
  fi
}
