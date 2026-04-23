#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>

#include <SDL2/SDL.h>

#define SCREEN_WIDTH 640
#define SCREEN_HEIGHT 480
static SDL_Window *sdl_window = NULL;
static SDL_Renderer *sdl_renderer = NULL;

typedef struct {
  uint8_t r;
  uint8_t g;
  uint8_t b;
} color_t;

static color_t current_color;
static color_t buffer[SCREEN_WIDTH][SCREEN_HEIGHT];

static color_t white = {.r=255, .g=255, .b=255};
static color_t black = {.r=0, .g=0, .b=0};

void clear_graph() {
  for (int i=0; i < SCREEN_WIDTH; i++) for (int j=0; j < SCREEN_HEIGHT; j++) buffer[i][j] = white;
  for (int i=0; i < SCREEN_WIDTH; i++) buffer[i][SCREEN_HEIGHT/2] = current_color;
  for (int j=0; j < SCREEN_HEIGHT; j++) buffer[SCREEN_WIDTH/2][j] = current_color;
  current_color = black;
}

static void init_graph() {
  SDL_SetHint(SDL_HINT_NO_SIGNAL_HANDLERS, "1");
  sdl_window = SDL_CreateWindow(
      "graph",
      SDL_WINDOWPOS_CENTERED,
      SDL_WINDOWPOS_CENTERED,
      SCREEN_WIDTH,
      SCREEN_HEIGHT,
      0
  );

  sdl_renderer = SDL_CreateRenderer(sdl_window, -1, SDL_RENDERER_ACCELERATED);

  clear_graph();
}

void render_graph() {
  if (!sdl_window) init_graph();
  for (int i=0; i < SCREEN_WIDTH; i++) {
    for (int j=0; j < SCREEN_HEIGHT; j++) {
      color_t color = buffer[i][j];

      SDL_SetRenderDrawColor(sdl_renderer, color.r, color.g, color.b, 255);
      SDL_RenderDrawPoint(sdl_renderer, i, j);
    }
  }

  SDL_RenderPresent(sdl_renderer);
}

void color_graph(uint8_t r, uint8_t g, uint8_t b) {
  current_color.r = r;
  current_color.g = g;
  current_color.b = b;
}

// `x` and `y` must be between -scale and scale
void draw_graph(int x, int y, int scale_x, int scale_y) {
  int i = (1+(double)(x)/scale_x) * SCREEN_WIDTH * 0.5;
  int j = (1-(double)(y)/scale_y) * SCREEN_HEIGHT * 0.5;

  for (int u=-1; u<=1; u++)
    for (int v=-1; v<=1; v++)
      if (i+u >= 0 && i+u < SCREEN_WIDTH && j+v >= 0 && j+v < SCREEN_HEIGHT)
        buffer[i+u][j+v] = current_color;
}
