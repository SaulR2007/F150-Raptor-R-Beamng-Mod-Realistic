local M = {}

local FORD_UI_SLOT = "sdd_trx2_ford_ui"

local function playerVehicle()
  return be:getPlayerVehicle(0)
end

local function hasFordControlUI()
  local vehicle = playerVehicle()
  if not vehicle then
    return false
  end
  local data = core_vehicle_manager and core_vehicle_manager.getPlayerVehicleData and core_vehicle_manager.getPlayerVehicleData()
  if data and data.chosenParts then
    local part = data.chosenParts[FORD_UI_SLOT]
    if part ~= nil and part ~= "" then
      return true
    end
    return false
  end
  -- Fallback before vehicle data is ready: still allow this truck by jbeam name
  local name = vehicle:getJBeamFilename() or ""
  return name == "f150" or name:find("f150", 1, true) ~= nil
end

-- Keep old name so existing UI callbacks keep working
local function isSddTrx2()
  return hasFordControlUI()
end

local function queueOnTrx(command, reloadVehicle)
  if not hasFordControlUI() then
    return
  end
  local vehicle = playerVehicle()
  if not vehicle then
    return
  end
  local prefix = "extensions.load('user_fordControlVehicle'); "
  if reloadVehicle then
    prefix = "extensions.unload('user_fordControlVehicle'); " .. prefix
  end
  vehicle:queueLuaCommand(prefix .. command)
end

local function ensureVehicleExt()
  queueOnTrx("extensions.load('user_fordControlVehicle')")
end

local function setDriveMode(mode)
  queueOnTrx("extensions.user_fordControlVehicle.applyPowertrainMode('" .. tostring(mode) .. "')")
end

local function cycleDse(delta)
  queueOnTrx("extensions.user_fordControlVehicle.cycleDse(" .. tostring(delta) .. ")")
end

local function toggleDiff(which)
  queueOnTrx("extensions.user_fordControlVehicle.toggleDiff('" .. tostring(which) .. "')")
end

local function metricArg()
  if settings.getValue("uiUnitLength") == "metric" then
    return "true"
  end
  return "false"
end

local function toggleTrail(wantOn)
  local metric = metricArg()
  -- Always hot-reload vehicle Lua from disk, then set on/off (unload clears locals)
  if wantOn == nil then
    queueOnTrx(string.format([[
      local was = extensions.user_fordControlVehicle and extensions.user_fordControlVehicle.isTrailActive and extensions.user_fordControlVehicle.isTrailActive()
      extensions.unload('user_fordControlVehicle')
      extensions.load('user_fordControlVehicle')
      extensions.user_fordControlVehicle.setTrail(not was, %s)
    ]], metric))
    return
  end
  local on = (wantOn == true or wantOn == 1 or wantOn == "true" or wantOn == "1") and "true" or "false"
  queueOnTrx("extensions.user_fordControlVehicle.setTrail(" .. on .. ", " .. metric .. ")", true)
end

local function adjustTrail(delta)
  queueOnTrx("extensions.user_fordControlVehicle.adjustTrail(" .. tostring(delta) .. ", " .. metricArg() .. ")")
end

local function openTrailCamera()
  if not playerVehicle() then
    return
  end
  local cam = extensions.core_camera
  if cam and cam.setBySlotId then
    cam.setBySlotId(0, 9)
  end
end

M.isSddTrx2 = isSddTrx2
M.hasFordControlUI = hasFordControlUI
M.ensureVehicleExt = ensureVehicleExt
M.setDriveMode = setDriveMode
M.cycleDse = cycleDse
M.toggleDiff = toggleDiff
M.toggleTrail = toggleTrail
M.adjustTrail = adjustTrail
M.openTrailCamera = openTrailCamera
return M
