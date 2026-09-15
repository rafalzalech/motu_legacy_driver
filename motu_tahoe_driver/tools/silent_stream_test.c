#include <CoreAudio/CoreAudio.h>
#include <CoreFoundation/CoreFoundation.h>

#include <math.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

typedef struct {
    _Atomic uint64_t callbacks;
    _Atomic uint64_t input_samples;
    _Atomic uint64_t nonzero_samples;
    _Atomic uint32_t peak_bits;
    _Atomic uint32_t channel_peak_bits[32];
    uint64_t output_frames;
    double sample_rate;
    double tone_hz;
    float tone_amplitude;
    UInt32 first_output_channel;
    UInt32 output_channel_count;
} TestState;

static void print_osstatus(const char *operation, OSStatus status) {
    char code[5] = {
        (char)((uint32_t)status >> 24),
        (char)((uint32_t)status >> 16),
        (char)((uint32_t)status >> 8),
        (char)(uint32_t)status,
        '\0'
    };
    for (int i = 0; i < 4; ++i) {
        if (code[i] < 32 || code[i] > 126) code[i] = '?';
    }
    fprintf(stderr, "%s failed: %d ('%s')\n", operation, (int)status, code);
}

static void update_peak(_Atomic uint32_t *destination, float value) {
    union { float f; uint32_t u; } candidate = { .f = fabsf(value) };
    uint32_t current = atomic_load_explicit(destination, memory_order_relaxed);
    union { float f; uint32_t u; } observed = { .u = current };
    while (candidate.f > observed.f &&
           !atomic_compare_exchange_weak_explicit(destination, &current, candidate.u,
                                                  memory_order_relaxed,
                                                  memory_order_relaxed)) {
        observed.u = current;
    }
}

static OSStatus io_callback(AudioObjectID device,
                            const AudioTimeStamp *now,
                            const AudioBufferList *input,
                            const AudioTimeStamp *input_time,
                            AudioBufferList *output,
                            const AudioTimeStamp *output_time,
                            void *context) {
    (void)device;
    (void)now;
    (void)input_time;
    (void)output_time;
    TestState *state = context;
    atomic_fetch_add_explicit(&state->callbacks, 1, memory_order_relaxed);

    if (input) {
        UInt32 channel_base = 0;
        for (UInt32 buffer_index = 0; buffer_index < input->mNumberBuffers; ++buffer_index) {
            const AudioBuffer *buffer = &input->mBuffers[buffer_index];
            const float *samples = buffer->mData;
            size_t count = buffer->mDataByteSize / sizeof(float);
            const UInt32 channels = buffer->mNumberChannels;
            atomic_fetch_add_explicit(&state->input_samples, count, memory_order_relaxed);
            for (size_t sample_index = 0; sample_index < count; ++sample_index) {
                float sample = samples ? samples[sample_index] : 0.0f;
                if (sample != 0.0f) {
                    atomic_fetch_add_explicit(&state->nonzero_samples, 1, memory_order_relaxed);
                    update_peak(&state->peak_bits, sample);
                    if (channels > 0) {
                        const UInt32 channel =
                            channel_base + (UInt32)(sample_index % channels);
                        if (channel < 32) {
                            update_peak(&state->channel_peak_bits[channel], sample);
                        }
                    }
                }
            }
            channel_base += channels;
        }
    }

    if (output) {
        UInt32 channel_base = 0;
        uint64_t callback_frames = 0;
        for (UInt32 buffer_index = 0; buffer_index < output->mNumberBuffers; ++buffer_index) {
            AudioBuffer *buffer = &output->mBuffers[buffer_index];
            if (buffer->mData && buffer->mDataByteSize) {
                memset(buffer->mData, 0, buffer->mDataByteSize);
                const UInt32 channels = buffer->mNumberChannels;
                const uint64_t frames = channels > 0
                    ? buffer->mDataByteSize / (sizeof(float) * channels)
                    : 0;
                if (frames > callback_frames) callback_frames = frames;
                if (state->tone_amplitude > 0.0f && state->tone_hz > 0.0 &&
                    state->sample_rate > 0.0) {
                    float *samples = buffer->mData;
                    for (uint64_t frame = 0; frame < frames; ++frame) {
                        const double phase = 2.0 * M_PI * state->tone_hz *
                            (double)(state->output_frames + frame) / state->sample_rate;
                        const float sample = state->tone_amplitude * (float)sin(phase);
                        for (UInt32 channel = 0; channel < channels; ++channel) {
                            const UInt32 absolute_channel = channel_base + channel;
                            if (absolute_channel >= state->first_output_channel &&
                                absolute_channel < state->first_output_channel +
                                                       state->output_channel_count) {
                                samples[frame * channels + channel] = sample;
                            }
                        }
                    }
                }
            }
            channel_base += buffer->mNumberChannels;
        }
        state->output_frames += callback_frames;
    }
    return noErr;
}

static CFStringRef copy_device_name(AudioObjectID device) {
    AudioObjectPropertyAddress address = {
        kAudioObjectPropertyName,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };
    CFStringRef name = NULL;
    UInt32 size = sizeof(name);
    if (AudioObjectGetPropertyData(device, &address, 0, NULL, &size, &name) != noErr) {
        return NULL;
    }
    return name;
}

static AudioObjectID find_device(const char *wanted_name) {
    AudioObjectPropertyAddress address = {
        kAudioHardwarePropertyDevices,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };
    UInt32 size = 0;
    if (AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &address, 0, NULL, &size) != noErr) {
        return kAudioObjectUnknown;
    }
    AudioObjectID *devices = malloc(size);
    if (!devices) return kAudioObjectUnknown;
    if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &address, 0, NULL, &size, devices) != noErr) {
        free(devices);
        return kAudioObjectUnknown;
    }

    AudioObjectID match = kAudioObjectUnknown;
    UInt32 count = size / sizeof(*devices);
    for (UInt32 index = 0; index < count; ++index) {
        CFStringRef name = copy_device_name(devices[index]);
        if (!name) continue;
        char utf8[256] = {0};
        if (CFStringGetCString(name, utf8, sizeof(utf8), kCFStringEncodingUTF8) &&
            strcmp(utf8, wanted_name) == 0) {
            match = devices[index];
        }
        CFRelease(name);
        if (match != kAudioObjectUnknown) break;
    }
    free(devices);
    return match;
}

static void print_stream_configuration(AudioObjectID device, AudioObjectPropertyScope scope,
                                       const char *label) {
    AudioObjectPropertyAddress address = {
        kAudioDevicePropertyStreamConfiguration,
        scope,
        kAudioObjectPropertyElementMain
    };
    UInt32 size = 0;
    if (AudioObjectGetPropertyDataSize(device, &address, 0, NULL, &size) != noErr) return;
    AudioBufferList *buffers = malloc(size);
    if (!buffers) return;
    if (AudioObjectGetPropertyData(device, &address, 0, NULL, &size, buffers) == noErr) {
        UInt32 channels = 0;
        for (UInt32 i = 0; i < buffers->mNumberBuffers; ++i) channels += buffers->mBuffers[i].mNumberChannels;
        printf("%s channels: %u\n", label, channels);
    }
    free(buffers);
}

static void print_preferred_stereo_channels(AudioObjectID device,
                                            AudioObjectPropertyScope scope,
                                            const char *label) {
    AudioObjectPropertyAddress address = {
        kAudioDevicePropertyPreferredChannelsForStereo,
        scope,
        kAudioObjectPropertyElementMain
    };
    UInt32 channels[2] = {0, 0};
    UInt32 size = sizeof(channels);
    OSStatus status = AudioObjectGetPropertyData(device, &address, 0, NULL, &size, channels);
    if (status == noErr && size == sizeof(channels)) {
        printf("Preferred stereo %s: %u-%u\n", label, channels[0], channels[1]);
    } else {
        char operation[96] = {0};
        snprintf(operation, sizeof(operation), "Read preferred stereo %s", label);
        print_osstatus(operation, status);
    }
}

static OSStatus set_preferred_stereo_output(AudioObjectID device, UInt32 left) {
    AudioObjectPropertyAddress address = {
        kAudioDevicePropertyPreferredChannelsForStereo,
        kAudioDevicePropertyScopeOutput,
        kAudioObjectPropertyElementMain
    };
    Boolean settable = false;
    OSStatus status = AudioObjectIsPropertySettable(device, &address, &settable);
    if (status != noErr) return status;
    if (!settable) return kAudioHardwareUnsupportedOperationError;

    const UInt32 channels[2] = {left, left + 1};
    return AudioObjectSetPropertyData(device, &address, 0, NULL,
                                      sizeof(channels), channels);
}

static OSStatus set_default_output_device(AudioObjectID device,
                                          AudioObjectPropertySelector selector) {
    AudioObjectPropertyAddress address = {
        selector,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };
    return AudioObjectSetPropertyData(kAudioObjectSystemObject, &address, 0, NULL,
                                      sizeof(device), &device);
}

int main(int argc, char **argv) {
    const char *name = argc > 1 ? argv[1] : "MOTU UltraLite";
    unsigned duration = argc > 2 ? (unsigned)strtoul(argv[2], NULL, 10) : 4;
    double tone_hz = argc > 3 ? strtod(argv[3], NULL) : 0.0;
    double tone_amplitude = argc > 4 ? strtod(argv[4], NULL) : 0.0;
    unsigned first_output_channel =
        argc > 5 ? (unsigned)strtoul(argv[5], NULL, 10) : 1;
    unsigned preferred_stereo_left =
        argc > 6 ? (unsigned)strtoul(argv[6], NULL, 10) : 0;
    const int make_default_output =
        argc > 7 ? (int)strtol(argv[7], NULL, 10) : 0;
    if (duration == 0 || duration > 30) duration = 4;
    if (tone_hz < 0.0 || tone_hz > 20000.0) tone_hz = 0.0;
    if (tone_amplitude < 0.0 || tone_amplitude > 0.1) tone_amplitude = 0.0;
    if (first_output_channel > 13) {
        fprintf(stderr,
                "First output channel must be from 1 through 13, or 0 for all outputs.\n");
        return 1;
    }
    if (preferred_stereo_left > 13) {
        fprintf(stderr, "Preferred stereo left channel must be from 1 through 13.\n");
        return 1;
    }

    AudioObjectID device = find_device(name);
    if (device == kAudioObjectUnknown) {
        fprintf(stderr, "Core Audio device not found: %s\n", name);
        return 2;
    }
    printf("Opening Core Audio device: %s (object %u)\n", name, device);
    if (make_default_output) {
        OSStatus default_status = set_default_output_device(
            device, kAudioHardwarePropertyDefaultOutputDevice);
        if (default_status != noErr) {
            print_osstatus("Set default output device", default_status);
            return 6;
        }
        default_status = set_default_output_device(
            device, kAudioHardwarePropertyDefaultSystemOutputDevice);
        if (default_status != noErr) {
            print_osstatus("Set default system output device", default_status);
            return 6;
        }
        printf("Set as default output and system output device.\n");
    }
    print_stream_configuration(device, kAudioDevicePropertyScopeInput, "Input");
    print_stream_configuration(device, kAudioDevicePropertyScopeOutput, "Output");
    if (preferred_stereo_left != 0) {
        OSStatus preferred_status =
            set_preferred_stereo_output(device, preferred_stereo_left);
        if (preferred_status != noErr) {
            print_osstatus("Set preferred stereo output", preferred_status);
            return 5;
        }
    }
    print_preferred_stereo_channels(device, kAudioDevicePropertyScopeInput, "input");
    print_preferred_stereo_channels(device, kAudioDevicePropertyScopeOutput, "output");

    AudioObjectPropertyAddress rate_address = {
        kAudioDevicePropertyNominalSampleRate,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };
    Float64 sample_rate = 0.0;
    UInt32 rate_size = sizeof(sample_rate);
    if (AudioObjectGetPropertyData(device, &rate_address, 0, NULL,
                                   &rate_size, &sample_rate) != noErr) {
        sample_rate = 48000.0;
    }

    TestState state = {
        .sample_rate = sample_rate,
        .tone_hz = tone_hz,
        .tone_amplitude = (float)tone_amplitude,
        .first_output_channel = first_output_channel == 0
                                    ? 0
                                    : first_output_channel - 1,
        .output_channel_count = first_output_channel == 0 ? 14 : 2,
    };
    AudioDeviceIOProcID proc = NULL;
    OSStatus status = AudioDeviceCreateIOProcID(device, io_callback, &state, &proc);
    if (status != noErr) {
        print_osstatus("AudioDeviceCreateIOProcID", status);
        return 3;
    }

    status = AudioDeviceStart(device, proc);
    if (status != noErr) {
        print_osstatus("AudioDeviceStart", status);
        AudioDeviceDestroyIOProcID(device, proc);
        return 4;
    }
    if (state.tone_amplitude > 0.0f && state.tone_hz > 0.0) {
        if (first_output_channel == 0) {
            printf("Streaming %.1f Hz at %.6f amplitude to all 14 outputs for %u second(s)...\n",
                   state.tone_hz, state.tone_amplitude, duration);
        } else {
            printf("Streaming %.1f Hz at %.6f amplitude to outputs %u-%u for %u second(s)...\n",
                   state.tone_hz, state.tone_amplitude,
                   state.first_output_channel + 1,
                   state.first_output_channel + 2, duration);
        }
    } else {
        printf("Streaming silence for %u second(s)...\n", duration);
    }
    fflush(stdout);
    sleep(duration);

    OSStatus stop_status = AudioDeviceStop(device, proc);
    OSStatus destroy_status = AudioDeviceDestroyIOProcID(device, proc);
    if (stop_status != noErr) print_osstatus("AudioDeviceStop", stop_status);
    if (destroy_status != noErr) print_osstatus("AudioDeviceDestroyIOProcID", destroy_status);

    union { float f; uint32_t u; } peak = {
        .u = atomic_load_explicit(&state.peak_bits, memory_order_relaxed)
    };
    uint64_t callbacks = atomic_load_explicit(&state.callbacks, memory_order_relaxed);
    uint64_t samples = atomic_load_explicit(&state.input_samples, memory_order_relaxed);
    uint64_t nonzero = atomic_load_explicit(&state.nonzero_samples, memory_order_relaxed);
    printf("Callbacks: %llu\n", (unsigned long long)callbacks);
    printf("Input samples inspected: %llu\n", (unsigned long long)samples);
    printf("Non-zero input samples: %llu\n", (unsigned long long)nonzero);
    printf("Peak absolute input sample: %.8f\n", peak.f);
    printf("Per-channel input peaks:\n");
    for (UInt32 channel = 0; channel < 14; ++channel) {
        union { float f; uint32_t u; } channel_peak = {
            .u = atomic_load_explicit(&state.channel_peak_bits[channel],
                                      memory_order_relaxed)
        };
        printf("  adc %2u: %.8f\n", channel + 1, channel_peak.f);
    }

    if (callbacks == 0) {
        fprintf(stderr, "FAIL: Core Audio started the device but delivered no callbacks.\n");
        return 5;
    }
    if (state.tone_amplitude > 0.0f && state.tone_hz > 0.0) {
        printf("PASS: Core Audio completed a live callback stream and generated %llu tone frames.\n",
               (unsigned long long)state.output_frames);
    } else {
        printf("PASS: Core Audio completed a live callback stream; all output buffers were zero-filled.\n");
    }
    return 0;
}
