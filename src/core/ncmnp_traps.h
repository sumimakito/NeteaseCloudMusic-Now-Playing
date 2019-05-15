#ifndef NCMNP_NCMNP_TRAPS_H
#define NCMNP_NCMNP_TRAPS_H

#include "ncmnp_types.h"

const byte_t _TRAP[] = {0xcc};

#define TRAP_SONG_NAME   ((trap_t) 0x95089)
#define TRAP_ARTIST_NAME ((trap_t) 0x950f7)
#define TRAP_ALBUM_NAME  ((trap_t) 0x9510f)
#define TRAP_RST         ((trap_t) 0x95112)
#define TRAP             ((vm_offset_t) &_TRAP[0])

#endif
