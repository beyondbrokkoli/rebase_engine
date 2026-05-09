local ffi = require("ffi")

-- 1. THE C-STRUCT CONTRACT
-- We mirror the exact C headers here so Lua can read the memory blindly.
ffi.cdef[[
    typedef struct {
        uint64_t ptr_address;
        size_t size_bytes;
        int alignment;
        char name[32];
    } BufferTelemetry;

    typedef struct {
        _Atomic uint64_t bridge_crossings; 
        _Atomic int current_c_phase;       
        BufferTelemetry buffers[14];
    } EngineTelemetryBoard;

    typedef struct {
        _Atomic int is_running;
        _Atomic int debug_frame_step; 
        // ... (other control fields omitted for brevity, proxy only needs the stepper) ...
    } EngineControlBoard;
]]

local DebugProxy = {
    IS_ACTIVE = true,
    show_ui = true,
    telemetry_ptr = nil, -- Bound via FFI to g_TelemetryBoard
    control_ptr = nil    -- Bound via FFI to g_ControlBoard
}

-- 2. THE INFECTOR (Zero-Overhead Wrapper)
function DebugProxy.Infect(module_name, target_module)
    if not DebugProxy.IS_ACTIVE then return target_module end
    
    local proxy = {}
    for key, value in pairs(target_module) do
        if type(value) == "function" then
            proxy[key] = function(...)
                -- The Megalomaniacal Audit: Track exactly how many times we cross the bridge
                if DebugProxy.telemetry_ptr then
                    -- Note: In a real C atomic, this would be an atomic increment. 
                    -- For Lua reading/writing it's a rough approximation, but good enough for UI.
                    DebugProxy.telemetry_ptr.bridge_crossings = DebugProxy.telemetry_ptr.bridge_crossings + 1
                end
                
                local start_time = os.clock()
                local results = { value(...) }
                local elapsed_ms = (os.clock() - start_time) * 1000

                -- Only spam console if a C-crossing took longer than 1ms
                if elapsed_ms > 1.0 then
                    print(string.format("[SPIKE] %s.%s took %.3f ms", module_name, key, elapsed_ms))
                end
                
                return unpack(results)
            end
        else
            proxy[key] = value
        end
    end
    return proxy
end

-- 3. BIND THE HARDWARE BOARDS
function DebugProxy.BindHardware(telemetry_cdata, control_cdata)
    DebugProxy.telemetry_ptr = ffi.cast("EngineTelemetryBoard*", telemetry_cdata)
    DebugProxy.control_ptr = ffi.cast("EngineControlBoard*", control_cdata)
    print("[TELEMETRY] Omniscient Proxy successfully bound to AVX2 Engine Core.")
end

-- 4. THE TIME MACHINE CONTROLS (Input Hooks)
function DebugProxy.KeyPressed(key)
    if not DebugProxy.IS_ACTIVE or not DebugProxy.control_ptr then return end

    if key == "f1" then
        DebugProxy.show_ui = not DebugProxy.show_ui
    elseif key == "p" then
        -- Toggle Pause/Free-Run
        local current = DebugProxy.control_ptr.debug_frame_step
        DebugProxy.control_ptr.debug_frame_step = (current == 0) and 1 or 0
        print("[TIME MACHINE] State: " .. (DebugProxy.control_ptr.debug_frame_step == 0 and "FREE RUN" or "PAUSED"))
    elseif key == "]" then
        -- Step Exactly One Frame
        if DebugProxy.control_ptr.debug_frame_step == 1 then
            DebugProxy.control_ptr.debug_frame_step = 2 
            print("[TIME MACHINE] Stepping One Frame...")
        end
    end
end

-- 5. THE TERMINAL VISUALIZER
function DebugProxy.PrintConsole()
    if not DebugProxy.IS_ACTIVE or not DebugProxy.show_ui or not DebugProxy.telemetry_ptr then return end

    local tb = DebugProxy.telemetry_ptr
    local cb = DebugProxy.control_ptr

    local phase_char = (tb.current_c_phase == 0) and "A" or "B"
    local run_state = (cb.debug_frame_step == 0) and "FREE RUN" or (cb.debug_frame_step == 1 and "PAUSED" or "STEPPING")

    -- Clear screen (ANSI escape code)
    io.write("\27[2J\27[H") 
    
    print("=== VIBE ENGINE MEGALOMANIACAL TELEMETRY ===")
    print(string.format("C-Core Phase Target: [%s]", phase_char))
    print(string.format("Time Machine State:  [%s]", run_state))
    print(string.format("FFI Bridge Crossings: %d", tonumber(tb.bridge_crossings)))
    
    tb.bridge_crossings = 0 

    print("--------------------------------------------------")
    print(string.format("%-4s %-15s %-20s %s", "", "BUFFER", "ADDRESS", "SIZE (MB)"))
    print("--------------------------------------------------")

    for i = 0, 13 do
        local b = tb.buffers[i]
        local name = ffi.string(b.name)
        
        local active_marker = "    "
        if (tb.current_c_phase == 0 and name:sub(-2) == "_A") or 
           (tb.current_c_phase == 1 and name:sub(-2) == "_B") then
            active_marker = ">>> " -- Danger: AVX2 is touching this!
        end

        local size_mb = tonumber(b.size_bytes) / (1024 * 1024)
        local addr_hex = string.format("0x%016llX", tonumber(b.ptr_address))

        print(string.format("%s %-15s %-20s %.2f", active_marker, name, addr_hex, size_mb))
    end
    print("--------------------------------------------------")
    print("[F1] Hide  [P] Pause  []] Step Frame")
end

return DebugProxy
