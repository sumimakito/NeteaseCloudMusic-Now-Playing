#import <Foundation/Foundation.h>
#include <string.h>
#include <stdlib.h>
#include <mach/mach_vm.h>
#include <mach/mach_error.h>
#include "NSString_helper.h"
#include "ncmnp.h"
#include "ncmnp_utils.h"

const char NSTPS_ENCODING_TABLE[] = "eilotrm.apdnsIc ufkMShjTRxgC4013bDNvwyUL2O856P-B79AFKEWV_zGJ/HYX";

// A helper function that converts NSTaggedPointerStrings to C strings
// Special thanks to Mike Ash (https://www.mikeash.com/pyblog/friday-qa-2015-07-31-tagged-pointer-strings.html)
void convert_NSTaggedPointerStrings_to_c_str(uint64_t ns_tps, char *buffer, unsigned long buffer_size) {
    // an NSTaggedPointerString can hold up to 11 characters (null-terminator not included)
    char _buffer[11];
    if (buffer_size < 11) {
        FATAL("convert_NSTaggedPointerStrings_to_c_str failed: buffer size must not be smaller than 11\n");
    }
    uint64_t length = ns_tps >> 0x4 & 0xf;
    if (length >= 0x8) {
        uint64_t stringData = ns_tps >> 0x8;
        uint64_t cursor = length;
        if (length < 0xa) {
            do {
                _buffer[cursor - 1] = NSTPS_ENCODING_TABLE[stringData & 0x3f];
                cursor = cursor - 0x1;
                stringData = stringData >> 0x6;
            } while (cursor != 0x0);
        } else {
            do {
                _buffer[cursor - 1] = NSTPS_ENCODING_TABLE[stringData & 0x1f];
                cursor = cursor - 0x1;
                stringData = stringData >> 0x5;
            } while (cursor != 0x0);
        }
    } else {
        *(uint64_t *) _buffer = ns_tps >> 0x8;
    }
    memcpy(buffer, _buffer, 11);
    buffer[10] = 0;
}

#ifdef __OBJC__
void copy_NSString_to_c_str(void *nss_ptr, char *buffer, unsigned long buffer_size){
    void *ns_str_mem = calloc(buffer_size, 1);
    memcpy(ns_str_mem, nss_ptr, buffer_size);
    NSString *str = (__bridge NSString *) (ns_str_mem);
    const char *c_str = [str UTF8String];
    memcpy(buffer, c_str, MIN(buffer_size, strlen(c_str) + 1));
    buffer[buffer_size - 1] = 0;
    free(ns_str_mem);
}
#endif
