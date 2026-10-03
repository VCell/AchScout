#!/usr/bin/env python3
"""Convert AchScanner.lua stats data into CompleteRate.lua format.

Reads achievement completion stats from AchScanner.lua and writes a
CompleteRate.lua file where each entry maps an achievement id to its
completion rate (completed / total), rounded to 4 decimal places.

Some achievements have different ids for Alliance and Horde. Ids listed in
FACTION_ID_PAIRS are merged before output: both ids get the summed
completed/total of the pair. If only one faction's id has data, the other
faction's id is also written with the same stats.

Usage:
    python3 convert_complete_rate.py [input.lua] [output.lua]

Defaults:
    input  -> AchScanner.lua   (next to this script)
    output -> CompleteRate.lua (next to this script)
"""

import os
import re
import sys
from datetime import datetime

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_INPUT = os.path.join(SCRIPT_DIR, "AchScanner.lua")
DEFAULT_OUTPUT = os.path.join(SCRIPT_DIR, "CompletionRate.lua")

# Matches a stats entry block, e.g.:
#   [6128] = {
#       ["completed"] = 40,
#       ["total"] = 203,
#   },
# String-keyed sections (["sampled"], ["sampleCount"]) are skipped because
# the id capture only accepts digits.
ENTRY_RE = re.compile(
    r'\[(\d+)\]\s*=\s*\{\s*'
    r'\["completed"\]\s*=\s*(\d+)\s*,\s*'
    r'\["total"\]\s*=\s*(\d+)\s*,\s*'
    r'\}'
)


SAMPLE_COUNT_RE = re.compile(r'\["sampleCount"\]\s*=\s*(\d+)')

# Alliance/Horde achievement id pairs for the same achievement.
# Fill in pairs as (alliance_id, horde_id); order within a pair does not matter.
FACTION_ID_PAIRS = [
    # (alliance_id, horde_id),
    (33, 1358), # 这个苔原不太远
    (34, 1356), # 峡湾巡游
    (35, 1359), # 龙骨荒野之力
    (37, 1357), # 欢迎来到灰熊丘陵
    (202, 1502), # 来去如风
    (203, 1251), # 我的地盘，我说了算
    (206, 1252), # 超级防守者
    (220, 873), # 完美霜狼
    (225, 1164), # 毫不浪费
    (230, 1175), # 战斗大师
    (246, 1005), # 知己知彼
    (388, 1006), # 城市卫兵
    (604, 603), # 联盟之怒
    (610, 615), # 杀死酋长 / 暴风城的风暴
    (611, 616), # 流血的血蹄 / 推翻议会
    (612, 617), # 黑暗女王之死 / 不再永恒
    (613, 618), # 杀死奎尔萨拉斯 / 熄灭圣光
    (614, 619), # 为了联盟
    (701, 700), # 联盟的自由
    (764, 763), # 燃烧的远征
    (899, 901), # 库雷尼 德拉诺的玛格汉
    (908, 909), # 战斗的召唤！
    (942, 943), # 外交家
    (948, 762), # 联盟的大使
    (963, 965), # 卡利姆多的糖果
    (966, 967), # 东部王国的糖果
    (969, 968), # 外域的糖果
    (1012, 1011), # 北地之风
    (1022, 1025), # 东部王国护焰者
    (1023, 1026), # 卡利姆多护焰者
    (1024, 1027), # 外域护焰者
    (1028, 1031), # 东部王国灭火
    (1029, 1032), # 卡利姆多灭火
    (1030, 1033), # 外域灭火
    (1034, 1036), # 艾泽拉斯的火焰
    (1035, 1037), # 亵渎部落 / 亵渎联盟
    (1038, 1039), # 护焰者 / 护火者
    (1040, 1041), # 糟糕的万圣节
    (1151, 224), # 忠诚的卫士
    (1184, 1203), # 奇怪的美酒
    (1189, 1271), # 来往地狱火半岛
    (1191, 1272), # 泰罗卡的恐惧
    (1192, 1273), # 纳格兰大满贯
    (1255, 259), # 冬幕节见鬼去吧！
    (1279, 1280), # 自讨苦吃
    (1686, 1685), # 节日情谊
    (1697, 1698), # 爱慕之国
    (1737, 2476), # 毁车灭迹
    (1757, 2200), # 远古防御
    (1762, 2192), # 片甲不丢
    (1782, 1783), # 日常食粮
    (2016, 2017), # 灰熊精英
    (2419, 2497), # 春天的悸动
    (2421, 2420), # 贵族的花园
    (2760, 2769), # 尊贵的达纳苏斯冠军 / 幽暗城冠军
    (2761, 2767), # 尊贵的埃索达冠军 / 银月城冠军
    (2762, 2766), # 尊贵的诺莫瑞根冠军 / 森金冠军
    (2763, 2768), # 尊贵的铁炉堡冠军 / 雷霆崖冠军
    (2764, 2765), # 尊贵的暴风城冠军 / 奥格瑞玛冠军
    (2817, 2816), # 尊贵的联盟银色冠军 / 部落银色冠军
    (3356, 3357), # 冬泉霜刃豹 / 毒皮暴掠龙
    (3556, 3557), # 感恩者的好胃口
    (3576, 3577), # 感恩全席
    (3580, 3581), # 誓死赴宴
    (3596, 3597), # 感恩之路
    (3676, 3677), # 银色挚友 / 夺日者
    (3851, 4177), # 都是我的 / 一个也不能少
    (3856, 4256), # 毁车不倦
    (3857, 3957), # 征服之岛主宰
    (4436, 4437), # 枪神
    (4786, 4790), # 诺莫瑞根行动 / 扎拉赞恩的灭亡
    (4869, 4982), # 沉入瓦丝琪尔
    (4873, 5501), # 遁入暮光
    (4925, 4976), # 灰谷任务
    (4929, 4978), # 尘泥沼泽任务
    (4932, 4979), # 菲拉斯任务
    (4936, 4980), # 石爪山脉任务
    (4937, 4981), # 南贫瘠之地任务
    (5213, 5214), # 高飞的灵魂
    (5221, 5222), # 烈焰，与我同行
    (5226, 5227), # 九重天
    (5231, 5552), # 两度遇险
    (5318, 5319), # 海底两万里
    (5320, 5321), # 高山之王
    (5322, 5323), # 效忠联盟 / 效忠部落
    (5330, 5345), # 列兵 / 侦察兵
    (5331, 5346), # 下士 / 步兵
    (5332, 5347), # 中士
    (5333, 5348), # 军士长 / 高阶军士
    (5334, 5349), # 士官长 / 一等军士长
    (5335, 5350), # 骑士 / 石头守卫
    (5336, 5351), # 骑士中尉 / 血卫士
    (5417, 5418), # 托尔巴拉德精英
    (5474, 5475), # 让我们共进午餐：暴风城 / 奥格瑞玛
    (5476, 5477), # 要钓就钓到最好：暴风城 / 奥格瑞玛
    (5489, 5490), # 托尔巴拉德主宰
    (5718, 5719), # 托尔巴拉德的新一天
    (5841, 5844), # 让我们共进午餐：铁炉堡 / 幽暗城
    (5847, 5850), # 要钓就钓到最好：铁炉堡 / 幽暗城
    (5848, 5849), # 要钓就钓到最好：达纳苏斯 / 雷霆崖
    (5853, 5854), # 想唱就唱
    (6007, 6010), # 诺森德灭火
    (6008, 6009), # 诺森德护焰者
    (6011, 6012), # 灾变护焰者
    (6013, 6014), # 大灾变灭火
    (6030, 6031), # 街头表演
    (6300, 6534), # 翻翡覆翠
    (6535, 6536), # 卡桑琅强力游侠
    (6537, 6538), # 流落昆莱山
    (6603, 6602), # 驯服东部王国 / 驯服卡利姆多
    (6828, 6827), # 熊猫人特使
    (6874, 7509), # 连场鏖战
    (7467, 7468), # 塞拉摩的沦陷
    (7523, 7524), # 塞拉摩的沦陷
    (7526, 7529), # 风筝大战
    (7527, 7530), # 你不是坦克
    (7941, 7942), # 横行无忌
    (7946, 8022), # 这下你可拉风了
    (7949, 7950), # 聚众闹事
    (8010, 8013), # 雄狮港 / 统御岗哨
    (8011, 8014), # 五号还活着
    (8012, 8015), # 勤俭持家
    (8030, 8031), # 勇气的试炼
    (8042, 8043), # 潘达利亚灭火
    (8045, 8044), # 潘达利亚护焰者
    (8052, 8055), # 可汗
    (8208, 8209), # 肯瑞托远征军 / 夺日者先锋军
    (8218, 8093), # 暴虐征服者
    (8304, 8302), # 坐骑大巡游
    (8306, 8307), # 部落颠覆者 / 暗矛起义者
    (8314, 8315), # 公海激战
    (8335, 8337), # 大打出手
    (8339, 8342), # 收集你的卡牌
    (8364, 8366), # 公海激战（英雄难度）
    (8679, 8680), # 奥格瑞玛征服者 / 奥格瑞玛解放者
    (18614, 18688), # 防御协议贝塔：终结
    (18677, 18678), # 防御协议贝塔：冠军试炼
    (19426, 19425), # 防御协议伽马：冠军试炼
    (19439, 19440), # 防御协议伽马：终结
    (61460, 61459), # 恶毒征服

]


def merge_faction_pairs(entries):
    """Merge stats for faction achievement id pairs.

    Returns a dict {id: (completed, total)} where each id of a listed pair
    maps to the summed stats of both ids. When only one faction's id has
    data, the other faction's id is added with the same stats.
    """
    stats = {aid: (completed, total) for aid, completed, total in entries}

    for id_a, id_b in FACTION_ID_PAIRS:
        comp = stats.get(id_a, (0, 0))[0] + stats.get(id_b, (0, 0))[0]
        tot = stats.get(id_a, (0, 0))[1] + stats.get(id_b, (0, 0))[1]
        if tot == 0:
            continue  # neither faction has data for this pair
        stats[id_a] = (comp, tot)
        stats[id_b] = (comp, tot)

    return stats


def parse_stats(text):
    """Return (entries, sample_count) where entries is a list of (id, completed, total) tuples."""
    entries = []
    for match in ENTRY_RE.finditer(text):
        aid = int(match.group(1))
        completed = int(match.group(2))
        total = int(match.group(3))
        entries.append((aid, completed, total))

    sample_match = SAMPLE_COUNT_RE.search(text)
    sample_count = int(sample_match.group(1)) if sample_match else 0

    return entries, sample_count

       
def format_rate(completed, total):
    """Completion rate as a string with exactly 4 decimal places."""
    if total == 0:
        return "0.0000"
    return f"{completed / total:.4f}"


def build_lua(stats, sample_count):
    """Build the CompletionRate.lua source text from merged stats.

    stats is a dict {id: (completed, total)}.
    """
    today = datetime.now().strftime("%Y-%m-%d")
    lines = [
        "local _, AchScout = ...",
        "",
        "Completion = {",
        "    rate = {",
    ]
    for aid in sorted(stats):
        completed, total = stats[aid]
        lines.append(f"        [{aid}] = {format_rate(completed, total)},")
    lines.append("    },")
    lines.append(f'    date = "{today}",')
    lines.append(f"    samples = {sample_count},")
    lines.append("}")
    lines.append("")
    lines.append("AchScout.Completion = Completion")
    lines.append("")
    return "\n".join(lines)


def main(argv):
    input_path = argv[1] if len(argv) > 1 else DEFAULT_INPUT
    output_path = argv[2] if len(argv) > 2 else DEFAULT_OUTPUT

    with open(input_path, "r", encoding="utf-8") as f:
        text = f.read()

    entries, sample_count = parse_stats(text)
    if not entries:
        print(f"No stats entries found in {input_path}", file=sys.stderr)
        return 1

    stats = merge_faction_pairs(entries)
    output = build_lua(stats, sample_count)
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(output)

    print(f"Wrote {len(stats)} entries to {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
