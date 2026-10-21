# MoonKconfig

MoonBit 编写的、可嵌入的构建配置引擎。版本 **0.2.0**，模块 `CYang-dep/moonkconfig`，Apache-2.0。

固件、产品变体和配置界面经常需要共同处理“用户请求并不等于最终配置”：隐藏选项不能被强制开启，依赖可能降低可见性，`select` 可以绕过依赖，而 choice 必须互斥。本项目将这些规则放进不依赖文件系统、Shell 或 Python 的 MoonBit 库，供宿主程序复用。

## 面向哪些使用者

- **固件/构建工具作者**：输入内存中的 Kconfig 源树与板级 `.config`，解析依赖并输出确定顺序的 `.config` 和 C 头文件。见 [固件示例](examples/firmware/main.mbt)。
- **产品配置维护者**：合并基础配置和产品覆盖层，审计冲突，比较最终配置的传递变化，生成可重放的精简请求片段。见 [变体示例](examples/variants/main.mbt)。
- **配置界面作者**：读取提示、帮助、类型、可见性、活动范围、来源和求值原因，查询一次显式请求实际可达到的逻辑值。见 [UI 示例](examples/ui/main.mbt)。不附带终端或浏览器 UI。

## 已实现功能

| 领域 | 本版本范围 |
| --- | --- |
| 值与表达式 | `n < m < y`、非/与/或、比较、括号、带溢出检测的 64 位有符号数 |
| 声明与作用域 | bool/tristate/string/int/hex、prompt/help、menu/if 的继承依赖和可见性、跨文件同名声明合并 |
| 源树 | 内存映射上的 source/rsource/osource/orsource，续行、排序通配、树内父路径、全部声明来源、循环与预算检测 |
| 预处理 | = / := / +=、参数函数与嵌套展开、宿主环境快照与 shell 回调、诊断及文件/行号内建函数 |
| 求值 | 首个有效 default、依赖与用户请求、强 select、弱 imply、模块开关 |
| 互斥选择 | 命名/匿名的布尔 choice，条件默认、optional 和最后显式请求顺序 |
| 数值约束 | 首个活动 range，用户越界时回退默认，默认越界时钳制；十六进制上下文 |
| 工程工作流 | 严格 .config 读取、覆盖冲突、配置差异、精简片段、C 头文件、独立 UI 快照 |
| 错误处理 | `ConfigError`，语法来源定位、未知赋值、类型冲突、循环路径与资源上限 |

项目终点固定为 **Linux v6.12 Kconfig 完整语言符合性**，包括跨文件同名声明合并和预处理。**0.2.0 是阶段版本，尚未完成全部符合性**；已实现语义、独立证据和未关闭项见 [符合性目标与跨文件最终配置](docs/conformance.md)。这些剩余差异属于实现任务，不以永久非目标排除。

## 安装与环境

安装官方 MoonBit 工具链。本地验证基线为 `moon 0.1.20261016` / `moonc v0.10.16+b1a0e846e`；CI 记录实际 stable 工具链。库仅依赖官方 core，不需要 Kconfiglib/Python；Python 只用于开发时独立测试。

在宿主模块中固定版本：

```sh
moon add CYang-dep/moonkconfig@0.2.0
```

可移植目标：`wasm-gc`、`wasm`、`js`、`native`。Native 执行需要平台 C 编译器；Windows 本地没有 C 编译器时，使用 Ubuntu CI 验证，不将“编译可用”等同于“本地运行通过”。

## 快速开始

在宿主的 `moon.pkg` 导入：

```moonbit
import {
  "CYang-dep/moonkconfig" @config,
}

pkgtype(kind: "executable")
```

`main.mbt`：

```moonbit
///|
fn main {
  try {
    let schema = @config.parse_kconfig("config ENABLE\n bool \"Enable\"\n default y\nconfig DEPTH\n int \"Depth\"\n range 1 32\n default 8")
    let requests = schema.parse_config("CONFIG_DEPTH=16")
    let result = schema.resolve(requests)
    assert_eq(result.value("ENABLE"), @config.Logic(@config.Y))
    assert_eq(result.value("DEPTH"), @config.Number(16L))
    println(schema.export_config(result))
    println(schema.export_header(result))
  } catch {
    _ => abort("configuration failed")
  }
}
```

```sh
moon run . --target js
```

克隆源码后可直接运行三个完整工作流：

```sh
moon run examples/firmware --target js
moon run examples/variants --target js
moon run examples/ui --target js
```

## 核心 API 与语义

- `parse_kconfig(text)` / `parse_sources(entry, files)` 返回不暴露内部可变定义的 `Schema`；内存源树只允许显式相对路径，绝不执行 Shell 或读取环境。
- `Schema::new`、`add`、`dependency`、`default_value`、`reverse_dependency` 支持直接构建配置模型。构建器表达式同样经过深度/节点校验。
- `schema.parse_config(text)` 是**严格**读取器：未知符号、重复赋值或非法类型会报错，不沿用 Kconfiglib 的宽松警告策略。重复覆盖应拆成片段，再调用 `merge_fragments`。
- `schema.request(fragment, name, value)` 将请求移到最后；`merge_fragments([base, overlay])` 按最后覆盖顺序工作。`overlay_conflicts` 报告发生值变化的请求。
- `schema.resolve(fragment)` 先检测依赖循环，再以有界迭代处理前向/反向依赖和 choice。请求只在提示可见时生效；`select` 绕过直接依赖会产生诊断，`imply` 保留用户否决权。
- 显式 `option modules`（或 `modules` 属性）控制 `m`；未配置/禁用模块时，tristate 按 bool 求值。布尔条件中的裸 `m` 与模块开关联动，比较中的 `m` 保留字面值。
- `result.value(name)` 返回 `Logic`、`Text`、`Number` 或 `Unset`。`Unset` 表示没有值的数字符号，不伪装成零；未定义表达式引用的字符串值为符号名、逻辑值为 n。
- int/hex 的**数值**归一化为 `Int64`；不保留用户的大小写、补零与原始十六进制拼写。hex 文本按十六进制读取，支持无 `0x` 的输入；int 输入要求十进制。超出有符号 64 位范围直接报错。
- `schema.export_config(result)` 按声明顺序输出完整值快照，包含 n 状态；不是逐字保留的原文件编辑器。`export_header` 以 `CONFIG_NAME_MODULE` 表示 m，省略 n 与 Unset。
- `schema.changes(before, after)` 包含间接变化；`minimal_fragment(target)` 通过实际重放贪心删除冗余请求，得到**不可再逐项删减**的片段，不保证全局最少条数。
- `schema.inspect(result)` 返回带类型/提示/帮助/来源/依赖/活动范围的副本；`request_options(fragment, name)` 通过实际求值查询逻辑请求转移，不宣称复刻 menuconfig 的完整控件策略。
- `dependency_order()` 给出稳定拓扑次序，循环错误含实际路径。返回的数组/映射是副本；改变它们不会改变已有 schema 或 resolution。

精简片段与交互探测限定 **256 个符号**，因为它们会重复求值。基础解析/求值上限为 4096 个符号；大型树应先自行评估运行成本，本项目未提供性能基准或“大规模更快”的结论。

正式接口见 [生成接口](pkg.generated.mbti)，实现路径见 [架构与边界](docs/architecture.md)。

## 验证

```sh
moon info
moon fmt --check
moon check --deny-warn --target wasm-gc
moon test --deny-warn --target wasm-gc
moon build --deny-warn --target wasm-gc
python -m pip install kconfiglib==14.1.0
python tools/differential.py --target js
python tools/audit.py
```

把目标替换为 wasm/js/native 可验证其余后端。CI 对四个目标执行严格检查、测试、构建、三个工作流和独立差分。

仓库包含 46 个常驻测试；差分脚本另生成临时测试，与固定 **Kconfiglib 14.1.0** 比较原创合成配置的值、可见性及自身导出回读。当前矩阵为 **113 场景 / 1,361 断言**；增补场景的最新计数由脚本输出，不将有限样本一致视为完整兼容证明。临时生成文件在 `finally` 中删除，不计入实现行数。

## 已知限制与非目标

- 当前未完成 tristate choice、choice 的完整关系与成员 default/select/imply、字符类 source glob、绝对路径宿主映射。它们属于完整符合性目标的待办，见符合性文档。
- 当前未完成环境变量 option、defconfig_list 及完整菜单元数据；transitional 不在目标 v6.12 语言中。Linux 构建系统、自动文件读写、CLI 菜单或网页 UI 不随库提供。menu/comment 标题仅做结构语法检查，不构建菜单树。
- 标量值按类型归一化；以数值符号和字符串混用、依赖原始数字拼写的比较不保证与 Kconfiglib 一致。不要依赖数字的原始文本表示。复杂关系表达式是本库扩展，不宣称属于原生 Kconfig 语法。
- `.config` 不保留注释、空行与字面格式；未知/重复赋值严格拒绝。字符串不允许控制字符，源码宏经过预处理，.config 中的 $ 文本按字面保存，不能用于承载多行文本。
- 单文件最多 4 Mi UTF-16 单元、逻辑行 65,536 单元、表达式最多 256 tokens / 128 层 / 4096 节点、source 深度 32、scope 深度 64、展开预算 16 Mi UTF-16 单元 / 65,536 行、依赖边 65,536。限制是防御性预算，不代表已做安全认证。
- 不支持超过 Int64 上界的无符号 hex；错误诊断以逻辑行为单位，不提供完整编辑器恢复语法树。

## 许可、参考与 AI 使用

原创实现采用 [Apache-2.0](LICENSE)。语言规则参考 Linux Kconfig 文档；独立测试对照 [Kconfiglib](https://github.com/ulfalizer/Kconfiglib) 14.1.0（ISC）。没有复制 Linux 实现、Kconfiglib 代码或上游测试夹具；上游不作为运行依赖或打包源码。参考版本、许可证边界和工具链信息见 [NOTICE](NOTICE.md)。

项目使用 AI 辅助进行选题调研、实现、测试与文档编写；发布依据是实际运行的检查、差分和 CI，不把 AI 推断写成兼容性保证。有限生态检查及被否决方向见 [公开查重记录](docs/competition/duplicate-check.md)。

## 跨文件语义验证

运行 `moon run examples/declarations --target js`，可以看到第二个文件的同名声明单独活动时输出 `CONFIG_SHARED=22`；两个声明都活动时取首个默认值 11，显式请求 37 则得到 37。[完整输入、最终配置及符合性进度](docs/conformance.md)给出可复现步骤。

## 公开验证记录

0.1.0 的 [历史四后端 CI](https://github.com/CYang-dep/moonkconfig/actions/runs/39398752351) 只证明旧版。0.2.0 的证据以对应提交 Actions 和 Release 为准，不能用旧 CI 代替。CI 对四个后端执行 46 个常驻测试、113 场景 / 1361 断言、五个示例及独立 .config 消费验证。有限通过不等于完整语言符合性。
