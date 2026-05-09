local ffi = require("ffi")
local DebugProxy = require("debug_proxy") -- Load your Console Proxy!

-- 1. FFI OS Sleep Binding
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

-- 2. Grab the string-casted pointers from the C Bridge
local t_str, c_str = C_Bridge.get_boards()

-- 3. Convert Strings -> Hex Numbers -> Raw CData Pointers
local telemetry_ptr = ffi.cast("EngineTelemetryBoard*", tonumber(t_str))
local control_ptr   = ffi.cast("EngineControlBoard*", tonumber(c_str))

-- 4. Hand the raw memory over to your Megalomaniacal Proxy
DebugProxy.BindHardware(telemetry_ptr, control_ptr)

-- 5. The Co-Overlord Infinite Loop
local ticks = 0

while control_ptr.is_running == 1 do
    
    -- Instead of a simple heartbeat, we draw the whole damn dashboard!
    -- Update the console UI every 60 frames (~1 second) so we don't flicker to death
    if ticks % 60 == 0 then
        DebugProxy.PrintConsole() 
    end
    
    ticks = ticks + 1
    os_sleep(16) -- Simulate 60FPS independent polling rate
end

print("\n[LUA VM] Engine shutdown detected. Exiting gracefully...")
