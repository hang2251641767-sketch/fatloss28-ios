# FitLife V4.1 · 原定制计划 + 本地计划库

中文 SwiftUI App，iOS 16.0+，全部训练计划和记录在本机保存。

[直接下载 V4.1 TIPA](https://github.com/hang2251641767-sketch/fatloss28-ios/releases/latest/download/FitLife-V4.1.tipa)
[发布记录](https://github.com/hang2251641767-sketch/fatloss28-ios/releases)

首次 V4.1 构建成功后下载链接生效。本包用于已安装 TrollStore 的兼容设备测试。

## V4.1 更新

上一版只迁移打卡记录，没有包含 V3 硬编码的完整训练表。现在自动补回原定制方案，并提供离线计划库。

原计划从保留的 V3 Sources/ContentView.swift 逐项恢复，25 项处方原文不变：
第 1 天上肢 A、第 2 天下肢 A、第 3 天低强度活动、第 4 天上肢 B、第 5 天恢复步行、第 6 天下肢 B＋核心、第 7 天休息 / 散步，循环 4 周。
如果已有旧开始日期，恢复时保持该日期；周期结束可在“我的方案”从今天重新开始。

内置 10 套：
1. 我的原定制 · 28 天居家减脂
2. 初级 · 自重基础入门
3. 初级 · 哑铃全身入门
4. 中级 · 上下肢四日分化
5. 中级 · 全身力量三日
6. 增肌 · 初级全身三日
7. 增肌 · 中级上下肢四日
8. 减脂 · 初级低冲击
9. 减脂 · 中级力量加有氧
10. 恢复 · 轻活动与灵活性

入口：训练 → 本地计划库。可按难度、目标和关键词筛选，查看器械、周期、每日动作与建议，选择开始日期后加入。
切换只暂停上一套方案，不删除自定义动作和历史；一次启用一套计划库方案，自定义每周循环计划独立保留。
重新开始已加入的方案会保留自己的动作修改。再次从库加入同一模板则建立新实例，保留旧实例。
所有计划由本项目编写；没有复制 Keep 视频、课程或付费内容。

重量默认 0 kg，需按自己的能力填写。次数/秒数默认采用建议范围下限。单侧动作按每侧记录。步行和支撑按秒记录并显示原始分钟/秒范围；活动习惯项目使用勾选清单。

## 升级与数据

Bundle ID 保持 `com.example.fatloss28`；持久化数据键保持 `fitlife.v4.data`，JSON 备份 schema version 仍为 4。
新增字段均可选，旧 V4.0 JSON 和没有新字段的自定义计划可继续读取。
首次 V4.1 启动只补回一次原方案，不覆盖原训练、体重或饮食。旧方案存在时也不重复创建。
若之前已有自定义计划，恢复的原方案先保存在“我的计划库方案”，不会强行更换当前安排；可手动启用。
V3 的 weightLog / doneItems 保留日期迁移，腰围等原始 JSON 存入 legacyV3 且旧键不删除。

先在旧版“我的”导出 JSON 备份，再通过 TrollStore 覆盖安装。不要先卸载；实机数据容器保留仍需设备验证。
恢复 JSON 会替换当前记录；恢复前建议备份，应用会另保留本机恢复前快照。

## 基础功能

首页：体重目标/趋势、今日训练、方案周数、连续打卡。
训练：本地计划库、自定义动作/组数/次数/重量、休息计时、独立训练历史。
饮食：按日期记录热量、蛋白质、碳水、脂肪。
日历：计划安排、训练记录、历史体重和补录。
我的：首次个人资料、目标、通知提醒、JSON 备份恢复。
数字输入有键盘“完成”按钮，支持滑动收起。

## Windows / GitHub

这个仓库的主分支更新会触发 Actions 的 **Build FitLife V4.1 TIPA**。也可到 Actions → 选择工作流 → Run workflow。
依次执行资源检查、生成 Xcode 工程、iOS 模拟器回归测试、iOS Release 编译、ad-hoc 签名、TIPA 校验并发布 GitHub Release。
成功后可以从 Releases 直接下载 .tipa，不需要 Mac 或 Apple 开发者证书。

上传到自己的新仓库时，解压源码 ZIP 并上传目录内容，不要只上传 ZIP；根目录需包含 FitLife、Tests、scripts、.github、project.yml：
```powershell
git init
git add FitLife Tests scripts .github project.yml README.md .gitignore
git commit -m "FitLife V4.1"
git branch -M main
git remote add origin https://github.com/你的用户名/你的仓库名.git
git push -u origin main
```
更换仓库时同步修改 README 下载链接。如果 Release 发布被组织权限限制，可以从成功构建的 Actions Artifact 下载并解压。

## TrollStore 安装

Safari 下载 .tipa → 文件 App → 分享 → TrollStore → 安装。
App 要求 iOS 16.0+，但 TrollStore 本身并不支持所有 iOS 16+ 版本，请核对 [TrollStore 官方说明](https://github.com/opa334/TrollStore)。
普通 iOS / App Store 安装须使用 Apple 的签名流程。

## macOS 本地开发

安装 Xcode、XcodeGen 后运行 `xcodegen generate`，打开 FitLife.xcodeproj。
普通真机签名选择自己的 Team。模拟器测试使用 FitLife scheme 的 Test；未签名设备编译：
```sh
xcodebuild -project FitLife.xcodeproj -scheme FitLife -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

## 测试与参考

回归测试覆盖原计划25项逐字比对、分类完整性、相对开始日期循环、V3迁移、V4兼容、重复升级不重复恢复、切换/重启保留模板和历史、时长单位与备份往返。
静态检查在 Windows 执行；实际 Xcode 编译及 XCTest 结果以对应 Actions 运行记录为准。
未验证：真机 UI、TrollStore 安装、通知交付与真机覆盖后数据容器。

新增训练方案是通用模板而非个人医疗处方。活动组合和渐进原则参考 [CDC 成年人身体活动说明](https://www.cdc.gov/physical-activity-basics/adding-adults/) 和 [ACSM 渐进抗阻训练立场声明](https://doi.org/10.1097/00005768-200202000-00027)；具体动作编排由项目编写，不能保证减脂或增肌效果。

图标沿用 V4 的内置图像生成工具成品：深绿色底、白色心形/叶片与哑铃，无文字、无外部圆角。
