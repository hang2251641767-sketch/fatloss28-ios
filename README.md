# FitLife V4.0 · 健身生活

纯简体中文 SwiftUI 工程，支持 iOS 16.0+；无第三方运行依赖，本地持久化。

**直接下载安装包：** https://github.com/hang2251641767-sketch/fatloss28-ios/releases/latest/download/FitLife-V4.0.tipa  
**发布记录：** https://github.com/hang2251641767-sketch/fatloss28-ios/releases

链接在首次 V4 Release 构建成功后生效。GitHub Release 文件不要求登录；Actions 的 Artifact 通常需要登录并解压。

## 功能
- 首页：最近体重、体重目标、趋势、今日计划、连续体重/训练打卡。
- 训练：每周循环自定义计划，动作增删，组次与重量编辑，逐组勾选，独立历史训练快照；可暂停/继续的休息计时器。
- 饮食：按日期记录热量、蛋白质、碳水、脂肪和餐次，查看日汇总。
- 日历：日历选日，体重补录、历史体重与训练组次详情。
- 我的：首次资料与目标设置，本地每日提醒，JSON 导出和恢复。
- 所有数字输入页面有键盘“完成”按钮；体重页面使用 FocusState 关闭键盘。

## Windows / GitHub 使用
直接在当前仓库的 Actions 页面选 **Build FitLife V4 TIPA → Run workflow**。成功后打开 Releases，点 `FitLife-V4.0.tipa` 下载，或用上面的直接链接。
无需 Windows 编译环境、Mac 电脑或 Apple 开发者证书。构建在 GitHub 的 macOS runner 执行。

要将源码上传到自己的新仓库：
1. 解压源码 ZIP；仓库根目录必须有 project.yml、FitLife、scripts 和 .github。不要只上传 ZIP。
2. 安装 Git，在解压目录打开 PowerShell，依次执行：
   ```powershell
   git init
   git add FitLife scripts .github project.yml README.md .gitignore
   git commit -m "FitLife V4"
   git branch -M main
   git remote add origin https://github.com/你的用户名/你的仓库名.git
   git push -u origin main
   ```
3. 开启仓库的 Actions。若组织限制令发布步骤无写权限，可到 Settings → Actions → General 检查 Workflow permissions，或从成功构建的 Artifact 下载。
4. 更换仓库时，把 README 中下载链接的用户名和仓库名一起修改。

## TrollStore 测试
在已安装 TrollStore 的兼容设备，用 Safari 下载 .tipa → 文件 App → 分享 → TrollStore → 安装。
本 App 要求 iOS 16.0+；这不代表所有 iOS 16+ 都能安装 TrollStore。请查阅 https://github.com/opa334/TrollStore 的设备/系统说明。
包以 ad-hoc 签名构建，TrollStore 安装时处理自身签名；它不用于 App Store 或普通 iOS 直接安装。

测试：首次资料、体重“完成”收键盘、退出重启数据保留、添加/编辑计划、训练保存后日历查看、休息计时、饮食汇总、关闭提醒、JSON 导出恢复。

## 旧版覆盖与迁移
从本仓库 V3 源码核实旧 Bundle ID 为 `com.example.fatloss28`，V4 已保留这一 ID。
首次 V4 启动自动读取旧 `weightLog` 和 `doneItems`；保留原日期，原始 startDate/waistLog/doneItems/weightLog 也保存在 JSON 备份的 legacyV3 字段中。
旧 keys 不删除。V3 的勾选包含训练、饮食等事项，所以迁移历史明确标为“V3 已打卡项目”，不会冒称每一天都是完整训练。
V3 默认安排并非自定义计划，V4 需建立自己的每周循环计划。

请先备份旧数据，再在 TrollStore 中覆盖安装；不要先卸载旧 App。Bundle ID 相同是复用旧容器的必要条件，真机容器保留仍需设备验证。
如果旧安装并非来自本仓库，请核对它的 Bundle ID 后再覆盖。

## macOS 本地构建
安装 Xcode、XcodeGen，运行 `xcodegen generate`，打开 FitLife.xcodeproj。
普通 Apple 真机签名要选择自己的 Team；TrollStore 测试构建可运行：
```sh
xcodebuild -project FitLife.xcodeproj -scheme FitLife -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

## 验证范围
静态检查：Swift 语法结构、资源 JSON/PNG、plist、Bundle ID、模块入口、iOS 16 不兼容组件扫描。
Actions：XcodeGen 工程生成、iOS Release 编译、签名校验、TIPA 的包目录/Info.plist/可执行文件和最低系统校验。
未验证：真实设备 UI、通知交付、TrollStore 安装和 V3 实机覆盖后的数据容器。
真实构建结果以相应 GitHub Actions 的运行记录为准。

App 图标使用内置图像生成工具制作，提示为“深绿色底、白色心形/叶片与哑铃的苹果原生简约 iOS 图标，无文字、无外部圆角”。
