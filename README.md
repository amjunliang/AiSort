# AiSort

AiSort 使用 Artificial Analysis 数据，比较 AI 模型的智力、价格和输出速度。支持厂商筛选、搜索、图表缩放、下拉刷新及离线缓存。

## 运行

使用 Xcode 打开 `AiSort.xcodeproj`，选择 AiSort scheme 后运行。首次使用需要在应用设置中填写 [Artificial Analysis API Key](https://artificialanalysis.ai/data-api)；密钥保存在设备钥匙串中，不写入项目。

在配置了项目 Developer ID 证书的 Mac 上，运行 `sh Scripts/install-macos.sh` 可构建、签名并安装到 `/Applications/MyApp/AiSort.app`，然后启动应用。使用同一证书签名更新可保持钥匙串访问身份稳定。

## 结构

- `AiSort/Models`：模型、API 数据结构与排序规则。
- `AiSort/Controllers`：协调数据加载、筛选状态与用户操作。
- `AiSort/Services`：API、离线缓存与钥匙串访问。
- `AiSort/Views`：由图表、工具栏、列表、筛选和详情等组件组合而成的 SwiftUI 界面。`ContentView` 负责页面组合和弹窗状态。

## 验证

在安装了 Xcode 的 macOS 上运行 `Tests/run.sh`，检查模型计算、排序、缓存和筛选状态持久化。也可以在 Xcode 中构建 iOS 或 macOS 目标。
