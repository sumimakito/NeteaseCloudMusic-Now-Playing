#ifndef NSString_helper_h
#define NSString_helper_h

#include <mach/vm_types.h>

void convert_NSTaggedPointerStrings_to_c_str(uint64_t ns_tps, char *buffer, unsigned long buffer_size);

void copy_NSString_to_c_str(void *nss_ptr, char *buffer, unsigned long buffer_size);

#endif
