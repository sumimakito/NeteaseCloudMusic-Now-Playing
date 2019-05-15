#include <stdio.h>
#include <fcntl.h>
#include <stdlib.h>
#include <zconf.h>
#include "../core/ncmnp_commons.h"

void on_updated(song_info_t *song_info, uid_t uid) {
    printf("Now playing:\n");
    printf("Song:   %s\n", song_info->song);
    printf("Artist: %s\n", song_info->artist);
    printf("Album:  %s\n", song_info->album);
    int pid = fork();
    if (pid == -1) {
        printf("failed to fork child process to call Python script");
    } else if (pid == 0) {
        // drop unnecessary privileges (if possible)
        setuid(uid);
        int fd = open("/dev/null", O_WRONLY);
        dup2(fd, 2);
        close(fd);
        char *args[6] = {"python", "script.py", song_info->song, song_info->artist, song_info->album, 0};
        execv("/usr/bin/python", args);
        exit(0);
    }
}

int main(int argc, const char *argv[]) {
    if (argc != 2) {
        printf("NeteaseMusic Now Playing\n");
        printf("Usage: %s PID\n", argv[0]);
        exit(0);
    }
    pid_t pid = (pid_t) strtol(argv[1], NULL, 10);
    attach(pid, &on_updated);
}