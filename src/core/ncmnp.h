#ifndef NCMNP_NCMNP_H
#define NCMNP_NCMNP_H

#include <mach/mach_types.h>
#include <zconf.h>
#include "ncmnp_types.h"
#include "ncmnp_commons.h"

byte_t *memory_backup_for(trap_t trap);

void arbitrary_copy_NSString_to_c_str(vm_address_t address, char *buffer, unsigned long buffer_size);

void target_backup_mem(trap_t trap);

void target_set_trap(trap_t trap);

void target_reset_trap(trap_t trap);

void target_set_traps();

void print_registers(th_state_t thread_state);

void handle_trap(th_state_t *thread_state);

vm_address_t get_base_for_task(mach_port_name_t task);

vm_address_t get_base_for_pid(pid_t pid);

#endif
