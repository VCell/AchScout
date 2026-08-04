local _, AchScout = ...
local L = AchScout.Locale

Logger = {
    debug = false
}

function Logger:SetDebug(debug)
    self.debug = debug
end

function Logger:Debug(msg)
    if self.debug then
        DEFAULT_CHAT_FRAME:AddMessage(L.DEBUG_PREFIX .. msg)
    end
end

function Logger:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(L.DEBUG_PREFIX .. msg)
end

AchScout.Logger = Logger