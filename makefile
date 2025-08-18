# -------------------------------
# Sources
# -------------------------------
CUBIOMES_SRC := $(addprefix cubiomes/,biomenoise.c biomes.c finders.c generator.c layers.c noise.c)

# -------------------------------
# Flags
# -------------------------------
LARGE_BIOMES ?= 1
override CFLAGS   += -O3
override CXXFLAGS += -O3 -std=c++20 -I asio/asio/include -DOMISSION_LARGE_BIOMES=$(LARGE_BIOMES)

# MAIN_CXXFLAGS inherits from CXXFLAGS (so we can add BOINC flags separately)
MAIN_CXXFLAGS := $(CXXFLAGS)

# NVCC compile flags (only for .cu -> .o)
NVCC_CFLAGS := $(CXXFLAGS) --expt-relaxed-constexpr --default-stream per-thread

# NVCC link flags (only for final link step)
NVCC_LDFLAGS :=

# -------------------------------
# BOINC support
# -------------------------------
ifdef BOINC
    BOINC_FLAGS := -Iboinc/ -DBOINC
    MAIN_LDFLAGS  += -lboinc_api -lboinc
    NVCC_LDFLAGS  += -lboinc_api -lboinc

    ifeq ($(OS),Windows_NT)
        BOINC_FLAGS += -Iboinc/win
        MAIN_LDFLAGS  += -Lboinc/lib/win
        NVCC_LDFLAGS  += -Lboinc/lib/win
    else
        MAIN_LDFLAGS  += -Lboinc/lib/lin
        NVCC_LDFLAGS  += -Lboinc/lib/lin
    endif

    CXXFLAGS     += $(BOINC_FLAGS)
    NVCC_CFLAGS  += $(BOINC_FLAGS)
    MAIN_CXXFLAGS += $(BOINC_FLAGS)
endif

# -------------------------------
# BOINC stamp file (auto rebuild)
# -------------------------------
BOINC_STAMP := .boinc_enabled

ifeq ($(BOINC),1)
BOINC_VALUE := 1
else
BOINC_VALUE := 0
endif

$(BOINC_STAMP):
	@echo $(BOINC_VALUE) > $(BOINC_STAMP)

%.o: $(BOINC_STAMP)

# -------------------------------
# Windows build
# -------------------------------
ifeq ($(OS),Windows_NT)

MAIN_OBJ := main.o

ifndef NO_GPU
    MAIN_OBJ += gpu.o
endif

ifndef NO_CPU
    MAIN_OBJ += cpu.o cubiomes.o libcubiomes.a
else
    CXXFLAGS += -DNO_CPU
endif

ifndef NO_NET
    MAIN_OBJ += client.o server.o
else
    CXXFLAGS += -DNO_NET
endif

all: main.exe

main.exe: $(MAIN_OBJ)
	nvcc $(MAIN_OBJ) $(CUBIOMES_SRC) -o $@ $(NVCC_CFLAGS) \
		-D_WIN32_WINNT=0x0601 $(MAIN_LDFLAGS) $(NVCC_LDFLAGS)

# -------------------------------
# Linux / Other build
# -------------------------------
else

NVCC_CFLAGS += -ccbin $(CXX)

MAIN_OBJ := main.o

ifndef NO_GPU
    MAIN_OBJ += gpu.o
endif

ifndef NO_CPU
    MAIN_OBJ += cpu.o cubiomes.o libcubiomes.a
else
    CXXFLAGS += -DNO_CPU
endif

ifndef NO_NET
    MAIN_OBJ += client.o server.o
else
    CXXFLAGS += -DNO_NET
endif

all: main

main: $(MAIN_OBJ)
	nvcc $(MAIN_OBJ) -o $@ $(NVCC_CFLAGS) $(MAIN_LDFLAGS) $(NVCC_LDFLAGS)

endif

# -------------------------------
# Object build rules (shared)
# -------------------------------
main.o: src/main.cpp src/common.h
	$(CXX) -c $< -o $@ $(MAIN_CXXFLAGS)

gpu.o: src/gpu.cu src/gpu.h src/common.h src/Random.h
	nvcc -c $< -o $@ $(NVCC_CFLAGS)

cpu.o: src/cpu.cpp src/cpu.h src/common.h src/cubiomes.h
	$(CXX) -c $< -o $@ $(CXXFLAGS)

client.o: src/client.cpp src/client.h src/common.h
	$(CXX) -c $< -o $@ $(CXXFLAGS)

server.o: src/server.cpp src/server.h src/common.h
	$(CXX) -c $< -o $@ $(CXXFLAGS)

cubiomes.o: src/cubiomes.c src/cubiomes.h
	$(CC) -c $< -o $@ $(CFLAGS)

libcubiomes.a:
	$(CC) -c $(CUBIOMES_SRC) -fwrapv $(CFLAGS)
	$(AR) rcs libcubiomes.a biomenoise.o biomes.o finders.o generator.o layers.o noise.o

# -------------------------------
# Convenience targets
# -------------------------------
.PHONY: boinc clean debug

boinc:
	$(MAKE) BOINC=1

debug:
	$(MAKE) clean
	$(MAKE) CXXFLAGS="-g -O0 -std=c++20 -I asio/asio/include -DOMISSION_LARGE_BIOMES=$(LARGE_BIOMES)" \
	        NVCC_CFLAGS="--expt-relaxed-constexpr --default-stream per-thread -g -G"

clean:
	rm -f *.o ./main ./main.exe *.a $(BOINC_STAMP)