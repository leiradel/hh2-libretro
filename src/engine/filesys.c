#include "filesys.h"
#include "log.h"
#include "djb2.h"

#include <inttypes.h>
#include <limits.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#define TAG "RIF "

/*
File structure (all integers are little-endian):

* Header
    1. "RIFF"
    2. uint32_t with the file size - 8
    3. "HH2 "
* Entries:
    1. "LIST"
    2. uint32_t with the chunk size - 8
    3. "path"
    4. uint32_t with the chunk size - 8
    5. Path, including the nul terminator
    6. "data"
    7. uint32_t with the chink size - 8
    8 Data
*/

typedef struct {
    char const* path;
    uint8_t const* data;
    long size;
    hh2_Djb2Hash hash;
}
hh2_Entry;

struct hh2_Filesys {
    uint8_t const* data;
    size_t size;
    unsigned num_entries;
    hh2_Entry entries[1];
};

struct hh2_File {
    uint8_t const* data;
    size_t size;
    size_t pos;
};

static void hh2_formatU8(uint8_t const u8, char string[static 5]) {
    // We don't want to use isprint to avoid issues with porting to baremetal
    // WARN(leiradel): ASCII only code
    int i = 0;

    if (u8 >= 32 && u8 < 127) {
        string[i++] = u8;
    }
    else {
        string[i++] = '\\';
        string[i++] = '0' + (u8 / 64);
        string[i++] = '0' + ((u8 / 8) % 8);
        string[i++] = '0' + (u8 % 8);
    }

    string[i] = 0;
}

static size_t hh2_chunkSize(uint8_t const* const data, size_t const size) {
    if (size < 8) {
        return 0;
    }

    return data[4] | (uint32_t)data[5] << 8 | (uint32_t)data[6] << 16 | (uint32_t)data[7] << 24;
}

static size_t hh2_paddedSize(size_t const size) {
    return size + (size & 1);
}

static size_t hh2_validateHeader(uint8_t const* const data, size_t const size, char const* const id) {
    if (strlen(id) != 4) {
        HH2_LOG(HH2_LOG_ERROR, TAG "invalid chunk id '%s' passed to %s", id, __func__);
        return 0;
    }

    if (size <= 8) {
        HH2_LOG(HH2_LOG_ERROR, TAG "chunk '%s' undersized, should be at least 8 plus subchunks, got %zu", id, size);
        return 0;
    }

    if (data[0] != id[0] || data[1] != id[1] || data[2] != id[2] || data[3] != id[3]) {
        char d0[5], d1[5], d2[5], d3[5];
        hh2_formatU8(data[0], d0);
        hh2_formatU8(data[1], d1);
        hh2_formatU8(data[2], d2);
        hh2_formatU8(data[3], d3);

        HH2_LOG(HH2_LOG_ERROR, TAG "invalid chunk id, wanted '%s', got '%s%s%s%s'", id, d0, d1, d2, d3);
        return 0;
    }

    size_t const chunk_size = hh2_chunkSize(data, size);

    if (chunk_size + 8 > size) {
        HH2_LOG(HH2_LOG_ERROR, TAG "invalid chunk '%s', size %" PRIu32 " is bigger than available %zu", chunk_size + 8, size);
        return 0;
    }

    return chunk_size + 8;
}

static size_t hh2_validatePath(uint8_t const* const data, size_t const size) {
    size_t const chunk_size = hh2_validateHeader(data, size, "path");

    if (chunk_size == 0) {
        return 0;
    }

    uint8_t const* const path = data + 8;

    if (path[chunk_size - 8 - 1] != 0) {
        char nul[5];
        hh2_formatU8(path[chunk_size - 8], nul);

        HH2_LOG(HH2_LOG_ERROR, TAG "invalid path chunk, path must end with a nul terminator buts ends with '%s'", nul);
        return 0;
    }

    return chunk_size;
}

static size_t hh2_validateData(uint8_t const* const data, size_t const size) {
    size_t const chunk_size = hh2_validateHeader(data, size, "data");

    if (chunk_size > LONG_MAX) {
        HH2_LOG(HH2_LOG_ERROR, TAG "invalid data chunk, size %u" PRIu32 " does not fit in a long");
        return 0;
    }

    return chunk_size;
}

static size_t hh2_validateList(uint8_t const* const data, size_t const size) {
    size_t const chunk_size = hh2_validateHeader(data, size, "LIST");

    if (chunk_size == 0) {
        return 0;
    }

    uint8_t const* const path = data + 8;
    size_t const path_size = hh2_validatePath(path, chunk_size);

    if (path_size == 0) {
        return 0;
    }

    uint8_t const* const contents = path + hh2_paddedSize(path_size);
    size_t const contents_size = hh2_validateData(contents, chunk_size);

    if (contents_size == 0) {
        return false;
    }

    return chunk_size;
}

static unsigned hh2_validateRiff(uint8_t const* const data, size_t const size) {
    size_t const chunk_size = hh2_validateHeader(data, size, "RIFF");

    if (chunk_size == 0) {
        return 0;
    }

    if (data[8] != 'H' || data[9] != 'H' || data[10] != '2' || data[11] != ' ') {
        char d0[5], d1[5], d2[5], d3[5];
        hh2_formatU8(data[0], d0);
        hh2_formatU8(data[1], d1);
        hh2_formatU8(data[2], d2);
        hh2_formatU8(data[3], d3);

        HH2_LOG(HH2_LOG_ERROR, TAG "invalid RIFF type, wanted 'HH2 ', got '%s%s%s%s'", d0, d1, d2, d3);
        return 0;
    }

    uint8_t const* list = data + 12;
    uint8_t const* const end = data + size;
    unsigned num_entries = 0;

    while (list < end) {
        size_t const list_size = hh2_validateList(list, size);

        if (list_size == 0) {
            return 0;
        }

        list += hh2_paddedSize(list_size);
        num_entries++;
    }

    if (list != end) {
        HH2_LOG(HH2_LOG_ERROR, TAG "corrupted RIFF, last chunk is incomplete");
        return 0;
    }

    if (num_entries == 0) {
        HH2_LOG(HH2_LOG_ERROR, TAG "invalid RIFF, no entries found");
        return 0;
    }

    return num_entries;
}

static void hh2_collectEntries(hh2_Filesys filesys) {
    uint8_t const* list = filesys->data + 12;
    unsigned const num_entries = filesys->num_entries;
    size_t const size = filesys->size;

    for (unsigned i = 0; i < num_entries; i++) {
        size_t const list_size = hh2_chunkSize(list, size);

        uint8_t const* const path = list + 8;
        filesys->entries[i].path = (char const*)(path + 8);
        filesys->entries[i].hash = hh2_djb2(filesys->entries[i].path);

        HH2_LOG(
            HH2_LOG_INFO,
            TAG "entry %u at %p with hash " HH2_PRI_DJB2HASH ": \"%s\"",
            i, list, filesys->entries[i].hash, filesys->entries[i].path
        );

        size_t const path_size = hh2_chunkSize(path, list_size) + 8;
        uint8_t const* const data = path + hh2_paddedSize(path_size);
        uint32_t const data_size = hh2_chunkSize(data, list_size);

        if (data_size == 0) {
            HH2_LOG(HH2_LOG_WARN, TAG "entry %u has no data", i);
        }

        filesys->entries[i].data = data + 8;
        filesys->entries[i].size = data_size;

        list += hh2_paddedSize(list_size) + 8;
    }
}

static int hh2_compareEntries(void const* ptr1, void const* ptr2) {
    hh2_Entry const* const entry1 = ptr1;
    hh2_Entry const* const entry2 = ptr2;

    hh2_Djb2Hash const hash1 = entry1->hash;
    hh2_Djb2Hash const hash2 = entry2->hash;

    if (hash1 < hash2) {
        return -1;
    }
    else if (hash1 > hash2) {
        return 1;
    }

    char const* path1 = entry1->path;
    char const* path2 = entry2->path;

    // TODO(leiradel): remove strcmp and use a NIH implementation
    return strcmp(path1, path2);
}

static hh2_Entry* hh2_fileFind(hh2_Filesys filesys, char const* path) {
    hh2_Entry key;
    key.path = path;
    key.hash = hh2_djb2(path);

    // TODO(leiradel): remove bsearch and use a NIH implementation
    hh2_Entry* found = bsearch(&key, filesys->entries, filesys->num_entries, sizeof(filesys->entries[0]), hh2_compareEntries);

    if (found == NULL) {
        HH2_LOG(HH2_LOG_INFO, TAG "file system %p does not contain path \"%s\"", filesys, path);
    }
    else {
        HH2_LOG(
            HH2_LOG_INFO, TAG "file system %p does contain path \"%s\", data=%p, size=%ld, hash=" HH2_PRI_DJB2HASH,
            filesys, path, found->data, found->size, found->hash
        );
    }

    return found;
}

hh2_Filesys hh2_createFilesystem(void const* const buffer, size_t const size) {
    HH2_LOG(HH2_LOG_INFO, TAG "creating filesystem from buffer %p with size %zu", buffer, size);

    // Validate structure
    unsigned const num_entries = hh2_validateRiff(buffer, size);

    if (num_entries == 0) {
        // Error already logged
        return NULL;
    }

    HH2_LOG(HH2_LOG_DEBUG, TAG "RIFF file has %u entries", num_entries);
    hh2_Filesys const filesys = malloc(sizeof(*filesys) + sizeof(filesys->entries[0]) * (num_entries - 1));

    if (filesys == NULL) {
        HH2_LOG(HH2_LOG_ERROR, TAG "out of memory");
        return NULL;
    }

    filesys->data = buffer;
    filesys->size = size;
    filesys->num_entries = num_entries;

    hh2_collectEntries(filesys);

    // TODO(leiradel): remove qsort and use a NIH implementation
    qsort(filesys->entries, filesys->num_entries, sizeof(filesys->entries[0]), hh2_compareEntries);
    HH2_LOG(HH2_LOG_DEBUG, TAG "created file system %p", filesys);
    return filesys;
}

void hh2_destroyFilesystem(hh2_Filesys filesys) {
    HH2_LOG(HH2_LOG_INFO, TAG "destroying file system %p", filesys);
    free(filesys);
}

bool hh2_fileExists(hh2_Filesys filesys, char const* path) {
    hh2_Entry const* const found = hh2_fileFind(filesys, path);
    return found != NULL;
}

long hh2_fileSize(hh2_Filesys filesys, char const* path) {
    hh2_Entry const* const found = hh2_fileFind(filesys, path);

    if (found == NULL) {
        return -1;
    }

    return found->size;
}

hh2_File hh2_openFile(hh2_Filesys filesys, char const* path) {
    HH2_LOG(HH2_LOG_INFO, TAG "opening \"%s\" in file system %p", path, filesys);

    hh2_Entry const* const found = hh2_fileFind(filesys, path);

    if (found == NULL) {
        return NULL;
    }

    hh2_File file = malloc(sizeof(*file));

    if (file == NULL) {
        HH2_LOG(HH2_LOG_ERROR, TAG "out of memory");
        return NULL;
    }

    file->data = found->data;
    file->size = found->size;
    file->pos = 0;

    HH2_LOG(HH2_LOG_DEBUG, TAG "opened \"%s\" in file system %p as %p", path, filesys, file);
    return file;
}

int hh2_seek(hh2_File file, long offset, int whence) {
    HH2_LOG(HH2_LOG_INFO, TAG "seeking file %p to %ld based off %d", file, offset, whence);

    long pos = 0;

    switch (whence) {
        case SEEK_SET: pos = offset; break;
        case SEEK_CUR: pos = file->pos + offset; break;
        case SEEK_END: pos = file->size - offset; break;

        default: {
            HH2_LOG(HH2_LOG_ERROR, TAG "invalid base for seek: %d", whence);
            return -1;
        }
    }

    if (pos < 0 || pos > file->size) {
        HH2_LOG(HH2_LOG_ERROR, TAG "invalid position to seek to: %ld", pos);
        return -1;
    }

    file->pos = pos;
    return 0;
}

long hh2_tell(hh2_File file) {
    HH2_LOG(HH2_LOG_INFO, TAG "returning current position %ld for file %p", file->pos, file);
    return file->pos;
}

size_t hh2_read(hh2_File file, void* buffer, size_t size) {
    HH2_LOG(HH2_LOG_INFO, TAG "reading from file %p to %p, %zu bytes", file, buffer, size);

    size_t const available = file->size - file->pos;
    size_t const toread = size < available ? size : available;

    memcpy(buffer, file->data + file->pos, toread);
    file->pos += toread;

    HH2_LOG(HH2_LOG_DEBUG, TAG "read from file %p to %p, %zu bytes", file, buffer, toread);
    return toread;
}

void hh2_close(hh2_File file) {
    HH2_LOG(HH2_LOG_INFO, TAG "closing file %p", file);
    free(file);
}
