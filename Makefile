$(shell mkdir -p bin)

all: bin/mipsdis \
	 bin/mipsdis.rb \
	 bin/mipsdis.js

# run the codegen to generate the core dispatch and decoder functions
disasm/c/mips_dispatch.h: scripts/mipsgen.rb codegen/*.rb tables/*.txt
	./scripts/mipsgen.rb c > $@

disasm/rb/mips_dispatch.rb: scripts/mipsgen.rb codegen/*.rb tables/*.txt
	./scripts/mipsgen.rb rb > $@

disasm/js/mips_dispatch.js: scripts/mipsgen.rb codegen/*.rb tables/*.txt
	./scripts/mipsgen.rb js > $@

bin/mipsdis: disasm/c/mips_dispatch.h disasm/c/mipsdis.c
	gcc -fprofile-arcs -ftest-coverage -g -pedantic -std=gnu90 -I. disasm/c/mipsdis.c -o $@

# deploy the disasm scripts to bin, and ensure we depend on codegen

./bin/mipsdis.rb: disasm/rb/mips_dispatch.rb disasm/rb/mipsdis.rb
	cp disasm/rb/mipsdis.rb $@

./bin/mipsdis.js: disasm/js/mips_dispatch.js disasm/js/mipsdis.js
	cp disasm/js/mipsdis.js $@

.PHONY: test

test: \
	bin/mipsdis \
	bin/mipsdis.rb \
	bin/mipsdis.js \
	test/input.txt \
	test/expected.txt
	./test/test.sh test/expected.txt test/input.txt

clean:
	rm -rf bin
	rm -f disasm/c/mips_dispatch.h
	rm -f disasm/js/mips_dispatch.js
	rm -f disasm/rb/mips_dispatch.rb
