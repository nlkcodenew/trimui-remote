/* remote-ui: man hinh thong tin SSH cho TrimUI Brick Pro / Smart Pro S.
 * - Chu TO theo pixel that (bai hoc Xiaozhi: khong dung logical size co dinh).
 * - Nut B (joystick button 0) lan 1: hien panel xac nhan TO giua man hinh.
 *   Nut B lan 2 trong 4s: thoat. Thoat man hinh KHONG tat dich vu nen.
 * - Nut Y (button 2) / phim y: TAT DEN man hinh kieu Music Player
 *   (ioctl /dev/disp 0x102 ve 0, may van thuc + WiFi song, khac Power=suspend).
 *   Bam phim bat ky de sang lai. Luc tat chi Delay 100ms, khong ve gi.
 * - Du phong: SELECT(8)+START(9) cung luc = thoat ngay; ESC tren ban phim cung vay.
 * - Endpoint Internet (VPS co dinh / Pinggy) duoc poll tu tunnel.sh moi 2s.
 * Build (CI): aarch64-linux-gnu-gcc -Os -o remote-ui remote-ui.c -lSDL2 -lSDL2_ttf
 */
#include <SDL2/SDL.h>
#include <SDL2/SDL_ttf.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <errno.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define BTN_B 0
#define BTN_A 1
#define BTN_Y 2
#define BTN_X 3
#define BTN_SELECT 8
#define BTN_START 9
#define CONFIRM_MS 4000

/* Tat den man hinh kieu Music Player: ioctl(/dev/disp, 0x102, 0),
 * may van thuc + WiFi song (khac han Power=suspend=tắt WiFi).
 * Bat ky phim nao cung sang lai. */
#define DISP_DEV "/dev/disp"
#define DISP_LCD_SET_BRIGHTNESS 0x102
static int disp_saved_brightness = -1;
static int disp_is_off = 0;
static char disp_recovery[768];

static int disp_set(int value) {
    int fd = open(DISP_DEV, O_RDWR);
    if (fd < 0) return 0;
    unsigned long p[4];
    p[0] = 0; p[1] = (unsigned long)value; p[2] = 0; p[3] = 0;
    int rc = ioctl(fd, DISP_LCD_SET_BRIGHTNESS, p);
    close(fd);
    return rc == 0;
}

static int disp_read_saved(void) {
    static const char *paths[] = {
        "/mnt/SDCARD/Saves/trim-ui-brick-pro-system.json",
        "/mnt/UDISK/system.json",
        "/appconfigs/system.json",
        NULL
    };
    for (int i = 0; paths[i]; i++) {
        FILE *f = fopen(paths[i], "r");
        if (!f) continue;
        char buf[1024];
        size_t n = fread(buf, 1, sizeof(buf) - 1, f);
        buf[n] = '\0';
        fclose(f);
        char *k = strstr(buf, "backlight");
        if (!k) k = strstr(buf, "brightness");
        if (!k) continue;
        char *c = strchr(k, ':');
        if (!c) continue;
        int v = atoi(c + 1);
        if (v >= 1 && v <= 10) return (int)((v - 1) * 254.0 / 9.0 + 1.0);
        if (v >= 1 && v <= 255) return v;
    }
    /* Thu file recovery do lan screen_off truoc de lai (crash giua chung). */
    if (disp_recovery[0]) {
        FILE *f = fopen(disp_recovery, "r");
        if (f) {
            int v = 0;
            if (fscanf(f, "{\"brightness\": %d}", &v) == 1 && v >= 1 && v <= 255) {
                fclose(f);
                return v;
            }
            fclose(f);
        }
    }
    return 128;
}

static void disp_write_recovery(int v) {
    if (!disp_recovery[0]) return;
    char tmp[800];
    snprintf(tmp, sizeof(tmp), "%s.tmp", disp_recovery);
    FILE *f = fopen(tmp, "w");
    if (!f) return;
    fprintf(f, "{\"brightness\": %d}\n", v);
    fclose(f);
    rename(tmp, disp_recovery);
}

static void disp_clear_recovery(void) {
    if (disp_recovery[0]) unlink(disp_recovery);
}

static void screen_off(void) {
    if (disp_is_off) return;
    if (disp_saved_brightness < 0)
        disp_saved_brightness = disp_read_saved();
    disp_write_recovery(disp_saved_brightness);
    if (disp_set(0)) disp_is_off = 1;
}

static void screen_on(void) {
    if (!disp_is_off) return;
    int v = disp_saved_brightness > 0 ? disp_saved_brightness : 128;
    if (v < 1) v = 1;
    if (v > 255) v = 255;
    disp_set(v);
    disp_is_off = 0;
    disp_clear_recovery();
}

static SDL_Window *win;
static SDL_Renderer *ren;
static TTF_Font *f_title, *f_body, *f_small;
static int W, H;
static char fontpath[768];

/* Intro logo NLK 2.2s giong het Music-Player / chiaki-ng / Terminal:
 * nen (8,8,12), chu do (229,9,20), bay len lan luot + overshoot + quet trang.
 * Bam phim bat ky de bo qua. Tat bang REMOTE_NO_INTRO=1, file intro.off /
 * .no-intro canh app, hoac config.json "intro": false. */
static int intro_disabled(const char *appdir) {
    const char *env = getenv("REMOTE_NO_INTRO");
    if (env && strcmp(env, "1") == 0) return 1;
    char p[768];
    snprintf(p, sizeof(p), "%s/intro.off", appdir);
    if (access(p, F_OK) == 0) return 1;
    snprintf(p, sizeof(p), "%s/.no-intro", appdir);
    if (access(p, F_OK) == 0) return 1;
    snprintf(p, sizeof(p), "%s/config.json", appdir);
    FILE *cfg = fopen(p, "r");
    if (!cfg) return 0;
    char buf[2048];
    size_t n = fread(buf, 1, sizeof(buf) - 1, cfg);
    buf[n] = '\0';
    fclose(cfg);
    char *key = strstr(buf, "\"intro\"");
    if (!key) return 0;
    char *colon = strchr(key, ':');
    if (!colon) return 0;
    colon++;
    while (*colon == ' ' || *colon == '\t') colon++;
    return strncmp(colon, "false", 5) == 0;
}

static double intro_spread(double progress, double k) {
    double ease = progress / 0.55;
    if (ease < 0.0) ease = 0.0;
    if (ease > 1.0) ease = 1.0;
    return (4.0 + 26.0 * (1.0 - (1.0 - ease) * (1.0 - ease))) * k;
}

static void play_intro(const char *appdir) {
    if (intro_disabled(appdir)) return;
    if (!ren || W <= 0 || H <= 0) return;
    double s = W / 1024.0, sy = H / 768.0;
    if (sy < s) s = sy;
    if (s < 0.75) s = 0.75;
    int giant = (int)(132.0 * s + 0.5);
    if (giant < 24) giant = 24;
    double k = giant / 132.0;
    TTF_Font *font = TTF_OpenFont(fontpath, giant);
    if (!font) {
        static const int smaller[] = {260, 220, 190, 160, 132, 100};
        for (size_t i = 0; i < sizeof(smaller) / sizeof(smaller[0]) && !font; i++) {
            if (smaller[i] >= giant) continue;
            font = TTF_OpenFont(fontpath, smaller[i]);
            if (font) { giant = smaller[i]; k = giant / 132.0; }
        }
    }
    if (!font) return;
    SDL_Color dark = {60, 5, 8, 255};
    SDL_Color bright = {229, 9, 20, 255};
    SDL_Color white = {255, 255, 255, 255};
    static const char *letters = "NLK";
    SDL_Texture *tex_dark[3] = {NULL, NULL, NULL};
    SDL_Texture *tex_bright[3] = {NULL, NULL, NULL};
    SDL_Texture *tex_white[3] = {NULL, NULL, NULL};
    int gw[3] = {0, 0, 0}, gh[3] = {0, 0, 0};
    for (int i = 0; i < 3; i++) {
        char ch[2] = {letters[i], '\0'};
        SDL_Surface *sd = TTF_RenderUTF8_Blended(font, ch, dark);
        SDL_Surface *sb = TTF_RenderUTF8_Blended(font, ch, bright);
        SDL_Surface *sw = TTF_RenderUTF8_Blended(font, ch, white);
        if (sb) { gw[i] = sb->w; gh[i] = sb->h; }
        if (sd) { tex_dark[i] = SDL_CreateTextureFromSurface(ren, sd); SDL_FreeSurface(sd); }
        if (sb) { tex_bright[i] = SDL_CreateTextureFromSurface(ren, sb); SDL_FreeSurface(sb); }
        if (sw) { tex_white[i] = SDL_CreateTextureFromSurface(ren, sw); SDL_FreeSurface(sw); }
    }
    TTF_CloseFont(font);
    int usable = 0;
    for (int i = 0; i < 3; i++) if (tex_bright[i]) usable++;
    if (usable < 3) {
        for (int i = 0; i < 3; i++) {
            if (tex_dark[i]) SDL_DestroyTexture(tex_dark[i]);
            if (tex_bright[i]) SDL_DestroyTexture(tex_bright[i]);
            if (tex_white[i]) SDL_DestroyTexture(tex_white[i]);
        }
        return;
    }
    const double duration_ms = 2200.0;
    Uint32 start = SDL_GetTicks();
    SDL_Event ev;
    int center_y = H / 2;
    double total_glyph = gw[0] + gw[1] + gw[2];
    int skipped = 0;
    while (!skipped) {
        Uint32 elapsed = SDL_GetTicks() - start;
        if ((double)elapsed >= duration_ms) break;
        double progress = (double)elapsed / duration_ms;
        while (SDL_PollEvent(&ev)) {
            if (ev.type == SDL_QUIT || ev.type == SDL_KEYDOWN ||
                ev.type == SDL_JOYBUTTONDOWN || ev.type == SDL_JOYHATMOTION)
                { skipped = 1; break; }
        }
        if (skipped) break;
        double spacing = intro_spread(progress, k);
        double total = total_glyph + spacing * 2.0;
        double fit = 1.0;
        if (total > 0.0 && (W - 80) / total < fit) fit = (W - 80) / total;
        if (fit < 0.05) fit = 0.05;
        int cursor = (int)((W - total * fit) / 2.0);
        SDL_SetRenderDrawColor(ren, 8, 8, 12, 255);
        SDL_RenderClear(ren);
        for (int i = 0; i < 3; i++) {
            int dw = (int)(gw[i] * fit), dh = (int)(gh[i] * fit);
            int x = cursor + (int)((gw[i] * fit - dw) / 2.0);
            double enter_at = 0.05 + i * 0.16;
            double local = (progress - enter_at) / 0.30;
            if (local > 0.0) {
                if (local > 1.0) local = 1.0;
                int rise = (int)((1.0 - local) * 90.0 * k);
                if (local > 0.65) {
                    double sn = sin((local - 0.65) / 0.35 * 3.14159265358979323846);
                    rise += (int)(-14.0 * k * sn);
                }
                int y = center_y - dh / 2 + rise;
                SDL_Texture *tex = (local * 1.5 >= 0.75) ? tex_bright[i] : tex_dark[i];
                if (local * 1.5 >= 0.75 && tex_dark[i]) {
                    SDL_Rect glow = {x + (int)(4.0 * fit * k), y + (int)(6.0 * fit * k), dw, dh};
                    SDL_RenderCopy(ren, tex_dark[i], NULL, &glow);
                }
                SDL_Rect r = {x, y, dw, dh};
                SDL_RenderCopy(ren, tex, NULL, &r);
            }
            cursor += (int)((gw[i] + spacing) * fit);
        }
        if (progress > 0.72) {
            double sweep = (progress - 0.72) / 0.28;
            cursor = (int)((W - total * fit) / 2.0);
            for (int i = 0; i < 3; i++) {
                int dw = (int)(gw[i] * fit), dh = (int)(gh[i] * fit);
                double center = i / 2.0;
                if (tex_white[i] && fabs(sweep - center * 0.9) < 0.18) {
                    SDL_Rect r = {cursor + (int)((gw[i] * fit - dw) / 2.0), center_y - dh / 2, dw, dh};
                    SDL_RenderCopy(ren, tex_white[i], NULL, &r);
                }
                cursor += (int)((gw[i] + spacing) * fit);
            }
        }
        SDL_RenderPresent(ren);
        SDL_Delay(16);
    }
    for (int i = 0; i < 3; i++) {
        if (tex_dark[i]) SDL_DestroyTexture(tex_dark[i]);
        if (tex_bright[i]) SDL_DestroyTexture(tex_bright[i]);
        if (tex_white[i]) SDL_DestroyTexture(tex_white[i]);
    }
    while (SDL_PollEvent(&ev)) { /* xa het phim nhan trong intro */ }
}

static void draw_text(TTF_Font *f, const char *s, int cx, int y,
                      Uint8 r, Uint8 g, Uint8 b) {
    if (!s || !*s) return;
    SDL_Color c = {r, g, b, 255};
    SDL_Surface *sf = TTF_RenderUTF8_Blended(f, s, c);
    if (!sf) return;
    SDL_Texture *tx = SDL_CreateTextureFromSurface(ren, sf);
    if (tx) {
        SDL_Rect d = {cx - sf->w / 2, y, sf->w, sf->h};
        SDL_RenderCopy(ren, tx, NULL, &d);
        SDL_DestroyTexture(tx);
    }
    SDL_FreeSurface(sf);
}

static int text_w(TTF_Font *f, const char *s) {
    int w = 0;
    TTF_SizeUTF8(f, s, &w, NULL);
    return w;
}

/* Lay endpoint Internet: goi tunnel.sh endpoint (co the rong luc dau). */
static char ep_buf[256];
static Uint32 last_poll;
static const char *appdir;
static void poll_endpoint(int force) {
    Uint32 now = SDL_GetTicks();
    if (!force && now - last_poll < 2000) return;
    last_poll = now;
    if (ep_buf[0]) return; /* co roi thi thoi */
    char cmd[768];
    snprintf(cmd, sizeof(cmd), "sh \"%s/tunnel.sh\" endpoint 2>/dev/null", appdir);
    FILE *p = popen(cmd, "r");
    if (!p) return;
    if (fgets(ep_buf, sizeof(ep_buf), p)) {
        size_t n = strlen(ep_buf);
        while (n && (ep_buf[n-1] == '\n' || ep_buf[n-1] == '\r' || ep_buf[n-1] == ' '))
            ep_buf[--n] = 0;
    }
    pclose(p);
}

/* Trang thai OTA: ota-update.sh (chay nen khi mo app) ghi file .ota-status:
 * "checking" | "downloading <ver>" | "done <ver>" | "failed".
 * Hien 1 dong vang tren man hinh de khong "mu mo" khi co ban moi. */
static char ota_buf[96];
static Uint32 last_ota_poll;
static int vps_mode = 0;
static void read_mode_once(void) {
    static int done = 0;
    if (done) return;
    done = 1;
    char p[768];
    snprintf(p, sizeof(p), "%s/data/tunnel.conf", appdir);
    FILE *f = fopen(p, "r");
    if (!f) return;
    char line[128];
    while (fgets(line, sizeof(line), f)) {
        if (strncmp(line, "MODE=", 5) == 0) {
            if (strstr(line, "vps")) vps_mode = 1;
            break;
        }
    }
    fclose(f);
}
static void poll_ota(int force) {
    Uint32 now = SDL_GetTicks();
    if (!force && now - last_ota_poll < 2000) return;
    last_ota_poll = now;
    ota_buf[0] = 0;
    char p[768];
    snprintf(p, sizeof(p), "%s/.ota-status", appdir);
    FILE *f = fopen(p, "r");
    if (!f) return;
    char s[64];
    if (fgets(s, sizeof(s), f)) {
        size_t n = strlen(s);
        while (n && (s[n-1] == '\n' || s[n-1] == '\r' || s[n-1] == ' '))
            s[--n] = 0;
        if (strncmp(s, "done ", 5) == 0)
            snprintf(ota_buf, sizeof(ota_buf),
                     "Có bản mới %s - thoát app mở lại để dùng", s + 5);
        else if (strncmp(s, "downloading ", 12) == 0)
            snprintf(ota_buf, sizeof(ota_buf),
                     "Đang tải bản mới %s...", s + 12);
        else if (strcmp(s, "checking") == 0)
            snprintf(ota_buf, sizeof(ota_buf), "Đang kiểm tra bản mới...");
        /* failed -> giu im lang, tranh spam */
    }
    fclose(f);
}

int main(int argc, char **argv) {
    const char *lan_ip = (argc > 1 && argv[1][0]) ? argv[1] : "?";
    const char *ver = (argc > 2 && argv[2][0]) ? argv[2] : "";
    appdir = (argc > 3 && argv[3][0]) ? argv[3] : "/mnt/SDCARD/Apps/TrimuiRemote";
    snprintf(disp_recovery, sizeof(disp_recovery), "%s/data/display-restore.json", appdir);
    /* Crash lan truoc de man den: sang lai ngay de khong bi man den vinh vien. */
    if (access(disp_recovery, F_OK) == 0) {
        disp_saved_brightness = disp_read_saved();
        screen_on();
        /* screen_on chi tac dung khi disp_is_off; truong hop crash thi
         * brightness dang 0 ma flag da mat -> bat buoc set truc tiep. */
        disp_set(disp_saved_brightness > 0 ? disp_saved_brightness : 128);
        disp_clear_recovery();
        disp_saved_brightness = -1;
    }

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_JOYSTICK) != 0) return 1;
    if (TTF_Init() != 0) return 1;
    for (int i = 0; i < SDL_NumJoysticks(); i++)
        if (SDL_JoystickOpen(i)) break;

    SDL_DisplayMode dm;
    SDL_GetDesktopDisplayMode(0, &dm);
    W = dm.w > 0 ? dm.w : 1024;
    H = dm.h > 0 ? dm.h : 768;
    win = SDL_CreateWindow("Trimui Remote", 0, 0, W, H, SDL_WINDOW_FULLSCREEN_DESKTOP);
    if (!win) return 1;
    ren = SDL_CreateRenderer(win, -1, SDL_RENDERER_SOFTWARE);
    if (!ren) return 1;

    snprintf(fontpath, sizeof(fontpath), "%s/assets/font.ttf", appdir);
    play_intro(appdir);
    int sz_title = H / 11, sz_body = H / 19, sz_small = H / 26;
    if (sz_body < 20) sz_body = 20;
    f_title = TTF_OpenFont(fontpath, sz_title);
    f_body = TTF_OpenFont(fontpath, sz_body);
    f_small = TTF_OpenFont(fontpath, sz_small);
    if (!f_body) return 1;
    if (!f_title) f_title = f_body;
    if (!f_small) f_small = f_body;

    char title[64], lan[128];
    snprintf(title, sizeof(title), "TRIMUI REMOTE %s", ver);
    snprintf(lan, sizeof(lan), "ssh root@%s -p 2222", lan_ip);

    Uint32 confirm_at = 0;
    int confirm_what = 0; /* 1 = thoat man hinh, 2 = tat dich vu + thoat */
    int rc = 0;
    int running = 1;
    int pressed[16] = {0};
    read_mode_once();
    poll_endpoint(1);
    poll_ota(1);

    while (running) {
        SDL_Event e;
        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT) { screen_on(); running = 0; }
            else if (e.type == SDL_JOYBUTTONDOWN) {
                int b = (int)e.jbutton.button;
                if (b >= 0 && b < 16) pressed[b] = 1;
                /* Man dang tat: bat ky phim nao cung chi de sang lai. */
                if (disp_is_off) { screen_on(); confirm_at = 0; continue; }
                if (pressed[BTN_SELECT] && pressed[BTN_START]) { screen_on(); running = 0; }
                else if (b == BTN_Y) { screen_off(); confirm_at = 0; }
                else if (b == BTN_B || b == BTN_X) {
                    int what = (b == BTN_B) ? 1 : 2;
                    Uint32 now = SDL_GetTicks();
                    if (confirm_at && confirm_what == what && now - confirm_at < CONFIRM_MS) {
                        rc = (what == 2) ? 3 : 0;
                        screen_on();
                        running = 0;
                    } else { confirm_at = now; confirm_what = what; }
                }
            } else if (e.type == SDL_JOYBUTTONUP) {
                int b = (int)e.jbutton.button;
                if (b >= 0 && b < 16) pressed[b] = 0;
            } else if (e.type == SDL_KEYDOWN) {
                if (disp_is_off) { screen_on(); confirm_at = 0; continue; }
                int what = 0;
                if (e.key.keysym.sym == SDLK_ESCAPE) what = 1;
                else if (e.key.keysym.sym == SDLK_x) what = 2;
                else if (e.key.keysym.sym == SDLK_y) { screen_off(); confirm_at = 0; continue; }
                if (what) {
                    Uint32 now = SDL_GetTicks();
                    if (confirm_at && confirm_what == what && now - confirm_at < CONFIRM_MS) {
                        rc = (what == 2) ? 3 : 0;
                        screen_on();
                        running = 0;
                    } else { confirm_at = now; confirm_what = what; }
                }
            }
        }
        if (confirm_at && SDL_GetTicks() - confirm_at >= CONFIRM_MS) confirm_at = 0;
        /* Man tat: khong ve gi ca (den da 0), nghi dai de mat CPU/RAM. */
        if (disp_is_off) { poll_endpoint(0); poll_ota(0); SDL_Delay(100); continue; }
        poll_endpoint(0);
        poll_ota(0);

        SDL_SetRenderDrawColor(ren, 13, 17, 23, 255);
        SDL_RenderClear(ren);
        int y = H / 14;
        int lh = sz_body + sz_body / 3;
        draw_text(f_title, title, W / 2, y, 229, 9, 20); y += sz_title + lh;
        if (ota_buf[0]) {
            draw_text(f_small, ota_buf, W / 2, y, 255, 200, 60);
            y += sz_small + sz_small / 2;
        }
        draw_text(f_body, "SSH trong mạng LAN (cùng WiFi):", W / 2, y, 255, 255, 255); y += lh;
        draw_text(f_body, lan, W / 2, y, 63, 185, 80); y += lh;
        draw_text(f_body, "SSH qua Internet:", W / 2, y, 255, 255, 255); y += lh;
        if (vps_mode) {
            /* VPS: port co dinh, khong co tcp:// nhu Pinggy. */
            draw_text(f_body, "VPS OK: trên PC chạy: ssh trimui-brick", W / 2, y, 63, 185, 80); y += lh;
            draw_text(f_small, "(user root, không cần cùng mạng)", W / 2, y, 160, 160, 160); y += lh;
        } else if (ep_buf[0]) {
            char net[300];
            /* Pinggy: dia chi doi lien tuc. VPS: dung ssh trimui-brick tren PC. */
            if (strstr(ep_buf, "pinggy.io"))
                snprintf(net, sizeof(net), "ssh root@%s  (port thay đổi)", ep_buf + 6);
            else
                snprintf(net, sizeof(net), "%s", ep_buf);
            /* cat bot neu qua dai so voi man hinh */
            while (text_w(f_body, net) > W * 9 / 10 && strlen(net) > 12)
                memmove(net, net + 1, strlen(net));
            draw_text(f_body, net, W / 2, y, 63, 185, 80);
            y += lh;
            draw_text(f_small, "trên PC: ssh trimui-brick  (user root)", W / 2, y, 160, 160, 160); y += lh;
        } else {
            draw_text(f_body, "đang kết nối...", W / 2, y, 255, 200, 60); y += lh;
        }
        char auth[160];
        snprintf(auth, sizeof(auth), "User: root   Pass: mật khẩu root của máy");
        draw_text(f_body, auth, W / 2, y, 255, 255, 255); y += lh * 2;
        draw_text(f_small, "B: thoát màn hình (dịch vụ vẫn chạy)", W / 2, H - sz_small * 7, 140, 140, 140);
        draw_text(f_small, "Y: tắt màn hình (vẫn SSH, bấm phím bất kỳ để sáng)", W / 2, H - sz_small * 5, 140, 140, 140);
        draw_text(f_small, "X: TẮT dịch vụ + thoát", W / 2, H - sz_small * 3, 140, 140, 140);

        if (confirm_at) {
            SDL_SetRenderDrawBlendMode(ren, SDL_BLENDMODE_BLEND);
            SDL_SetRenderDrawColor(ren, 0, 0, 0, 160);
            SDL_Rect full = {0, 0, W, H};
            SDL_RenderFillRect(ren, &full);
            int bw = W * 4 / 5, bh = H / 4;
            SDL_Rect box = {W / 2 - bw / 2, H / 2 - bh / 2, bw, bh};
            SDL_SetRenderDrawColor(ren, 30, 34, 42, 255);
            SDL_RenderFillRect(ren, &box);
            SDL_SetRenderDrawColor(ren, 229, 9, 20, 255);
            SDL_RenderDrawRect(ren, &box);
            SDL_Rect box2 = {box.x + 3, box.y + 3, box.w - 6, box.h - 6};
            SDL_RenderDrawRect(ren, &box2);
            draw_text(f_body, confirm_what == 2 ? "BẤM X LẦN NỮA ĐỂ TẮT DỊCH VỤ" : "BẤM B LẦN NỮA ĐỂ THOÁT", W / 2, H / 2 - sz_body, 255, 255, 255);
        }
        SDL_RenderPresent(ren);
        SDL_Delay(33);
    }

    TTF_Quit();
    SDL_Quit();
    screen_on();
    return rc;
}
