local _, AchScout = ...
local L = AchScout.Locale
local Logger = AchScout.Logger
local QueryContent = {}

local function AchievementNameFilter(str)
    if #str == 0 then return str end
    if not L.FILTER_ACHIEVEMENT_NAME then
        return str
    end
    return string.gsub(str, "^([%z\1-\127\194-\244][\128-\191]*)", "%1.")
end

-- 构建查询成就完成情况并通报的queryContent
function QueryContent.CreateCompleteQuery(id, name)
    return {
        missingNames = {},    -- 未完成成就的玩家名单
        failedNames = {},     -- 查询失败列表
        completeNames = {},   -- 完成成就的玩家名单
        completeCount = 0,    -- 完成成就的人数
        missingCount = 0,     -- 未完成成就的人数
        failedCount = 0,      -- 查询失败人数
        achievementID = id,
        achievementName = name,
        

        QueryForPlayer = function(self) 
            Logger:Debug("QueryForPlayer start" )
            local completed = select(13, GetAchievementInfo(self.achievementID))
            
            if not completed then
                self:addMissingPlayer(GetUnitName("player", true))
            else
                self:addCompletePlayer(GetUnitName("player", true))
            end
        end,

        OnQueryFailed = function(self, name)
            self:addFailedPlayer(name)
        end, 

        FetchResult = function(self, unit)
            Logger:Debug("FetchResult start")
            local isCompleted, _, _, _  = GetAchievementComparisonInfo(self.achievementID)
            local name = GetUnitName(unit, true)
            Logger:Debug(string.format("GetAchievementComparisonInfo unit:%s, name:%s, id:%d, result:%s", unit, name, self.achievementID, tostring(isCompleted)))

            if not isCompleted then
                self:addMissingPlayer(name)
            else
                self:addCompletePlayer(name)
            end
            -- local point = GetComparisonAchievementPoints()
            -- ATC:Debug(string.format("GetComparisonAchievementPoints unit:%s, %d", unit, point))
        end,

        GetReport = function(self)
            Logger:Debug("GetReport start")
            local message, messageExt

            local achievementName = AchievementNameFilter(self.achievementName)
            local totalMembers = self.missingCount + self.completeCount + self.failedCount
            if self.missingCount == 0 then

                local options = {}
                for i, tmpl in ipairs(L.ALL_COMPLETE) do
                    options[i] = string.format(tmpl, achievementName)
                end
                message = options[math.random(1, #options)]

            elseif self.completeCount == 0 then

                local options = {}
                for i, tmpl in ipairs(L.NONE_COMPLETE) do
                    options[i] = string.format(tmpl, achievementName)
                end
                message = options[math.random(1, #options)]

            elseif self.missingCount <= self.completeCount then 

                local options = {}
                for i, tmpl in ipairs(L.MOSTLY_MISSING) do
                    options[i] = string.format(tmpl, achievementName, self.missingCount, totalMembers)
                end
                message = options[math.random(1, #options)]
                messageExt = L.MISSING_LIST_PREFIX .. table.concat(self.missingNames, ",")

            elseif self.missingCount > self.completeCount then  

                local options = {}
                for i, tmpl in ipairs(L.MOSTLY_COMPLETE) do
                    options[i] = string.format(tmpl, achievementName, self.completeCount, totalMembers)
                end
                message = options[math.random(1, #options)]
                messageExt = L.COMPLETE_LIST_PREFIX .. table.concat(self.completeNames, ",")

            end

            if self .failedCount > 0 then 
                message = message .. string.format(L.OUT_OF_RANGE_SUFFIX, self.failedCount)
            end
    
            return {message, messageExt}
        end,

        -- 添加缺失玩家
        addMissingPlayer = function(self, playerName)
            table.insert(self.missingNames, playerName)
            self.missingCount = self.missingCount + 1
            Logger:Debug(playerName .. " 未完成")
        end,
        
        -- 添加完成玩家
        addCompletePlayer = function(self, playerName)
            table.insert(self.completeNames, playerName)
            self.completeCount = self.completeCount + 1
            ATC:Debug(playerName .. "已完成")
        end,

        addFailedPlayer = function(self, playerName)
            table.insert(self.failedNames, playerName)
            self.failedCount = self.failedCount + 1 
            ATC:Debug(playerName .. "查询失败")
        end
    }
end

-- 构建查询成就点数，并通报成就点排名的queryContent
function QueryContent.CreatePointQuery(id, name)
    return {
        points = {}, -- name-point的map
        failedCount = 0,      -- 查询失败人数

        QueryForPlayer = function(self) 
            Logger:Debug("QueryForPlayer start" )
            local myPoints = GetTotalAchievementPoints()
            local name = GetUnitName("player", true)
            self.points[name] = myPoints
        end,

        OnQueryFailed = function(self, name)
            self.failedCount = self.failedCount + 1
        end, 

        FetchResult = function(self, unit)
            Logger:Debug("FetchResult start")
            local point = GetComparisonAchievementPoints()
            local name = GetUnitName(unit, true)
            Logger:Debug(string.format("GetComparisonAchievementPoints unit:%s, %d", unit, point))

            self.points[name] = point
        end,

        GetReport = function(self)
            Logger:Debug("GetReport start")
            
            -- 将点数数据转换为可排序的数组
            local ranking = {}
            for name, points in pairs(self.points) do
                table.insert(ranking, {
                    name = name,
                    points = points or 0
                })
            end
            
            -- 按点数降序排序
            table.sort(ranking, function(a, b)
                return a.points > b.points
            end)
            
            -- 生成排名消息
            local messages = {}
            
            if #ranking > 0 then
                -- 标题行
                table.insert(messages, L.POINTS_RANK_TITLE)
                
                -- 排名内容
                for i, player in ipairs(ranking) do
                    if i <= 10 then -- 最多显示前10名
                        local rankText = string.format(L.POINTS_RANK_ROW, i, player.name, player.points)
                        table.insert(messages, rankText)
                    end
                end
                
                -- 添加失败人数信息
                if self.failedCount > 0 then
                    table.insert(messages, string.format(L.QUERY_FAILED_COUNT, self.failedCount))
                end

                table.insert(messages, L.RANK_COMMENT[math.random(1, #L.RANK_COMMENT)])
            else
                table.insert(messages, L.NO_POINTS_DATA)
            end
            
            return messages
        end,

    }
end

-- 构建查询成就点数，并通报成就点排名的queryContent
function QueryContent.CreateFeatQuery(id, name)
    return {
        points = {}, -- name-point的map
        failedCount = 0,      -- 查询失败人数

        QueryForPlayer = function(self) 
            Logger:Debug("QueryForPlayer start" )
            local _,complete,_ = GetCategoryNumAchievements(81)
            local name = GetUnitName("player", true)
            self.points[name] = complete
        end,

        OnQueryFailed = function(self, name)
            self.failedCount = self.failedCount + 1
        end, 

        FetchResult = function(self, unit)
            Logger:Debug("FetchResult start")
            local point = GetComparisonCategoryNumAchievements(81)
            local name = GetUnitName(unit, true)
            Logger:Debug(string.format("GetComparisonCategoryNumAchievements unit:%s, %d", unit, point))

            self.points[name] = point
        end,

        GetReport = function(self)
            Logger:Debug("GetReport start")
            
            -- 将点数数据转换为可排序的数组
            local ranking = {}
            for name, points in pairs(self.points) do
                table.insert(ranking, {
                    name = name,
                    points = points or 0
                })
            end
            
            -- 按点数降序排序
            table.sort(ranking, function(a, b)
                return a.points > b.points
            end)
            
            -- 生成排名消息
            local messages = {}
            
            if #ranking > 0 then
                -- 标题行
                table.insert(messages, L.FEAT_RANK_TITLE)
                
                -- 排名内容
                for i, player in ipairs(ranking) do
                    if i <= 10 then -- 最多显示前10名
                        local rankText = string.format(L.FEAT_RANK_ROW, i, player.name, player.points)
                        table.insert(messages, rankText)
                    end
                end
                
                -- 添加失败人数信息
                if self.failedCount > 0 then
                    table.insert(messages, string.format(L.QUERY_FAILED_COUNT, self.failedCount))
                end

                table.insert(messages, L.RANK_COMMENT[math.random(1, #L.RANK_COMMENT)])
            else
                table.insert(messages, L.NO_POINTS_DATA)
            end
            
            return messages
        end,

    }
end

AchScout.QueryContent = QueryContent