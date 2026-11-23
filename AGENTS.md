# AiSort 项目约定

每次修改 AiSort 应用后，运行 `sh Scripts/install-macos.sh`。脚本会在独立临时目录构建、使用项目的 Developer ID 签名、替换并打开 `/Applications/MyApp/AiSort.app`，结束时清理临时构建产物。

安装后确认该路径下的 AiSort 已启动。清理范围限于构建与安装临时产物，保留应用设置、用户数据和钥匙串。
