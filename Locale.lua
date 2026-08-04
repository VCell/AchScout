local _, AchScout = ...

local L = {}

local locale = GetLocale()

-- ============ 默认：简体中文 (zhCN 及未知语言的兜底) ============
L.SEARCH_LABEL              = "搜索"
L.ADDON_LOADED              = "成就团队检查插件已加载."
L.ADDON_LOADED_DELAYHOOK    = "成就团队检查插件已加载 DelayHook"

L.POINTS_RANK_BUTTON        = "点数排名"
L.POINTS_RANK_TOOLTIP_TITLE = "成就点数排名"
L.POINTS_RANK_TOOLTIP_DESC  = "检查团队中所有人的成就点数并通报排名"

L.FEAT_RANK_BUTTON          = "光辉排名"
L.FEAT_RANK_TOOLTIP_TITLE   = "光辉事迹排名"
L.FEAT_RANK_TOOLTIP_DESC    = "检查团队中所有人的光辉事迹数量并通报排名"

L.QUERY_BUTTON              = "团队查询"
L.QUERY_BUTTON_TOOLTIP_TITLE = "查询团队成就完成情况"
L.QUERY_BUTTON_TOOLTIP_DESC  = "点击在团队频道公布结果"

L.NOT_IN_GROUP              = "你不在团队中！"
L.QUERY_IN_PROGRESS         = "当前成就检查中，稍后重试"
L.QUERY_START                = "开始查询团队成员的成就完成情况..."
L.QUERY_TIMEOUT_SUFFIX       = ":超时"
L.QUERY_FAILED_SUFFIX        = ":失败"
L.SEND_FAILED_PREFIX         = "消息发送失败: "
L.GROUP_MESSAGE_PREFIX        = "(团队消息) "

L.DEBUG_MODE_STATUS          = "ATC进入调试模式，Hook状态: "
L.USAGE_HEADER                = "用法:"
L.USAGE_DEBUG                 = "/atc debug - 调试模式"
L.USAGE_HOOK                  = "/atc hook - 手动重新Hook成就界面"

L.DEBUG_PREFIX                = "|cFF00FF00AchScout_DEBUG|r: "
L.PRINT_PREFIX                = "|cFF00FF00成就团队检查|r: "

-- 完成情况通报（{name} 由 AchievementNameFilter 处理过的成就名）
L.ALL_COMPLETE = {
    "果然[%s]这么简单的成就，大家都完成了。",
    "震惊！成就[%s]居然全员完成！你们是不是偷偷努力了？",
}
L.NONE_COMPLETE = {
    "哇有这么难吗，团队里竟无人获得成就[%s]？",
    "插件出BUG了吗，团队里怎么一个获得[%s]的都没有？",
}
L.MOSTLY_MISSING = {
    "怎么会还有人没有成就[%s]? %d/%d人未获得。",
    "[%s]成就点击就送，还没有的%d/%d人赶快去刷。",
    "[%s]成就有手就行，还没有的%d/%d人赶快去搞。",
}
L.MOSTLY_COMPLETE = {
    "哇太强了！成就[%s]，我们队伍里竟然有%d/%d人完成了。",
    "[%s]成就怎么只有%d/%d人完成，不是点击就送吗？",
    "[%s]成就怎么只有%d/%d人完成，不是有手就行吗？",
}
L.MISSING_LIST_PREFIX          = "未获得的萌新是:"
L.COMPLETE_LIST_PREFIX         = "完成的大佬是:"
L.OUT_OF_RANGE_SUFFIX          = " (%d人不在查询范围)"

L.POINTS_RANK_TITLE            = "成就点数排名："
L.POINTS_RANK_ROW              = "%d. %s - %d点"
L.FEAT_RANK_TITLE              = "光辉事迹数量排名："
L.FEAT_RANK_ROW                = "%d. %s - %d"
L.QUERY_FAILED_COUNT           = "(%d人查询失败)"
L.RANK_COMMENT                 = { "看来，人与人的差距，真的很大。" }
L.NO_POINTS_DATA               = "暂无成就点数数据，可能大家都太低调了～"

L.COMPLETION_PERCENT_TOOLTIP_TITLE = "%.2f%%的玩家完成了该成就"
L.COMPLETION_PERCENT_TOOLTIP_DESC = "采样日期：%s, 采样人数：%d"



-- 是否对成就名做"插入分隔符"处理（避免中文聊天过滤器误判/触发表情替换等）。
-- 这个处理是针对中文字符设计的，非中文语言客户端不需要。
L.FILTER_ACHIEVEMENT_NAME       = true

-- ============ English (enUS / enGB) ============
if locale == "enUS" or locale == "enGB" then
    L.SEARCH_LABEL              = "Search"
    L.ADDON_LOADED              = "AchScout loaded."
    L.ADDON_LOADED_DELAYHOOK    = "AchScout loaded (DelayHook)."

    L.POINTS_RANK_BUTTON        = "Points Rank"
    L.POINTS_RANK_TOOLTIP_TITLE = "Achievement Points Ranking"
    L.POINTS_RANK_TOOLTIP_DESC  = "Check everyone in the group's achievement points and report the ranking"

    L.FEAT_RANK_BUTTON          = "Feats Rank"
    L.FEAT_RANK_TOOLTIP_TITLE   = "Feats of Strength Ranking"
    L.FEAT_RANK_TOOLTIP_DESC    = "Check everyone in the group's Feats of Strength count and report the ranking"

    L.QUERY_BUTTON               = "Group Check"
    L.QUERY_BUTTON_TOOLTIP_TITLE = "Check group achievement completion"
    L.QUERY_BUTTON_TOOLTIP_DESC  = "Click to report the results in group chat"

    L.NOT_IN_GROUP               = "You are not in a group!"
    L.QUERY_IN_PROGRESS          = "An achievement check is already running, try again shortly"
    L.QUERY_START                 = "Checking the group's achievement completion..."
    L.QUERY_TIMEOUT_SUFFIX        = ":timeout"
    L.QUERY_FAILED_SUFFIX         = ":failed"
    L.SEND_FAILED_PREFIX          = "Failed to send message: "
    L.GROUP_MESSAGE_PREFIX         = "(Group message) "

    L.DEBUG_MODE_STATUS           = "ATC entering debug mode, hook status: "
    L.USAGE_HEADER                 = "Usage:"
    L.USAGE_DEBUG                  = "/atc debug - toggle debug mode"
    L.USAGE_HOOK                   = "/atc hook - manually re-hook the achievement UI"

    L.DEBUG_PREFIX                 = "|cFF00FF00ATC_DEBUG|r: "
    L.PRINT_PREFIX                 = "|cFF00FF00AchScout|r: "

    L.ALL_COMPLETE = {
        "Turns out [%s] was easy - everyone's got it.",
        "Shocking! The whole group has completed [%s]!",
    }
    L.NONE_COMPLETE = {
        "Is [%s] really that hard? Nobody in the group has it.",
        "Is the addon bugged, or does literally nobody have [%s]?",
    }
    L.MOSTLY_MISSING = {
        "How is anyone still missing [%s]? %d/%d haven't gotten it.",
        "[%s] is basically free, the %d/%d who don't have it should go get it.",
        "[%s] takes no effort, the %d/%d who don't have it should go get it.",
    }
    L.MOSTLY_COMPLETE = {
        "Impressive! [%s] has been completed by %d/%d of us.",
        "[%s] - only %d/%d have it? Isn't that supposed to be free?",
        "[%s] - only %d/%d have it? Isn't that supposed to be easy?",
    }
    L.MISSING_LIST_PREFIX          = "Still missing it: "
    L.COMPLETE_LIST_PREFIX         = "Already got it: "
    L.OUT_OF_RANGE_SUFFIX          = " (%d out of query range)"

    L.POINTS_RANK_TITLE            = "Achievement Points Ranking:"
    L.POINTS_RANK_ROW              = "%d. %s - %d pts"
    L.FEAT_RANK_TITLE              = "Feats of Strength Ranking:"
    L.FEAT_RANK_ROW                = "%d. %s - %d"
    L.QUERY_FAILED_COUNT           = "(%d failed to respond)"
    L.RANK_COMMENT                 = { "Turns out people really aren't equal." }
    L.NO_POINTS_DATA               = "No achievement point data yet, maybe everyone's just modest~"

    L.COMPLETION_PERCENT_TOOLTIP_TITLE = "%d%% of players have completed this achievement"
    L.COMPLETION_PERCENT_TOOLTIP_DESC = "Sample date: %s, Sample size: %d"
    L.FILTER_ACHIEVEMENT_NAME       = false
end

AchScout.Locale = L