#pragma once

#include "common.h"

struct GpuThread: Thread<GpuThread> {
    int device;
    GpuOutputs &outputs;
    #ifdef BOINC
    uint64_t start_seed;
    uint64_t end_seed;
    double elapsed_chkpoint;
    GpuThread(int device, GpuOutputs &outputs, uint64_t start_seed, uint64_t end_seed, double elapsed_chkpoint);
    #else
    GpuThread(int device, GpuOutputs &outputs);
    #endif
    void run();
};