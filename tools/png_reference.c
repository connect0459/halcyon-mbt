#include <png.h>
#include <setjmp.h>
#include <stdio.h>
#include <stdlib.h>

/* Decodes a PNG file with libpng into 8-bit RGBA and writes
   "<width> <height> <fnv1a32>" to stdout. Exits non-zero on any error. */

static uint32_t fnv1a32(const unsigned char *data, size_t length) {
  uint32_t hash = 2166136261u;
  for (size_t i = 0; i < length; i++) {
    hash ^= data[i];
    hash *= 16777619u;
  }
  return hash;
}

static void ignore_warning(png_structp png, png_const_charp message) {
  (void)png;
  (void)message;
}

int main(int argc, char **argv) {
  if (argc != 2) {
    fprintf(stderr, "usage: %s file.png\n", argv[0]);
    return 2;
  }
  FILE *file = fopen(argv[1], "rb");
  if (!file) {
    return 2;
  }
  png_structp png = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, ignore_warning);
  png_infop info = png_create_info_struct(png);
  unsigned char *pixels = NULL;
  png_bytep *rows = NULL;
  if (setjmp(png_jmpbuf(png))) {
    free(pixels);
    free(rows);
    fclose(file);
    return 1;
  }
  png_init_io(png, file);
  png_read_info(png, info);
  png_uint_32 width = png_get_image_width(png, info);
  png_uint_32 height = png_get_image_height(png, info);
  int color_type = png_get_color_type(png, info);
  int bit_depth = png_get_bit_depth(png, info);

  png_set_expand(png);
  if (bit_depth == 16) {
    png_set_scale_16(png);
  }
  if (color_type == PNG_COLOR_TYPE_GRAY || color_type == PNG_COLOR_TYPE_GRAY_ALPHA) {
    png_set_gray_to_rgb(png);
  }
  png_set_add_alpha(png, 0xFF, PNG_FILLER_AFTER);
  png_set_interlace_handling(png);
  png_read_update_info(png, info);

  pixels = malloc((size_t)width * height * 4);
  rows = malloc(sizeof(png_bytep) * height);
  for (png_uint_32 y = 0; y < height; y++) {
    rows[y] = pixels + (size_t)y * width * 4;
  }
  png_read_image(png, rows);
  png_read_end(png, NULL);
  printf("%u %u %u\n", width, height, fnv1a32(pixels, (size_t)width * height * 4));
  free(pixels);
  free(rows);
  fclose(file);
  png_destroy_read_struct(&png, &info, NULL);
  return 0;
}
