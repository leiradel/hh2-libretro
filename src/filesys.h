#ifndef HH2_FILESYS_H__
#define HH2_FILESYS_H__

#include <stddef.h>
#include <stdbool.h>

typedef struct hh2_Filesys* hh2_Filesys;
typedef struct hh2_File* hh2_File;

// hh2_filesystemCreate does **not** take ownership of buffer
hh2_Filesys hh2_filesystemCreate(void const* buffer, size_t size);
void hh2_filesystemDestroy(hh2_Filesys filesys);

bool hh2_fileExists(hh2_Filesys filesys, char const* path);
long hh2_fileSize(hh2_Filesys filesys, char const* path);
hh2_File hh2_fileOpen(hh2_Filesys filesys, char const* path);
int hh2_fileSeek(hh2_File file, long offset, int whence);
long hh2_fileTell(hh2_File file);
size_t hh2_fileRead(hh2_File file, void* buffer, size_t size);
void hh2_fileClose(hh2_File file);

#endif // HH2_FILESYS_H__
