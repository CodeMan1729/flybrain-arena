# FlyBrain Arena — Status

维护规则：每次重大修改后必须更新本文件。这是跨会话/跨 agent 的状态入口，先读这个再读代码。

## 项目目标（改造成什么样子）

把原版 FLYFEAR（恐怖游戏，玩家被一只用真实 MaleCNS 连接组驱动的苍蝇追）改造成 **FlyBrain Arena**：玩家 vs 无人机（Drone，复用原来的 fly.gd 追逐/探测代码）的对战。

- **胜负规则**：Drone 想尽办法贴到玩家身上（类似自爆无人机）→ Drone/游戏方"胜利"；玩家用简单武器（raycast 打点，一次 10 血，HP 初始 100，可调）打光 Drone 的 HP → 玩家胜利。
- **闪避是核心难点**：玩家攻击要产生"威胁/逼近"信号，真实进入 MaleCNS 神经通路（已验证的真实解剖连接：LC4→DNp01/DNp03、LPLC2→DNp01），驱动 Drone 做出方向不固定的闪避，不能是硬编码的"往一个方向躲"式假通路。
- **当前阶段只是第一版**：现在的场景是封闭空间（复用原版关卡），当前用的是这一份 MaleCNS v1.0 数据集和这一套 signed-activity 模型。**这两个都不是长期定案**——以后场景计划改成开放空间，神经模型/数据集以后也可能替换。P2/P3 阶段的实现要避免跟"封闭空间"或"这一份具体模型"强耦合，写代码时接口要留出替换空间，但不需要现在就为这些假设的未来变化过度设计。

## 当前阶段

P0/P1 已完成。**P2 战斗主线、自主贴近、Drone 外观/显示命名已完成并通过真实后端 smoke**：射线击杀 → won；默认出生点自主物理接触 → lost；菜单、重开、结果持久化已接通。首次人工试玩反馈已落实：Drone 降速 20%，新增第一人称枪模与开火动画，等待重启复测和难度确认；P3 未开始。先看下面“试玩反馈：降速和枪模（最新入口）”，历史交接仅供背景参考。

## 环境（Windows 原生，非 WSL）

- 仓库：`E:\FlyBrain\flyfear`，git 分支 `flybrain-arena`（基于 upstream `main`）
- upstream: https://github.com/furkancak1r/flyfear（原版是 macOS ARM64 专用：zsh 脚本、`.app` 版 Godot、uv 工具链）
- Python: `D:\python3.12.5\python.exe`，venv 已建在 `.venv/`（Windows venv 用 `.venv\Scripts\python.exe`，不是 `.venv/bin/python`）
- Godot: 4.5.2-stable win64，从 GitHub Releases 下载到 `tools/godot.zip`，解压到 `tools/`（macOS 版是 `tools/Godot.app/...`，Windows 版是 `tools/Godot_v4.5.2-stable_win64.exe` 之类，具体文件名待确认解压结果）
- 下载 GitHub Releases 资源没开 VPN 会连接卡死/reset，开 VPN 后正常，速度约 1MB/s

## 已确认的架构事实（读 README + brain/*.py + game/*.gd 得出，不是猜测）

- 数据流：`game/player.gd` telemetry → `game/fly.gd`（读取 director.neural.output）← `game/director.gd`（WebSocket 客户端）←→ `brain/server.py`（WebSocket 服务端）→ `brain/connectome.py`（Connectome.step，真实 166,700 神经元 + 25.5M 有向边稀疏矩阵乘法）+ `brain/director.py`（Budget/Readout 学习层）
- 飞行体控制（`fly.gd`）是**工程规则**，不是神经输出：lateral/climb/speed 从 4 个神经输出（L1/L2/L3/Mi1 组平均）算出，但追逐距离/速度/加速度都是硬编码常数。README 原文明确说这不是生物飞行力学或习得导航。
- 神经输出目前只驱动 4 个"恐怖事件"选择（lights/steps/silhouette/wait），不驱动闪避。**闪避是全新功能，没有现成代码可抠**。
- `data/manifest.json`、`data/mapping.json`、`data/learning-prior.json` 已经在 git 里（是参考产物，含神经元 ID 映射），但真正的连接组权重矩阵（`.feather` 原始文件、`.npz`/`.npy` 派生矩阵）被 gitignore，需要 `tools/download_data.py` 从 Google Cloud Storage 下载（约 1.1GB）再跑 `brain/connectome.py prepare` 生成。
- Godot ↔ Python 通信协议、消息类型、budget/reward 学习细节：见 `brain/server.py` 全文（已读，376 行不到）。

## 待办（按 P0→P4 优先级，见用户原始 mission）

- [x] P0: 解压 Godot Windows 版，确认可执行（`tools/Godot_v4.5.2-stable_win64.exe`，版本号 `4.5.2.stable.official.6ce3de25a` 已验证）
- [x] P0: 用 pip 装 `requirements.txt`（numpy/scipy/pyarrow/websockets/psutil），装在 `.venv`
- [x] P0: 写 Windows 版 `setup.ps1`/`run.ps1`/`test.ps1`（替代 zsh 版），改了 `tools/launch.py` 用 `msvcrt.locking` 替代 `fcntl`（Windows 无 fcntl），路径改 `.venv\Scripts\python.exe` 和 Windows 版 Godot exe
- [x] P0: 下载 MaleCNS 完整连接组数据。三个文件全部下载+SHA256 校验通过：annotations.feather(14.5MB)、neurotransmitters.feather(43.3MB)、edges.feather(1051241946 字节，独立复核 SHA256 = `e35da783d1c686b2b58b3b87cd6a403ae43bfcfba8bff28e08ef752c1a56afc1`，与 `research/source.lock.json` 一致)。**中间有一次进程中断**：第一次下载在 `data/edges.partial` 卡在 722MB（约69%）时后台进程消失（可能是 WSL/Windows 环境本身重启或进程被回收，未查具体原因），但 `reports/download.log` 是更早一次全成功运行留下的残留日志，导致定时检查时误判"已验证"。用 `.venv/Scripts/python.exe tools/download_data.py`（注意是 Windows venv，不是 WSL 的 `.venv/bin/python`——这个项目的下载脚本设计为在 Windows 侧跑）重新启动后，curl 的 `-C -` 断点续传直接从 722MB 续传剩余 31%，几秒内完成并真正通过校验。
- [x] P0: 跑 `brain.connectome prepare` 生成 `data/weights.npz`(93.7MB)/`counts.npz`(79.6MB)/`ids.npy`(1.3MB)。结果：166,700 个神经元，25,582,938 条有向边（从原始 151,856,684 条边过滤掉未标注/Glia 后），124,177,617 突触触点。
- [x] P0: `brain.server` 后端 + Godot headless import 均验证通过（细节见下方"环境跑通记录"），完整 in-game 手动试玩仍未做（P0 剩余项）
- [x] P1: 写 `docs/ARCHITECTURE_NOTES.md`（已完成，含完整数据流图 + 真实神经 vs 工程规则的区分 + P3 dodge 设计的架构含义）
- [ ] P2: Drone 改造（fly.gd 改名/贴图）+ 玩家武器（raycast hitscan）+ HP + win/lose
- [ ] P3: Threat → neural escape → dodge 双层管线（Stage A 先搭接口，Stage B 接真实神经信号）
- [ ] P4: 视觉/音效打磨

## P3 关键调研发现（已确认，非猜测）

用 pyarrow 读 `data/annotations.feather` 的 `type` 列做频次统计，确认以下逃逸相关神经元类型**真实存在**于 MaleCNS 数据中：
- `LPLC2`: 185 个神经元（looming 探测，已知文献关联）
- `LC4`: 126 个神经元（looming/escape 相关 lobula columnar 细胞）
- `DNp01`: 2 个神经元（双侧各一，descending neuron）
- `DNp03`: 2 个神经元
- `GFC1`(3个)/`GFC2`(10个)/`GFC3`(13个)/`GFC4`(8个): 注意数据集里没有字面叫 "Giant Fiber" 或 "GF" 的 type，但有 GFC1-4（Giant Fiber Cluster？need 确认），可能是 Giant Fiber 通路相关细胞，需要进一步查文献或数据集文档确认这个缩写
- R1-R6（现有视觉输入用的那组）: 3,377 个神经元，候选逃逸神经元的 body ID 已存到 `/tmp/escape_candidates.json`（临时文件，重启会丢，正式使用前需要重新生成或存到 `data/` 下）

**验证结果（已完成，用 `tools/verify_escape_pathway.py` 对 `data/counts.npz` 真实有向边直查，非猜测）**：

- **R1-R6 → LPLC2/LC4：0 条直连边。这是预期结果，不是数据缺陷。** 独立验证了 R1-R6 → L1/L2/L3/L4/L5（lamina）有大量真实突触边（如 R1-R6→L2 共 3280 条边、权重 107646），证明连接组数据完整可信；但 L1-L5 → LPLC2 同样是 0 条边，说明 LPLC2/LC4 是在 medulla 更深层（Mi1/Tm 系列/T4-T5 等）才接收视觉信号，是多突触通路，不是 lamina 单层直连。R1-R6 到 LPLC2/LC4 的"威胁→looming 探测"信号如果要接真实神经通路，需要经过至少 2-3 层中继，不能指望这两组之间有直连边。
- **LPLC2 → DNp01：185 条真实有向边，总突触权重 4862。** 强连接（如 body 31563→10010 权重64）。
- **LPLC2 → DNp03：仅 1 条边，权重1（几乎无连接）。**
- **LC4 → DNp01：126 条真实有向边，权重合计 6362。**
- **LC4 → DNp03：126 条真实有向边，权重合计 2507。**

结论：**LC4→DNp01/DNp03 和 LPLC2→DNp01 是真实、有分量的解剖学逃逸通路，可以作为"威胁→dodge"信号的候选直连边**；LPLC2→DNp03 几乎没有直连贡献，不要用它。R1-R6 不能作为这条逃逸通路的直接输入源，除非在 pipeline 里显式建模经过 lamina→medulla 的多跳传播（或者放弃直连假设，改用 LPLC2/LC4 自身的活动作为"威胁探测已发生"的起点，不再往前追溯到感光细胞层）。

## 环境跑通记录

- **`brain.server` 需要 `FLYFEAR_TOKEN` 环境变量（≥16字符）才会启动**（`brain/server.py:276`，本地 WebSocket 鉴权口令，防止未授权连接）。`run.ps1`/`run.sh` 都没有预置这个值，说明设计上要使用者自己提供，不是 bug。当前用随机生成的 48 位 hex token 在启动进程的环境变量里传入（未写入任何文件，仅本次会话内存在），验证成功：`{"ready": true, "port": 8765, "neurons": 166700}`。**下次真正长期跑，需要用户自己决定 token 怎么管理（存 `.env`？每次随机生成？），不要我自己代为持久化存放凭据。**
- 遇到过一次误导性报错：`asyncio.get_running_loop().add_signal_handler` 在 Windows 抛 `NotImplementedError`，但 `server.py:33` 明明已经用 `os.name!='nt'` guard 了。排查后发现是 `brain/__pycache__/server.cpython-312.pyc` 缓存导致（可能是上一次异常终止的进程留下的过期字节码）。删掉 `__pycache__` 重新编译后问题消失，磁盘上的源码从未有 bug。**如果以后再见到"guard 代码明明对，但 traceback 命中被 guard 掉的分支"这种矛盾，先删 `__pycache__` 排查，不要怀疑源码逻辑。**
- Godot headless import（`tools/Godot_v4.5.2-stable_win64_console.exe --headless --path game --editor --import --quit`）退出码 0，日志无 error/fail/exception/crash，证明 `game/` 下的 GDScript 没有解析期错误。**这只验证了脚本能被解析加载，不等于游戏逻辑正确/能玩**，完整试玩仍需手动起 server + 起 Godot game 场景。

## 2026-09-23 试玩反馈：降速和枪模（最新入口）

- 用户首次试玩反馈：Drone 稍快，只有准星、没有枪。`drone.gd` 新增可调 `flight_speed_scale=0.8`，最终期望速度和加速度同比降低 20%；上限由 8 降为 6.4 m/s，加速度 24→19.2 m/s²。神经输出、视线/遮挡、随机扰动和接触判定不变；仍是工程飞行调参，并非 P3 闪避。
- 新增 `game/weapon_view.gd`：程序化第一人称枪模、短暂枪口闪光和回弹动画。使用独立透明 SubViewport，无碰撞体，不遮挡游戏射线、不接管鼠标；枪模位于世界上方、HUD 下方。暂停/结算隐藏并清理残留动画，恢复/重开显示；准星仍是命中判定基准。伤害 10、冷却 0.35 秒、射程 25 m 保持不变，未新增枪声。
- `player.gd` 接入 active/reset/fire 的可视反馈；闪光只在通过冷却后触发。已有局部胜负测试验证击杀信号不会留下枪模。已原生渲染检查 `reports/p2-playtest/weapon-idle.png`、`weapon-fire.png`、`weapon-paused.png`，枪模避开右侧脑活动面板，暂停隐藏正常。
- 新增 `tests/weapon_view.gd` 12 PASS；combat_round 19、pursuit 19、fly 55、gameplay 52、mobile 54、hud 3 PASS，退出均为 0。基线枪模用例失败；加强至 6.4 m/s 的追击限速基线 6 项失败，修改后通过。既有退出资源释放警告仍存在。
- 用户原来的游戏仍在运行，未关闭其进程；普通 launcher smoke 因单实例锁退出 1。新代码需要退出旧游戏并重新启动才能体验。
- 随后使用独立端口、临时口令和独立学习/历史目录 `reports/p2-playtest/smoke-session/` 跑真实 MaleCNS smoke：退出 0、passed=true，击杀获胜和默认出生点自主接触失败均通过；未复用或停止用户现有后端。离线 9 组追击中，接触时间由原 31–42 帧变为 36–51 帧（60 Hz），此小幅降速尚不代表难度已平衡。
- 交付 `reports/p2-playtest/`：original/modified 快照、哈希、changes.patch、verification.json、rollback.py；补丁应用及回滚均在隔离目录验证，只撤销本轮改动。
- 下一步：用户重启后再次评估速度和枪模手感。P2 仍待难度确认；P3 未开始，旧 Python 测试问题和资源释放警告未处理。未提交 git。

## 2026-09-23 Drone 外观续作（历史入口）

- P2 外观/显示命名已完成：新增 `game/drone.gd`，用程序化四旋翼、护圈、机身和发光前向传感器替换昆虫模型；旋翼反向旋转仅为装饰。碰撞半径 0.1、视觉缩放 0.5、HP、追击、神经门控和接触规则保持不变。原 buzz 音源仍保留，音效重做留给 P4。
- `main.gd` 改用 `DroneScript`，运行节点名为 Drone，菜单/窗口显示 FlyBrain Arena。保留 `game.fly` 内部接口及 `fly.gd` 兼容入口；`project.godot` 中旧项目 ID、FLYFEAR 环境变量和存储路径不变，避免丢失原设置或破坏启动协议。
- 新增 `tests/drone_visual.gd`：基线 4 FAIL、退出 1；修改后 8 PASS、退出 0，覆盖模型、命名、旋翼动画、停机和碰撞配置。combat_round 19、pursuit 19、fly 55、gameplay 52、hud 3、mobile 54 项均通过，退出 0；gameplay/UI 按实时运行。部分物理测试仍有退出时资源释放警告，未在本轮处理。
- 原生 OpenGL 实际渲染并检查 `reports/p2-drone/drone-preview.png` 和 `menu-preview.png`；渲染退出 0、无 stderr。这是外观检查，不代替人工战斗试玩。
- 真实全图 smoke 再次通过：`reports/p2-drone/game-smoke.json` passed=true，launcher 退出 0；日志 `logs/validation/20260923-130608/`。击杀、默认出生点自主接触、won/lost ACK 与历史持久化均通过。
- 交付目录 `reports/p2-drone/`：original/modified 快照、SHA256 manifest、changes.patch、verification.json 和 rollback.py；回滚在隔离副本演练，仅撤销本轮改动。
- 下一步：人工战斗试玩、评估默认出生点约半秒接触的难度；之后推进 P3 threat→真实逃逸读出。P2 暂不整体勾选；P3 未开始，旧 Python 全套的 3 处失败尚未处理。本轮未提交 git。

## 2026-09-23 自主贴近续作（历史入口）

- 本轮推进 P2 自主贴近；Drone 外观/命名和人工试玩仍待处理，P3 未开始。下方旧交接所说“默认出生点未验证”已由本节更新。
- `game/fly.gd` 移除可见目标前 2.3 m 停留/后退项，改为非负距离缩放追击；保留神经新鲜度/非零门控、随机扰动、最后可见位置记忆、碰撞、8 m/s 限速和 24 m/s² 加速度限制。这仍是工程控制，不是神经闪避。
- 接触阈值提取为 `CONTACT_DISTANCE=0.6`；移动后重新检查到玩家躯干的遮挡，避免隔薄墙触发死亡。
- 新增 `tests/pursuit.gd`：3 组驱动 × 3 个 seed，默认出生点、不注入速度，静止玩家在 31–42 物理帧内被自主接触；各组速度 ≤8 m/s。另有薄墙阻止接触/telemetry 用例，共 19 PASS。输入为脚本驱动及历史实测回放，非实时神经实验。
- 同一测试基线：9 个自主接触及薄墙用例失败，退出 1；修改后 19 PASS、退出 0。`tests/fly.gd` 在测试内恢复玩家 HP/active，让持续路线测试不被接触结算中断；生产战斗不变。55 PASS，包含过门、遮挡隐藏轨迹一致、失联停止。
- `main.gd::automated_run()` 采集全图/面板数据时暂缓飞行，随后验证实际运动；最终死亡轮删除旧的 0.65 m 摆位及接近速度，使用默认出生点自主追击。真实全图 smoke 成功（`reports/game-smoke.json` passed=true，launcher exit 0；日志 `logs/validation/20260923-122920/`），won/lost ACK 和持久化均通过。
- 回归：combat_round 19 PASS；gameplay 52 PASS（实时运行，音频和过期用例依赖墙钟，不能加 fixed-fps）；fly 55 PASS（fixed-fps 60）。新测试及部分旧测试退出仍有 ObjectDB/resource 释放警告，未宣称消除。默认出生点追击很快，难度待窗口试玩评估。
- 交付：`reports/p2-pursuit/` 内 original/modified 快照、SHA256 manifest、changes.patch、verification.json、rollback.py。回滚仅恢复本轮代码/STATUS，保留前次已有修改；在隔离副本中实际演练并核对哈希。
- 下一步：P2 Drone 外观/命名、人工试玩；随后 P3 threat→真实逃逸读出。旧 Python 全套的 3 处失败未处理；本轮未跑 Python 全套。尚未提交 git。

## 2026-09-23 本轮结果（前次战斗结算交接）

- `game/main.gd`：删除钥匙/开门状态、E 交互和旧胜利条件；接通 `fly.defeated → win_game()`、`player.defeated → lose_game()`，共享 `end_round()`。新增 `round_outcome`，结算重复调用不覆盖首个结果或重复发送 finish。清运动、音效、特效后回菜单；死亡 HP 保持 0，新回合恢复双方 HP。
- `brain/server.py`：finish 消息白名单补入 `lost`。之前仅接受 `won/quit`，单改 main.gd 会导致失败结果保存被拒。
- `game/touch_controls.gd`：移除引用已删除 `interact` 的旧按钮；相应更新 `tests/mobile.gd` 的手电按钮索引。没有新增触屏开火。
- `tests/hud.gd`：旧钥匙菜单期望替换为战斗文案，并分别覆盖 won/lost。新增 `tests/combat_round.gd`，覆盖连续十枪、信号结算、重复结果保护、死亡 HP、胜负后重开。
- `automated_run()`：保留实际神经数据、4096 样本、移动/墙体、音效、暂停、断线重连验证；改为真实 hitscan 减血击杀和真实物理接触死亡，检查后端 ACK 与最近历史中的 won/lost。结果 `reports/game-smoke.json` 为 passed=true，启动器退出 0，日志在 `logs/validation/20260923-121418/`。
- **smoke 边界**：射击部分固定 Drone 位置并暂停其物理更新，仍走真实物理射线；死亡部分把 Drone 放到接触阈值外 0.65 m、赋接近速度，再恢复物理更新跨入接触阈值。神经输出来自真实全图，未替换为假数据。此验证不代表默认出生点可自主追上玩家。
- **下一步重点**：`fly.gd` 仍有旧版 `relative.length()-2.3` 保持距离规则，近距离会后退；接触阈值为 0.6 m。需在后续 P2 飞行行为改造中验证/修正自主贴近，同时保留视线遮挡、速度界限及为 P3 预留接口。本轮按交接保留既有 fly/player 接口，没有调这些参数，也没有替换苍蝇外观。
- 验证记录：`reports/p2-handoff/` 保存基线和修改后的完整命令、输出、退出码。gameplay 52 PASS；mobile 54 PASS；settings 17 PASS；hud 3 PASS；brain_view 24 PASS；新增 combat_round 19 PASS，以上退出码均为 0。fly 使用 `--fixed-fps 60` 跑完整套得到 55 PASS、退出 0，但退出阶段仍有 ObjectDB/resource 泄漏告警（待查）；前一次带 `--quit-after 36000` 仅跑到 49 条即自动退出，不能视为完整通过，该记录另存 fly-truncated.json。settings 中两条 ERROR 是故意损坏配置/备份失败用例；headless 鼠标捕获检查为 SKIP，尚未做窗口试玩。
- Python 全套：13 项，10 通过、1 失败、2 错误，退出 1。`test_client.py:25` 和 `test_socket.py:107` 硬编码 macOS Godot 路径导致 Windows FileNotFoundError；`test_public.py:250` 断连历史计数期望 2、实际 1，原因尚待调查。不要引用 `test.ps1` 的末行文案作为全套通过证据，该脚本尚未对原生命令退出码逐条 fail-fast。
- 本轮尚未提交 git；进入时已有的 fly/player、数据映射、Windows 工具等改动全部保留。下方交接中的“main.gd 尚未实现”是历史状态，勿重复执行。

## P2 历史交接说明（main.gd 已完成，以本轮结果为准）

**范围确认**（已跟用户逐条确认，不要重新讨论）：
- 完全替换成战斗，不保留"找钥匙开门逃出房间"这条主线。房间/门/钥匙的**视觉网格**可以留着当装饰，但 `has_key`/`door_open`/`place_key()`/`key_object`/`door`/`KEY_SPOTS`/`key_slot`/`key_rng`/`can_interact()`/`interact()` 这些游戏状态和函数要整个删除，不需要"等价替换"。
- 武器开火方式：鼠标左键，raycast hitscan。已在 `player.gd` 实现（`fire()` 方法），碰撞层 mask=3（世界墙体 layer 1 + Drone layer 2 都能命中，墙体会挡住射线）。
- 玩家被 Drone 贴到：接触即死（不是逐次扣血）。已在 `fly.gd`/`player.gd` 实现为"贴到时传满值伤害"（`player.take_damage(player.max_hp)`），为以后按接触部位分级伤害预留接口，但当前效果=瞬间团灭，不需要额外做别的。
- 结算流程：简单模式，直接结束回合+回菜单，不需要专门的胜负 UI/动画/音效（那些留给 P4）。

**已经实现、已验证通过的部分**（`game/fly.gd`、`game/player.gd`，不要重新设计这部分接口）：
- `fly.gd`：`hp`/`max_hp`（默认 100/100，`reset_body()` 会重置），`take_damage(amount)`（扣血，hp 归零时 `active=false` 并 emit `defeated` 信号），`_physics_process` 末尾新增"贴到玩家就让玩家掉血"的接触判定。
- `player.gd`：`hp`/`max_hp`（默认 100/100，`reset_motion()` 会重置），`take_damage(amount)`（同上机制，hp 归零 emit `defeated` 信号），`weapon_range`(25.0)/`weapon_damage`(10)/`fire_cooldown`(0.35s)/`fire_ready`，`fire()` 方法（raycast hitscan，命中 Drone 调 `take_damage`），鼠标左键已接到 `_unhandled_input()` 触发 `fire()`（仅桌面模式，`Input.mouse_mode==MOUSE_MODE_CAPTURED` 时才生效）。
- 这两个文件的改动已经跑过 `tests/fly.gd`（55 项全过）和 `tests/gameplay.gd`/`tests/mobile.gd` 里新增的战斗断言，全部验证通过。

**需要在 `main.gd` 里实现的部分**（这是唯一剩下要写的代码）：
1. 删除 `has_key`/`door_open`/`place_key()`/`key_object`/`door`/`KEY_SPOTS`/`key_slot`/`key_rng`/`can_interact()`/`interact()`，以及 `_process()` 里读它们的 HUD 文案逻辑（`objective.text`/`prompt.text` 里引用钥匙/门的部分）、`_unhandled_input()` 里 `KEY_E` 触发 `interact()` 的分支。
2. 把 `finish_game()` 拆成 `win_game()` 和 `lose_game()` 两个公开方法（测试文件已经按这两个名字写断言，不要用别的名字）。两者共享"暂停 player/fly、通知 director.finish_session(outcome)、清 scare 特效、回菜单、按钮文案"这套逻辑，只是 outcome 字符串和菜单文案不同。
3. 在 `_ready()` 里连接信号：`fly.defeated.connect(win_game)`、`player.defeated.connect(lose_game)`（我已经确认这两个信号存在且工作正常，直接连即可）。
4. `start_game()` 里删掉 `has_key=false`/`door_open=false`/`place_key()`/`door.position.x=0` 这几行（已经在我的改动里删了，确认没被别的分支漏掉）。
5. `automated_run()`（headless smoke test，被 `run.ps1 --headless --smoke`/`test.ps1` 调用）目前整段还是走"找钥匙开门"的旧剧本，且调用了还不存在的 `win_game`。这段需要改写成战斗剧本（走近 Drone、开枪、验证 hp 变化、验证 `win_game` 触发；反向场景验证站着不动被贴到触发 `lose_game`）。这段是纯实现代码，不是测试基础设施，具体怎么写留给你决定，只要覆盖"至少一条真实物理路径能触发 win，至少一条能触发 lose"就行。
6. 手机触屏模式（`touch_mode`）目前没有开火输入：`tests/mobile.gd` 里原来"触屏拿钥匙"的测试已经改成一段 TODO 注释（搜 `TODO(P2 combat)`），本轮不需要处理，除非用户后续单独要求。

**测试怎么跑**：`./tools/Godot_v4.5.2-stable_win64_console.exe --headless --path game --script ../tests/gameplay.gd`（以及同样方式跑 `mobile.gd`）。目前跑到 `win_game`/`lose_game` 未定义那一步会报 `SCRIPT ERROR: Invalid call. Nonexistent function 'win_game'`，这是预期的红灯——在此之前的所有断言（HUD 刷新、门/墙碰撞、武器命中/冷却/挡墙、Drone HP 归零触发 defeated、玩家接触归零触发 defeated、原有音频/暂停/恢复等）都应该全部 PASS。如果你的改动让红灯提前出现（比如某个我列的 PASS 项变红），说明改动破坏了已验证的行为，先别继续往下写，回头检查。`tests/fly.gd` 这条测试很慢（几分钟级别），跑的时候给够超时时间，不要因为超时就当它挂了。

## 决策记录

- 平台改造范围：用户已认可"全自动改造"（重写 setup/run 脚本、换 Windows Godot、pip 替代 uv）
- 数据下载：用户已确认直接下载完整 1.1GB 连接组数据，不用 mock/占位数据
- 子 agent 使用原则：为省 token，文件树/代码定位类查找任务分给子 agent，描述尽量简短；但涉及项目质量的判断（架构决策、神经信号映射设计等）不外包，自己多花 token 也要保证质量
