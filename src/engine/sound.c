#include "sound.h"
#include "filesys.h"
#include "log.h"

#define DR_WAV_IMPLEMENTATION
#include <dr_wav.h>

#define HH2_SAMPLES_PER_VIDEO_FRAME 735 // 44,100 Hz / 60 Hz
#define HH2_MAX_CHANNELS 8

#define TAG "SND "

typedef int16_t hh2_Sample;

// Image blit is coded for 16 bpp, make sure the build fails if hh2_RGB565 does not have 16 bits
typedef char hh2_staticAssertSoundSampleMustBeInt16[sizeof(hh2_Sample) == sizeof(int16_t) ? 1 : -1];

struct hh2_Pcm {
    size_t sample_count;
    hh2_Sample samples[1];
};

typedef struct {
    hh2_Pcm pcm;
    size_t position;
}
hh2_Voice;

static int16_t hh2_audioFrames[HH2_SAMPLES_PER_VIDEO_FRAME * 2];
static hh2_Voice hh2_voice = {NULL, 0};

static size_t hh2_wavRead(void* const userdata, void* const buffer, size_t const count) {
    hh2_File const file = (hh2_File)userdata;
    return hh2_read(file, buffer, count);
}

static drwav_bool32 hh2_wavSeek(void* const userdata, int const offset, drwav_seek_origin const origin) {
    hh2_File const file = (hh2_File)userdata;
    return hh2_seek(file, offset, origin == drwav_seek_origin_start ? SEEK_SET : SEEK_CUR) == 0;
}

static char const* hh2_wavError(drwav_result const error) {
    switch (error) {
        case DRWAV_SUCCESS: return "DRWAV_SUCCESS";
        case DRWAV_ERROR: return "DRWAV_ERROR";
        case DRWAV_INVALID_ARGS: return "DRWAV_INVALID_ARGS";
        case DRWAV_INVALID_OPERATION: return "DRWAV_INVALID_OPERATION";
        case DRWAV_OUT_OF_MEMORY: return "DRWAV_OUT_OF_MEMORY";
        case DRWAV_OUT_OF_RANGE: return "DRWAV_OUT_OF_RANGE";
        case DRWAV_ACCESS_DENIED: return "DRWAV_ACCESS_DENIED";
        case DRWAV_DOES_NOT_EXIST: return "DRWAV_DOES_NOT_EXIST";
        case DRWAV_ALREADY_EXISTS: return "DRWAV_ALREADY_EXISTS";
        case DRWAV_TOO_MANY_OPEN_FILES: return "DRWAV_TOO_MANY_OPEN_FILES";
        case DRWAV_INVALID_FILE: return "DRWAV_INVALID_FILE";
        case DRWAV_TOO_BIG: return "DRWAV_TOO_BIG";
        case DRWAV_PATH_TOO_LONG: return "DRWAV_PATH_TOO_LONG";
        case DRWAV_NAME_TOO_LONG: return "DRWAV_NAME_TOO_LONG";
        case DRWAV_NOT_DIRECTORY: return "DRWAV_NOT_DIRECTORY";
        case DRWAV_IS_DIRECTORY: return "DRWAV_IS_DIRECTORY";
        case DRWAV_DIRECTORY_NOT_EMPTY: return "DRWAV_DIRECTORY_NOT_EMPTY";
        case DRWAV_END_OF_FILE: return "DRWAV_END_OF_FILE";
        case DRWAV_NO_SPACE: return "DRWAV_NO_SPACE";
        case DRWAV_BUSY: return "DRWAV_BUSY";
        case DRWAV_IO_ERROR: return "DRWAV_IO_ERROR";
        case DRWAV_INTERRUPT: return "DRWAV_INTERRUPT";
        case DRWAV_UNAVAILABLE: return "DRWAV_UNAVAILABLE";
        case DRWAV_ALREADY_IN_USE: return "DRWAV_ALREADY_IN_USE";
        case DRWAV_BAD_ADDRESS: return "DRWAV_BAD_ADDRESS";
        case DRWAV_BAD_SEEK: return "DRWAV_BAD_SEEK";
        case DRWAV_BAD_PIPE: return "DRWAV_BAD_PIPE";
        case DRWAV_DEADLOCK: return "DRWAV_DEADLOCK";
        case DRWAV_TOO_MANY_LINKS: return "DRWAV_TOO_MANY_LINKS";
        case DRWAV_NOT_IMPLEMENTED: return "DRWAV_NOT_IMPLEMENTED";
        case DRWAV_NO_MESSAGE: return "DRWAV_NO_MESSAGE";
        case DRWAV_BAD_MESSAGE: return "DRWAV_BAD_MESSAGE";
        case DRWAV_NO_DATA_AVAILABLE: return "DRWAV_NO_DATA_AVAILABLE";
        case DRWAV_INVALID_DATA: return "DRWAV_INVALID_DATA";
        case DRWAV_TIMEOUT: return "DRWAV_TIMEOUT";
        case DRWAV_NO_NETWORK: return "DRWAV_NO_NETWORK";
        case DRWAV_NOT_UNIQUE: return "DRWAV_NOT_UNIQUE";
        case DRWAV_NOT_SOCKET: return "DRWAV_NOT_SOCKET";
        case DRWAV_NO_ADDRESS: return "DRWAV_NO_ADDRESS";
        case DRWAV_BAD_PROTOCOL: return "DRWAV_BAD_PROTOCOL";
        case DRWAV_PROTOCOL_UNAVAILABLE: return "DRWAV_PROTOCOL_UNAVAILABLE";
        case DRWAV_PROTOCOL_NOT_SUPPORTED: return "DRWAV_PROTOCOL_NOT_SUPPORTED";
        case DRWAV_PROTOCOL_FAMILY_NOT_SUPPORTED: return "DRWAV_PROTOCOL_FAMILY_NOT_SUPPORTED";
        case DRWAV_ADDRESS_FAMILY_NOT_SUPPORTED: return "DRWAV_ADDRESS_FAMILY_NOT_SUPPORTED";
        case DRWAV_SOCKET_NOT_SUPPORTED: return "DRWAV_SOCKET_NOT_SUPPORTED";
        case DRWAV_CONNECTION_RESET: return "DRWAV_CONNECTION_RESET";
        case DRWAV_ALREADY_CONNECTED: return "DRWAV_ALREADY_CONNECTED";
        case DRWAV_NOT_CONNECTED: return "DRWAV_NOT_CONNECTED";
        case DRWAV_CONNECTION_REFUSED: return "DRWAV_CONNECTION_REFUSED";
        case DRWAV_NO_HOST: return "DRWAV_NO_HOST";
        case DRWAV_IN_PROGRESS: return "DRWAV_IN_PROGRESS";
        case DRWAV_CANCELLED: return "DRWAV_CANCELLED";
        case DRWAV_MEMORY_ALREADY_MAPPED: return "DRWAV_MEMORY_ALREADY_MAPPED";
        case DRWAV_AT_END: return "DRWAV_AT_END";
        default: return "unknown drwav error";
    }
}

hh2_Pcm hh2_readPcm(hh2_Filesys filesys, char const* path) {
    HH2_LOG(HH2_LOG_INFO, TAG "creating PCM \"%s\" from filesys %p", path, filesys);

    hh2_File const file = hh2_openFile(filesys, path);

    if (file == NULL) {
        // Error already logged
        return NULL;
    }

    drwav wav;

    if (!drwav_init(&wav, hh2_wavRead, hh2_wavSeek, file, NULL)) {
        HH2_LOG(HH2_LOG_ERROR, TAG "error loading WAV: %s", hh2_wavError(drwav_uninit(&wav)));
        return NULL;
    }

    if (wav.channels > HH2_MAX_CHANNELS) {
        HH2_LOG(HH2_LOG_ERROR, TAG "too many channels in WAV: %u, we only support %d", wav.channels, HH2_MAX_CHANNELS);
        drwav_uninit(&wav);
        hh2_close(file);
        return NULL;
    }

    hh2_Pcm pcm = (hh2_Pcm)malloc(sizeof(*pcm) + (wav.totalPCMFrameCount - 1) * sizeof(hh2_Sample));

    if (pcm != NULL) {
        HH2_LOG(HH2_LOG_ERROR, TAG "out of memory");
        drwav_uninit(&wav);
        hh2_close(file);
        return NULL;
    }

    pcm->sample_count = wav.totalPCMFrameCount;

    for (drwav_uint64 i = 0; i < wav.totalPCMFrameCount; i++) {
        drwav_int32 samples[HH2_MAX_CHANNELS];
        drwav_uint64 const num_read = drwav_read_pcm_frames_s32(&wav, 1, samples);

        if (num_read != 1) {
            HH2_LOG(HH2_LOG_ERROR, TAG "error reading samples: %s", hh2_wavError(drwav_uninit(&wav)));
            free(pcm);
            hh2_close(file);
            return NULL;
        }

        pcm->samples[i] = (hh2_Sample)samples[0]; // We only support mono, get the first sample
    }

    drwav_uninit(&wav);
    hh2_close(file);

    HH2_LOG(HH2_LOG_DEBUG, TAG "created pcm %p", pcm);
    return pcm;
}

void hh2_destroyPcm(hh2_Pcm pcm) {
    if (hh2_voice.pcm == pcm) {
        hh2_voice.pcm = NULL;
        hh2_voice.position = 0;
    }

    free(pcm);
}

void hh2_playPcm(hh2_Pcm pcm) {
    hh2_voice.pcm = pcm;
    hh2_voice.position = 0;
}

static void hh2_mixPcm(int32_t* const buffer, hh2_Voice* const voice) {
    size_t const buffer_free = HH2_SAMPLES_PER_VIDEO_FRAME;
    hh2_Pcm const pcm = voice->pcm;

    size_t const available = pcm->sample_count - voice->position;
    hh2_Sample const* const sample = pcm->samples + voice->position;

    if (available < buffer_free) {
        for (size_t i = 0; i < available; i++) {
            buffer[i] += sample[i];
        }

        voice->pcm = NULL;
        voice->position = 0;
    }
    else {
        for (size_t i = 0; i < buffer_free; i++) {
            buffer[i] += sample[i];
        }

        voice->position += buffer_free;
    }
}

int16_t const* hh2_soundMix(size_t* const frames) {
    int32_t buffer[HH2_SAMPLES_PER_VIDEO_FRAME * 2];

    memset(buffer, 0, sizeof(buffer));

    if (hh2_voice.pcm) {
        hh2_mixPcm(buffer, &hh2_voice);
    }

    for (size_t i = 0; i < HH2_SAMPLES_PER_VIDEO_FRAME * 2; i++) {
        int32_t const s32 = buffer[i];
        int16_t const s16 = s32 < -32768 ? -32768 : s32 > 32767 ? 32767 : s32;

        hh2_audioFrames[i] = s16;
        hh2_audioFrames[i + 1] = s16;
    }

    *frames = HH2_SAMPLES_PER_VIDEO_FRAME;
    return hh2_audioFrames;
}
