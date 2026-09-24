# FLYFEAR / FlyBrain Arena — Architecture Notes

## P3 当前实现（2026-09-23；下文原内容为 P1 历史基线）

`player` 接受开火 → `last_shot_time`；`ThreatSensor.sample(drone, player)` 检查射程、瞄准射线距离及世界遮挡，产生独立的 `{level:0..1,bearing:-1..1}`。没有模拟子弹运动；即时伤害规则不变。威胁可由预瞄产生，因此反应针对正在形成/持续的攻击而不是撤销命中。

`main` 每帧更新 threat，`director` 有威胁时最多每 0.65 s 提交一个 escape 请求；与普通 decision 共享一个在途计算槽，不在每帧重跑全图。server 每个会话串行计算，escape 不选 scare、不消耗其 budget、不更新 reward；所有客户端共享只读权重但各有独立 state。普通 decision 仍保持原冷却。

`Connectome.step(values, threat=None)` 保持旧调用兼容。`EscapePathway` 从本地 annotation/ids 建立 LC4/LPLC2 左右输入组和 DNp01/DNp03 左右输出组；与原来 R1-R6 drive 相加，通过同一次完整 W@state、24 迭代传播。DN 从未被直接注入。返回完整 neural（原 output/readout/view_activity + escape），所以追逐、脑视图和闪避使用同一状态。未重建/替换数据文件。

逃逸读出：左右半球 DN 正活动和→strength；右−左→lateral；DNp03−DNp01→vertical。这是明示工程读出，不把胞体侧别误称为已验证生物运动坐标。当前 full-graph 实验左右输入可翻转 lateral；垂直偏向向下是本模型/读出的观察，不声称完整三维生物行为。背景追逐的旧随机 dart 不计入神经逃逸证据。

客户端只接受匹配 ID、运行中、请求年龄≤0.85 s 的回复，信号有效期基于原请求时间而非新请求或到达时间。暂停、结束、重连清除；物理层还要求连接新鲜、当前可见威胁和 `source=full_graph_dnp`，否则零 dodge。通过速度/加速度限制及 move_and_slide，没有位移瞬移或免伤。

验证：`tests/test_escape.py`（真实群组和连接、左右输入、局部边消融、无输入、重置、非法值）、`tests/escape.gd`（传感/限速/遮挡/生命周期）、`tests/test_escape_socket.py` + `escape_live.gd`（真实服务和生产客户端）、`tests/test_client.py` + `escape_deadline.gd`（合成延迟只测协议，不当作神经证据）。实现基于本地数据实测，不新增未经外部验证的生物学文献结论。

---

本文档记录从代码通读中确认的架构事实（读 `README.md`、`brain/connectome.py`、`brain/director.py`、`brain/server.py`、`game/director.gd`、`game/fly.gd`、`game/player.gd` 得出）。所有结论都标注来源文件行号，没有猜测。

## 完整数据流

```
玩家键盘/鼠标 (game/player.gd)
    │  CharacterBody3D 物理移动 + 朝向
    ▼
player.telemetry() → {x, z, look_x, look_z, look_y, speed, pause_seconds, retreat, turn_rate}
    │  (player.gd:97-105)
    ▼
game/fly.gd._physics_process(): 视线检测 (raycast, 18 单位内, dot>-0.8)
    │  可见时把 sight 设为 player.telemetry() 的拷贝（fly.gd:134-140）
    ▼
game/director.gd: 每 0.1s 发 telemetry 消息, 每 interval(2-5s) 发 decision 请求 (director.gd:175-183)
    │  WebSocket ws://127.0.0.1:{PORT}/{TOKEN}
    ▼
brain/server.py: handler() 收到 telemetry/decision → normalize(t) (brain/director.py:10-20)
    │  8 维标准化输入 [-1,1]: x/6, (z+5)/11, look_x, look_z, look_y, speed 缩放, pause 缩放, retreat 缩放
    ▼
brain/connectome.py: Connectome.step(values) (connectome.py:137-155)
    │  8 输入 → 分配到 3,377 个 R1-R6 感光神经元的驱动
    │  W[j,i] = C[j,i] * sign(i) / 归一化, a ← a + 0.35*(tanh(1.5*W@a + drive) - a), 迭代 24 次
    │  真实 166,700 神经元 + 25,582,938 有向边稀疏矩阵，来自 MaleCNS v1.0
    ▼
输出: output[4] (L1/L2/L3/Mi1 组平均), readout[12] (4 类型均值 + 8 个下游 context 组)
    │  (connectome.py:148-150)
    ▼
brain/director.py: Readout.choose() 用 12 维 readout 特征选事件 (lights/steps/silhouette/wait)
    │  三种模式: random / fixed(softmax) / learn(LinUCB 风格线性带 UCB)
    │  Budget 限制: 60s 窗口内最多 5 事件，事件间隔≥8s，同事件重复间隔≥16s (director.py:39-56)
    ▼
brain/server.py 把 {action, neural:{output,readout,...}} 发回 Godot
    ▼
game/director.gd 收到 decision → action_received signal, neural 字典存起来
    ▼
game/fly.gd._physics_process(): 读 director.neural.output[4]
    │  lateral = clamp((output[0]-output[1])*15, -1, 1)   ← L1-L2 差驱动左右
    │  climb   = clamp((output[2]+output[3])*5, -0.75, 0.75) ← L3+Mi1 驱动高度
    │  speed   = clamp(|output[0]|*40, 4.8, 8.0)             ← |L1| 驱动接近速度
    │  (fly.gd:128-130)
    ▼
苍蝇 CharacterBody3D velocity/move_and_slide() → 实际逼近玩家
```

## 关键结论：什么是"真神经"，什么是"工程规则"

**真实（来自连接组数据 + 真实矩阵乘法计算）：**
- 166,700 个神经元的连接拓扑、突触接触数、神经递质类型（决定兴奋/抑制符号）
- 每次 decision 请求时实际跑的稀疏矩阵-向量乘法（24 次迭代），`output`/`readout`/`view_activity` 都是这次真实计算的结果
- L1/L2/L3/Mi1 的组平均活动数值

**工程设计（不是生物学，README 原文明确声明）：**
- 8 维遥测→输入神经元的映射方式（`connectome.py:62-64`：R1-R6 按 ID 排序切 8 段，不是空间视网膜映射）
- 输出→事件语义的分配（哪个神经元组对应"调暗灯光"，纯工程决定）
- **飞行体控制规则本身**（`fly.gd:3` 注释原文："Engineered body controller: visual tracking + measured neural modulation, not insect biomechanics"）：追逐距离 2.3 单位、速度上限 8 单位/秒、加速度 24 单位/秒² 全是硬编码常数，只有 lateral/climb/speed 三个系数从神经输出读取，飞行体"看见玩家→追玩家"这个行为逻辑本身是 if/else 写的，不是神经网络学出来的
- 动态方程本身（`a ← a + 0.35*(tanh(...) - a)`，24 次迭代）是工程化的"signed activity deviation model"，不是校准过的 LIF 模型或 Shiu et al. 模型的复现

## 对 FlyBrain Arena 改造的含义

1. **Drone 追逐/贴身逻辑可以直接复用 `fly.gd` 现有框架**：把"苍蝇模型换成无人机 mesh"是纯美术层替换，追逐算法（lateral/climb/speed 从神经输出读取 + 硬编码运动学）架构上不用大改。

2. **闪避（dodge）是全新功能，没有现成代码路径**：现有 4 个神经输出（L1/L2/L3/Mi1）已经被"scare event" 系统占用（lights/steps/silhouette/wait 三选一 + budget）。要做"威胁→looming 信号→神经通路→逃逸输出→dodge"，需要：
   - 新的输入通道：把"玩家开枪/子弹接近"编码成新的感知输入（不能挤占现有 8 维 x/z/look/speed/pause/retreat，需要新增或复用维度）
   - 需要调研 MaleCNS 数据里 LPLC2/LC4/DNp01/DNp03/Giant Fiber 等逃逸相关神经元的真实 body ID 是否存在于 `data/mapping.json` 之外的 annotation 表里（当前 mapping.json 只含 R1-R6 输入和 L1/L2/L3/Mi1 输出，逃逸通路神经元尚未被挑出来）
   - 需要新的输出读出：从这些逃逸神经元组读活动值，映射到 dodge 方向/强度

3. **Godot ↔ Python 协议需要扩展**：当前 `brain/server.py` 的 decision 消息只返回 `{action, neural}` 用于 scare event。Dodge 需要复用同一次 `Connectome.step()` 调用（不能加第二次矩阵乘法，性能上不允许每帧跑两次 24 迭代稀疏乘法），而是从同一次 step 的输出/readout 里额外读取逃逸相关神经元组的活动，作为 dodge 信号跟 scare event 并行返回。

4. **两层实现路径（对应 mission Stage A/B）**：
   - Stage A: 先搭 `ThreatSensor → NeuralBackend → EscapeSignal → DroneController` 接口，`NeuralBackend` 这一层可以先用现有 `Connectome.step()` 的 context_groups 读出（8 个已存在的下游分组，`connectome.py:100-103`）做 proxy，明确标注"这是工程 heuristic，不是验证过的逃逸通路"
   - Stage B: 调研 annotations.feather 里 LPLC2/LC4/DNp01/DNp03 等 cell type 是否存在（需要重新跑 pyarrow 读 annotations 表按 type 过滤），如果存在则在 `data/mapping.json` 里新增一组"escape_output"神经元 ID 列表，改造 `Connectome.__init__` 或 `mapping()` 增加这组读出

## 尚待调研（不是猜测，是明确的 TODO）

- [ ] MaleCNS annotations.feather 的 `type` 列里是否真的存在 LPLC2/LC4/DNp01/DNp03/Giant Fiber 对应的 cell type 标签，以及每种有多少个神经元、体 ID 是什么
- [ ] 这些候选逃逸神经元与现有 8 个输入组（尤其视觉相关的 R1-R6）之间是否存在真实有向连接（如果没有连接，读出值不会对威胁输入敏感，等于假信号）
