-- The only NewTool component that writes Scrap Mechanic interaction text.
-- Callers submit plain text with a priority; the highest-priority prompt for
-- the frame is presented when flush() is called by the tool host.

PromptPresenter = {}

function PromptPresenter.init(tool)
    tool.PromptPresenter = {}
    local self = tool.PromptPresenter
    local pending = nil
    local sequence = 0

    function self.beginFrame()
        pending = nil
        sequence = 0
    end

    function self.show(text, priority)
        sequence = sequence + 1
        local candidate = {
            text = tostring(text or ""),
            priority = priority or 0,
            sequence = sequence
        }
        if pending == nil or candidate.priority > pending.priority or
            (candidate.priority == pending.priority and candidate.sequence > pending.sequence) then
            pending = candidate
        end
    end

    function self.flush()
        if pending == nil then
            sm.gui.setInteractionText("")
            return
        end
        sm.gui.setInteractionText(
            "<p textShadow='false' bg='gui_keybinds_bg' color='#ffffff' spacing='4'>" ..
            pending.text .. "</p>"
        )
    end

    function self.clear()
        pending = nil
        sm.gui.setInteractionText("")
    end
end
