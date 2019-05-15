all:
	mkdir -p build
	make -C src/core
	make -C src/cli
