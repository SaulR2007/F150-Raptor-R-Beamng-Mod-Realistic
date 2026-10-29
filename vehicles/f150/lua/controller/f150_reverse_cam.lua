-- Feeds the in-cab reverse screen from three bumper nodes.
-- Move it in f150_bumper_R.jbeam: camNodes, posOffset, rotOffset, fov.
local M = {}
M.type = "auxiliary"

local geExt = "user_f150ReverseCam"
local target
local nodeIdRef, nodeIdX, nodeIdY
local posOffset = vec3()
local aimOffset = vec3()
local res = {640, 360}
local fov = 90
local clip = {0.1, 150}
local loggedError = false

local function isReversing()
  local rev = electrics.values.reverse
  if rev == true then
    return true
  end
  if type(rev) == "number" then
    return rev > 0.49
  end
  return false
end

local function nodeVec(cid)
  return vec3(obj:getNodePosition(cid))
end

local function init(jbeamData)
  jbeamData = jbeamData or {}
  target = jbeamData.texTargetName or "@f150_reverse_cam"

  local nodes = jbeamData.camNodes or {}
  nodeIdRef = beamstate.nodeNameMap[nodes.idRef or ""]
  nodeIdX = beamstate.nodeNameMap[nodes.idX or ""]
  nodeIdY = beamstate.nodeNameMap[nodes.idY or ""]

  if jbeamData.posOffset then
    posOffset:set(jbeamData.posOffset.x or 0, jbeamData.posOffset.y or 0, jbeamData.posOffset.z or 0)
  end
  if jbeamData.rotOffset then
    aimOffset:set(jbeamData.rotOffset.x or 0, jbeamData.rotOffset.y or 0, jbeamData.rotOffset.z or 0)
  end

  res = jbeamData.res or res
  fov = jbeamData.fov or fov
  clip = jbeamData.clip or clip

  obj:queueGameEngineLua("extensions.load('user_f150ReverseCam')")
end

local function updateGFX(dt)
  if not (target and nodeIdRef and nodeIdX and nodeIdY) then
    if not loggedError then
      loggedError = true
      log("E", "f150_reverse_cam", "Reverse camera nodes were not found on the rear bumper")
    end
    return
  end
  if not (isReversing() and playerInfo and playerInfo.anyPlayerSeated) then
    return
  end

  local idRef = nodeVec(nodeIdRef)
  local idX = nodeVec(nodeIdX)
  local idY = nodeVec(nodeIdY)
  local edgeX = idX - idRef
  local edgeY = idY - idX
  local camDir = edgeX:cross(edgeY)
  if camDir:squaredLength() < 1e-8 then
    return
  end
  camDir:normalize()

  local rot = quat(obj:getRotation())
  if aimOffset:squaredLength() > 1e-8 then
    camDir = camDir + aimOffset:rotated(rot)
    if camDir:squaredLength() < 1e-8 then
      return
    end
    camDir:normalize()
  end

  local camPos = vec3(obj:getPositionXYZ()) + idRef + posOffset:rotated(rot) + obj:getVelocity() * dt
  local camRot = quatFromDir(camDir, obj:getDirectionVectorUp())

  obj:queueGameEngineLua(string.format(
    "extensions.user_f150ReverseCam.renderCam(%d, '%s', %.6f, %.6f, %.6f, %.6f, %.6f, %.6f, %.6f, %d, %d, %.3f, %.3f, %.3f)",
    objectId,
    target,
    camPos.x, camPos.y, camPos.z,
    camRot.x, camRot.y, camRot.z, camRot.w,
    res[1], res[2],
    fov,
    clip[1], clip[2]
  ))
end

M.init = init
M.reset = init
M.updateGFX = updateGFX

return M
