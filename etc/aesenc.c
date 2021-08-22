#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include <sys/stat.h>
#include <aes.h>

static void const* readAll(char const* const path, size_t* const size) {
    struct stat statbuf;

    if (stat(path, &statbuf) != 0) {
        fprintf(stderr, "Error getting file info: %s\n", strerror(errno));
        return NULL;
    }

    void* const data = malloc(statbuf.st_size);

    if (data == NULL) {
        fprintf(stderr, "Out of memory allocating %zu bytes\n", statbuf.st_size);
        return NULL;
    }

    FILE* file = fopen(path, "rb");

    if (file == NULL) {
        fprintf(stderr, "Error opening file: %s\n", strerror(errno));
        free(data);
        return NULL;
    }

    size_t numread = fread(data, 1, statbuf.st_size, file);

    if (numread != (size_t)statbuf.st_size) {
        fprintf(stderr, "Error reading file: %s\n", strerror(errno));
        fclose(file);
        free(data);
        return NULL;
    }

    fclose(file);
    *size = numread;
    return data;
}

static int writeAll(char const* const path, void const* const data, size_t const size) {
    FILE* file = fopen(path, "wb");

    if (file == NULL) {
        fprintf(stderr, "Error opening file: %s\n", strerror(errno));
        return -1;
    }

    size_t numwritten = fwrite(data, 1, size, file);

    if (numwritten != size) {
        fprintf(stderr, "Error writing file: %s\n", strerror(errno));
        fclose(file);
        return -1;
    }

    fclose(file);
    return 0;
}

int main(int argc, char const* const argv[]) {
    if (argc < 3) {
        fprintf(stderr, "USAGE: aesenc <key> <infile> <outfile>\n");
        return EXIT_FAILURE;
    }

    if (strlen(argv[1]) != 32) {
        fprintf(stderr, "Error, key must have 32 characters\n");
        return EXIT_FAILURE;
    }

    size_t size = 0;
    void const* const data = readAll(argv[2], &size);

    if (data == NULL) {
        return EXIT_FAILURE;
    }

    void* const encrypted = malloc(size);

    if (encrypted == NULL) {
        fprintf(stderr, "Out of memory allocating %zu bytes\n", size);
        return EXIT_FAILURE;
    }

    static uint8_t const iv[] = {0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f};

    uint32_t key_schedule[60];
    aes_key_setup(argv[1], key_schedule, 256);
    aes_decrypt_ctr((uint8_t const*)data, size, (uint8_t*)encrypted, key_schedule, 256, iv);

    if (writeAll(argv[3], encrypted, size) != 0) {
        free((void*)data);
        return EXIT_FAILURE;
    }

    free((void*)data);
    return EXIT_SUCCESS;
}
