#!/bin/bash

# This script converts a raw binary file containing MIPS bytecodes into the
# format expected by mipsdis.
#
# usage:
#     rawdump.sh file [offset]
#
# examples:
#     rawdump.sh file.bin
#     rawdump.sh file.bin 0x80001000

set -e
set -u

inp=$1
off=${2:-0}

xxd -o $off -c 4 -g 4 $inp |cut -c1-18
