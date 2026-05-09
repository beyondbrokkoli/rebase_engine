local ffi = require("ffi")
local DebugProxy = require("debug_proxy") -- Assuming you update paths inside this too!

-- ========================================================
-- 1. CROSS-PLATFORM SLEEP
-- ========================================================
if ffi.os == "Windows" then
    ffi.cdef[[ void Sleep(uint32_t ms); ]]
else
    ffi.cdef[[ int usleep(uint32_t usec); ]]
end

local function os_sleep(ms)
    if ffi.os == "Windows" then
        ffi.C.Sleep(ms)
    else
        ffi.C.usleep(ms * 1000)
    end
end

-- ========================================================
-- 2. THE GENERALIZED FFI SCHEMA (Stripped of _Atomic)
-- ========================================================
ffi.cdef[[
    // --- Asynchronous Data Structures ---
    typedef struct {
        uint32_t sequence; 
        float matrix[16];
    } AsyncCameraMatrix;

    // --- Sub-System Boards ---
    typedef struct {
        int is_running;
        int force_draw_buffer;
        int debug_frame_step;
    } CoreStateBoard;

    typedef struct {
        uint32_t total_active_count;
        uint32_t cpu_core_offset;    uint32_t cpu_core_count;
        uint32_t gpu_hunters_offset; uint32_t gpu_hunters_count;
        uint32_t gpu_boids_offset;   uint32_t gpu_boids_count;
        uint32_t gpu_meteors_offset; uint32_t gpu_meteors_count;
    } AtlasBoard;

    typedef struct {
        int swarm_state;
        float params[16];  // The Frictionless Sandbox (VIBE_MAX_USER_PARAMS)
    } SimulationBoard;

    typedef struct {
        uint32_t mouse_buttons;
        float mouse_x;
        float mouse_y;
        uint32_t key_states;
    } InputBoard;

    // --- The Master Control Board ---
    typedef struct {
        CoreStateBoard  core;
        AtlasBoard      atlas;
        SimulationBoard sim;
        InputBoard      input;
        AsyncCameraMatrix camera;
    } EngineControlBoard;

    // --- Megalomaniacal Telemetry Layer ---
    typedef struct {
        uint64_t ptr_address;
        size_t size_bytes;
        int alignment;
        char name[32];
    } BufferTelemetry;

    typedef struct {
        uint64_t bridge_crossings;
        int current_c_phase;
        BufferTelemetry buffers[14];
    } EngineTelemetryBoard;
]]

-- ========================================================
-- 3. THE PARAMETER DICTIONARY (Zero C-Recompilation!)
-- ========================================================
-- Map your indexes here. AVX2/GLSL read these same indexes.
local Params = {
    GRAVITY_BLEND = 0,
    METAL_BLEND   = 1,
    PARADOX_BLEND = 2,
    AUDIO_BASS    = 3,
    AUDIO_MID     = 4,
    AUDIO_TREBLE  = 5,
    QUANTUM_JITTER = 6 -- Look at that! Added a new feature without touching C!
}

-- ========================================================
-- 4. HARDWARE BINDING
-- ========================================================
print("\n[LUA VM] Thread 5 Awoken. Binding hardware...")

local t_str, c_str = C_Bridge.get_boards()
local telemetry_ptr = ffi.cast("EngineTelemetryBoard*", tonumber(t_str))
local control_ptr   = ffi.cast("EngineControlBoard*", tonumber(c_str))

-- If you are using the proxy, make sure debug_proxy.lua expects `cb.core.debug_frame_step`
pcall(function() DebugProxy.BindHardware(telemetry_ptr, control_ptr) end)

print("[LUA VM] Hardware successfully bound. Entering IPC Horizon.")

-- ========================================================
-- 5. THE CO-OVERLORD LOOP
-- ========================================================
local ticks = 0

-- Notice the namespace routing: control_ptr.core.is_running
while control_ptr.core.is_running == 1 do
    
    -- --- EXAMPLE: WRITING TO THE FRICTIONLESS SANDBOX ---
    -- We can modulate parameters here safely while the C thread is crunching
    control_ptr.sim.params[Params.QUANTUM_JITTER] = math.sin(ticks * 0.01)

    -- --- TELEMETRY HEARTBEAT ---
    if ticks % 60 == 0 then
        -- Read the phase from C
        local phase_char = telemetry_ptr.current_c_phase == 0 and "A" or "B"
        print(string.format("\n[LUA VM] Spying on C... Phase %s | Jitter: %.3f", 
            phase_char, control_ptr.sim.params[Params.QUANTUM_JITTER]))
            
        -- Optional: Call DebugProxy.PrintConsole() if you updated the paths inside it
        -- DebugProxy.PrintConsole() 
    end
    
    ticks = ticks + 1
    os_sleep(16)
end

print("\n[LUA VM] Engine shutdown detected. Exiting gracefully...")
