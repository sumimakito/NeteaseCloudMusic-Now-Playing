CC=clang

FRAMEWORKS:=-fobjc-arc

SOURCE=ncmnp.m NSString_helper.m mach_excServer.c

OUT_DIR=../../build

OUT=libncmnp.dylib

all:
	$(CC) -dynamiclib $(SOURCE) $(FRAMEWORKS) -o $(OUT_DIR)/$(OUT)
