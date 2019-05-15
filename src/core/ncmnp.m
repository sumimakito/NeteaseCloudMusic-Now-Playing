

#include <stdio.h>
#include <mach/mach.h>
#include <zconf.h>
#include <sys/ptrace.h>
#include <stdlib.h>

#include <mach/mach_vm.h>
#include <libproc.h>

#include "NSString_helper.h"
#include "ncmnp.h"
#include "ncmnp_traps.h"

//#define NCMNP_LOGGING_COLORFUL

#include "ncmnp_utils.h"

byte_t _memory_backup[4];
vm_address_t base;
mach_port_name_t target_task_port;
uid_t startup_uid;
uint detach_ctrl = 0;

FUNC_ON_UPDATE_GENERATE(_func_on_update) = NULL;

song_info_t current_song_info;

byte_t *memory_backup_for(trap_t trap) {
    switch (trap) {
        case TRAP_SONG_NAME:
            return &_memory_backup[0];
        case TRAP_ARTIST_NAME:
            return &_memory_backup[1];
        case TRAP_ALBUM_NAME:
            return &_memory_backup[2];
        case TRAP_RST:
            return &_memory_backup[3];
        default:
            return 0;
    }
}

void arbitrary_copy_NSString_to_c_str(vm_address_t address, char *buffer, unsigned long buffer_size) {
    if (buffer_size < sizeof(vm_address_t)) {
        FATAL("arbitrary_copy_NSString_to_c_str failed: buffer size must not be smaller than %d",
              (int) sizeof(vm_address_t));
    }
    kern_return_t kr;
    vm_offset_t data_out = 0;
    mach_msg_type_number_t data_out_size = 0;
    if ((kr = mach_vm_read(target_task_port, address, buffer_size, &data_out, &data_out_size)) != KERN_SUCCESS) {
        INFO("mach_vm_read failed: %s %x", mach_error_string(kr), kr);
        // the address itself is likely to be an NSTaggedPointerString but not NSString
        convert_NSTaggedPointerStrings_to_c_str(address, buffer, buffer_size);
        return;
    }
    copy_NSString_to_c_str((void *) data_out, buffer, buffer_size);
    buffer[buffer_size - 1] = 0;
}

void target_backup_mem(trap_t trap) {
    kern_return_t kr;
    if ((kr = mach_vm_protect(target_task_port, base + trap, 1, FALSE, VM_RWX)) != KERN_SUCCESS) {
        FATAL("mach_vm_protect failed: %s %x", mach_error_string(kr), kr);
    }

    vm_offset_t data_out = 0;
    mach_msg_type_number_t data_out_size = 0;
    if ((kr = mach_vm_read(target_task_port, base + trap, 1, &data_out, &data_out_size)) != KERN_SUCCESS) {
        FATAL("mach_vm_read failed: %s %x", mach_error_string(kr), kr);
    }
    memcpy(memory_backup_for(trap), (void *) data_out, 1);
}

void target_set_trap(trap_t trap) {
    kern_return_t kr;
    if ((kr = mach_vm_protect(target_task_port, base + trap, 1, FALSE, VM_RWX)) != KERN_SUCCESS) {
        FATAL("mach_vm_protect failed: %s %x", mach_error_string(kr), kr);
    }

    if ((kr = mach_vm_write(target_task_port, base + trap, TRAP, 1)) != KERN_SUCCESS) {
        FATAL("mach_vm_write failed: %s %x", mach_error_string(kr), kr);
    }
    INFO("target_set_trap: %#08llx set", trap);
}

void target_reset_trap(trap_t trap) {
    kern_return_t kr;
    if ((kr = mach_vm_protect(target_task_port, base + trap, 1, FALSE, VM_RWX)) != KERN_SUCCESS) {
        FATAL("mach_vm_protect failed: %s %x", mach_error_string(kr), kr);
    }

    if ((kr = mach_vm_write(target_task_port, base + trap, (vm_offset_t) memory_backup_for(trap), 1)) != KERN_SUCCESS) {
        FATAL("mach_vm_write failed: %s %x", mach_error_string(kr), kr);
    }
    INFO("target_reset_trap: %#08llx reset", trap);
}

void target_set_traps() {
    target_set_trap(TRAP_SONG_NAME);
    target_set_trap(TRAP_ARTIST_NAME);
    target_set_trap(TRAP_ALBUM_NAME);
}

void print_registers(th_state_t thread_state) {
    INFO("REGISTERS");
    INFO("    RIP        = %#016llx (-BASE = %#016llx)", thread_state.__rip, thread_state.__rip - base);
    INFO("    RAX        = %#016llx", thread_state.__rax);
#ifdef NCMNP_SHOW_ALL_REGS
    INFO("    RCX        = %#016llx", thread_state.__rcx);
    INFO("    RDX        = %#016llx", thread_state.__rdx);
    INFO("    RBP        = %#016llx", thread_state.__rbp);
    INFO("    RSI        = %#016llx", thread_state.__rsi);
    INFO("    RDI        = %#016llx", thread_state.__rdi);
    INFO("    R8         = %#016llx", thread_state.__r8);
    INFO("    R9         = %#016llx", thread_state.__r9);
#endif
}

void handle_trap(th_state_t *thread_state) {
    char buffer[2048];
    trap_t trap = thread_state->__rip - 0x1 - base;
    switch (trap) {
        case TRAP_SONG_NAME:
        case TRAP_ARTIST_NAME:
        case TRAP_ALBUM_NAME:
            arbitrary_copy_NSString_to_c_str(thread_state->__rax, &buffer[0], 2048);
            INFO("\t\t\tNSString = %s", buffer);
            target_set_trap(TRAP_RST);
            break;
        case TRAP_RST:
            target_set_traps();
            break;
        default:
        FATAL("handle_trap failed: unknown trap (%%rip = %#016llx)", thread_state->__rip);
    }
    switch (trap) {
        case TRAP_SONG_NAME:
            if (thread_state->__rax != current_song_info._song_addr) {
                memcpy(&current_song_info.song[0], &buffer[0], strlen(buffer) + 1);
                current_song_info._song_addr = thread_state->__rax;
                current_song_info._song_updated = 1;
            }
            break;
        case TRAP_ARTIST_NAME:
            if (thread_state->__rax != current_song_info._artist_addr) {
                memcpy(&current_song_info.artist[0], &buffer[0], strlen(buffer) + 1);
                current_song_info._artist_addr = thread_state->__rax;
                current_song_info._artist_updated = 1;
            }
            break;
        case TRAP_ALBUM_NAME:
            if (thread_state->__rax != current_song_info._album_addr) {
                memcpy(&current_song_info.album[0], &buffer[0], strlen(buffer) + 1);
                current_song_info._album_addr = thread_state->__rax;
                current_song_info._album_updated = 1;
            }
            if (current_song_info._song_updated || current_song_info._artist_updated ||
                current_song_info._album_updated) {
                if (_func_on_update != NULL) {
                    _func_on_update(&current_song_info, startup_uid);
                }
            }
            current_song_info._song_updated = 0;
            current_song_info._artist_updated = 0;
            current_song_info._album_updated = 0;
            break;
        default:
            break;
    }
    target_reset_trap(trap);
    thread_state->__rip--;
}

vm_address_t get_base_for_task(mach_port_name_t task) {
    kern_return_t krc;
    vm_address_t address = 0;
    vm_size_t size = 0;
    uint32_t depth = 1;
    while (1) {
        struct vm_region_submap_info_64 info;
        mach_msg_type_number_t count = VM_REGION_SUBMAP_INFO_COUNT_64;
        krc = vm_region_recurse_64(task, &address, &size, &depth, (vm_region_info_64_t) &info, &count);
        if (krc == KERN_INVALID_ADDRESS) {
            break;
        }
        if (info.is_submap) {
            depth++;
        } else {
            return address;
        }
    }
    return 0;
}

vm_address_t get_base_for_pid(pid_t pid) {
    mach_port_name_t task;
    if (task_for_pid(mach_task_self(), pid, &task) != KERN_SUCCESS) {
        perror("task_for_pid");
        return 0;
    }
    return get_base_for_task(task);
}

extern kern_return_t catch_mach_exception_raise(
        mach_port_t exception_port,
        mach_port_t thread_port,
        mach_port_t task_port,
        exception_type_t exception_type,
        mach_exception_data_t codes,
        mach_msg_type_number_t num_codes) {

    INFO("EXC_TYPE = %#x", exception_type);
    INFO("THREAD   = %#x", thread_port);

    thread_suspend(task_port);
    INFO("thread suspended");
    thread_t th;
    kern_return_t kr;

    th_state_t thread_state;
    mach_msg_type_number_t sc = TH_STATE_COUNT;

    if ((kr = mach_port_get_context(mach_task_self(), exception_port, (mach_vm_address_t *) &th)) != KERN_SUCCESS) {
        FATAL("mach_port_get_context failed: %s %x", mach_error_string(kr), kr);
    }
    if ((kr = thread_get_state(thread_port, TH_STATE, (thread_state_t) &thread_state, &sc)) !=
        KERN_SUCCESS) {
        FATAL("thread_get_state failed: %s %x", mach_error_string(kr), kr);
    }
    print_registers(thread_state);

    handle_trap(&thread_state);

    if ((kr = thread_set_state(thread_port, TH_STATE, (thread_state_t) &thread_state, sc)) !=
        KERN_SUCCESS) {
        FATAL("thread_set_state failed: %s %x", mach_error_string(kr), kr);
    }
    if ((kr = thread_get_state(thread_port, TH_STATE, (thread_state_t) &thread_state, &sc)) !=
        KERN_SUCCESS) {
        FATAL("thread_get_state failed: %s %x", mach_error_string(kr), kr);
    }
    print_registers(thread_state);


    return KERN_SUCCESS;
}

extern kern_return_t catch_mach_exception_raise_state(
        mach_port_t exception_port,
        exception_type_t exception,
        const mach_exception_data_t code,
        mach_msg_type_number_t codeCnt,
        int *flavor,
        const thread_state_t old_state,
        mach_msg_type_number_t old_stateCnt,
        thread_state_t new_state,
        mach_msg_type_number_t *new_stateCnt) {

    return MACH_RCV_INVALID_TYPE;
}

extern kern_return_t catch_mach_exception_raise_state_identity(
        mach_port_t exception_port,
        mach_port_t thread,
        mach_port_t task,
        exception_type_t exception,
        mach_exception_data_t code,
        mach_msg_type_number_t codeCnt,
        int *flavor,
        thread_state_t old_state,
        mach_msg_type_number_t old_stateCnt,
        thread_state_t new_state,
        mach_msg_type_number_t *new_stateCnt) {

    return MACH_RCV_INVALID_TYPE;
}

extern boolean_t mach_exc_server(mach_msg_header_t *InHeadP, mach_msg_header_t *OutHeadP);

void detach(pid_t target_pid, mach_port_name_t target_exception_port) {
    task_suspend(target_task_port);
    target_reset_trap(TRAP_SONG_NAME);
    target_reset_trap(TRAP_ARTIST_NAME);
    target_reset_trap(TRAP_ALBUM_NAME);
    target_reset_trap(TRAP_RST);
    ptrace(PT_DETACH, target_pid, 0, 0);
    mach_port_deallocate(mach_task_self(), target_exception_port);
    task_resume(target_task_port);
    printf("Detached\n");
    exit(0);
}

void sig_handler(int signo) {
    if (signo == SIGINT) {
        printf("SIGINT received\n");
        printf("Detaching...\n");
        detach_ctrl = 1;
    }
}

void attach(pid_t target_pid, FUNC_ON_UPDATE_GENERATE(func_on_update)) {
    printf("NeteaseMusic Now Playing Interceptor by Makito\n");

    if (signal(SIGINT, sig_handler) == SIG_ERR) {
        FATAL("failed to setup signal handler for SIGINT");
    }

    if (getuid() == 0) {
        WARN("running as root");
    }
    setuid(0);
    if (getuid() != 0) {
        FATAL("interception is not available since setuid(0) has failed");
    }

    current_song_info._song_addr = 0;
    current_song_info._artist_addr = 0;
    current_song_info._album_addr = 0;
    current_song_info._song_updated = 0;
    current_song_info._artist_updated = 0;
    current_song_info._album_updated = 0;

    task_for_pid(mach_task_self(), target_pid, &target_task_port);

    exception_mask_t saved_masks[EXC_TYPES_COUNT];
    mach_port_t saved_ports[EXC_TYPES_COUNT];
    exception_behavior_t saved_behaviors[EXC_TYPES_COUNT];
    thread_state_flavor_t saved_flavors[EXC_TYPES_COUNT];
    mach_msg_type_number_t saved_exception_types_count;

    exception_mask_t mask = EXC_MASK_BREAKPOINT;

    task_get_exception_ports(target_task_port, mask, saved_masks, &saved_exception_types_count,
                             saved_ports, saved_behaviors, saved_flavors);

    mach_port_name_t target_exception_port;
    mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &target_exception_port);
    mach_port_insert_right(mach_task_self(), target_exception_port, target_exception_port, MACH_MSG_TYPE_MAKE_SEND);
    task_set_exception_ports(target_task_port, mask, target_exception_port, EXCEPTION_DEFAULT | MACH_EXCEPTION_CODES,
                             MACHINE_THREAD_STATE);

    if (ptrace(PT_ATTACHEXC, target_pid, 0, 0) < 0) {
        perror("ptrace");
        FATAL("failed to attach to process");
    }
    INFO("attached");
    task_suspend(target_task_port);
    INFO("process suspended");
    base = get_base_for_task(target_task_port);
    INFO("base: %#016llx", (unsigned long long int) base);
    _func_on_update = func_on_update;

    kern_return_t kr;

    target_backup_mem(TRAP_SONG_NAME);
    target_backup_mem(TRAP_ARTIST_NAME);
    target_backup_mem(TRAP_ALBUM_NAME);
    target_backup_mem(TRAP_RST);

    INFO("injecting to process...");

    target_set_traps();
    task_resume(target_task_port);

    printf("Initialized\n");
    printf("REMEMBER TO USE ^C TO DETACH THE INTERCEPTOR FIRST\n");
    printf("OTHERWISE THE ATTACHED PROCESS MIGHT CRASH\n");

    char req[128], rpl[128];
    while (!detach_ctrl) {
        INFO("waiting");
        while ((kr = mach_msg(
                (mach_msg_header_t *) req,
                MACH_RCV_MSG | MACH_RCV_TIMEOUT,
                0,
                sizeof(req),
                target_exception_port,
                100,
                MACH_PORT_NULL)) == MACH_RCV_TIMED_OUT) {
            if (detach_ctrl) {
                detach(target_pid, target_exception_port);
            }
        }

        if (kr == KERN_SUCCESS) {
            INFO("trapped");
            task_suspend(target_task_port);
            INFO("process suspended");
            if (!mach_exc_server((mach_msg_header_t *) req, (mach_msg_header_t *) rpl)) {
                kr = ((mig_reply_error_t *) rpl)->RetCode;
                FATAL("message_parse failed: %s %x", mach_error_string(kr), kr);
            }
        } else {
            FATAL("mach_msg recv failed: %s %x", mach_error_string(kr), kr);
        }
        task_resume(target_task_port);
        INFO("process resumed");

        mach_msg_size_t send_sz = ((mach_msg_header_t *) rpl)->msgh_size;
        if ((kr = mach_msg(
                (mach_msg_header_t *) rpl,
                MACH_SEND_MSG,
                send_sz,
                0,
                MACH_PORT_NULL,
                MACH_MSG_TIMEOUT_NONE,
                MACH_PORT_NULL)
            ) != MACH_MSG_SUCCESS) {
            FATAL("mach_msg failed: %s %x", mach_error_string(kr), kr);
        }
    }
    detach(target_pid, target_exception_port);
}
