local M = {}
M.type = "auxiliary"

local pendingReapply = false
local timer = 0

local function reping()
  local dse = controller.getControllerSafe("driveModes")
  if not dse then return end

  if not dse.getCurrentDriveModeKey or not dse.setDriveMode then return end

  local key = dse.getCurrentDriveModeKey()
  if key then
    dse.setDriveMode(key)
  end
end

local function init(jbeamData)
  pendingReapply = true
  timer = 0.25
end

local function reset(jbeamData)
  pendingReapply = true
  timer = 0
end

local function updateGFX(dt)
  if not pendingReapply then return end

  timer = timer - dt
  if timer <= 0 then
    pendingReapply = false
    reping()
  end
end

M.init = init
M.reset = reset
M.updateGFX = updateGFX

return M
