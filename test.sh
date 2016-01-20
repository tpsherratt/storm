#!/bin/bash

# weird escapes print as bold
printf "\n\n\n\033[1m***** RUNNING storm SPECS *******\033[00m\n"

bundle install | grep Installing

bundle exec rspec spec

exit $?
