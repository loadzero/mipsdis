#!/usr/bin/env ruby

# Mipsgen is a command line tool that generates code for MIPS bytecode
# disassemblers.
#
# The current code generation flavours are c, javascript and ruby.
#
# usage:
#     mipsgen.rb c
#     mipsgen.rb rb
#     mipsgen.rb js

require 'pp'

$:.unshift(File.expand_path("../../codegen", __FILE__))

require 'parse.rb'
require 'ancillary.rb'

def path_of(table_filename)
    $script_dir + '/../tables/' + table_filename
end

# Load all the code generator modules.
def load_code_generators(flavours)
    flavours.each{|f|
        require "#{f}gen.rb"

        gen_fn = "#{f}_generate".to_sym

        if (!Object.respond_to?(gen_fn, true))
            raise "code generator #{f} does not have #{f}_generate method"
        end
    }
end

# Load and process the metadata needed for the code generators.
def load_metadata()
    codegen_info = {}

    dt = parse_dispatch_tables(path_of('dispatch_tables.txt'))
    ob = parse_opcode_bits(path_of('opcode_bits.txt'))
    af = parse_asm_format(path_of('asm_format.txt'))
    ff = parse_field_format(path_of('field_format.txt'))

    check_integrity(dt, ob, af, ff)

    bm = build_masks(ob)
    sg = build_switch_groups(dt)

    codegen_info = {'dispatch_tables' => dt, 'asm_format' => af,
                'opcode_bits' => ob, 'field_format' => ff,
                'bitmasks' => bm}

    sg.each{|k,v|
        codegen_info['dispatch_tables'][k]['groups'] = v
    }

    return codegen_info
end

# This is the mipsgen entry point.
#
# Initialize the code generators and metadata, then call the correct
# generator for the requested flavour in ARGV[0].
def main()
    Signal.trap("PIPE", "EXIT")
    $script_dir = File.dirname(__FILE__)

    flavours = %w[c js rb]
    load_code_generators(flavours)

    flavour = ARGV[0]

    if (!flavours.include?(flavour))
        STDERR.puts "usage: generator.rb #{flavours.join('|')}"
        exit 1
    end

    codegen_info = load_metadata()
    gen_fn = "#{flavour}_generate".to_sym

    Object.send(gen_fn, codegen_info)
end

main()
