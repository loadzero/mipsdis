# Mipsdis

`mipsdis` is a MIPS bytecode disassembler that I've been hacking on that uses source code generation. For those in a hurry, [here](http://blog.loadzero.com/draft/mipsdis.html) is a link to the obligatory in-browser demo.

I wrote `mipsdis` because I'm interested in low-level software and getting to
grips with an [ISA](https://en.wikipedia.org/wiki/Instruction_set) has been on
my list for a while. As far as that goes, I thought writing a
[disassembler](https://en.wikipedia.org/wiki/Disassembler) would be a good
first step.

I picked [MIPS](https://en.wikipedia.org/wiki/MIPS_architecture) because it is
very simple and regular, and is small enough to fit in your head. I think that
writing an [x86](https://en.wikipedia.org/wiki/X86) disassembler would take me
about ten times as long. I am unsure about
[ARM](https://en.wikipedia.org/wiki/ARM_architecture), but I get the feeling
that it is more complex than MIPS.

I decided to use source code generation for a few reasons.

Firstly, I find writing a bunch of slightly different dispatch and decoding
routines by hand is tedious and error-prone. I find manipulating metadata using
a simple and commented text format to be much more pleasant.

Secondly, I wanted both a C version of the disassembler that I could use on the
command line as a filter, and also a javascript version that would be easy to
share and demonstrate.

Finally, I also wanted to use the metadata and code generation for some other
low-level projects that I am working on.

This article will demonstrate the different versions of the disassembler,
discuss the code generator, describe how to extend mipsdis, tell you how to get
the code and run it, and then conclude by describing some of the extra
documentation available for the project.

# Demo

There are two parts of mipsdis that can be demonstrated.

The first is a javascript version that runs in the browser which you can try
out below. The data in the input text area consists of the program counter in
hex followed by the MIPS opcode. It is a similar format to that used by
[objdump](https://en.wikipedia.org/wiki/Objdump).

If you click disassemble, the browser will disassemble the program and show the
MIPS mnemonic and operands in the output text area.

The default program shown is a fragment of a hello world binary. The program
uses a loop to load a byte from the C string "hello world" and store it to a
memory location that will cause it to be output to the console.

Click [here](http://blog.loadzero.com/draft/mipsdis.html) for the browser demo.

The second part to be demonstrated is the command line version of mipsdis. Note
that we use the C version of mipsdis for this.

To disassemble the same MIPS program as in the browser demo:

    $ ./bin/mipsdis test/hello.txt

    80001000:	3c048000	lui $4,0x8000
    80001004:	34844000	ori $4,$4,0x4000
    80001008:	3c05b400	lui $5,0xb400
    8000100c:	34a503f8	ori $5,$5,0x3f8
    80001010:	80860000	lb $6,0($4)
    80001014:	10c00005	beq $6,$0,0x8000102c
    80001018:	00000000	sll $0,$0,0x0
    8000101c:	a0a60000	sb $6,0($5)
    80001020:	24840001	addiu $4,$4,1
    80001024:	08000404	j 0x80001010
    80001028:	00000000	sll $0,$0,0x0
    8000102c:	3c05bfbf	lui $5,0xbfbf
    80001030:	34a50004	ori $5,$5,0x4
    80001034:	3c060000	lui $6,0x0
    80001038:	34c6002a	ori $6,$6,0x2a
    8000103c:	a0a60000	sb $6,0($5)

If you wish to disassemble an existing MIPS binary with mipsdis, you will need
to adapt it into the format that mipsdis understands.

For a raw binary, that is, a bare binary file just containing opcodes and no
metadata, as you might get from extracting part of an executable or from a
memory dump, you can use 'mipsdis' as a filter like so:

    $ xxd -o 0x80001000 -c 4 -g 4 test/hello.bin |awk '{print $1,$2}' | ./bin/mipsdis -

    80001000:	3c048000	lui $4,0x8000
    80001004:	2484203c	addiu $4,$4,8252
    80001008:	3c05b400	lui $5,0xb400
    8000100c:	34a503f8	ori $5,$5,0x3f8
    ...

The starting offset `0x80001000` needs to be specified because the raw
binary file does not contain this metadata. Without the right address, branch
offsets and jump targets will not be decoded correctly.

The pipeline shown above hexdumps the raw binary file `test/hello.bin` and
adjusts the starting offset, extracts the address and opcode column, and then
pipes the data to `mipsdis`, specifying '-' for stdin.

For convenience, [scripts/rawdump.sh](scripts/rawdump.sh) is provided, which does the same thing:

    $ ./scripts/rawdump.sh test/hello.bin 0x80001000 | ./bin/mipsdis -

    80001000:	3c048000	lui $4,0x8000
    ...

To disassemble a binary in a specific format, such as ELF, you will need to use
the appropriate tool, such as `objdump` or `gdb` to extract the opcodes.

Shown below is a demo of how to do just that:

    $ file test/hello

    test/hello: ELF 32-bit MSB executable, MIPS, MIPS32 version 1 (SYSV), statically linked, not stripped
    
    $ mips-baremetal-elf-objdump -d test/hello | grep '^[0-9a-f]\{8\}:' |awk '{print $1,$2}' | ./bin/mipsdis -

    80001000:	3c048000	lui $4,0x8000
    80001004:	2484203c	addiu $4,$4,8252
    80001008:	3c05b400	lui $5,0xb400
    8000100c:	34a503f8	ori $5,$5,0x3f8
    ...

Obtaining and installing a MIPS toolchain is outside the scope of this article, but imgtec does provide one [here](https://community.imgtec.com/developers/mips/tools/codescape-mips-sdk/).

The ruby and javascript versions of `mipsdis` function identically to the C
version.

ruby:

    $ ./bin/mipsdis.rb test/hello.txt

    80001000:	3c048000	lui $4,0x8000
    ...

javascript:

    $ nodejs ./bin/mipsdis.js test/hello.txt

    80001000:	3c048000	lui $4,0x8000
    ...

# Mipsgen

I wrote [mipsgen](scripts/mipsgen.rb) to do the heavy lifting of generating the
bulk of the code for each version of the disassembler. It currently supports the generation of C, javascript and ruby source code.

The metadata used by mipsgen was created by a process of reading the
architecture manuals and then compiling the information on each mnemonic into a
form that makes sense for both humans and machines.

The resultant metadata is contained in these files:

[tables/dispatch_tables](tables/dispatch_tables.txt) is used to drive decoder switch statements.  
[tables/opcode_bits.txt](tables/opcode_bits.txt) specifies the bitwise layout of each opcode.  
[tables/asm_format.txt](tables/asm_format.txt) specifies the human readable format of each mnemonic.  
[tables/field_format.txt](tables/field_format.txt) specifies the printf format of fields inside `asm_format`.  

`mipsgen` parses this data, and then hands it off to specific code generation
routines that generate the appropriate switch statements and formatting code
for each language.

This keeps the amount of language specific code for each disassembler down to
around 300 lines. The amount of autogenerated code is around 1300 lines for
each version.

`mipsgen` is invoked by the build system of mipsdis as part of the process of
building the different versions of the disassembler. 

It is possible to invoke directly, e.g. to generate the routines for javascript, you would do this:

    $ ./scripts/mipsgen.rb js

    ...
    function decode_j(pc, op)
    {
        return sprintf("j 0x%x", gettarget(pc,op));
    }
    ...

# Extending mipsdis

Adding support for another language such as python to the code generator would
be straightforward, you would have to do something like this:

- Copy mipsdis/rbgen.rb to mipsdis/pygen.rb
- Adjust the method names accordingly
- Modify the print statements in `py_emit_decoder` and `py_gen_switch` to emit
  the appropriate python code.
- Port disasm/rb/mipsdis.rb to disasm/py/mipsdis.py. This is mostly a matter of
  tweaking the bitwise field extraction routines to make the semantics correct
  for python.

Adding new opcodes would be a bit harder, depending on how complex they are. You would have to do something like this:

- Add the correct entry to [tables/dispatch_tables.txt](tables/dispatch_tables.txt)
- Add the bitwise layout of the opcode to [tables/opcode_bits.txt](tables/opcode_bits.txt)
- Add the format of the command to [tables/asm_format.txt](tables/asm_format.txt) and [tables/field_format.txt](tables/field_format.txt)
- If the new opcode introduces new fields or a new interpretation of those
  fields, new field_xxx and getxxx functions will have to be added. See field_m
  and getbroff in [disasm/c/mipsdis.c](disasm/c/mipsdis.c) for details.

# Building

To get the source and run it:

    git clone https://github.com/loadzero/mipsdis.git && cd mipsdis
    ./configure.sh
    make
    make test

The configure script will check for these dependencies:

- make
- ruby
- nodejs (optional)

`nodejs` is an optional dependency that is used only to test the autogenerated
javascript code. If it is not found, then that test is skipped. I did not
really feel like adding it as a hard dependency.

I have tested on OSX 10.11.6 and Ubuntu 16.04. Other unix variants are likely
to work with minimal or no changes.

The code is tested by running [test/input.txt](test/input.txt) through each
disassembler and ensuring that [test/expected.txt](test/expected.txt) is the
result.

The test input was generated by a fuzzer script that uses
[tables/opcode_bits.txt](tables/opcode_bits.txt) and
[tables/dispatch_tables.txt](tables/dispatch_tables.txt) to generate test
cases.

The expected output was generated by running the same input through `objdump`
and filtering it slightly to match the style used by mipsdis.

# Documentation

Apart from this post, there are a few other bits and pieces of documentation
that are worth looking at.

There is an outline of the code in [outline.md](outline.md) that contains a
summary of each module. The modules are listed in topological order.

Each file in the project has (or should have) a blurb at the top that contains
a verbose description of what it is and why it is present. If necessary, the
blurb contains cross references to other related files.

There is some more documentation on the code generation, as well as a static
copy of the auto generated code inside the `docs/` directory.

See [docs/cgen.md](docs/cgen.md) for the C version.  
See [docs/jsgen.md](docs/jsgen.md) for the javascript version.  
See [docs/rbgen.md](docs/rbgen.md) for the ruby version.  

I found the following references very useful:

1. [MIPS Registers](http://www.cs.uwm.edu/classes/cs315/Bacon/Lecture/HTML/ch05s03.html)
2. [MIPS Instruction Formats](https://en.wikibooks.org/wiki/MIPS_Assembly/Instruction_Formats)
3. [MIPS32 Architecture for Programmers Vol 2](http://www.cs.cornell.edu/courses/cs3410/2015sp/MIPS_Vol2.pdf)
4. [MIPS32 4K User's manual](https://imagination-technologies-cloudfront-assets.s3.amazonaws.com/documentation/MD00016-2B-4K-SUM-01.18.pdf)
