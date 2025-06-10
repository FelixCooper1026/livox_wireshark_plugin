# Livox Mid-360 Pushmsg Diagnostic Wireshark Lua Plugin

这是一个用于解析 Livox Mid-360 雷达推送数据的 Wireshark Lua 插件。它能够将原始 UDP 数据包中的推送信息（如雷达配置、工作状态、故障码等）解析并以易读的方式显示在 Wireshark 协议树中。

## 功能

*   解析 Livox Mid-360 推送信息数据
*   将各种诊断字段（如点云坐标格式、扫描模式、IP配置、IMU数据使能、固件版本、MAC地址、核心板温度、时间同步信息等）以清晰的文本形式展示
*   支持解析并显示 HMS 诊断码，提供详细的故障ID和异常等级描述
*   支持对指定 UDP 端口的数据包进行自动解析

## 支持端口

该插件默认会解析以下 UDP 端口上的数据：
*   **56200**
*   **56201**

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
    现在，当您在 Wireshark 中捕获包含 Livox Pushmsg 数据（通过 UDP 端口 56200）的网络流量，或打开一个包含这些数据的 `.pcap` 或 `.pcapng` 抓包文件时，Wireshark 将自动使用此插件解析这些数据包，并在协议树中显示详细的 "Livox Pushmsg Diag" 信息。

    您可以在 Wireshark 的主窗口中，在协议列看到 "Livox"，并在详细信息窗格中展开 "Livox Pushmsg Diag" 协议树来查看解析后的字段。 