local M = {}
M.type = "auxiliary"

-- list of per-diff state tables, filled from JBeam
local diffs = {}

-- how fast abuse decays when you're not actively abusing it
local abuseCooldownFactor = 0.25

-- Groundmodels we consider "solid / paved"
-- Names must match map groundmodel names (uppercase for easy compare)
local solidGroundmodels = {
  ASPHALT          = true,
  ASPHALT_OLD      = true,
  ASPHALT1         = true,
  ASPHALT_WET2     = true,
  ASPHALT_WET3     = true,
  CONCRETE         = true,
  CONCRETE2        = true,
  COBBLESTONE      = true,
  BRICK            = true,
}

-- Try to get some name/id for the surface under this wheel.
-- You MAY need to tweak this based on what fields actually exist;
-- check in-game with:  dump(wheels.wheels[0])
local function getWheelGroundmodelName(w)
  if not w then return nil end

  -- These field names are "best guess" and may differ a bit per version.
  -- Adjust to whatever you see in dump(wheels.wheels[i]).
  local gm = w.groundModelName or
             w.lastGroundModelName or
             w.surfaceType or
             w.lastSurfaceType or
             nil

  if not gm then return nil end
  return tostring(gm):upper()
end

local function wheelOnSolidSurface(idx)
  local w = wheels.wheels[idx]
  if not w then return false end

  local gmName = getWheelGroundmodelName(w)
  if not gmName then
    return false
  end

  return solidGroundmodels[gmName] == true
end

local function init(jbeamData)
  diffs = {}

  local cfgList = jbeamData.diffs or {}

  -- allow single-diff config too
  if #cfgList == 0 and jbeamData.diffDeviceName then
    cfgList = { jbeamData }
  end

  for _, cfg in ipairs(cfgList) do
    table.insert(diffs, {
      name              = cfg.diffDeviceName      or "rearDiff",
      lockElectricsName = cfg.lockElectricsName   or "diff_lock",
      wheelIndexA       = cfg.wheelIndexA         or 0,
      wheelIndexB       = cfg.wheelIndexB         or 1,
      minSpeed          = cfg.minSpeed            or 5.0,   -- m/s
      minSteer          = cfg.minSteer            or 0.05,
      damageThreshold   = cfg.damageThreshold     or 6.0,   -- "seconds of abuse"
      damagePerSecond   = cfg.damagePerSecond     or 1.0,
      abuse             = 0.0,
    })
  end
end

local function updateGFX(dt)
  if not diffs or #diffs == 0 then return end

  local speed    = electrics.values.wheelspeed or 0
  local steer    = electrics.values.steering   or 0
  local throttle = electrics.values.throttle  or 0

  for _, d in ipairs(diffs) do
    local lockVal = electrics.values[d.lockElectricsName] or 0

    -- if diff unlocked -> bleed off abuse and skip
    if lockVal < 0.5 then
      d.abuse = math.max(0, d.abuse - dt * d.damagePerSecond * abuseCooldownFactor)
      goto continue
    end

    -- need some real load: moving, turning, some throttle
    if speed < d.minSpeed or math.abs(steer) < d.minSteer or throttle < 0.1 then
      d.abuse = math.max(0, d.abuse - dt * d.damagePerSecond * abuseCooldownFactor)
      goto continue
    end

    -- only punish on solid surfaces (for that diff’s axle wheels)
    local solidA = wheelOnSolidSurface(d.wheelIndexA)
    local solidB = wheelOnSolidSurface(d.wheelIndexB)

    if not (solidA or solidB) then
      -- dirt / mud / rocks = allowed, cool down
      d.abuse = math.max(0, d.abuse - dt * d.damagePerSecond * abuseCooldownFactor)
      goto continue
    end

    local wA = wheels.wheels[d.wheelIndexA]
    local wB = wheels.wheels[d.wheelIndexB]
    if not wA or not wB then
      goto continue
    end

    local avA = wA.angularVelocity or 0
    local avB = wB.angularVelocity or 0
    local diffAV = math.abs(avA - avB)

    -- if the two sides are fighting each other, build abuse
    if diffAV > 1.0 then
      d.abuse = d.abuse + dt * d.damagePerSecond
    else
      d.abuse = math.max(0, d.abuse - dt * d.damagePerSecond * abuseCooldownFactor)
    end

    if d.abuse >= d.damageThreshold then
      local dev = powertrain.getDevice(d.name)
      if dev then
        log("I", "diff_lock_damage",
          string.format("Breaking diff '%s' due to locked-diff abuse on solid surface", tostring(d.name)))
        powertrain.breakDevice(dev)
      end
      d.abuse = 0
    end

    ::continue::
  end
end

M.init      = init
M.updateGFX = updateGFX

return M
