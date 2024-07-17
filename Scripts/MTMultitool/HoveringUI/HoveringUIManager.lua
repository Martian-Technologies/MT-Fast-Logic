print("loading HoveringUI")

sm.HoveringUI = sm.HoveringUI or {}
local HoveringUI = sm.HoveringUI
dofile "BaseElement.lua"
dofile "Cursor.lua"
dofile "TextButton.lua"

function HoveringUI.trigger(multitool, primaryState, secondaryState, forceBuild, lookingAt)
    HoveringUI.fovMult = sm.camera.getFov() / 90
    if HoveringUI.updateNametags == nil then
        HoveringUI.updateNametags = NametagManager.createController(multitool)
    end
    if HoveringUI.elements == nil then
        HoveringUI.elements = {}
    end
    -- cursor
    HoveringUI.Cursor.setStates(primaryState, secondaryState, forceBuild)
    HoveringUI.Cursor.update()
    -- updates
    for element, _ in pairs(HoveringUI.elements) do
        element.update(element)
    end
    -- render
    local renderDatas = {}
    for element, _ in pairs(HoveringUI.elements) do
        table.appendTable(renderDatas, element.getRenderData(element))
    end
    local tags = {}
    local camPos = sm.camera.getPosition()
    for i = 1, #renderDatas do
        local render = renderDatas[i]
        tags[#tags+1] = {
            txt = render.txt,
            color = render.color,
            pos = HoveringUI.rotation *
            (
                sm.vec3.new(25-render.pos.layer * 0.05, 0, 0)
                :rotateY(render.pos.pitch * math.pi / 90 * HoveringUI.fovMult)
                :rotateZ(render.pos.yaw * math.pi / 90 * HoveringUI.fovMult)
            ) + camPos
        }
    end
    HoveringUI.updateNametags(tags)
end

function HoveringUI.load(elements)
    HoveringUI.elements = elements
    HoveringUI.rotation = sm.quat.angleAxis(
        math.atan2(cameraDirection.y, cameraDirection.x),
        sm.vec3.new(0, 0, 1)
    )
end

function HoveringUI.clear()
    HoveringUI.load({})
end

function HoveringUI.doPointBoxCollision(pos1, pos2, width, hight)
    return (math.abs(pos1.yaw - pos2.yaw) <= width * HoveringUI.fovMult) and
           (math.abs(pos1.pitch - pos2.pitch) <= hight * HoveringUI.fovMult)
end