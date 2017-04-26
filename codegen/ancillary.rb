# This file contains routines for buliding ancillary data that the mipsgen 
# code generator requires.
#
# See scripts/mipsgen.rb for the caller of this code.
# See docs/cgen.md for more info.

# Compute bitmasks and comparison values for the fixed parts of each mnemonic.
#
# Example:
#   andi     001100ssssstttttiiiiiiiiiiiiiiii
#
#   mask     11111100000000000000000000000000
#   value    00110000000000000000000000000000
#
# See tables/opcode_bits.txt for more information.
def build_masks(bits)

    masks = {}

    bits.each{|k,x|

        # We don't support jump hints on this arch, so set to zero.
        # We leave the bits marked in the file for clarity wrt to the manual
        # and for the fuzzer.
        
        v = x.tr('h', '0')

        has_reserved = x.include?('r')

        # reserved bits should be zero
        v.tr!('r', '0')

        mask = v.tr('01a-z', '110')
        value = v.tr('a-z', '0')

        # Calculate the mask and expected value.
        # This is used later on by check_opcode, in C this would look like:
        #     (op & mask) == value

        masks[k] = { 'mask' => tohex8(mask.to_i(2)),
                     'value' => tohex8(value.to_i(2)),
                     'reserved' => has_reserved }
    }

    return masks
end

# Generate the data required to build decoder switch statements.
#
# The case value for each entry is simply its linear index, and any repeated
# entries in a table get grouped together by name or function.
#
# See tables/dispatch_tables.txt for more information.
def build_switch_groups(tables)

    sg = {}

    tables.each{|k,v|

        groups = Hash.new{|h,k| h[k] = []}
        ctr = 0

        v['list'].each{|op|

            first = op[0]

            if (islower(first))
                groups[op] << ctr
            elsif (isupper(first))
                groups[op] << ctr
            elsif (first == ".")
                groups['reserved'] << ctr
            elsif (first == "?")
                groups['unusable'] << ctr
            else
                raise "unrecognized dispatch table entry #{k} : #{op}"
            end

            ctr += 1
        }

        sg[k] = groups
    }

    return sg;
end
