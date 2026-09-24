# FlyBrain Arena — Status

维护规则：每次重大修改后必须更新本文件。这是跨会话/跨 agent 的状态入口，先读这个再读代码。

## 项目目标（改造成什么样子）

把原版 FLYFEAR（恐怖游戏，玩家被一只用真实 MaleCNS 连接组驱动的苍蝇追）改造成 **FlyBrain Arena**：玩家 vs 无人机（Drone，复用原来的 fly.gd 追逐/探测代码）的对战。

- **胜负规则**：Drone 想尽办法贴到玩家身上（类似自爆无人机）→ Drone/游戏方"胜利"；玩家用简单武器（raycast 打点，单发固定 15 点伤害，即当前 100 点满血的 15%；7 枪击倒）打光 Drone 的 HP → 玩家胜利。
- **闪避是核心难点**：玩家攻击要产生"威胁/逼近"信号，真实进入 MaleCNS 神经通路（已验证的真实解剖连接：LC4→DNp01/DNp03、LPLC2→DNp01），驱动 Drone 做出方向不固定的闪避，不能是硬编码的"往一个方向躲"式假通路。
- **当前阶段只是第一版**：现在的场景是封闭空间（复用原版关卡），当前用的是这一份 MaleCNS v1.0 数据集和这一套 signed-activity 模型。**这两个都不是长期定案**——以后场景计划改成开放空间，神经模型/数据集以后也可能替换。P2/P3 阶段的实现要避免跟"封闭空间"或"这一份具体模型"强耦合，写代码时接口要留出替换空间，但不需要现在就为这些假设的未来变化过度设计。

## 当前阶段

P0/P1/P2 已完成，单发固定 15 点伤害、Drone 0.8 速度倍率保持不变。**P3 真实神经闪避、P4 首版命中标记/战斗音效/机械旋翼声均已完成并通过整套回归及真实 smoke**。当前使用说明见 `docs/ARENA.md`；先看下一节，旧条目仅作历史记录。下一步为人工评估闪避和音效手感，及独立处理快速 headless 退出时的音频资源警告。

## 2026-09-24 README.md 重写为 FlyBrain Arena 现状（英文，已推送 GitHub）

- 上一轮只是把原版土耳其语 README 逐段直译成英文，内容仍是"找钥匙逃出房间"的旧叙事。本轮应用户要求**整篇重写**（不是翻译），删掉了钥匙搜索/三房间探索/开门胜利这套已被 P2 整体替换的旧玩法描述，以及 web 部署、macOS/uv 工具链这些这个 fork 从未验证过的内容；改成准确描述当前战斗玩法：Drone 对战、武器数值（15 伤害/7 枪击倒/100 HP/0.35s 冷却/25m 射程）、玩家被贴到即死、P4 命中标记与音效。
- 新增一节专讲这个 fork 存在的原因和 P3 神经闲避通路的真实性边界：明确写出 LC4→DNp01/DNp03、LC4→DNp03、LPLC2→DNp01 是真实解剖连接（消融测试后逃逸强度 1.0→0.088 作证据），LPLC2→DNp03 几乎无连接；R1-R6 到 LC4/LPLC2 无直连边，所以威胁信号是直接注入 LC4/LPLC2 而非伪造一条视觉通路，这是工程选择，写清楚不是重新发现了生物学通路。这部分内容对齐 `docs/ARCHITECTURE_NOTES.md` 和上面"P3 关键调研发现"一节，未新增未经验证的结论。
- 本地环境部分改成 Windows 原生（`setup.ps1`/`run.ps1`/`test.ps1`），删掉了原版 macOS ARM64 + uv 的说明（这个 fork 从未在 macOS 上跑过）。新增"upstream FLYFEAR 删除了什么"一节，明确列出 `has_key`/`door_open`/`interact()` 等已整个删除，不是保留成未用的兼容层，并指向 upstream 仓库给想玩原版的人。
- 保留了原版就有的"真实 vs 工程"数值模型免责段落（signed-activity-deviation model、166,700 神经元/25,582,938 边等），因为底层 Connectome 计算代码未变。数据/许可证段落同样保留 CC BY 4.0 + MIT 归属,指向 `THIRD_PARTY.md`。
- 写之前逐条核对过引用的文件路径是否存在（`docs/ARENA.md`、`brain/escape.py`、`research/source.lock.json` 等）和代码里的真实常量（`game/player.gd::weapon_damage=15`、`game/drone.gd::CONTACT_DISTANCE=0.6`/`flight_speed_scale=0.8`、`game/director.gd::ESCAPE_MAX_AGE=0.85`/0.65s 请求间隔），没有凭 STATUS.md 记忆直接抄数字。
- 未改代码、未跑测试（本轮是纯文档重写，不涉及游戏逻辑）。提交到 `origin`（`https://github.com/CodeMan1729/flybrain-arena.git`）的 `flybrain-arena` 分支，只推了 `README.md` 和 `STATUS.md` 两个文件的改动。

## 2026-09-24 P4 视听反馈（最新入口，已验证）

- 新增 `game/combat_feedback.gd`：真实命中后显示 0.14 s 准星周围命中标记；接受的开火、命中、won/lost 分别播放独立短音效。冷却拒绝的输入无重复反馈，未命中无命中提示；暂停/重开清空残留，重复结算保留首个结果。全走既有 Master 音量和静音，不改伤害、速度、冷却或神经模型。
- `tools/generate_combat_audio.py` 生成 5 份原创、可复现、低幅度单声道 PCM（shot/hit/won/lost/rotor），无外部素材。Drone 音源替换为机械旋翼循环，旧 buzz 文件保留。已认可的枪模和开火动画不变。
- 新增 17 项 Godot 反馈检查（含真实致命 hitscan 后无残留标记）、5 音源参数/复现性检查（1 个 Python unittest）。原生 OpenGL 1280×720 截图 ready/hit/paused/won 已生成并逐张检查，渲染退出 0、stderr 为空；截图是离线视觉 fixture，不作为真实神经实验。胜利截图也通过剩余 6 次真实 hitscan 结算，只有 fixture 冷却被跳过。
- P4 第一次全套：22 项 Python 通过，gameplay 近远音量用例失败。新增结算声混入了原来只测 Drone 的 Master 采样；在音频 fixture 采样前清理战斗短音效后通过。原始旋翼音量保持，未放宽衰减断言；实测 near=0.000468386、far=0.000006235，能量约 75 倍。音色主观效果仍待人工试听。
- 最终 `test.ps1 -SkipSmoke`：退出 0，22 项 Python + 299 项独立 Godot 检查通过；Python 内另含真实客户端 10 条 Godot 断言。独立端口/临时口令/学习目录的真实 smoke：40 项 CHECK、passed=true、退出 0，记录 `reports/p4-feedback/game-smoke.json`。包括 P3 神经链路、七枪结算、默认出生点自主接触、won/lost 持久化的既有回归。
- `reports/p4-feedback/` 含 original/modified、SHA256 manifest、支持 WAV 的二进制 changes.patch、verification.json、rollback.py；补丁应用和回滚均在隔离目录运行并核对字节。verification 保留首轮失败，最后同名 label 为准。快速 headless 用例仍有 WAV playback 退出释放警告（含新增声音）；原生渲染无此警告，不声称已修复引擎释放问题。
- P3 的交付快照保持不动。阶段回滚先 P4、后 P3；两阶段串联恢复已在隔离副本验证。保护脚本会拒绝覆盖阶段之后变化的文件。未提交 git。`docs/ARENA.md` 记录启动、操作、真实/工程边界、验证与回滚；触屏开火仍未新增。

## 2026-09-23 P3 持续推进（最新入口，已验证）

- `game/threat_sensor.gd`：以可见射线附近的瞄准和已接受开火产生 level/bearing，遮挡、背后、超射程、远离射线均无威胁。Hitscan 仍即时伤害，闪避针对预瞄和后续攻击，不伪造子弹飞行时间或无敌帧。
- `brain/escape.py` + `Connectome.step(values, threat=None)`：使用 annotation 的真实 somaSide/ID，LC4 126、LPLC2 185、DNp01/DNp03 各 2 个；输入直接注入 LC4/LPLC2，经过原有完整 166,700 神经元/25.5M 边、24 次迭代后读 DN。输入编码、signed-rate 动力学、DN→运动映射均为工程模型，不声称复现视网膜 looming 或生物飞行动力学。
- 独立 `escape` 请求绕开旧 scare 2–5 秒冷却；每个客户端仍串行使用自己的全图神经状态。客户端单个在途计算、威胁请求间隔 0.65 s、从发出请求起有效期 0.85 s，后端完成后冷却 0.25 s。暂停/断线/重开/过期/错 ID 清理或拒绝读出；无神经输出不使用随机替代。
- `drone.gd` 将真实 DN 双侧差读出接入期望速度，保留限速 6.4 m/s、加速度 19.2 m/s²、物理碰撞和接触结算。原有 dart 是追逐背景扰动，不是新增的神经闪避。
- 已验证：6 项真实全图测试，直连边切除使逃逸强度 1.0→0.088；左右输入产生相反 DN 和运动方向。20 项离线 sensor/physics 检查；真实 Python→WebSocket→生产 Godot 客户端左右闪避均通过（10 条 Godot 断言，RTT 约 350–410 ms）。迟到/错 ID/暂停在途回复测试已通过。
- 技术待办：统一测试用 Godot 路径，修复 public 测试终止 worker 早于断连持久化的竞争及 Windows UTF-8 日志读取；反馈测试冻结 Drone 运动以专测 reward 而非接触死亡；`test.ps1` 每条命令检查退出码，加入 P2/P3 用例与可选 `-SkipSmoke`。移动端 320 px 宽反馈文字与按钮重叠已修复，54 项通过。快速结束回合时的零帧 FPS 报告现在写 JSON null，不再写非法 inf；新增 2 项报告测试。
- 最终统一入口 `powershell -NoProfile -ExecutionPolicy Bypass -File test.ps1 -SkipSmoke`：退出 0，21 项 Python（含真实客户端 10 条断言）+ 282 项独立 Godot 检查通过。独立端口/口令/学习目录真实 smoke：40 项 CHECK，通过、退出 0、合法 JSON，`reports/p3-neural/game-smoke.json`。无 FPS 样本时为 null，不将其称作性能达标证据。
- 证据目录 `reports/p3-neural/`：original/modified、SHA256 manifest、changes.patch、verification.json、rollback.py；补丁应用及回滚已在隔离目录运行并逐文件核对字节。verification 保留历史失败，最终以 test-ps1 和 modified-isolated-smoke 为准。退出 AudioStreamWAV/Playback 警告尚未解决，不宣称干净退出。未关闭用户进程；未提交 git。
- 下一步：P4 视听反馈。人工操作手感尚待试玩，不以自动化测试代替。

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
- [x] P2: Drone 改造（drone.gd / 四旋翼模型）+ 玩家武器（raycast hitscan / 枪模）+ HP + win/lose；试玩反馈已落实，用户确认单发 15 点伤害
- [x] P3: Threat → neural escape → dodge 双层管线，真实全图/局部消融/生产客户端/战斗 smoke 已验证
- [x] P4: 首版视觉/音效打磨（命中标记、开火/命中/胜负音效、机械旋翼声；自动化/原生渲染已验证，主观手感待试玩）

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

## 2026-09-23 试玩反馈：单发伤害 15（最新入口）

- **用户最新确认**：确认“单发伤害调到 15%”的决定，沿用已经实现的固定 15 点伤害，即当前 Drone 满血 100 点的 15%；不是按剩余血量递减，也未改为随最大 HP 自动缩放。P2 计划功能收尾，P3 保持未开始。本次只更新文档，不修改代码或宣称新增验证。
- 用户确认枪模符合预期，但仍觉得偏难，明确要求单发伤害改为 15。`game/player.gd::weapon_damage` 已由 10 改为 15；100 HP Drone 需要命中 7 枪，HP 序列为 85/70/55/40/25/10/0。
- 不改 0.35 秒射击冷却、25 m 射程、Drone 0.8 速度倍率、接触即死和神经控制。`tests/combat_round.gd` 改为验证七枪结算，`tests/weapon_view.gd` 首枪 HP 期望改为 85；既有冷却与挡墙用例保留。
- 基线 combat_round 19、weapon_view 12 PASS；修改后 combat_round 16、weapon_view 12、gameplay 52 PASS，共 80 项、退出均为 0。战斗断言数少 3 是十枪改为七枪，并非删减其他场景。本轮未重跑真实后端 smoke；部分测试仍有既有退出资源警告。
- 本轮原始快照、改后快照、补丁、验证和已演练回滚保存在 `reports/p2-damage15/`。用户须退出并重启游戏加载新参数；未关闭用户游戏，未提交 git。P3 未开始。

## 2026-09-23 试玩反馈：降速和枪模（历史入口）

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
