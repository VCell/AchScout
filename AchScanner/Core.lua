-- AchScanner
-- 采样统计成就完成率的简易插件
-- 核心机制参考自 AchievementTeamChecker（SetAchievementComparisonUnit /
-- INSPECT_ACHIEVEMENT_READY / GetAchievementComparisonInfo 这套已验证的流程）

local AS = {
    eventFrame = nil,
    debug = false,

    -- 节流：两次请求之间的最小间隔（秒）。太快连续请求，
    -- SetAchievementComparisonUnit 大概率会被服务器丢弃或延迟。
    THROTTLE_SECONDS = 2.5,
    lastRequestTime = 0,

    -- 单次查询的超时时间（秒）
    QUERY_TIMEOUT = 3,

    -- 全部成就ID列表缓存，首次采样时构建
    achievementIDs = nil,

    -- 当前进行中的查询：{ unit = "target", guid = "0x...", timeout = timerHandle }
    pending = nil,
}

--------------------------------------------------------------------------------
-- 初始化 / SavedVariables
--------------------------------------------------------------------------------

local function EnsureDB()
    AchScannerDB = AchScannerDB or {}
    AchScannerDB.stats = AchScannerDB.stats or {}     -- [achievementID] = { completed = n, total = n }
    AchScannerDB.sampled = AchScannerDB.sampled or {} -- [guid] = true，用于跨会话去重
    AchScannerDB.sampleCount = AchScannerDB.sampleCount or 0
end

function AS:Init()
    EnsureDB()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("INSPECT_ACHIEVEMENT_READY")
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "INSPECT_ACHIEVEMENT_READY" then
            self:INSPECT_ACHIEVEMENT_READY(...)
        end
    end)
end

--------------------------------------------------------------------------------
-- 成就ID列表构建（与参考插件搜索功能用的是同一套遍历方式）
--------------------------------------------------------------------------------

function AS:BuildAchievementIDList()
    local ids = {}
    local categories = GetCategoryList()
    for _, catID in ipairs(categories) do
        local num = GetCategoryNumAchievements(catID) or 0
        for index = 1, num do
            local id = GetAchievementInfo(catID, index)
            if id then
                ids[#ids + 1] = id
            end
        end
    end
    return ids
end

function AS:GetAchievementIDList()
    if not self.achievementIDs then
        self.achievementIDs = self:BuildAchievementIDList()
        self:Print(string.format("已构建成就列表，共 %d 项。", #self.achievementIDs))
    end
    return self.achievementIDs
end

--------------------------------------------------------------------------------
-- 采样入口
--------------------------------------------------------------------------------

-- unit: "target" / "mouseover" / 具体unitID，默认 "target"
function AS:Sample(unit)
    unit = unit or "target"

    if self.pending then
        self:Print("上一次查询还未完成，请稍候再试。")
        return
    end

    if not UnitExists(unit) then
        self:Print("目标不存在。")
        return
    end
    if not UnitIsPlayer(unit) then
        self:Print("目标不是玩家，跳过。")
        return
    end
    if UnitIsUnit(unit, "player") then
        self:Print("目标是你自己，跳过。")
        return
    end
    if not UnitIsConnected(unit) then
        self:Print("目标不在线，跳过。")
        return
    end

    local guid = UnitGUID(unit)
    if not guid then
        self:Print("无法获取目标GUID，跳过。")
        return
    end

    if AchScannerDB.sampled[guid] then
        self:Print("该玩家已经采样过，跳过（去重）。")
        return
    end

    local now = GetTime()
    if now - self.lastRequestTime < self.THROTTLE_SECONDS then
        self:Print(string.format("请求过于频繁，请 %.1f 秒后再试。",
            self.THROTTLE_SECONDS - (now - self.lastRequestTime)))
        return
    end
    self.lastRequestTime = now

    -- 提前构建好成就列表，避免拿到对比数据后才现场遍历分类耗时导致数据过期
    self:GetAchievementIDList()

    ClearAchievementComparisonUnit()
    local success = SetAchievementComparisonUnit(unit)
    self:Debug(string.format("SetAchievementComparisonUnit unit:%s guid:%s res:%s", unit, guid, tostring(success)))

    if not success then
        self:Print("发起对比请求失败（可能距离太远/不同阵营/无法检视），跳过。")
        return
    end

    self.pending = { unit = unit, guid = guid }
    self.pending.timeout = C_Timer.After(self.QUERY_TIMEOUT, function()
        if self.pending and self.pending.guid == guid then
            self:Debug("查询超时: " .. guid)
            self:Print("查询超时，未获取到数据。")
            ClearAchievementComparisonUnit()
            self.pending = nil
        end
    end)
end

--------------------------------------------------------------------------------
-- 事件回调：对比数据就绪
--------------------------------------------------------------------------------

function AS:INSPECT_ACHIEVEMENT_READY(guid)
    if not self.pending or guid ~= self.pending.guid then
        -- 不是我们发起的这次查询（比如成就界面本身也在用这套API），忽略
        return
    end

    local unit = self.pending.unit
    self.pending = nil -- 提前清空，避免下面处理过程中又触发一次早退

    local ids = self:GetAchievementIDList()
    local stats = AchScannerDB.stats

    for _, id in ipairs(ids) do
        local isCompleted = GetAchievementComparisonInfo(id)
        local s = stats[id]
        if not s then
            s = { completed = 0, total = 0 }
            stats[id] = s
        end
        s.total = s.total + 1
        if isCompleted then
            s.completed = s.completed + 1
        end
    end

    AchScannerDB.sampled[guid] = true
    AchScannerDB.sampleCount = AchScannerDB.sampleCount + 1

    ClearAchievementComparisonUnit()

    local name = GetUnitName(unit, true) or guid
    self:Print(string.format("采样完成：%s（累计样本数 %d）", name, AchScannerDB.sampleCount))
end

--------------------------------------------------------------------------------
-- 简单报表 / 维护命令
--------------------------------------------------------------------------------

function AS:Report()
    EnsureDB()
    local total = AchScannerDB.sampleCount
    local numAch = 0
    for _ in pairs(AchScannerDB.stats) do numAch = numAch + 1 end
    self:Print(string.format("当前样本数: %d，已记录数据的成就数: %d", total, numAch))
    self:Print("完整数据在 WTF/.../SavedVariables/AchScanner.lua 中（AchScannerDB.stats）。")
end

function AS:ResetConfirm()
    self:Print("确认要清空所有采样数据吗？输入 /ascan resetconfirm 执行。此操作不可撤销。")
end

function AS:Reset()
    AchScannerDB = { stats = {}, sampled = {}, sampleCount = 0 }
    self:Print("采样数据已清空。")
end

--------------------------------------------------------------------------------
-- 工具函数
--------------------------------------------------------------------------------

function AS:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[AchScanner]|r " .. tostring(msg))
end

function AS:Debug(msg)
    if self.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cff888888[AchScanner-Debug]|r " .. tostring(msg))
    end
end

--------------------------------------------------------------------------------
-- 启动
--------------------------------------------------------------------------------

local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function()
    AS:Init()
end)

--------------------------------------------------------------------------------
-- Slash 命令
--------------------------------------------------------------------------------

SLASH_ACHSCANNER1 = "/ascan"
SlashCmdList["ACHSCANNER"] = function(msg)
    msg = string.lower(string.match(msg or "", "^%s*(.-)%s*$"))

    if msg == "" or msg == "target" then
        AS:Sample("target")
    elseif msg == "mouseover" then
        AS:Sample("mouseover")
    elseif msg == "report" then
        AS:Report()
    elseif msg == "reset" then
        AS:ResetConfirm()
    elseif msg == "resetconfirm" then
        AS:Reset()
    elseif msg == "debug" then
        AS.debug = not AS.debug
        AS:Print("调试模式: " .. tostring(AS.debug))
    else
        AS:Print("用法:")
        AS:Print("  /ascan 或 /ascan target - 采样当前目标")
        AS:Print("  /ascan mouseover        - 采样鼠标指向的单位")
        AS:Print("  /ascan report           - 查看当前统计概况")
        AS:Print("  /ascan reset            - 清空数据（需二次确认）")
        AS:Print("  /ascan debug            - 切换调试输出")
    end
end

_G.AchScanner = AS