# Livox Wireshark Lua Plugin

一个用于解析 **Livox 全系列雷达数据** 的 Wireshark Lua 插件。  
支持 **Mid-360、HAP、Avia、Horizon、Tele-15、Mid-70、Mid-40** 等产品的数据解析，包括 **推送消息、点云数据、IMU 数据以及控制指令帧** 的解析。

---

## ✨ 功能特性

### 数据解析支持
- **Mid-360 & HAP**  
  - 推送消息  
  - 点云数据  
  - IMU 数据 （陀螺仪、加速度计详细解析与显示） 
  - 控制指令  
- **老产品系列 (Avia/Horizon/Tele-15/Mid-70/Mid-40)**  
  - 点云数据  
  - IMU 数据 （陀螺仪、加速度计详细解析与显示） 
  - 控制指令    


### 控制指令解析
- **通用指令集**  
  握手、心跳、设备信息查询、开始/停止采样、IP 配置、重启  
- **雷达指令集**  
  模式切换、外部参数设置、抗雨雾功能、风扇控制、回波模式设置  
- **详细状态显示**  
  设备状态码、固件版本、工作状态、特征信息  

### 高级特性
- **HMS 诊断码解析**：详细的故障 ID 与异常等级描述  
- **状态码解析**：温度、电压、电机、脏污、固件、PPS、设备寿命等全方位监控  
- **时间同步支持**：PTP、GPS、PPS 等方式  
- **参数配置**：高灵敏度功能、扫描模式、slot id 等  

---

## 📝 更新历史（Changelog）

- **2025-09-19**: 增加对 Avia 等老工规雷达控制指令帧解析，支持通用指令集和雷达指令集全功能解析  
- **2025-09-04**: 优化 HMS 诊断码错误描述  
- **2025-08-05**: 增加对 Avia 等老工规雷达 IMU 数据解析  
- **2025-07-17**: 增加对控制指令帧的解析  
- **2025-06-26**: 增加对点云及 IMU 数据的解析  
- **2025-06-23**: 增加 HAP 雷达解析支持  
- **2025-06-09**: 修复 `time_offset` 数据类型解析错误，应为 `int64_t`  
- **2025-06-03**: 修复端口号解析错误，应为小端序  
- **2025-05-26**: 增加对应字段高亮显示功能    

---

## 📡 支持端口

### Mid-360 相关端口
| 端口  | 用途     | 协议类型   |
|-------|----------|------------|
| 56100 | 控制指令 | LivoxCtrl  |
| 56200 | 推送数据 | LivoxPushmsg |
| 56300 | 点云数据 | LivoxData  |
| 56400 | IMU 数据 | LivoxData  |

### HAP 相关端口
| 端口  | 用途              | 协议类型                  |
|-------|-------------------|---------------------------|
| 56000 | 推送数据/控制指令 | LivoxPushmsg / LivoxCtrl  |
| 57000 | 点云数据          | LivoxData                 |
| 58000 | IMU 数据          | LivoxData                 |

### 老产品系列(Avia, Mid-70等)相关端口
| 端口  | 用途     | 协议类型    |
|-------|----------|-------------|
| 60001 | 点云数据 | LivoxOldData |
| 60003 | IMU 数据 | LivoxOldData |
| 65000 | 控制指令 | LivoxOldCtrl    |

---

## ⚙️ 安装与使用 (Installation & Usage)

### 安装步骤 (Installation Steps)

1. **下载插件 (Download Plugin)**  
   - 下载 `livox.lua` 文件到本地计算机 (Download the `livox.lua` file to your local computer)  

2. **定位 Wireshark 插件目录 (Locate Wireshark Plugin Directory)**  
   - 打开 Wireshark → Help (帮助) → About Wireshark (关于 Wireshark)  
   - 在弹出的窗口中，选择 Folders (文件夹) 选项卡  
   - 查找 Personal Lua Plugins (个人 Lua 插件) 或 Global Lua Plugins (全局 Lua 插件) 路径  

   **常见路径 (Common paths):**  
   - Windows: `%APPDATA%\Wireshark\plugins\`  
   - Linux: `~/.config/wireshark/plugins/`  
   - macOS: `~/Library/Application Support/Wireshark/plugins/`  

3. **放置插件文件 (Place the Plugin File)**  
   - 将 `livox.lua` 文件复制到插件目录中 (Copy the `livox.lua` file into the plugin directory)  

4. **重启 Wireshark (Restart Wireshark)**  
   - 关闭并重新启动 Wireshark，以加载插件 (Close and restart Wireshark to load the plugin)  


---

### 使用说明
- **开始抓包或打开抓包文件**  
- **过滤特定协议**  
  - `livox` → 显示所有 Livox 相关数据包  
  - `livoxpushmsg` → 仅显示推送消息  
  - `livoxdata` → 仅显示点云和 IMU 数据  
  - `livoxolddata` → 仅显示老产品数据  
  - `livoxoldctrl` → 仅显示控制指令  
- **查看解析结果**  
  - 协议列查看协议类型标识  
  - 详细信息窗格展开协议树查看字段  
  - 使用专家信息查看错误与警告  

---

## 📖 协议特性

### 控制指令特性
- 完整的命令集解析（`CMD/ACK/MSG`）  
- 序列号跟踪与 CRC 校验  
- 详细错误代码与状态描述  
- 支持设备特定功能解析  

### 数据协议特性
- 多设备类型支持  
- 多坐标系统（直角坐标系、球坐标系）  
- 多回波模式（单/双/三回波）  
- 时间同步状态显示  
- 设备状态监控  

