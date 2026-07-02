# sts2-cli

<details open>
<summary><b>English</b></summary>

A CLI for Slay the Spire 2.

Runs the real game engine headless in your terminal — all damage, card effects, enemy AI, relics, and RNG are identical to the actual game. Everything is unlocked from the start: all characters, cards, relics, potions, and ascension levels — no timeline progression required.

![demo](docs/demo_en.gif)

## Setup

Requirements:
- [Slay the Spire 2](https://store.steampowered.com/app/2868840/Slay_the_Spire_2/) on Steam
- [.NET 9 SDK](https://dotnet.microsoft.com/download)
- Python 3.9+

```bash
git clone https://github.com/wuhao21/sts2-cli.git
cd sts2-cli
./setup.sh      # copies DLLs from Steam → IL patches → builds
```

Or just run `python scripts/play.py` — it auto-detects and sets up on first run.

To check the game path, required DLLs, and .NET SDK without copying, patching,
or building anything:

```bash
./setup.sh --validate-only /path/to/game/data
```

### Windows PowerShell

Copy `config.example.json` to `config.json`, then set `game_path` to the Slay
the Spire 2 installation directory. Backslashes in JSON must be doubled:

```json
{
  "game_path": "D:\\SteamLibrary\\steamapps\\common\\Slay the Spire 2",
  "launch_args": ["--lang", "zh", "--no-log"]
}
```

`launch_args` accepts the same arguments as `scripts/play.py`, including
`--lang`, `--character`, `--ascension`, `--seed`, `--auto`, and `--no-log`.
Explicit command-line arguments and launcher menu choices take precedence.
It may be either a command-line string or an array of tokens/argument fragments.

```powershell
Copy-Item .\config.example.json .\config.json
.\setup.ps1
python .\launch.py
```

The path can also be supplied without a config file:

```powershell
.\setup.ps1 -GameDir "D:\SteamLibrary\steamapps\common\Slay the Spire 2"
```

Validation without changing files:

```powershell
.\setup.ps1 -ValidateOnly
```

On Windows, use `python`, not `python3`; many Python installers do not create a
`python3.exe` command. Native game saves end in `.save` (not `.sav`). To inspect
the exact available filenames, run:

```powershell
python .\scripts\play.py --saves
```

For `setup.ps1`, path precedence is `-GameDir`, `STS2_GAME_DIR`, `config.json`,
then platform auto-detection. Set `STS2_CLI_CONFIG` or pass `-ConfigPath` to
use another config file.

## Play

```bash
python scripts/play.py                        # interactive (Chinese)
python scripts/play.py --lang en              # interactive (English)
python scripts/play.py --ascension 10         # Ascension 10
python scripts/play.py --character Silent     # play as Silent
```

Type `help` in-game:

```

HP, gold, potions, and relics are shown at every decision point. `deck` can be
used from any prompt, including map, event, reward, shop, and rest-site choices.
Unclaimed card rewards preview all candidate cards before you choose their
position in the reward order.
  help     — show help
  map      — show map
  deck     — show deck
  draw     — inspect the combat draw pile
  discard  — inspect the combat discard pile
  d0       — discard potion 0 at any decision point
  potions  — show potions
  relics   — show relics
  quit     — quit

  Map:     enter path number (0, 1, 2)
  Combat:  card index / e (end turn) / p0 (use potion)
  Reward:  reward index (claim in any order) / p0 use potion / d0 discard / leave
  Cards:   card index / s (skip)
  Rest:    option index
  Event:   option index / leave
  Shop:    c0 (card) / r0 (relic) / p0 (potion) / rm (remove) / leave
```

## JSON Protocol

For programmatic control (AI agents, RL, etc.), communicate via stdin/stdout JSON:

```bash
dotnet run --project src/Sts2Headless/Sts2Headless.csproj
```

```json
{"cmd": "start_run", "character": "Ironclad", "seed": "test", "ascension": 0}
{"cmd": "action", "action": "play_card", "args": {"card_index": 0, "target_index": 0}}
{"cmd": "action", "action": "end_turn"}
{"cmd": "action", "action": "select_map_node", "args": {"col": 3, "row": 1}}
{"cmd": "action", "action": "skip_card_reward"}
{"cmd": "quit"}
```

Each command returns a JSON decision point (`map_select` / `combat_play` /
`reward_select` / `card_reward` / `rest_site` / `event_choice` / `shop` /
`game_over`). Use `get_map` at act-opening Ancient events and `get_piles`
during combat. All names are in English.

## Game Logs

Every run is automatically logged to `logs/` as a JSONL file (one JSON per line), recording each game state and action with timestamps. Logs older than 7 days are cleaned up automatically.

```bash
python scripts/play.py --no-log    # disable logging
```

**When filing a bug report, please attach the relevant log file from `logs/`** — it contains the full step-by-step game state needed to reproduce the issue.

## Supported Characters

| Character | Status |
|---|---|
| Ironclad | Fully playable |
| Silent | Fully playable |
| Defect | Fully playable |
| Necrobinder | Fully playable |
| Regent | Fully playable |

## Architecture

```
Your code (Python / JS / LLM)
    │  JSON stdin/stdout
    ▼
src/Sts2Headless (C#)
    │  RunSimulator.cs
    ▼
sts2.dll (game engine, IL patched)
  + src/GodotStubs (replaces GodotSharp.dll)
  + Harmony patches (localization)
```

</details>

<details>
<summary><b>中文</b></summary>

杀戮尖塔2的命令行版本。

在终端里运行真实游戏引擎 — 所有伤害计算、卡牌效果、敌人AI、遗物触发、随机数都和真实游戏一致。所有内容从一开始就全部解锁：全角色、全卡牌、全遗物、全药水、全渐进难度等级，无需时间线进度。

![demo](docs/demo_zh.gif)

## 安装

需要：
- [Slay the Spire 2](https://store.steampowered.com/app/2868840/Slay_the_Spire_2/) (Steam)
- [.NET 9 SDK](https://dotnet.microsoft.com/download)
- Python 3.9+

```bash
git clone https://github.com/wuhao21/sts2-cli.git
cd sts2-cli
./setup.sh      # 从 Steam 复制 DLL → IL patch → 编译
```

或者直接运行 `python scripts/play.py`，首次会自动完成 setup。

仅检查游戏目录、所需 DLL 和 .NET SDK，不复制、不打补丁、不编译：

```bash
./setup.sh --validate-only /path/to/game/data
```

### Windows PowerShell

将 `config.example.json` 复制为 `config.json`，并把 `game_path` 修改为
《杀戮尖塔 2》的安装目录。注意 JSON 中的反斜杠需要写成双反斜杠：

```json
{
  "game_path": "D:\\SteamLibrary\\steamapps\\common\\Slay the Spire 2",
  "launch_args": ["--lang", "zh", "--no-log"]
}
```

`launch_args` 支持 `scripts/play.py` 的参数，例如 `--lang`、`--character`、
`--ascension`、`--seed`、`--auto` 和 `--no-log`。显式命令行参数及启动器
菜单中的选择优先级更高。它既可以写成完整命令行字符串，也可以写成参数
分词或参数片段数组。

```powershell
Copy-Item .\config.example.json .\config.json
.\setup.ps1
python .\launch.py
```

也可以直接通过参数指定路径：

```powershell
.\setup.ps1 -GameDir "D:\SteamLibrary\steamapps\common\Slay the Spire 2"
```

仅校验环境而不修改文件：

```powershell
.\setup.ps1 -ValidateOnly
```

Windows 下请使用 `python`，不要使用 `python3`；许多 Windows Python
安装不会提供 `python3.exe` 命令。游戏原生存档的扩展名是 `.save`，
不是 `.sav`。可以使用以下命令查看准确的存档文件名：

```powershell
python .\scripts\play.py --saves
```

对于 `setup.ps1`，路径优先级为：`-GameDir`、`STS2_GAME_DIR`、
`config.json`、平台自动检测。可通过 `STS2_CLI_CONFIG` 或
`-ConfigPath` 指定其他位置的配置文件。

## 玩

```bash
python scripts/play.py                        # 中文交互模式
python scripts/play.py --lang en              # English
python scripts/play.py --ascension 10         # 渐进难度 10
python scripts/play.py --character Silent     # 选择静默猎手
```

游戏内输入 `help` 查看所有命令：

```

每个决策界面都会显示生命、金币、药水和遗物。`deck` 可在地图、事件、
奖励、商店、休息点等任意提示中使用。尚未领取的卡牌奖励会直接预览其中
所有候选牌，无需先改变奖励领取顺序。
  help     — 帮助
  map      — 显示地图
  deck     — 查看牌组
  draw     — 查看战斗抽牌堆
  discard  — 查看战斗弃牌堆
  d0       — 在任意决策阶段丢弃第 0 瓶药水
  potions  — 查看药水
  relics   — 查看遗物
  quit     — 退出

  地图:    输入编号 (0, 1, 2)
  战斗:    输入卡牌编号 / e 结束回合 / p0 使用药水
  奖励:    输入奖励编号（可自由选择领取顺序）/ p0 使用药水 / d0 丢弃 / leave
  卡牌:    输入卡牌编号 / s 跳过
  休息:    输入选项编号
  事件:    输入选项编号 / leave 离开
  商店:    c0 买卡 / r0 买遗物 / p0 买药水 / rm 移除 / leave 离开
```

## 角色支持

| 角色 | 状态 |
|---|---|
| 铁甲战士 (Ironclad) | 完全可玩 |
| 静默猎手 (Silent) | 完全可玩 |
| 故障机器人 (Defect) | 完全可玩 |
| 亡灵契约师 (Necrobinder) | 完全可玩 |
| 储君 (Regent) | 完全可玩 |

## JSON 协议

除了交互模式，也可以通过 stdin/stdout JSON 协议编程控制（写 AI agent、RL 训练等）：

```bash
dotnet run --project src/Sts2Headless/Sts2Headless.csproj
```

```json
{"cmd": "start_run", "character": "Ironclad", "seed": "test", "ascension": 0}
{"cmd": "action", "action": "play_card", "args": {"card_index": 0, "target_index": 0}}
{"cmd": "action", "action": "end_turn"}
{"cmd": "action", "action": "select_map_node", "args": {"col": 3, "row": 1}}
{"cmd": "action", "action": "skip_card_reward"}
{"cmd": "quit"}
```

每个命令返回一个 JSON decision point（`map_select` / `combat_play` /
`reward_select` / `card_reward` / `rest_site` / `event_choice` / `shop` /
`game_over`）。幕初先古事件中可使用 `get_map`，战斗中可使用
`get_piles`。所有名称为英文。

## 游戏日志

每局游戏会自动记录到 `logs/` 目录下的 JSONL 文件中，包含每一步的游戏状态和操作，附带时间戳。超过 7 天的旧日志会自动清理。

```bash
python scripts/play.py --no-log    # 关闭日志
```

**提交 bug 报告时，请附上 `logs/` 中对应的日志文件** — 它包含了复现问题所需的完整游戏步骤。

## 架构

```
你的代码 (Python / JS / LLM)
    │  JSON stdin/stdout
    ▼
src/Sts2Headless (C#)
    │  RunSimulator.cs
    ▼
sts2.dll (游戏引擎, IL patched)
  + src/GodotStubs (替代 GodotSharp.dll)
  + Harmony patches (本地化)
```

</details>
