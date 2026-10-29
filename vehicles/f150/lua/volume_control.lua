local M = {}

-- Required modules
local htmlTexture = require('htmlTexture')

-- Track volume state
local current_volume = 500  -- Starting volume at 50%
local VOLUME_CHANGE_SPEED = 250  -- How fast the volume changes
local lastVolume = 500  -- Track last volume to detect changes

local function updateGFX(dt)
    if not electrics then return end
    
    -- Get button states for volume controls
    local vol_up_state = electrics.values.VolUp or 0
    local vol_down_state = electrics.values.VolDown or 0
    
    -- Volume up control
    if vol_up_state == 1 then
        current_volume = current_volume + VOLUME_CHANGE_SPEED * dt
        if current_volume > 1000 then 
            current_volume = 1000
        end
    end
    
    -- Volume down control
    if vol_down_state == 1 then
        current_volume = current_volume - VOLUME_CHANGE_SPEED * dt
        if current_volume < 0 then 
            current_volume = 0
        end
    end
    
    -- Update volume value in electrics
    electrics.values.Volume = current_volume or 500
    
    -- Only update screen if volume actually changed
    if math.abs(current_volume - lastVolume) > 1 then
        -- Try to update volume display on screen
        local success, error = pcall(function()
            htmlTexture.call("@sdd_trx2_screen", string.format([[
                (function() {
                    window.postMessage({
                        type: 'volumeChange',
                        volume: %f
                    }, '*');
                })();
            ]], current_volume / 10))
        end)
        
        if success then
            lastVolume = current_volume
        end
    end
end

local function onReset()
    current_volume = 500  -- Reset to 50% volume
    lastVolume = current_volume
    if electrics then
        electrics.values.Volume = current_volume
    end
end

local function onVehicleActiveChanged(active)
    if active then
        electrics.registerHandler("updateGFX", updateGFX)
        electrics.values.Volume = current_volume
    end
end

M.onVehicleActiveChanged = onVehicleActiveChanged
M.onReset = onReset
M.updateGFX = updateGFX

return M