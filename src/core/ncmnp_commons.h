#ifndef NCMNP_NCMNP_COMMONS_H
#define NCMNP_NCMNP_COMMONS_H

#include <mach/vm_types.h>
#include <ntsid.h>

typedef struct song_info {
    char song[2048];
    char artist[2048];
    char album[2048];
    vm_address_t _song_addr;
    vm_address_t _artist_addr;
    vm_address_t _album_addr;
    uint _song_updated;
    uint _artist_updated;
    uint _album_updated;
} song_info_t;

#define FUNC_ON_UPDATE_GENERATE(name) void (*(name))(song_info_t *)
#define FUNC_ON_UPDATE_TYPE void (*)(song_info_t *)

void detach(pid_t target_pid, mach_port_name_t target_exception_port);

void attach(pid_t target_pid, void (*)(song_info_t *, uid_t));

#endif
