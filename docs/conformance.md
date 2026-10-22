# Linux v6.12 Kconfig 符合性

## 固定终点

本项目以 Linux v6.12、提交 `adc218676eef25575469234709c2d87185ca223a` 的 Kconfig 语言与最终配置语义为完整符合性终点，包括预处理及跨文件同名声明。参考为该提交的语言/宏文档和 `scripts/kconfig/conf`；不是泛指所有 Kconfig 方言。0.3.0 的 `parse_linux612` 单独固定此语义，已有可移植扩展保留原 API。

此前阶段把命名/tristate/optional choice、glob source 当作此版本欠缺项，版本核对后纠正：这些不是 v6.12 的合法语法。固定路径按原生接受/拒绝处理，而非追加不同方言语法。

## 已补齐的行为

| 问题 | 实现与回归 |
| --- | --- |
| 多文件同名声明 | 每个声明保留局部条件，依赖/提示组合保留节点语义，默认按遍历顺序；`source_locations` 返回全部位置 |
| 预处理 | 变量赋值、参数、嵌套函数、内建函数、消息副作用、文件/行号、宿主环境和 Shell；帮助正文不作为宏或代码重复扫描 |
| 语言与选择 | 匿名 bool choice 的成员归属、默认、重复提示和告警，modules 唯一性，menu/if 条件、真实帮助缩进 |
| 原生数值 | RawNumber 保留文本，C 数值前缀/溢出/带符号与无符号比较，范围端点的基数、钳制与拼写 |
| 兼容配置 | `read_linux_config` 宽松读入并产生诊断；有效后写覆盖；`export_linux_config` 与原生赋值省略规则对照 |
| 警告与错误 | 原生接受但警告的声明不能升级成解析失败；原生拒绝的输入不能静默接受 |

完整行为通过源代码、常驻回归与独立原生对照共同维护，没有将上述语言功能排除在终点之外。

## 跨文件同名声明及最终配置

`examples/linux612/main.mbt` 提供完整可执行输入：根文件声明 LEFT/RIGHT，然后 source 两个文件；left/Kconfig 的第 2 行声明 int SHARED 默认 11，继承 LEFT；right/Kconfig 第 2 行同名声明默认 22，继承 RIGHT。两个位置均保留。

| LEFT | RIGHT | 显式 SHARED | 最终 SHARED | 导出 |
| --- | --- | --- | --- | --- |
| n | n | 无 | 0 | 不写 SHARED |
| y | n | 无 | 11 | CONFIG_SHARED=11 |
| n | y | 无 | 22 | CONFIG_SHARED=22 |
| y | y | 无 | 11 | CONFIG_SHARED=11 |
| n | y | 37 | 37 | CONFIG_SHARED=37 |

这五组同时列入 `tools/linux612_cases.py`，由原生 conf 生成参考结果。旧 `examples/declarations` 和 Kconfiglib 回读仍验证可移植路径，不代替固定版本证据。

## 独立证据及复现

`tools/linux612-pins.json` 固定外部源文件 Git blob SHA；`tools/build_linux612.py` 检查后编译 C 工具。`tools/linux612.py` 对每个输入运行原生 olddefconfig，再生成临时 MoonBit 断言；临时文件在 finally 清理，不计入生产规模。

当前 327 项包含 14 个上游夹具/模式输入、原创表达式/数值/语法/警告向量、五组跨文件最终配置，以及 7 个真实叶组件在四组明确宿主配置下的 28 个集成输入：温度传感器、RTC、USB serial、TCPM、UCSI、fanotify、inotify。比较接受/拒绝、每个值的实际文本、最终赋值集合；预处理夹具还比较 info/warning 的实际消息及位置。JSON 保留输入 SHA-256、原生返回码和结果映射。

本地 wasm-gc、wasm、JS 已执行同组 327 项。公开 CI 对 wasm-gc/wasm/js/native 重新构建 oracle、执行对照并上传逐项报告。以对应发行提交的真实 CI 为发布门禁；文档不把尚未运行的任务写成通过。

Kconfiglib 14.1.0 的 113 场景/1361 断言是额外回归，不等同于 Linux v6.12 证明。外部 conf 自身的上游自测也不等同于本库通过全部交互测试。

复现命令见根 README 和 CI；测试无需运行库访问 Python、文件系统或 Shell。GPL 外部 oracle 和夹具不进入 MoonCakes 包。

## 边界及缺陷处理

宿主提供源文件映射、环境、Shell 和路径适配；界面呈现、原生生成标题/注释/排版不是库的输出契约。实际赋值、值文本及省略在对照范围内。资源预算公开且超限报错。没有执行完整内核树的配置或内核编译，组件集成不能替代这种证据。

完整符合性是固定的实现承诺；有限输入通过不构成所有输入的形式证明，不保证赛事审核结论。后续发现的目标版本语义差异按缺陷处理，保留回归，不能删除正确预期或改为永久非目标。
