# 28天减脂打卡 iOS 项目

这是用于 iPhone（iOS 16.0+）的 SwiftUI 本地打卡应用项目，含每日训练清单、饮食参考、体重/腰围记录。

## 重要说明
- 此仓库提供源码和 GitHub Actions 构建流程，不代表已经在真实 iPhone/TrollStore 上验证。
- 工作流尝试将未签名 iOS `.app` 打包为 `.tipa`，能否被你当前 TrollStore 版本安装，需要实际测试。
- 体重与腰围记录、训练打卡保存在应用本机数据中；卸载可能丢失。
- 默认 Bundle ID 是 `com.example.fatloss28`。若你之后要长期使用或安装多个版本，可改成自己的唯一标识。

## 用 GitHub 构建
1. 在 GitHub 新建一个空仓库，例如 `fatloss28-ios`。
2. 上传本项目中的全部文件，确保 `.github/workflows/build-tipa.yml` 也上传。
3. 打开仓库的 **Actions** 标签，选择 **Build TrollStore TIPA**。
4. 点 **Run workflow**，等待任务结束。
5. 成功后打开本次运行页面，在 Artifacts 中下载 `28天减脂打卡-tipa`，解压 ZIP 后取得 `.tipa` 文件。
6. 把 `.tipa` 传到 iPhone，再通过 TrollStore 安装。安装失败时先不要删除原有记录或应用，反馈具体报错。

## 如果 Actions 没有运行
进入仓库 Settings → Actions → General，检查允许 Actions 工作流运行；然后再回到 Actions 手动运行。
