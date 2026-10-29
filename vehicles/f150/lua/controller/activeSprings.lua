-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.type = "auxiliary"

local springHydro
local springBeamNames = {}
local springBeams = {}
local springModes = {}
local currentSpringMode = nil

local function collectBeams()
  springBeams = {}
  for _, b in pairs(v.data.beams) do
    if b.name then
      for _, name in pairs(springBeamNames) do
        if b.name == name then
          table.insert(springBeams, b.cid)
        end
      end
    end
  end
end

local function loadModes(jbeamData)
  springModes = {}
  for _, mode in pairs(tableFromHeaderTable(jbeamData.modes or {})) do
    springModes[mode.name] = {
      springLengthCoef = mode.springLengthCoef or 1,
      beamSpringCoef = mode.beamSpringCoef or 1
    }
  end
end

local function configure(jbeamData)
  springHydro = jbeamData.springHydro or springHydro or "springHydro"
  springBeamNames = jbeamData.springBeamNames or springBeamNames or {}
  collectBeams()
  loadModes(jbeamData)
end

local function setSpringsMode(modeName)
  local mode = springModes[modeName]
  if not mode then
    log("E", "activeSprings.setSpringsMode", "Can't find mode: " .. tostring(modeName))
    return
  end

  for _, cid in ipairs(springBeams) do
    local beam = v.data.beams[cid]
    if beam then
      obj:setBeamSpringDamp(cid, beam.beamSpring * mode.beamSpringCoef, -1, beam.beamDamp, -1)
    end
  end

  electrics.values[springHydro] = mode.springLengthCoef
  currentSpringMode = modeName
end

local function init(jbeamData)
  configure(jbeamData)
  currentSpringMode = nil
end

local function reset(jbeamData)
  configure(jbeamData)
  currentSpringMode = nil
end

local function setParameters(parameters)
  if parameters.springMode then
    setSpringsMode(parameters.springMode)
  end
end

M.init = init
M.reset = reset
M.setParameters = setParameters

return M
