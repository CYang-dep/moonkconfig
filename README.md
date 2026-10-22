# MoonKconfig

MoonBit 编写的可嵌入构建配置引擎，版本 **0.3.0**，模块 `CYang-dep/moonkconfig`，Apache-2.0。

语言实现终点固定为 **Linux v6.12 Kconfig 完整语言符合性**，参考提交 `adc218676eef25575469234709c2d87185ca223a`，包括预处理、跨文件同名声明合并及最终配置求值。0.3.0 提供独立的 `parse_linux612` 路径，保留原有可移植配置 API。符合性目标、证据映射和宿主职责见 [符合性说明](docs/conformance.md)。有限测试是可复验的工程证据，不是对所有输入的形式证明或赛事审核结论。

## 使用场景

- 固件工具将内存源树和板级配置交给统一求值器，输出 `.config` 和 C 头文件。见 [固件示例](examples/firmware/main.mbt)。
- 产品构建合并基础配置与型号覆盖，审计冲突、最终值变化，并生成可重放片段。见 [变体示例](examples/variants/main.mbt)。
- 配置界面复用提示、帮助、来源、可见性、范围和请求探测。见 [UI 示例](examples/ui/main.mbt)。
- Kconfig 集成使用固定版本语言路径处理重复声明、宏、依赖、choice 和兼容配置导入。见 [Linux v6.12 示例](examples/linux612/main.mbt)。

## 安装与环境

安装官方 MoonBit 工具链，在宿主模块执行：

```sh
moon add CYang-dep/moonkconfig@0.3.0
```

本地基线 `moon 0.1.20261016` / `moonc v0.10.16+b1a0e846e`。四个目标为 wasm-gc、wasm、js、native；原生目标需要 C 编译器。CI 记录实际 stable 版本，并分别执行严格检查、测试、构建、六个示例及独立差分。运行库仅依赖官方 core；Python、Kconfiglib、Linux C 工具仅为外部开发验证依赖。

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

## Linux v6.12 路径

`parse_linux612(entry, files, preprocessor~)` 使用明确传入的源树；`files` 是路径到文本的 Map。环境快照、Shell 回调和消息回调经 `Preprocessor` 显式注入，库本身不读取环境、不运行进程。完整用例见 `examples/linux612`。

```moonbit
let schema = @config.parse_linux612("Kconfig", files)
let requests = schema.read_linux_config("CONFIG_RIGHT=y")
let result = schema.resolve(requests)
println(schema.export_linux_config(result))
```

| 领域 | 固定版本语义 |
| --- | --- |
| 声明 | bool/tristate/string/int/hex，menu/menuconfig/if/comment/help，重复声明按遍历顺序合并并保留每个来源 |
| 表达式与值 | 三态逻辑、字符串词典序、带符号/无符号比较、保留数值原始文本与基数 |
| 预处理 | =、:=、+=，参数函数、嵌套展开、标准内建函数、文件/行号和显式环境/Shell 适配 |
| 源树 | 固定版本的字面 source 路径、循环诊断、条件继承；完整输入由宿主提供 |
| 求值 | 首个有效 default、depends on、select、imply、modules、匿名 bool choice、首个活动 range |
| 配置 | 宽松读取及诊断、重复有效赋值后写覆盖，最终配置的赋值省略与数值拼写 |

v6.12 的 choice 为匿名 bool，不支持命名、tristate、optional choice；`source` 不展开 glob。旧可移植 API 的这些扩展不混入固定版本路径。`Value::RawNumber(String, Kind)` 保留 Linux 数值文本；使用枚举穷举匹配的下游需要适配新分支。

跨文件 `SHARED` 在 LEFT 条件下默认 11，在 RIGHT 条件下默认 22：

| LEFT | RIGHT | 显式 SHARED | 最终值 | 最终导出 |
| --- | --- | --- | --- | --- |
| n | n | 无 | 0 | 省略 SHARED |
| y | n | 无 | 11 | CONFIG_SHARED=11 |
| n | y | 无 | 22 | CONFIG_SHARED=22 |
| y | y | 无 | 11 | CONFIG_SHARED=11 |
| n | y | 37 | 37 | CONFIG_SHARED=37 |

运行 `moon run examples/linux612 --target js` 可检查全部五组及两个源位置；同样输入经固定原生 conf 独立对照。

## 可移植 API

`parse_kconfig`、`parse_sources` 及 `Schema::new` 保留原有构建配置行为；`parse_config` 严格拒绝未知、重复或非法赋值，`export_config` 输出完整快照。固定版本路径使用 `read_linux_config` 和 `export_linux_config`。二者的差异是公开 API 契约，不能混用完整快照与原生省略规则。

`merge_fragments` 保留最后覆盖顺序，`overlay_conflicts` 报告覆盖，`changes` 比较最终值。`minimal_fragment` 实际重放求值，`inspect` 和 `request_options` 提供独立元数据副本。详情见 [架构](docs/architecture.md) 和生成的 `.mbti`。

## 验证与复现

```sh
moon info
moon fmt --check
moon check --deny-warn --target js
moon test --deny-warn --target js
moon build --deny-warn --target js
python -m pip install kconfiglib==14.1.0
python tools/differential.py --target js
python tools/check_declarations.py --target js
python tools/audit.py
```

常驻测试 59 个；原有 Kconfiglib 14.1.0 合成对照 113 场景、1361 断言。固定 Linux v6.12 原生 conf 对照 **327 项**，包括接受/拒绝输入、预处理消息、配置值和最终赋值集合、上游语言夹具，以及 7 个真实组件的 28 组配置。工具在测试前检查外部文件的 Git blob 摘要；不把自身输出当参考答案。

原生工具复现（Linux，已安装 cc、bison、flex、Python）：

```sh
git clone --filter=blob:none --no-checkout https://github.com/torvalds/linux _oracle/linux
git -C _oracle/linux checkout adc218676eef25575469234709c2d87185ca223a
python tools/build_linux612.py --source _oracle/linux --output _oracle/build
python tools/linux612.py --source _oracle/linux --conf _oracle/build/conf --target js --report _oracle/report-js.json
```

[四后端工作流](.github/workflows/ci.yml) 在每个提交重新构建外部 oracle 并保存逐项 JSON 证据；请核对对应提交的 CI，不能用旧发行的绿灯代替。`tools/linux612-pins.json` 固定来源及实际输入；`tools/linux612.py` 可在 Windows 通过 `--wsl Ubuntu` 调用外部 conf。

## 限制与宿主职责

- 目标是固定版本的语言与最终配置语义；不交付 Linux 构建系统或终端菜单应用。`.config` 对照比较赋值内容和省略，不复制原生生成标题、菜单注释、排版与诊断的完整呈现格式。
- 宿主需显式提供完整源树、环境、Shell 结果与资源策略。测试包含真实叶组件与合成宿主符号，没有宣称完成整个内核配置树或内核编译。
- 资源有界：4096 符号、表达式 256 tokens / 128 层 / 4096 节点、source 深度 32、scope 深度 64、展开预算 16 Mi UTF-16 单元 / 65536 行、依赖边 65536；精简及交互探测限 256 符号。超限报错，这些预算不是安全认证。
- 有限差分不能穷尽语言输入。发现目标版本的语义差异应作为实现缺陷修复，不能改成永久非目标；当前测试映射与实际证据见符合性说明。

## 许可、参考与 AI 使用

原创实现采用 [Apache-2.0](LICENSE)。固定 Linux v6.12 的 GPL-2.0 源码与夹具由开发工具下载到外部目录，单独编译和运行，未随库发布、不参与运行时链接。Kconfiglib 14.1.0（ISC）仅为开发 oracle。来源、摘要和边界见 [NOTICE](NOTICE.md)。

项目使用 AI 辅助进行实现、测试与文档编写，结论来自实际执行。有限生态检查见 [公开查重记录](docs/competition/duplicate-check.md)。
