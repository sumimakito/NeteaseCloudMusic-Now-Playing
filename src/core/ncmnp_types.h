#ifndef NCMNP_NCMNP_TYPES_H
#define NCMNP_NCMNP_TYPES_H

#include <ntsid.h>
#include <lzma.h>
#include <mach/mach_types.h>

typedef u_char byte_t;
typedef uint64_t trap_t;
typedef x86_thread_state64_t th_state_t;

#define TH_STATE       x86_THREAD_STATE64
#define TH_STATE_COUNT x86_THREAD_STATE64_COUNT
#define VM_RWX         ((vm_prot_t) (VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE))

#endif
