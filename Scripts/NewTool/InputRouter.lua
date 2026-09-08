-- Converts Scrap Mechanic tool callbacks and sampled controls into one input
-- snapshot for the active NewTool mode.

NewToolInputRouter = {}

function NewToolInputRouter.init(host)
    host.InputRouter = {}
    local self = host.InputRouter

    local reloadPending = false
    local rotatePending = false
    local crouchingHeld = false

    local function isCrouching()
        return host.tool:isCrouching()
    end

    function self.queueReload()
        reloadPending = true
    end

    function self.queueRotate()
        rotatePending = true
    end

    function self.sample(dt, primaryState, secondaryState)
        local crouching = isCrouching()
        local input = {
            dt = dt,
            primaryState = primaryState,
            secondaryState = secondaryState,
            reloadPressed = reloadPending,
            rotatePressed = rotatePending,
            crouching = crouching,
            crouchPressed = crouching and not crouchingHeld,
            crouchReleased = not crouching and crouchingHeld
        }

        reloadPending = false
        rotatePending = false
        crouchingHeld = crouching
        return input
    end

    function self.reset()
        reloadPending = false
        rotatePending = false
        crouchingHeld = isCrouching()
    end
end
