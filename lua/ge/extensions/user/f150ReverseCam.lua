-- Renders the bumper reverse camera into the @f150_reverse_cam texture.
-- The nav screen material samples that texture while the truck is in reverse.
local M = {}

local pending = nil

local function renderCam(vehId, target, px, py, pz, qx, qy, qz, qw, resX, resY, fov, clipN, clipF)
  pending = {
    vehId = vehId,
    target = target,
    px = px, py = py, pz = pz,
    qx = qx, qy = qy, qz = qz, qw = qw,
    resX = resX, resY = resY,
    fov = fov, clipN = clipN, clipF = clipF,
  }
end

local function onPreRender()
  local p = pending
  if not p then
    return
  end
  pending = nil

  local vehicle = be:getObjectByID(p.vehId)
  if not vehicle then
    return
  end

  vehicle:renderCameraToMaterial(
    p.target,
    vec3(p.px, p.py, p.pz),
    QuatF(p.qx, p.qy, p.qz, p.qw),
    Point2I(p.resX, p.resY),
    p.fov,
    Point2F(p.clipN, p.clipF)
  )
end

M.renderCam = renderCam
M.onPreRender = onPreRender

return M
