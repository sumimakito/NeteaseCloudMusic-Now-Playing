import sys


def on_updated(song, artist, album):
    with open('now-playing.txt', 'w') as f:
        f.write('\n'.join([song, artist, album]))


if __name__ == '__main__':
    if len(sys.argv) != 4:
        print('invalid arguments')
        print('usage: {} song artist album'.format(sys.argv[0]))
        exit(0)
    on_updated(sys.argv[1], sys.argv[2], sys.argv[3])
