#include <setjmp.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <jpeglib.h>

/* Decodes a JPEG file with libjpeg(-turbo) into 8-bit RGBA using the accurate
   integer DCT and fancy upsampling, and writes "<width> <height> <fnv1a32>" to
   stdout. Exits non-zero on any error or warning. */

struct failure {
  struct jpeg_error_mgr base;
  jmp_buf jump;
};

static void on_error(j_common_ptr cinfo) {
  longjmp(((struct failure *)cinfo->err)->jump, 1);
}

static void on_message(j_common_ptr cinfo, int level) {
  if (level < 0) {
    longjmp(((struct failure *)cinfo->err)->jump, 1);
  }
}

static uint32_t fnv1a32(const unsigned char *data, size_t length) {
  uint32_t hash = 2166136261u;
  for (size_t i = 0; i < length; i++) {
    hash ^= data[i];
    hash *= 16777619u;
  }
  return hash;
}

int main(int argc, char **argv) {
  if (argc != 2) {
    fprintf(stderr, "usage: %s file.jpg\n", argv[0]);
    return 2;
  }
  FILE *file = fopen(argv[1], "rb");
  if (!file) {
    return 2;
  }
  struct jpeg_decompress_struct cinfo;
  struct failure err;
  unsigned char *pixels = NULL;
  cinfo.err = jpeg_std_error(&err.base);
  err.base.error_exit = on_error;
  err.base.emit_message = on_message;
  if (setjmp(err.jump)) {
    jpeg_destroy_decompress(&cinfo);
    free(pixels);
    fclose(file);
    return 1;
  }
  jpeg_create_decompress(&cinfo);
  jpeg_stdio_src(&cinfo, file);
  jpeg_read_header(&cinfo, TRUE);
  cinfo.dct_method = JDCT_ISLOW;
  cinfo.do_fancy_upsampling = TRUE;
  cinfo.do_block_smoothing = FALSE;
  cinfo.out_color_space = JCS_EXT_RGBA;
  jpeg_start_decompress(&cinfo);
  size_t stride = (size_t)cinfo.output_width * 4;
  pixels = malloc(stride * cinfo.output_height);
  while (cinfo.output_scanline < cinfo.output_height) {
    unsigned char *row = pixels + stride * cinfo.output_scanline;
    jpeg_read_scanlines(&cinfo, &row, 1);
  }
  jpeg_finish_decompress(&cinfo);
  printf("%u %u %u\n", cinfo.output_width, cinfo.output_height,
         fnv1a32(pixels, stride * cinfo.output_height));
  jpeg_destroy_decompress(&cinfo);
  free(pixels);
  fclose(file);
  return 0;
}
