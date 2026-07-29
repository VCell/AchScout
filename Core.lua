-- AchievementTeamChecker
local L = _G.ATCLocale
local ATC = {
    achievementButtons = {},
    eventFrame = nil,
    isHooked = false,
    queryState = nil, 
    debug = false,
    MESSAGE_DELAY = 0.5,
    searchText = "",
    currentCategory = nil, -- 当前浏览的分类，通过AchievementButton_DisplayAchievement间接记录
    searchCategory = nil,  -- searchResults缓存对应的分类
    searchQuery = nil,     -- searchResults缓存对应的搜索词
    searchResults = {}     -- 当前搜索词在currentCategory下匹配到的成就序号列表（有序）
}

-- 初始化
function ATC:Init()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("PLAYER_LOGIN")
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        self[event](self, ...)
    end)
end

-- 初始化
function ATC:SetDebug(debug)
    self.debug = debug
end

-- 玩家登录后开始尝试Hook成就界面
function ATC:PLAYER_LOGIN()
    self:HookAchievementUI()
    
    -- -- 定期检查成就界面是否加载
    -- C_Timer.NewTicker(5, function()
    --     if not self.isHooked and AchievementFrame and AchievementFrame:IsShown() then
    --         self:HookAchievementUI()
    --     end
    -- end)
end


-- QueryState 构造函数
function ATC:CreateQueryState(query)
    return {
        pendingQueries = {},  -- 待查询的玩家列表 
        totalMembers = 0,     -- 总团队成员数
        currentTimeout = nil, -- 当前查询的超时计时器
        overallTimeout = nil, -- 整体查询的超时计 时器
        currentUnit = nil,    -- 用于unit超时的判断
        isQuerying = false,   -- 用于总体超时的判断
        queryContent = query, 
    }
end

-- Hook 成就界面
function ATC:HookAchievementUI()
    if self.isHooked or not AchievementFrame then
        return
    end
    
    -- 方法1: 直接Hook成就按钮显示函数
    local achievementsFrame = AchievementFrame
    if achievementsFrame then 
        self:AddOverviewButton(achievementsFrame)
        self:AddSearchBox(achievementsFrame)
    else 
        self.Print("AddOverviewButton Failed")
    end

    if AchievementButton_DisplayAchievement then
        hooksecurefunc("AchievementButton_DisplayAchievement", function(button, category, achievement)
            -- AchievementFrame上没有selectedCategory字段，借助每次渲染的category间接记录"当前浏览的分类"
            self.currentCategory = category
            self:AddQueryButtonToAchievement(button, category, achievement)
        end)
        self:InstallCustomAchievementsUpdate()
        self.isHooked = true
        self:Print(L.ADDON_LOADED)
        return
    end
    
    -- -- 方法2: 监听成就框架显示事件
    -- self.eventFrame:RegisterEvent("ACHIEVEMENT_EARNED")
    -- self.eventFrame:SetScript("OnEvent", function(_, event, ...)
    --     if event == "ACHIEVEMENT_EARNED" then
    --         if AchievementFrame and AchievementFrame:IsVisible() then
    --             self:DelayHook()
    --         end
    --     elseif event == "INSPECT_ACHIEVEMENT_READY" then
    --         self:INSPECT_ACHIEVEMENT_READY(...)
    --     end
    -- end)
end

-- 接管 AchievementFrameAchievements_Update：
-- 暴雪在 AchievementFrameAchievements_OnLoad 里把这个函数的引用保存进了
-- AchievementFrameAchievementsContainer.update 字段，滚轮/拖动滚动条实际调用的是这个字段，
-- 不是函数名本身；所以两处都要指向同一个包装函数，否则滚动不会触发我们的过滤渲染。
function ATC:InstallCustomAchievementsUpdate()
    if self.originalAchievementsUpdate then
        return -- 已安装过
    end
    if not AchievementFrameAchievements_Update then
        return
    end

    self.originalAchievementsUpdate = AchievementFrameAchievements_Update

    local wrapper = function(...)
        if ATC.searchText ~= "" then
            ATC:RenderFilteredAchievements()
        else
            ATC.originalAchievementsUpdate(...)
        end
    end

    AchievementFrameAchievements_Update = wrapper
    if AchievementFrameAchievementsContainer then
        AchievementFrameAchievementsContainer.update = wrapper
    end
end

-- 搜索状态下，自己维护一份"当前分类里匹配搜索词的成就序号列表"，
-- 滚动条范围/每一行显示哪个成就都按这份列表来算，而不是暴雪原本的"分类里的原始顺序"。
function ATC:RenderFilteredAchievements()
    local category = self.currentCategory
    local scrollFrame = AchievementFrameAchievementsContainer
    if not category or not scrollFrame or not scrollFrame.buttons then
        return
    end

    -- 分类或搜索词变化时才重新扫描整个分类；同一个词连续触发（比如滚动）时直接复用缓存
    if self.searchCategory ~= category or self.searchQuery ~= self.searchText then
        self.searchCategory = category
        self.searchQuery = self.searchText
        self.searchResults = {}
        local total = GetCategoryNumAchievements(category) or 0
        for index = 1, total do
            local id, name, _, _, _, _, _, description = GetAchievementInfo(category, index)
            if id and self:MatchesSearch(name, description) then
                table.insert(self.searchResults, index)
            end
        end
    end

    local offset = HybridScrollFrame_GetOffset(scrollFrame)
    local buttons = scrollFrame.buttons
    local numButtons = #buttons
    local numResults = #self.searchResults
    local selection = AchievementFrameAchievements and AchievementFrameAchievements.selection
    local rowHeight = ACHIEVEMENTBUTTON_COLLAPSEDHEIGHT or 84
    local displayedHeight = 0
    local extraHeight = 0 -- 展开详情的那一行会比默认行高高出一截，要单独补进totalHeight，否则可滚动区域不够，详情会被裁掉

    for i = 1, numButtons do
        local achievementIndex = self.searchResults[i + offset]
        if achievementIndex then
            AchievementButton_DisplayAchievement(buttons[i], category, achievementIndex, selection)
            local buttonHeight = buttons[i]:GetHeight()
            displayedHeight = displayedHeight + buttonHeight
            if buttonHeight > rowHeight then
                extraHeight = extraHeight + (buttonHeight - rowHeight)
            end
        else
            buttons[i]:Hide()
        end
    end

    local totalHeight = numResults * rowHeight + extraHeight
    HybridScrollFrame_Update(scrollFrame, totalHeight, displayedHeight)
end


function ATC:MatchesSearch(name, description)
    if self.searchText == "" then
        return true
    end
    local haystack = string.lower((name or "") .. "\n" .. (description or ""))
    return string.find(haystack, self.searchText, 1, true) ~= nil
end


function ATC:ShowAchievementSearch(text)
    self.searchText = string.lower(string.match(text or "", "^%s*(.-)%s*$"))

    -- 搜索词一变，之前的滚动位置就没意义了（尤其是从"过滤结果"切回"完整列表"，
    -- 或者反过来），统一归零，避免看起来像是卡住或跳到奇怪的位置
    if AchievementFrameAchievementsContainerScrollBar then
        AchievementFrameAchievementsContainerScrollBar:SetValue(0)
    end

    -- 强制让列表重新走一遍渲染流程：
    -- 搜索词非空时，AchievementFrameAchievements_Update 已经被替换成我们的 RenderFilteredAchievements；
    -- 搜索词为空时会自动落回暴雪原本的逻辑（见 InstallCustomAchievementsUpdate）
    if AchievementFrameAchievements_ForceUpdate then
        AchievementFrameAchievements_ForceUpdate()
    elseif AchievementFrameAchievements_Update then
        AchievementFrameAchievements_Update()
    end
end

function ATC:AddSearchBox(parentFrame)
    if parentFrame.atcSearchBox then
        return
    end

    local searchBox = CreateFrame("EditBox", nil, parentFrame, "InputBoxTemplate")
    searchBox:SetSize(80, 20)
    searchBox:SetPoint("LEFT", parentFrame.featButton, "RIGHT", 8, 0)
    searchBox:SetFrameStrata("HIGH")
    searchBox:SetFrameLevel(parentFrame:GetFrameLevel() + 10)
    searchBox:SetToplevel(true)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(80)
    searchBox:SetTextInsets(6, 6, 0, 0)

   -- 用输入框内的浅色提示字代替原来悬浮在框上方的标签，省一行空间，也更符合原生输入框的观感
    -- 注意：不要用 ARTWORK 层，InputBoxTemplate自带的边框贴图也在这一层，子层级顺序没保证的话会被盖住；
    -- 用 OVERLAY 层（比 BACKGROUND/BORDER/ARTWORK 都高）确保稳定盖在输入框贴图之上
    local placeholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    placeholder:SetPoint("LEFT", searchBox, "LEFT", 8, 0)
    placeholder:SetJustifyH("LEFT")
    placeholder:SetTextColor(0.6, 0.6, 0.6, 1)
    placeholder:SetText(L.SEARCH_LABEL)

    local function UpdatePlaceholder()
        if searchBox:GetText() == "" and not searchBox:HasFocus() then
            placeholder:Show()
        else
            placeholder:Hide()
        end
    end
    searchBox:HookScript("OnEditFocusGained", UpdatePlaceholder)
    searchBox:HookScript("OnEditFocusLost", UpdatePlaceholder)
    UpdatePlaceholder()

    searchBox:SetScript("OnTextChanged", function(box, userInput)
        UpdatePlaceholder()
        if userInput then
            ATC:ShowAchievementSearch(box:GetText())
        end
    end)
    searchBox:SetScript("OnEscapePressed", function(box)
        box:SetText("")
        box:ClearFocus()
        -- box:SetText("")触发的OnTextChanged里userInput是false，不会走ShowAchievementSearch，
        -- 这里显式同步一次，避免"框显示是空的，但self.searchText还是旧值、过滤仍然生效"这种状态不一致
        ATC:ShowAchievementSearch("")
    end)
    searchBox:SetScript("OnEnterPressed", function(box)
        box:ClearFocus()
    end)
    parentFrame.atcSearchBox = searchBox
end

-- 延迟Hook以确保界面完全加载
function ATC:DelayHook()
    C_Timer.After(0.5, function()
        if not self.isHooked and AchievementButton_DisplayAchievement then
            hooksecurefunc("AchievementButton_DisplayAchievement", function(button, category, achievement)
                ATC:AddQueryButtonToAchievement(button, category, achievement)
            end)
            self.isHooked = true
            self:Print(L.ADDON_LOADED_DELAYHOOK)
        end
    end)
end

-- 添加查询按钮到成就；同时承担"按搜索词过滤显示"的职责：
-- 成就列表(AchievementFrameAchievementsContainer)是 HybridScrollFrame，每一行是链式锚点
-- （下一行的TOP锚定在上一行的BOTTOM），且暴雪自己统计可视高度时用的是button:GetHeight()的实时值。
-- 所以不匹配的行不能只Hide()（Hide不影响锚点占位），还要把高度缩到接近0，
-- 这样链式锚点会让后面的行自动贴上来，消除空白间隙。
function ATC:AddQueryButtonToAchievement(button, category, achievement)
    if not button or not achievement or self.isHooked == false then return end

    local id, name, _, completed, _, _, _, description, _, icon, _, _, wasEarnedByMe = GetAchievementInfo(category, achievement)
    if not id then return end

    if not self:MatchesSearch(name, description) then
        button:SetHeight(1)
        button:Hide()
        if button.atcOthersMarker then
            button.atcOthersMarker:Hide()
        end
        return
    end

    -- 匹配的行：如果它不是当前正展开看详情的成就，强制恢复成标准行高
    -- （正常情况暴雪自己的DisplayAchievement也会重置，这里是保险，防止残留上一次搜索时缩小的高度）
    local isExpandedSelection = AchievementFrameAchievements and AchievementFrameAchievements.selection == id
    if not isExpandedSelection and ACHIEVEMENTBUTTON_COLLAPSEDHEIGHT then
        button:SetHeight(ACHIEVEMENTBUTTON_COLLAPSEDHEIGHT)
    end

    ATC:Debug(string.format("AddQueryButtonToAchievement name:%s category:%s achievement:%s",name, tostring(category), tostring(achievement)))
    button.description:SetText(description..' ID: '..id)
    
    -- 创建查询按钮
    local queryButton = button.queryButton
    if not queryButton then
        queryButton = CreateFrame("Button", nil, button, "UIPanelButtonTemplate")
        queryButton:SetSize(80, 22)
        queryButton:SetText(L.QUERY_BUTTON)
        queryButton:SetPoint("TOPRIGHT", button, "TOPRIGHT", -75, -5)
        queryButton:SetFrameLevel(button:GetFrameLevel() + 1)
        queryButton:SetToplevel(true)
        
        -- 悬停提示
        queryButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L.QUERY_BUTTON_TOOLTIP_TITLE)
            GameTooltip:AddLine(L.QUERY_BUTTON_TOOLTIP_DESC, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        
        queryButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        button.queryButton = queryButton
    end
    queryButton:SetScript("OnClick", function()
        local query = ATC:CreateCompleteQuery(id, name)
        ATC:QueryTeamAchievement(query)
    end)
    queryButton:Show()

    -- 标记"账号下其他角色完成、但当前角色未完成"的成就：在成就项最右侧加一个红色色块
    self:MarkOthersCompleted(button, completed, wasEarnedByMe)
end

-- 给"已完成，但不是当前角色完成的（账号下其他角色完成）"成就，在成就项最右侧添加一个
-- 70x70的红色色块作为标记；未命中该条件时隐藏（这个button控件会在滚动时被不同成就复用，
-- 所以色块也要复用、不能重复创建）
function ATC:MarkOthersCompleted(button, completed, wasEarnedByMe)
    local marker = button.atcOthersMarker
    if not marker then
        marker = CreateFrame("Frame", nil, button)
        marker:SetSize(70, 70)
        marker:SetPoint("RIGHT", button, "RIGHT", -5, 0)
        marker:SetFrameLevel(button:GetFrameLevel())
        marker:EnableMouse(false) -- 不拦截鼠标事件，避免挡住成就项本身的点击/悬停

        local tex = marker:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints(marker)
        tex:SetColorTexture(1, 0, 0, 0.5)
        marker.texture = tex

        button.atcOthersMarker = marker
    end

    if completed and not wasEarnedByMe then
        marker:Show()
    else
        marker:Hide()
    end
end

--测试
function ATC:AddOverviewButton(parentFrame)
    -- 创建团队检查按钮
    local pointsButton = CreateFrame("Button", nil, parentFrame, "UIPanelButtonTemplate")
    pointsButton:SetSize(80, 22)
    pointsButton:SetText(L.POINTS_RANK_BUTTON)
    pointsButton:SetFrameStrata("HIGH")
    pointsButton:SetToplevel(true)
    pointsButton:SetPoint("TOP", AchievementFrame, "TOP", -15, -10)
    pointsButton:SetScript("OnClick", function()
        local query = ATC:CreatePointQuery()
        ATC:QueryTeamAchievement(query)
    end)
    pointsButton:SetNormalFontObject("GameFontNormal")
    pointsButton:SetHighlightFontObject("GameFontHighlight")
    pointsButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.POINTS_RANK_TOOLTIP_TITLE)
        GameTooltip:AddLine(L.POINTS_RANK_TOOLTIP_DESC, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    
    pointsButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    pointsButton:Show()

    local featButton = CreateFrame("Button", nil, parentFrame, "UIPanelButtonTemplate")
    featButton:SetSize(80, 22)
    featButton:SetText(L.FEAT_RANK_BUTTON)
    featButton:SetFrameStrata("HIGH")
    featButton:SetToplevel(true)
    featButton:SetPoint("LEFT", pointsButton, "RIGHT", 0, 0) -- 放在点数按钮右边
    featButton:SetScript("OnClick", function()
        local query = ATC:CreateFeatQuery()
        ATC:QueryTeamAchievement(query)
    end)
    featButton:SetNormalFontObject("GameFontNormal")
    featButton:SetHighlightFontObject("GameFontHighlight")
    featButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.FEAT_RANK_TOOLTIP_TITLE)
        GameTooltip:AddLine(L.FEAT_RANK_TOOLTIP_DESC, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    
    featButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    featButton:Show()
    parentFrame.featButton = featButton

end

-- 注册成就检查事件
function ATC:RegisterAchievementEvents()
    self.eventFrame:RegisterEvent("INSPECT_ACHIEVEMENT_READY")
end

-- 成就数据就绪事件
function ATC:INSPECT_ACHIEVEMENT_READY(guid)
    ATC:Debug("INSPECT_ACHIEVEMENT_READY ".. guid)
    if not self.queryState then return end

    local query = self.queryState
    local unit = query.currentUnit
    
    if unit and guid == UnitGUID(unit) then
        -- 取消当前单位的超时计时器
        if query.currentTimeout then
            query.currentTimeout:Cancel()
            query.currentTimeout = nil
        end

        query.queryContent:FetchResult(unit)

        query.currentUnit = nil
        self:StartNextQuery()
    else
        ATC:Debug("INSPECT_ACHIEVEMENT_READY ERROR GUID:".. guid)
    end

end

-- 查询团队成就
function ATC:QueryTeamAchievement(queryContent)
    if not IsInGroup() and not IsInRaid() then
        self:Print(L.NOT_IN_GROUP)
        return
    end
    if self.queryState ~= nil then
        self:Print(L.QUERY_IN_PROGRESS)
        return
    end

    ATC:Debug(string.format("QueryTeamAchievement start"))
    -- 重置状态

    self:RegisterAchievementEvents()
    
    local unitPrefix = IsInRaid() and "raid" or "party"
    local numGroupMembers = GetNumGroupMembers()
    
    self.queryState = ATC:CreateQueryState(queryContent)
    local query = self.queryState
    query.totalMembers = numGroupMembers
    
    -- 检查自己
    query.queryContent:QueryForPlayer()

    -- 构建待查询列表 
    for i = 1, numGroupMembers do
        local unit = unitPrefix .. i
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            table.insert(query.pendingQueries, unit)
        end
    end
    -- ATC:Debug("QueryTeamAchievement  pendingQueries count :"..tostring(#(self.queryState.pendingQueries)))

    if #query.pendingQueries <= 0 then
        -- 没有其他玩家需要查询，直接报告结果
        self:ReportResults()
    else
        query.isQuerying = true
        self:Print(L.QUERY_START)
        self:StartNextQuery()
        
        -- 设置总超时（备用，防止某些情况下查询卡住）
        query.overallTimeout = C_Timer.After(30, function()
            if query.isQuerying then
                self:Debug("查询总超时，强制结束查询")
                self:ReportResults(true)
            end
        end)
    end
end

-- 开始下一个查询
function ATC:StartNextQuery()
    ATC:Debug("StartNextQuery")
    local query = self.queryState
    ClearAchievementComparisonUnit()
    
    if #query.pendingQueries == 0 then
        self:ReportResults()
        return
    end
    
    local unit = table.remove(query.pendingQueries, 1)
    query.currentUnit = unit
    
    -- 设置成就比较单位
    local success = false
    if UnitIsConnected(unit) then 
        success = SetAchievementComparisonUnit(unit)
        ATC:Debug(string.format("SetAchievementComparisonUnit unit:%s res:%s", unit, tostring(success)))
    end
    
    if success then
        -- 为当前查询设置单独的超时（3秒）
        query.currentTimeout = C_Timer.After(3, function()
            if query.currentUnit == unit then
                ATC:Debug(string.format("查询超时: %s", unit))
                local name = GetUnitName(unit, true)
                query.queryContent:OnQueryFailed(name .. L.QUERY_TIMEOUT_SUFFIX)
                query.currentUnit = nil
                query.currentTimeout = nil
                self:StartNextQuery()
            end
        end)
    else
        -- 设置失败，直接视为未完成
        local name = GetUnitName(unit, true)
        query.queryContent:OnQueryFailed(name .. L.QUERY_FAILED_SUFFIX)
        query.currentUnit = nil
        self:StartNextQuery()
    end
end


-- 报告结果
function ATC:ReportResults(isTimeout)
    ATC:Debug("ReportResults")
    if not self.queryState then return end
    
   local query = self.queryState
    
    -- 清理状态
    if query.currentTimeout then
        query.currentTimeout:Cancel()
        query.currentTimeout = nil
    end
    if query.overallTimeout then
        query.overallTimeout:Cancel()
        query.overallTimeout = nil
    end
    
    ClearAchievementComparisonUnit()
    query.isQuerying = false
    query.currentUnit = nil

    self.queryState = nil
    
    local messages = query.queryContent:GetReport()
    ATC:Debug(tostring(messages))

    local chatType = IsInRaid() and "RAID" or "PARTY"

    for i, message in ipairs(messages) do
        C_Timer.After((i-1) * self.MESSAGE_DELAY, function()
            self:SafeSendChatMessage(message, chatType)
        end)
    end

end

function ATC:SafeSendChatMessage(message, chatType)
    local success, err = pcall(SendChatMessage, message, chatType)
    if not success then
        self:Print(L.SEND_FAILED_PREFIX .. tostring(err)) 
        self:Print(L.GROUP_MESSAGE_PREFIX .. message)
        return false
    end
    return true
end

-- 打印消息
function ATC:Debug(msg)
    if self.debug then 
       DEFAULT_CHAT_FRAME:AddMessage(L.DEBUG_PREFIX .. msg)
    end
end

-- 打印消息
function ATC:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(L.PRINT_PREFIX .. msg)
end  

-- 初始化插件
ATC:Init()

-- Slash 命令
SLASH_ACHIEVEMENTTEAMCHECKER1 = "/atc"
SlashCmdList["ACHIEVEMENTTEAMCHECKER"] = function(msg)
    if msg == "debug" then
        ATC:Print(L.DEBUG_MODE_STATUS .. tostring(ATC.isHooked))
        ATC.debug = true
    elseif msg == "hook" then
        ATC:HookAchievementUI()
    else
        ATC:Print(L.USAGE_HEADER)
        ATC:Print(L.USAGE_DEBUG)
        ATC:Print(L.USAGE_HOOK)
    end
end

-- 全局引用
_G.AchievementTeamChecker = ATC
