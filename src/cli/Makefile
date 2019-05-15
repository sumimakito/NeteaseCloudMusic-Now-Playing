CC=clang

LD:=-lncmnp

DYLIB_DIR:=../../build

DYLIB=libncmnp.dylib

LDFLAGS+=-L$(DYLIB_DIR)

SOURCE=main.c

OUT_DIR=../../build

OUT=ncmnp

all:
	$(CC) $(LD) $(LDFLAGS) $(SOURCE) -o $(OUT_DIR)/$(OUT)
	install_name_tool -change $(DYLIB_DIR)/$(DYLIB) @executable_path/$(DYLIB) $(OUT_DIR)/$(OUT)
