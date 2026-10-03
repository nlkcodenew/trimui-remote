/* remote-ui: man hinh thong tin SSH cho TrimUI Brick Pro / Smart Pro S.
 * - Chu TO theo pixel that (bai hoc Xiaozhi: khong dung logical size co dinh).
 * - Nut B (joystick button 0) lan 1: hien panel xac nhan TO giua man hinh.
 *   Nut B lan 2 trong 4s: thoat. Thoat man hinh KHONG tat dich vu nen.
 * - Du phong: SELECT(8)+START(9) cung luc = thoat ngay; ESC tren ban phim cung vay.
 * - Endpoint Internet (VPS co dinh / Pinggy) duoc poll tu tunnel.sh moi 2s.
 * Build (CI): aarch64-linux-gnu-gcc -Os -o remote-ui remote-ui.c -lSDL2 -lSDL2_ttf
 */
#include <SDL2/SDL.h>
#include <SDL2/SDL_ttf.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define BTN_B 0
#define BTN_X 3
#define BTN_SELECT 8
#define BTN_START 9
#define CONFIRM_MS 4000

static SDL_Window *win;
static SDL_Renderer *ren;
static TTF_Font *f_title, *f_body, *f_small;
static int W, H;

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

int main(int argc, char **argv) {
    const char *lan_ip = (argc > 1 && argv[1][0]) ? argv[1] : "?";
    const char *ver = (argc > 2 && argv[2][0]) ? argv[2] : "";
    appdir = (argc > 3 && argv[3][0]) ? argv[3] : "/mnt/SDCARD/Apps/TrimuiRemote";

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

    char fontpath[768];
    snprintf(fontpath, sizeof(fontpath), "%s/assets/font.ttf", appdir);
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
    poll_endpoint(1);

    while (running) {
        SDL_Event e;
        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT) running = 0;
            else if (e.type == SDL_JOYBUTTONDOWN) {
                int b = (int)e.jbutton.button;
                if (b >= 0 && b < 16) pressed[b] = 1;
                if (pressed[BTN_SELECT] && pressed[BTN_START]) running = 0;
                else if (b == BTN_B || b == BTN_X) {
                    int what = (b == BTN_B) ? 1 : 2;
                    Uint32 now = SDL_GetTicks();
                    if (confirm_at && confirm_what == what && now - confirm_at < CONFIRM_MS) {
                        rc = (what == 2) ? 3 : 0;
                        running = 0;
                    } else { confirm_at = now; confirm_what = what; }
                }
            } else if (e.type == SDL_JOYBUTTONUP) {
                int b = (int)e.jbutton.button;
                if (b >= 0 && b < 16) pressed[b] = 0;
            } else if (e.type == SDL_KEYDOWN) {
                int what = 0;
                if (e.key.keysym.sym == SDLK_ESCAPE) what = 1;
                else if (e.key.keysym.sym == SDLK_x) what = 2;
                if (what) {
                    Uint32 now = SDL_GetTicks();
                    if (confirm_at && confirm_what == what && now - confirm_at < CONFIRM_MS) {
                        rc = (what == 2) ? 3 : 0;
                        running = 0;
                    } else { confirm_at = now; confirm_what = what; }
                }
            }
        }
        if (confirm_at && SDL_GetTicks() - confirm_at >= CONFIRM_MS) confirm_at = 0;
        poll_endpoint(0);

        SDL_SetRenderDrawColor(ren, 13, 17, 23, 255);
        SDL_RenderClear(ren);
        int y = H / 14;
        int lh = sz_body + sz_body / 3;
        draw_text(f_title, title, W / 2, y, 229, 9, 20); y += sz_title + lh;
        draw_text(f_body, "SSH trong mang LAN (cung WiFi):", W / 2, y, 255, 255, 255); y += lh;
        draw_text(f_body, lan, W / 2, y, 63, 185, 80); y += lh;
        draw_text(f_body, "SSH qua Internet:", W / 2, y, 255, 255, 255); y += lh;
        if (ep_buf[0]) {
            char net[300];
            /* Pinggy: dia chi doi lien tuc. VPS: dung ssh trimui-brick tren PC. */
            if (strstr(ep_buf, "pinggy.io"))
                snprintf(net, sizeof(net), "ssh root@%s  (port thay doi)", ep_buf + 6);
            else
                snprintf(net, sizeof(net), "%s", ep_buf);
            /* cat bot neu qua dai so voi man hinh */
            while (text_w(f_body, net) > W * 9 / 10 && strlen(net) > 12)
                memmove(net, net + 1, strlen(net));
            draw_text(f_body, net, W / 2, y, 63, 185, 80);
            y += lh;
            draw_text(f_small, "tren PC: ssh trimui-brick  (user root)", W / 2, y, 160, 160, 160); y += lh;
        } else {
            draw_text(f_body, "dang ket noi...", W / 2, y, 255, 200, 60); y += lh;
        }
        char auth[160];
        snprintf(auth, sizeof(auth), "User: root   Pass: mat khau root cua may");
        draw_text(f_body, auth, W / 2, y, 255, 255, 255); y += lh * 2;
        draw_text(f_small, "B: thoat man hinh (dich vu van chay)  |  X: TAT dich vu + thoat", W / 2, H - sz_small * 3, 140, 140, 140);

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
            draw_text(f_body, confirm_what == 2 ? "BAM X LAN NUA DE TAT DICH VU" : "BAM B LAN NUA DE THOAT", W / 2, H / 2 - sz_body, 255, 255, 255);
        }
        SDL_RenderPresent(ren);
        SDL_Delay(33);
    }

    TTF_Quit();
    SDL_Quit();
    return rc;
}
