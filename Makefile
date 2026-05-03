OBJECTS=$(patsubst examples/%.miniml, out/%.trieste, $(shell ls examples/*.miniml))
FAILING_OBJECTS=$(patsubst examples/fail/%.miniml, out/fail/%.trieste, $(shell ls examples/fail/*.miniml))

all: build/miniml

build/miniml: build
	cd build; ninja

build:
	mkdir -p build; cd build; cmake -G Ninja ../src -DCMAKE_BUILD_TYPE=Debug -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_CXX_STANDARD=20 -DCMAKE_EXPORT_COMPILE_COMMANDS=1

buildf:
	touch out/$f.trieste; ./build/miniml build examples/$f.miniml -o out/$f.trieste

buildp:
	touch out/$f.trieste; ./build/miniml build examples/$f.miniml -o out/$f.trieste -p $p

fuzz:
	./build/miniml test -f

out:
	mkdir -p out

out/fail: out
	mkdir -p out/fail

out/fail/%.trieste: examples/fail/%.miniml | out/fail
	@build/miniml build $< -o $@ > /dev/null && echo "Failing test succeeded:" $< || true

out/%.trieste: examples/%.miniml | out
	build/miniml build $< -o $@

test: $(OBJECTS) $(FAILING_OBJECTS)

experiment: out
	python run_experiments.py

llvm: out generate-code compile-llvm

generate-code: all
	touch out/test.trieste; > out/test.trieste; ./build/miniml build llvmir_tests/test.miniml -o out/test.trieste;

compile-llvm:
# This is a test for the LLVM IR files. It compiles the LLVM IR file, runs it and prints returnval to stdout.
	clang out/test.ll -o out/test.out; ./out/test.out; echo $$?

clean:
	rm -rf out/* *.trieste; rm -rf build; rm -rf out; rm out.ll; rm compiler_output.txt



RUNS ?= 1
TESTCOUNTS ?= 100

configure-cov:
	mkdir -p build-cov; cd build-cov; cmake -G Ninja ../src \
		-DCODE_COVERAGE=ON \
		-DCMAKE_BUILD_TYPE=Debug \
		-DCMAKE_CXX_COMPILER=clang++ \
		-DCMAKE_CXX_STANDARD=20 \
		-DCMAKE_EXPORT_COMPILE_COMMANDS=1 \
		-DCMAKE_THREAD_LIBS_INIT="-lpthread" \
		-DLLVM_ENABLE_TERMINFO=OFF \
		-DCMAKE_EXE_LINKER_FLAGS="-ltinfo"

compile-cov:
	cd build-cov; ninja -j2

coverage-trieste:
	bash coverage.sh --mode trieste --testcounts $(TESTCOUNTS) --runs $(RUNS) \
		--bin build-cov/miniml --src-dir $(shell pwd)/src \
		--exclude "/_deps/" --out-dir coverage-out

coverage-external:
	bash coverage.sh --mode external \
		--external-dir starsmith_tests \
		--bin build-cov/miniml --src-dir $(shell pwd)/src \
		--exclude "/_deps/" --out-dir coverage-out

clean-coverage:
	rm -rf coverage-out

clean-cov:
	rm -rf build-cov coverage-out

.PHONY: clean all build/miniml test configure-cov compile-cov coverage-trieste coverage-external clean-cov clean-coverage