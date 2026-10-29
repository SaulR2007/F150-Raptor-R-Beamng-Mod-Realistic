-- Trailer ABS sync: when a trailer couples to this truck, enable wheel ABS on the
-- trailer using settings matched to the F-150 custom ABS so trailer wheels don't lock.

local M = {}
M.type = "auxiliary"

local absFrequency = 100
local slipRatioTarget = 0.12
local absBehavior = "realistic"
local enabled = true

-- trailerObjId -> true while we are managing that trailer's ABS
local managedTrailers = {}
local lastTruckAbsOn = true

local function buildEnableCommand()
  -- Runs on the trailer vehicle. Backs up wheel ABS state once, then enables ABS.
  return string.format([[
    do
      if not wheels or not wheels.wheels then return end
      f150_trailerAbsSync = f150_trailerAbsSync or { refCount = 0, wheels = {} }
      local st = f150_trailerAbsSync
      st.refCount = (st.refCount or 0) + 1
      if st.refCount == 1 then
        st.wheels = {}
        for _, wd in pairs(wheels.wheels) do
          if wd and wd.name then
            st.wheels[wd.name] = {
              hasABS = wd.hasABS,
              absFrequency = wd.absFrequency,
              absTime = wd.absTime,
              slipRatioTarget = wd.slipRatioTarget
            }
            wd.hasABS = true
            wd.absFrequency = %d
            wd.absTime = 1 / %d
            wd.slipRatioTarget = %f
          end
        end
        if wheels.setABSBehavior then
          wheels.setABSBehavior(%q)
        end
        if electrics and electrics.values then
          electrics.values.f150_trailerAbsSync = 1
        end
      end
    end
  ]], absFrequency, absFrequency, slipRatioTarget, absBehavior)
end

local function buildDisableCommand()
  return [[
    do
      if not f150_trailerAbsSync then return end
      local st = f150_trailerAbsSync
      st.refCount = math.max(0, (st.refCount or 1) - 1)
      if st.refCount > 0 then return end
      if wheels and wheels.wheels and st.wheels then
        for _, wd in pairs(wheels.wheels) do
          local bak = st.wheels[wd.name]
          if bak then
            wd.hasABS = bak.hasABS
            wd.absFrequency = bak.absFrequency
            wd.absTime = bak.absTime
            wd.slipRatioTarget = bak.slipRatioTarget
          end
        end
        if wheels.resetABSBehavior then
          wheels.resetABSBehavior()
        elseif wheels.setABSBehavior then
          wheels.setABSBehavior("realistic")
        end
      end
      if electrics and electrics.values then
        electrics.values.f150_trailerAbsSync = 0
      end
      f150_trailerAbsSync = nil
    end
  ]]
end

local function buildForceOffCommand()
  -- Used when truck ABS is switched off while still coupled.
  return [[
    do
      if not f150_trailerAbsSync or not wheels or not wheels.wheels then return end
      local st = f150_trailerAbsSync
      if st.wheels then
        for _, wd in pairs(wheels.wheels) do
          local bak = st.wheels[wd.name]
          if bak then
            wd.hasABS = bak.hasABS
            wd.absFrequency = bak.absFrequency
            wd.absTime = bak.absTime
            wd.slipRatioTarget = bak.slipRatioTarget
          else
            wd.hasABS = false
          end
        end
        if wheels.resetABSBehavior then
          wheels.resetABSBehavior()
        elseif wheels.setABSBehavior then
          wheels.setABSBehavior("realistic")
        end
      end
      if electrics and electrics.values then
        electrics.values.f150_trailerAbsSync = 0
      end
    end
  ]]
end

local function buildForceOnCommand()
  return string.format([[
    do
      if not wheels or not wheels.wheels then return end
      f150_trailerAbsSync = f150_trailerAbsSync or { refCount = 1, wheels = {} }
      local st = f150_trailerAbsSync
      if not st.wheels or not next(st.wheels) then
        st.wheels = {}
        for _, wd in pairs(wheels.wheels) do
          if wd and wd.name then
            st.wheels[wd.name] = {
              hasABS = wd.hasABS,
              absFrequency = wd.absFrequency,
              absTime = wd.absTime,
              slipRatioTarget = wd.slipRatioTarget
            }
          end
        end
      end
      for _, wd in pairs(wheels.wheels) do
        if wd and wd.name then
          wd.hasABS = true
          wd.absFrequency = %d
          wd.absTime = 1 / %d
          wd.slipRatioTarget = %f
        end
      end
      if wheels.setABSBehavior then
        wheels.setABSBehavior(%q)
      end
      if electrics and electrics.values then
        electrics.values.f150_trailerAbsSync = 1
      end
    end
  ]], absFrequency, absFrequency, slipRatioTarget, absBehavior)
end

local function isTruckAbsOn()
  if not enabled then
    return false
  end
  -- Prefer electrics flag from wheels.lua; fall back to true while ABS part is fitted
  if electrics and electrics.values and electrics.values.hasABS ~= nil then
    return electrics.values.hasABS and true or false
  end
  return true
end

local function enableOnTrailer(trailerId)
  if not trailerId or trailerId == objectId then
    return
  end
  if not isTruckAbsOn() then
    managedTrailers[trailerId] = true
    return
  end
  obj:queueObjectLuaCommand(trailerId, buildEnableCommand())
  managedTrailers[trailerId] = true
end

local function disableOnTrailer(trailerId)
  if not trailerId or trailerId == objectId then
    return
  end
  if not managedTrailers[trailerId] then
    return
  end
  obj:queueObjectLuaCommand(trailerId, buildDisableCommand())
  managedTrailers[trailerId] = nil
end

local function syncAbsStateToManaged()
  local truckAbsOn = isTruckAbsOn()
  if truckAbsOn == lastTruckAbsOn then
    return
  end
  lastTruckAbsOn = truckAbsOn
  local cmd = truckAbsOn and buildForceOnCommand() or buildForceOffCommand()
  for trailerId, _ in pairs(managedTrailers) do
    obj:queueObjectLuaCommand(trailerId, cmd)
  end
end

local function onCouplerAttached(nodeId, obj2id, obj2nodeId, attachSpeed, attachEnergy)
  if not enabled then
    return
  end
  if not obj2id or obj2id == objectId then
    return
  end
  -- Only manage other vehicles (trailers / towed units), not self-latches
  enableOnTrailer(obj2id)
end

local function onCouplerDetached(nodeId, obj2id, obj2nodeId, breakForce)
  if not obj2id or obj2id == objectId then
    return
  end
  disableOnTrailer(obj2id)
end

local function updateGFX(dt)
  if not enabled then
    return
  end
  if next(managedTrailers) then
    syncAbsStateToManaged()
  end
end

local function init(jbeamData)
  enabled = jbeamData.enableTrailerAbsSync ~= false
  absFrequency = jbeamData.absFrequency or absFrequency
  slipRatioTarget = jbeamData.slipRatioTarget or slipRatioTarget
  absBehavior = jbeamData.absBehavior or absBehavior
  managedTrailers = {}
  lastTruckAbsOn = isTruckAbsOn()
end

local function reset(jbeamData)
  -- Drop tracking; trailers keep ABS until they reset themselves / reconnect
  managedTrailers = {}
  lastTruckAbsOn = isTruckAbsOn()
  init(jbeamData or {})
end

M.init = init
M.reset = reset
M.updateGFX = updateGFX
M.onCouplerAttached = onCouplerAttached
M.onCouplerDetached = onCouplerDetached

return M
