#!/bin/bash

# This file runs the test cases for mipsdis/mipsgen.
#
# At present, there is one test, which is to check that running test/input.txt
# through each version of the mipsdis disassembler produces the results in
# test/expected.txt
#
# See test/input.txt for more info.
# See test/expected.txt for more info.

set -e
set -u
set -o pipefail

# strip comments from expected.txt
sc()
{
    cat "$1" | grep -v '^#' | awk 'NF'
}

# test the disassemblers by comparing their output to an expected result

echo "C test"
diff <(sc $1) <(./bin/mipsdis $2) |head

echo "ruby test"
diff <(sc $1) <(./bin/mipsdis.rb $2) |head

# nodejs is an optional dependency

if type /usr/bin/nodejs >/dev/null 2>&1; then
    echo "javascript test"
    diff <(sc $1) <(nodejs ./bin/mipsdis.js $2) |head
fi
