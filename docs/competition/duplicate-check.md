# 需求与语义查重（2026-10-20）
本次使用已安装 osc2026-guide 的 Project Research Guide：moon search → MoonCakes 详情 → 上游源码/接口/测试；再核对官方 awesome、GitHub 和永久注册表。结论仅限记录范围，不是绝对唯一或比赛认可。

## 候选与需求门禁
|领域|成熟需求依据及任务|最小核心/验收|决定|
|--|--|--|--|
|随机决策规划|PyMDPtoolbox；导航、库存、维护用户将状态/概率/奖励变成策略|稀疏模型、VI/PI、策略评价；解析解/参考结果|淘汰：zgfzgf899/MoonMDPKit 直接覆盖|
|数字波形|VCD/GTKWave；硬件开发、仿真、测试用户将事件流变成信号时序|声明/事件解析、查询、报告；标准样例|淘汰：moonbit-vcd 与 MiniVCD 已直接覆盖|
|三维制造数据|STL及网格工具；切片、几何、检测用户将网格变成修复/检查结果|二进制/ASCII、拓扑和质量检查|淘汰：mik1e80/stlkit 直接覆盖|
|构建配置语言|Linux Kconfig / Kconfiglib；固件、产品构建、配置UI用户将选项及依赖变成有效配置|三态表达式、类型/依赖/反向依赖、布尔choice、配置读写；Kconfiglib差分及错误边界|选择：记录范围无成熟直接替代|

这些用户任务来自上述成熟生态，不冒充参赛者经历或用户访谈。MoonBit 内缺少可嵌入语义引擎时，重复手写配置依赖和配置导出容易产生不一致；这是设计推断而非已测市场规模。

## 检索记录与限制
- Moon 0.1.20261012，moon search 各词 --limit 100：markov(8)、mdp(2)、bellman(9)、reinforcement(9)、vcd(4)、waveform(16)、stl(6)、mesh(43)、kconfig(2)、menuconfig(0)、tristate(4)、defconfig(10)，另查询 configuration、select imply。多词搜索存在模糊无关匹配，零结果不是唯一性证明；limit100的广义configuration结果不是全量生态。
- MoonCakes 官方 `/api/v0/modules/OWNER/NAME` 取得已发布版本和 repository，详情 docs 路由为SPA不能单凭HTML判断API；改读链接仓库的实际源码/接口/测试。
- GitHub repositories，per_page=100：value iteration language:MoonBit (1 MoonMDPKit)、mdp (2)、vcd (5)、stl (1)、kconfig (0)、Kconfig moonbit (0)、tristate moonbit (0)；另查比赛planning。搜索是索引快照，未对所有私有或未索引仓库作保证。
- 官方清单 https://github.com/moonbitlang/awesome-moonbit 的 README 实读；其中 moonbitlang/parser 是 MoonBit 源码/配置语法解析支持，不是Kconfig求值。最初误用community路径404已纠正，不把404当查重通过。
- 永久注册表完整加载、按行为筛选并读取相关指纹。MoonWire 2026-09-11 曾提 Kconfig 但明确是未预留的替代候选；MoonINI 是无损INI文本编辑，MoonOpenFeature 是Provider SDK，MoonPetri 是标识可达性；不提供Kconfig构建选项求值。未覆盖或抹去任何既有条目。

## 实际近邻能力矩阵
|项目/所读证据|输入及语义|输出/重合分类|处理|
|--|--|--|--|
|[MoonMDPKit](https://github.com/zgfzgf899/MoonMDPKit)：README/solvers.mbt/moonmdpkit_wbtest.mbt|通用稀疏MDP、策略评价/值迭代/策略迭代|策略和值；MDP候选直接重合|不实现该候选|
|[MoonRLLab](https://github.com/liuzhiyug/MoonRLLab)：planning.mbt、接口及测试|学习器/固定gridworld规划|训练及网格策略；MDP高度相邻|MoonMDPKit已足以否决|
|[moon-survival](https://github.com/Lyl66655/moon-survival)：markov_model、decision_analysis、接口|单转移矩阵的队列/医疗经济模型|占用率/成本；不是构建配置|保留边界|
|[moonbit-vcd](https://github.com/lqhy1234567/moonbit-vcd)：README/接口/parser_test|VCD声明与波形事件|时序查询报告；直接重合|淘汰波形候选|
|[stlkit](https://github.com/mik1e80/stlkit)：README及stl_wbtest|STL网格及修复分析|网格质量；直接重合|淘汰网格候选；猜测的根接口路径404不记作接口审计|
|[moon-certified](https://github.com/Juwan-Hwang/moon-certified)：递归源码树|大量算法；搜索词可命中其描述|已读源码树未见Kconfig实现；非全库形式化排除|限制保留，反查再核对|

## 最终范围及独立建设理由
固件作者输入Kconfig及用户值得到依赖约束配置；产品构建者合并片段得到.config和C头；配置UI读取类型/提示/可见性/choice/原因。它是编译期选项语言，不是运行时flag服务、INI文本编辑、通用规则合约或任务DAG调度。将其加进上述近邻会混合完全不同的数据模型，独立包有理由。

语法/语义基线：[Linux Kconfig language](https://github.com/torvalds/linux/blob/f47d223627f80cb7a1eb14c585fe6cb35de5e984/Documentation/kbuild/kconfig-language.rst)；测试参考 [Kconfiglib](https://github.com/ulfalizer/Kconfiglib/tree/061e71f7d78cb057762d88de088055361863deff)（ISC）。独立编写代码与合成fixture，不复制Linux源码。支持的可移植核心必须完成，宏/环境/shell预处理、完整Linux/Zephyr树、三态choice不支持并拒绝，不包装为兼容。

评分（广度/需求/复用/低重合风险/深度/可验证/可完成/维护，1–5）：MDP 5/5/5/1/4/5/5/4；VCD 4/5/4/1/4/5/5/4；STL 5/5/5/1/4/5/4/3；Kconfig 5/5/5/4/5/5/4/4。前三硬失败不以分数补救。最终发布前反查 parse_kconfig / resolve_config / select / imply / write_config 核心行为。
