# 架构与契约

源树与预处理生成带来源的逻辑行；词法/表达式解析器和作用域解析器产生声明节点。重复声明保留每个局部条件、提示、默认与反向边，合并为符号；图检查检测递归依赖。有界固定点求值处理可见性、default、select/imply、modules、choice 与 range，收敛后输出独立结果及诊断。

`parse_linux612` 固定 Linux v6.12 的语言路径；旧 `parse_kconfig`/`parse_sources` 和构建器默认保留可移植扩展。内部 profile 标记贯穿词法、声明、值、导入与导出，不能仅更换解析入口后继续使用旧输出规则。

`Value::RawNumber` 保留 Linux 数值的任意文本表示，运算按相应 C 数值转换语义处理；旧 Number(Int64) 契约保留。严格 `parse_config`/完整快照 `export_config` 与兼容 `read_linux_config`/`export_linux_config` 分开。后者比较最终赋值集合和拼写，不复制原生 UI 排版。

片段保存最后赋值次序；覆盖必须同时移动请求位置。choice 成员归属校验与默认选择独立，固定版本只接受匿名 bool choice。范围采用首个活动规则，按端点类型和基数解释，越界请求回退默认再钳制。`inspect`、来源、诊断和结果数组返回副本，避免调用者改动模式内部状态。

精简片段和交互探测会实际重放求值；最多 256 符号。主流程的符号、表达式、展开和迭代预算见 README。没有性能优于上游或安全沙箱的声明。

外部独立对照由 `tools/linux612.py` 执行：固定 Linux 文件摘要，单独编译 C conf，先取参考结果再生成临时断言，四目标复用同一实际 oracle 契约。常驻测试防回归，Kconfiglib 对照维护旧 API，CI 保存逐项 native 对照报告。详见 [符合性说明](conformance.md)。
