/* dispctl: bat/tat den man hinh TrimUI (TinaLinux/Allwinner) ma khong can python3.
 * Giong Music-Player display.py: ioctl(/dev/disp, 0x102, brightness).
 *   dispctl off      -> den ve 0 (man den, may van thuc + WiFi song)
 *   dispctl on       -> den ve 128 (mac dinh)
 *   dispctl <0..255> -> den ve gia tri cho truoc
 * Tra ve 0 khi thanh cong. Build (CI, giong remote-ui):
 *   gcc -Os -o dispctl dispctl.c
 */
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

#define DISP_DEV "/dev/disp"
#define DISP_LCD_SET_BRIGHTNESS 0x102

int main(int argc, char **argv) {
    int v = 128;
    if (argc > 1) {
        if (strcmp(argv[1], "off") == 0) v = 0;
        else if (strcmp(argv[1], "on") == 0) v = 128;
        else {
            v = atoi(argv[1]);
            if (v < 0) v = 0;
            if (v > 255) v = 255;
        }
    }
    int fd = open(DISP_DEV, O_RDWR);
    if (fd < 0) {
        perror("open /dev/disp");
        return 1;
    }
    unsigned long p[4];
    p[0] = 0;
    p[1] = (unsigned long)v;
    p[2] = 0;
    p[3] = 0;
    int rc = ioctl(fd, DISP_LCD_SET_BRIGHTNESS, p);
    close(fd);
    if (rc != 0) {
        perror("ioctl brightness");
        return 1;
    }
    return 0;
}
