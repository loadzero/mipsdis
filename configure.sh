#!/bin/bash

set -e
set -u

function check_for()
{
    printf "checking for $1 ... "

    if ! which "$1"; then

        printf "failed\n"

        echo "ERROR - could not find $1"
        exit 1
    fi
}

function optional()
{
    printf "optional checking for $1 ... "
    shift

    for i in "$@"; do
        if which $i; then
            return 0
        fi
    done

    printf "not found\n"
}

# this isn't a real autoconf script. it's much simpler.

check_for make
check_for ruby

optional nodejs node nodejs

echo ok
