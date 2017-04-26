# This file contains the routines for parsing and verifying the textual data 
# that drives the disassembler code generator.
#
# The textual data that drives these routines comes from these files:
#
# tables/dispatch_tables.txt - used to drive decoder switch statements
# tables/opcode_bits.txt     - specifies bitwise layout of each opcode
# tables/asm_format.txt      - specifies the human readable format of 
#                              each mnemonic
# tables/field_format.txt    - specifies the printf format of fields 
#                              inside asm_format
#
# Relevant docs:
#    See MIPS_Vol2.pdf p34
#    See MD00016-2B-4K-SUM-01.18.pdf p169

require 'util.rb'

# Parse the decoding tables.
# See tables/dispatch_tables.txt for more documentation about layout.
def parse_dispatch_tables(fn)

    ctr = 0
    name = nil
    tables = {}

    File.read(fn).each_line{|l| 

        ctr += 1
        l.strip!

        next if (iscomment(l) || isblank(l))

        # table header
        if (l =~ /^\[(.*) (.*)\]$/)
            name=$1

            tables[name] = Hash.new
            tables[name]['table'] = []
            tables[name]['field'] = $2
            next
        end

        if (name == nil)
            raise "error: no table name #{fn}: line #{ctr}"
        end

        tables[name]['table'] << l.split
    }

    verify_dispatch_tables(tables);

    return tables
end

# Checks that each decoding table is rectangular.
def verify_dispatch_tables(h)

    h.each{|k,h|

        field = h['field']
        tbl = h['table']

        numrows = tbl.size
        numcols = tbl[0].size

        rowctr = 0

        tbl.each{|r|

            if (r.size != numcols)
                raise "error: tbl #{k} error row #{rowctr}"
            end

            rowctr += 1
        }
    }
end

# Parse the text file containing the bitwise layout of each mnemonic.
# See tables/opcode_bits.txt for more information.
#
# example:
#   andi     001100ssssstttttiiiiiiiiiiiiiiii
def parse_opcode_bits(fn)

    ctr = 0
    name = nil
    bits = {}

    File.read(fn).each_line{|l| 

        ctr += 1
        l.strip!

        next if (iscomment(l) || isblank(l))
        t = l.split

        if (t.size != 2)
            raise "error: bits line #{ctr}"
        end

        bits[t[0]] = t[1]
    }

    return bits
end

# Parse the text file containing the human readable format of each mnemonic
# See tables/asm_format.txt for more information.
#
# example:
#    andi     rt,rs,imm
def parse_asm_format(fn)
    ctr = 0
    name = nil
    format = {}

    File.read(fn).each_line{|l|

        ctr += 1
        l.strip!

        next if (iscomment(l) || isblank(l))
        t = l.split

        if (t.size == 1)
            format[t[0]] = []
        elsif (t.size == 2)

            fmt = t[1]
            toks = fmt.strip.scan(/[a-z0-9]+|[ ,()]/)
            format[t[0]] = toks
        else
            raise "error: format line #{ctr}"
        end
    }

    return format
end

# Parse the text file containing the printf format of fields inside asm_format.
# See tables/field_format.txt for more information.
#
# example:
#   imm       0x%x  false
def parse_field_format(fn)
    ctr = 0
    name = nil
    field_format = {}

    File.read(fn).each_line{|l|

        ctr += 1
        l.strip!

        next if (iscomment(l) || isblank(l))
        t = l.split

        if (t.size != 3)
            raise "error: field format line #{ctr}"
        end

        mne, args, needspc = t

        if (!['true', 'false'].include?(needspc))
            raise "error: field format line #{ctr} column 3"
        end

        field_format[mne] = [args, needspc == 'true']
    }

    return field_format
end

# Verify that the parsed data makes sense as a whole.
def check_integrity(tables, bits, asm_format, field_format)

    opcodes = {}

    tables.each{|name, tbl|

        tbl['list'] = tbl['table'].flatten
        tbl['list'].select {|x| islower(x[0]) }.each {|o|

            if (opcodes.include?(o))
                raise "repeated opcode #{o} in table #{name}"
            else
                opcodes[o] = 1
            end
        }
    }

    opcodes.each_key{|o|

        if (!bits.include?(o))
            raise "opcode #{o} has no entry in bits file"
        end

        if (!asm_format.include?(o))
            raise "opcode #{o} has no entry in format file"
        end
    }

    bits.each_key{|o|

        if (!opcodes.include?(o))
            raise "unknown opcode #{o} in bits file"
        end
    }

    ref_asm = {}

    asm_format.each{|o,args|

        if (!opcodes.include?(o))
            raise "unknown opcode #{o} in asm_format file"
        end

        args.each{|a|

            next if %w[( ) ,].include?(a)

            ref_asm[a] = 1

            if (!field_format.include?(a))
                raise "asm format error #{o} #{a}"
            end
        }
    }

    field_format.each_key{|o|

        if (!ref_asm.include?(o))
            raise "unreferenced #{o} in field_format"
        end
    }
end
