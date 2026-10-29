local M = {}

local DSE_KEYS = {"slippery", "tow", "sport", "comfort", "offroad", "sand", "baja", "rock crawl"}
local MPH_TO_MS = 0.44704
local KMH_TO_MS = 1 / 3.6

local lastPub = nil
local trailActive = false
local trailDisplay = 0
local useMetric = true
local trailRampedMs = 0
local trailBrakeHold = 0
local trailThrottleHold = 0
local trailOnHill = false
local trailStruggleTime = 0
-- Same slow edges for both; separate state so they don't fight
local trailBrakeSmooth = newTemporalSmoothing(22, 50)
local trailThrottleSoftSmooth = newTemporalSmoothing(22, 50)
local trailCruiseSmooth = newTemporalSmoothing(120, 160)
local trailSpeedPID = newPIDStandard(0.3, 2.0, 0.0, 0, 0.7, 1, 1, 0, 0.7)

local function firstDevice(names)
  for i = 1, #names do
    local device = powertrain.getDevice(names[i])
    if device then
      return device
    end
  end
  return nil
end

local function setDeviceMode(names, mode)
  local device = firstDevice(names)
  if device and mode and device.setMode then
    device:setMode(mode)
  end
end

local function deviceMode(names)
  local device = firstDevice(names)
  if not device then
    return nil
  end
  return device.mode
end

local function setDiffUnlocked(names)
  setDeviceMode(names, "open")
end

local function setDiffLocked(names)
  setDeviceMode(names, "locked")
end

local function applyTransfer(frontShaftMode, centerMode, fallbackCaseMode)
  local frontOutput = powertrain.getDevice("transfercase_F")
  if frontOutput then
    if frontShaftMode and frontOutput.setMode then
      frontOutput:setMode(frontShaftMode)
    end
    setDeviceMode({"transfercase"}, centerMode)
  else
    setDeviceMode({"transfercase"}, fallbackCaseMode)
  end
end

local function currentFour()
  local range = deviceMode({"rangebox"})
  local frontOut = deviceMode({"transfercase_F"})
  local center = deviceMode({"transfercase"})
  if range == "low" then
    return 3
  elseif frontOut == "disconnected" then
    return 0
  elseif center == "lsd" then
    return 1
  elseif frontOut == "connected" then
    return 2
  end
  return -1
end

local function isReverse()
  local gearIndex = electrics.values.gearIndex
  if type(gearIndex) == "number" then
    return gearIndex < 0
  end
  local gear = electrics.values.gear
  if type(gear) == "number" then
    return gear < 0
  end
  if type(gear) == "string" then
    return gear == "R" or gear == "r"
  end
  return false
end

local function setUnits(metric)
  useMetric = metric == true or metric == 1 or metric == "true" or metric == "1"
end

local function displayToMs(value)
  if useMetric then
    return value * KMH_TO_MS
  end
  return value * MPH_TO_MS
end

local function msToDisplay(ms)
  if useMetric then
    return ms * 3.6
  end
  return ms / MPH_TO_MS
end

local function trailCap()
  if useMetric then
    return isReverse() and 8 or 32
  end
  return isReverse() and 5 or 20
end

local function trailMin()
  return 1
end

-- DCT creeps / "walks" around this with zero throttle in Drive
local function idleWalkMs()
  if useMetric then
    return 9 * KMH_TO_MS
  end
  return 5.5 * MPH_TO_MS
end

local function clearTrailOverrides()
  electrics.values.throttleOverride = nil
  electrics.values.brakeOverride = nil
end

-- vehicleController uses `brakeOverride or pedal` — so override replaces the pad.
-- Always merge so controller/keyboard can never be blocked.
local function applyBrake(trailAmt)
  local pedal = input.brake or 0
  if pedal > 0.02 then
    trailAmt = 0
  end
  local v = math.max(tonumber(trailAmt) or 0, pedal)
  electrics.values.brakeOverride = v > 0.01 and v or nil
end

local function applyThrottle(trailAmt)
  local pedal = input.throttle or 0
  if pedal > 0.02 then
    trailAmt = 0
  end
  local v = math.max(tonumber(trailAmt) or 0, pedal)
  electrics.values.throttleOverride = v > 0.01 and v or nil
end

local function resetTrailControl()
  trailRampedMs = math.abs(electrics.values.wheelspeed or 0)
  trailBrakeHold = 0
  trailThrottleHold = 0
  trailOnHill = false
  trailStruggleTime = 0
  trailSpeedPID:reset()
  trailBrakeSmooth:reset()
  trailThrottleSoftSmooth:reset()
  trailCruiseSmooth:reset()
  clearTrailOverrides()
end

-- Soft prop + slow hold (same feel for brake and under-9 throttle)
local function softActuator(error, hold, maxOut, minOut, smoother, dt)
  -- error > 0 means we need more of this actuator
  if error > 0.04 then
    hold = math.min(maxOut, hold + error * 0.2 * dt)
  elseif error < -0.05 then
    hold = math.max(0, hold + error * 0.8 * dt)
  else
    hold = math.max(0, hold - 0.04 * dt)
  end
  local prop = 0
  if error > 0.03 then
    prop = (error - 0.03) * 0.35
  end
  local cmd = prop + hold
  if error > -0.04 and minOut > 0 then
    cmd = math.max(minOut, cmd)
  end
  cmd = math.min(maxOut, cmd)
  local out = smoother:getUncapped(cmd, dt)
  return out, hold
end

-- Nose-up pitch only (no accel guessing — that caused flat-ground throttle pulse)
local function isClimbing()
  local _, _, fz = obj:getDirectionVectorXYZ()
  return (fz or 0) > 0.045 -- ~2.6°
end

local function stopTrail()
  trailActive = false
  resetTrailControl()
end

local function trailAllowed()
  local four = currentFour()
  return four == 1 or four == 2 or four == 3
end

local MACROS = {
  ["2H"] = function()
    setDeviceMode({"rangebox"}, "high")
    setDeviceMode({"transfercase"}, "locked")
    applyTransfer("disconnected", "locked", "2WD")
    setDiffUnlocked({"differential_F", "frontDiff"})
    setDiffUnlocked({"differential_R", "rearDiff"})
    stopTrail()
  end,
  ["4A"] = function()
    setDeviceMode({"rangebox"}, "high")
    applyTransfer("connected", "lsd", "AWD")
    setDiffUnlocked({"differential_F", "frontDiff"})
    setDiffUnlocked({"differential_R", "rearDiff"})
  end,
  ["4H"] = function()
    setDeviceMode({"rangebox"}, "high")
    applyTransfer("connected", "locked", "4WD")
    setDiffUnlocked({"differential_F", "frontDiff"})
    setDiffUnlocked({"differential_R", "rearDiff"})
  end,
  ["4L"] = function()
    setDeviceMode({"rangebox"}, "low")
    applyTransfer("connected", "locked", "4WD")
    setDiffLocked({"differential_F", "frontDiff"})
    setDiffLocked({"differential_R", "rearDiff"})
  end,
}

local function applyPowertrainMode(mode)
  local macro = MACROS[mode]
  if not macro then
    return
  end
  macro()
end

local function cycleDse(delta)
  local dse = controller.getControllerSafe("driveModes")
  if not dse then
    return
  end
  delta = tonumber(delta) or 0
  if delta > 0 and dse.nextMode then
    dse.nextMode()
    return
  end
  if delta < 0 and dse.previousMode then
    dse.previousMode()
    return
  end
  if delta < 0 and dse.prevMode then
    dse.prevMode()
    return
  end
  if not dse.getCurrentDriveModeKey or not dse.setDriveMode then
    return
  end
  local key = dse.getCurrentDriveModeKey()
  local idx = 1
  for i = 1, #DSE_KEYS do
    if DSE_KEYS[i] == key then
      idx = i
      break
    end
  end
  idx = idx + delta
  if idx < 1 then
    idx = #DSE_KEYS
  elseif idx > #DSE_KEYS then
    idx = 1
  end
  dse.setDriveMode(DSE_KEYS[idx])
end

local function toggleDiff(which)
  local names
  if which == "front" then
    names = {"differential_F", "frontDiff"}
  else
    names = {"differential_R", "rearDiff"}
  end
  local device = firstDevice(names)
  if not device or not device.setMode then
    return
  end
  if device.mode == "locked" then
    device:setMode("open")
  else
    device:setMode("locked")
  end
end

local function setTrail(on, metric)
  setUnits(metric)
  if not on then
    stopTrail()
    lastPub = nil
    return
  end
  if not trailAllowed() then
    stopTrail()
    lastPub = nil
    return
  end
  local speed = msToDisplay(math.abs(electrics.values.wheelspeed or 0))
  local minimum = trailMin()
  if speed < minimum then
    speed = minimum
  end
  trailDisplay = math.max(minimum, math.min(trailCap(), speed))
  trailActive = true
  resetTrailControl()
  lastPub = nil
end

local function toggleTrail(metric)
  setTrail(not trailActive, metric)
end

local function adjustTrail(delta, metric)
  setUnits(metric)
  if not trailActive then
    return
  end
  delta = tonumber(delta) or 0
  trailDisplay = math.max(trailMin(), math.min(trailCap(), trailDisplay + delta))
  local targetMs = displayToMs(trailDisplay)
  if targetMs < trailRampedMs then
    trailRampedMs = targetMs
  end
  lastPub = nil
end

local function updateTrail(dt)
  -- Clear every frame first so a stuck override can never eat the pad
  clearTrailOverrides()

  if not trailActive then
    return
  end
  if not trailAllowed() then
    stopTrail()
    lastPub = nil
    return
  end
  trailDisplay = math.max(trailMin(), math.min(trailCap(), trailDisplay))

  if extensions.cruiseControl and extensions.cruiseControl.setEnabled then
    local cfg = extensions.cruiseControl.getConfiguration and extensions.cruiseControl.getConfiguration()
    if cfg and cfg.isEnabled then
      extensions.cruiseControl.setEnabled(false)
    end
  end

  dt = math.max(0.001, math.min(0.05, dt or 0.016))
  local speed = math.abs(electrics.values.wheelspeed or 0)
  local targetMs = displayToMs(trailDisplay)
  local walkMs = idleWalkMs()
  local maxBrake = 0.8
  local maxThrottle = 0.7
  local overspeed = speed - targetMs

  trailRampedMs = targetMs

  -- Hill latch: pitch on, clear when nose is flat again
  local climbing = isClimbing()
  if climbing then
    trailOnHill = true
  elseif trailOnHill then
    local _, _, fz = obj:getDirectionVectorXYZ()
    if (fz or 0) < 0.02 then
      trailOnHill = false
    end
  end

  local belowWalk = targetMs < walkMs * 0.95

  -- Under ~9 km/h
  if belowWalk then
    if overspeed < -0.12 then
      trailStruggleTime = trailStruggleTime + dt
      if trailStruggleTime > 0.7 then
        trailOnHill = true
        trailStruggleTime = 0
      end
    else
      trailStruggleTime = 0
    end

    -- Overspeed always brakes (flat creep OR downhill)
    if overspeed > 0.02 then
      trailThrottleHold = 0
      trailThrottleSoftSmooth:getUncapped(0, dt)
      local brakeOut
      brakeOut, trailBrakeHold = softActuator(overspeed, trailBrakeHold, maxBrake, 0.037, trailBrakeSmooth, dt)
      applyThrottle(0)
      applyBrake(brakeOut)
      return
    end

    -- Underspeed on hill/tow → soft throttle (same ramp as brakes)
    if trailOnHill and overspeed < -0.03 then
      trailBrakeHold = 0
      trailBrakeSmooth:getUncapped(0, dt)
      local throttleOut
      throttleOut, trailThrottleHold = softActuator(-overspeed, trailThrottleHold, maxThrottle, 0.037, trailThrottleSoftSmooth, dt)
      applyBrake(0)
      applyThrottle(throttleOut)
      return
    end

    -- Near target on flat: keep min brake against creep
    trailThrottleHold = 0
    trailThrottleSoftSmooth:getUncapped(0, dt)
    local brakeOut
    brakeOut, trailBrakeHold = softActuator(overspeed, trailBrakeHold, maxBrake, 0.037, trailBrakeSmooth, dt)
    applyThrottle(0)
    applyBrake(brakeOut)
    return
  end

  -- Above idle walk: cruise throttle; soft brake if over
  trailThrottleHold = 0
  trailOnHill = false
  trailStruggleTime = 0

  if overspeed > 0.15 then
    trailCruiseSmooth:getUncapped(0, dt)
    trailSpeedPID:reset()
    local brakeOut
    brakeOut, trailBrakeHold = softActuator(overspeed, trailBrakeHold, maxBrake, 0, trailBrakeSmooth, dt)
    applyThrottle(0)
    applyBrake(brakeOut)
  else
    trailBrakeHold = math.max(0, trailBrakeHold - 0.5 * dt)
    trailBrakeSmooth:getUncapped(0, dt)
    local out = trailSpeedPID:get(speed, targetMs, dt)
    applyBrake(0)
    applyThrottle(out)
  end
end

local function publishState()
  if not electrics or not electrics.values then
    return
  end

  local four = currentFour()
  local dseIdx = 3
  local dse = controller.getControllerSafe("driveModes")
  if dse and dse.getCurrentDriveModeKey then
    local dseKey = dse.getCurrentDriveModeKey()
    for i = 1, #DSE_KEYS do
      if DSE_KEYS[i] == dseKey then
        dseIdx = i - 1
        break
      end
    end
  end

  local frontDiff = firstDevice({"differential_F", "frontDiff"})
  local rearDiff = firstDevice({"differential_R", "rearDiff"})
  local fd = (frontDiff and frontDiff.mode == "locked") and 1 or 0
  local rd = (rearDiff and rearDiff.mode == "locked") and 1 or 0
  local tc = trailActive and 1 or 0
  local spd = math.floor(trailDisplay + 0.5)
  local unit = useMetric and 1 or 0

  electrics.values.ford_4x4 = four
  electrics.values.ford_dse = dseIdx
  electrics.values.ford_fd = fd
  electrics.values.ford_rd = rd

  local sig = four .. ":" .. dseIdx .. ":" .. fd .. ":" .. rd .. ":" .. tc .. ":" .. spd .. ":" .. unit
  if sig ~= lastPub then
    lastPub = sig
    obj:queueGameEngineLua(string.format("guihooks.trigger('fordControlState', {four=%d,dse=%d,fd=%d,rd=%d,tc=%d,spd=%d,unit=%d})", four, dseIdx, fd, rd, tc, spd, unit))
  end
end

local function updateGFX(dt)
  updateTrail(dt)
  publishState()
end

M.applyPowertrainMode = applyPowertrainMode
M.cycleDse = cycleDse
M.toggleDiff = toggleDiff
M.toggleTrail = toggleTrail
M.setTrail = setTrail
M.isTrailActive = function()
  return trailActive
end
M.adjustTrail = adjustTrail
M.updateGFX = updateGFX

return M
