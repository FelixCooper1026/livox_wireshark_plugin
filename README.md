# Livox Mid-360 & HAP Wireshark Lua Plugin

一个用于解析 Livox Mid-360 和 HAP 雷达数据的 Wireshark Lua 插件。它可以将原始 UDP 数据包中的信息以易读的方式显示在 Wireshark 协议树中。

## 功能

*   支持 Livox Mid-360 和 HAP 雷达推送消息、点云和IMU数据以及控制指令帧的解析
*   支持 IMU 数据（陀螺仪、加速度计）数据的详细解析与显示
*   将各种设备参数信息字段（如点云坐标格式、扫描模式、IP 配置、IMU 数据使能、固件版本、MAC 地址、核心板温度、时间同步信息等）以清晰的文本形式展示
*   支持解析并显示 HMS 诊断码，提供详细的故障 ID 和异常等级描述
*   支持Livox 控制指令帧解析（如参数配置、设备重启、固件升级等）

## 更新历史（Changelog）

- 2025-06-26：增加对点云及IMU数据的解析
- 2025-06-23：增加 HAP 雷达解析支持
- 2025-06-09：修复time_offset数据类型解析错误，应为 int64_t
- 2025-06-03：修复端口号解析错误，应为小端序
- 2025-05-26：增加对应字段高亮显示功能
- beta modify：将core_temp改为float
- 2025-07-17：增加对控制指令帧的解析
- 2025-08-05: 增加对 Avia 等（老工规雷达） IMU 数据解析
- 2025-09-04: 优化 HMS 诊断码错误描述

## 支持端口

该插件默认会解析以下 UDP 端口上的数据：

**Mid-360 相关端口：**

| 端口   | 用途       |
|--------|------------|
| 56100  | 控制指令   |
| 56200  | 推送数据   |
| 56300  | 点云数据   |
| 56400  | IMU 数据   |

**HAP 相关端口：**

| 端口   | 用途       |
|--------|------------|
| 56000  | 推送数据/控制指令   |
| 57000  | 点云数据   |
| 58000  | IMU 数据   |

**Avia 相关端口：**

| 端口   | 用途       |
|--------|------------|
| 60003  | IMU 数据   |

> 注：不同端口分别用于推送信息、点云/IMU 数据以及控制指令，具体用途如上表所示。

## 安装与使用

要使用此 Lua 脚本作为 Wireshark 插件，请按照以下步骤操作：

1.  **下载 `livox.lua` 文件**:
    将 `livox.lua` 文件下载到您的本地计算机。

2.  **定位 Wireshark 插件目录**:
    打开 Wireshark，然后导航到菜单栏：
    *   `Help` (帮助) -> `About Wireshark` (关于 Wireshark)
    *   在弹出的窗口中，选择 `Folders` (文件夹) 选项卡。
    *   查找 "Personal Lua Plugins" 或 "Global Lua Plugins" 或 "Personal configuration" 对应的路径。通常，您应该将插件放在个人配置文件夹下的 `plugins` 子目录，或者直接放在 Wireshark 的安装目录下的 `plugins` 目录。

    **常见路径示例 (具体路径可能因操作系统和 Wireshark 版本而异)：**
    *   **Windows**:
        *   `C:\Program Files\Wireshark\plugins\` (全局)
        *   `%APPDATA%\Wireshark\profiles\default\plugins\` (用户配置文件，推荐)
    *   **Linux**:
        *   `/usr/lib/wireshark/plugins/` (全局)
        *   `~/.config/wireshark/profiles/default/plugins/` (用户配置文件，推荐)
    *   **macOS**:
        *   `/Applications/Wireshark.app/Contents/Resources/share/wireshark/plugins/` (全局)
        *   `~/Library/Application Support/Wireshark/profiles/default/plugins/` (用户配置文件，推荐)

3.  **放置 `livox.lua` 文件**:
    将下载的 `livox.lua` 文件复制到您找到的 Wireshark 插件目录中。

4.  **重启 Wireshark**:
    关闭并重新启动 Wireshark，以确保插件被加载。

5.  **开始抓包或打开抓包文件**:
    现在，当您在 Wireshark 中捕获包含 Livox Pushmsg、点云或 IMU 数据（通过上述 UDP 端口）的网络流量，或打开一个包含这些数据的 `.pcap` 或 `.pcapng` 抓包文件时，Wireshark 将自动使用此插件解析这些数据包，并在协议树中显示详细的 "Livox Pushmsg Diag" 或 "Livox Data" 信息。

    您可以在 Wireshark 的主窗口中，在协议列看到 "LivoxPushmsg" 或 "LivoxData"，并在详细信息窗格中展开协议树来查看解析后的字段。 
