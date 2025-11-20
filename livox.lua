-------------------------------------------------------------------------------
-- File: livox.lua
-- Description: Wireshark Lua Plugin for Livox Mid-360 Pushmsg Diagnostic
-- Author: FelixCooper1026
-- Date: 2025-06-26
-- Version: 1.2.1
-------------------------------------------------------------------------------
-- History:
-- 2025-11-20: 增加对56500端口Log数据帧解析
-- 2025-11-11: 优化老工规雷达控制指令字段显示
-- 2025-05-26: 增加对应字段高亮显示功能
-- beta modify：将core_temp改为float
-- 2025-06-03：修复端口号解析错误，应为小端序
-- 2025-06-09：修复time_offset数据类型解析错误，应为 int64_t
-- 2025-06-23：增加对 HAP 雷达解析支持
-- 2025-06-26：增加对点云及IMU数据的解析
-- 2025-07-17：增加对控制指令帧的解析
-- 2025-08-05: 增加对 Avia 等（老工规雷达）IMU 数据解析
-- 2025-09-04: 优化 HMS 诊断码错误描述
-- 2024-09-19：增加对 Avia 等（老工规雷达）控制指令帧解析
-------------------------------------------------------------------------------


local livox_pushmsg_proto = Proto("LivoxPushmsg", "Livox Pushmsg Diag")

local f_pcl_type = ProtoField.string("livox.pcl_type", "点云坐标格式", base.UNICODE)
local f_pattern_mode = ProtoField.string("livox.pattern_mode", "扫描模式", base.UNICODE)
local f_lidar_ip = ProtoField.string("livox.lidar_ip", "雷达IP信息", base.UNICODE)
local f_target_push = ProtoField.string("livox.target_push", "推送数据目标地址", base.UNICODE)
local f_target_pcl = ProtoField.string("livox.target_pcl", "点云数据目标地址", base.UNICODE)
local f_target_imu = ProtoField.string("livox.target_imu", "IMU数据目标地址", base.UNICODE)
local f_install_attitude = ProtoField.string("livox.install_attitude", "外参配置", base.UNICODE)
local f_fov_cfg0 = ProtoField.string("livox.fov_cfg0", "FOV0配置", base.UNICODE)
local f_fov_cfg1 = ProtoField.string("livox.fov_cfg1", "FOV1配置", base.UNICODE)
local f_fov_en = ProtoField.string("livox.fov_en", "FOV使能", base.UNICODE)
local f_detect_mode = ProtoField.string("livox.detect_mode", "探测模式", base.UNICODE)
local f_func_io_cfg = ProtoField.string("livox.func_io_cfg", "功能线配置", base.UNICODE)
local f_work_tgt_mode = ProtoField.string("livox.work_tgt_mode", "目标工作模式", base.UNICODE)
local f_imu_data_en = ProtoField.string("livox.imu_data_en", "IMU数据输出", base.UNICODE)
local f_rpm_mode = ProtoField.string("livox.rpm_mode", "电机转速模式", base.UNICODE)
local f_sn = ProtoField.string("livox.sn", "SN号", base.UNICODE)
local f_product_info = ProtoField.string("livox.product_info", "产品信息", base.UNICODE)
local f_version_app = ProtoField.string("livox.version_app", "固件版本", base.UNICODE)
local f_mac = ProtoField.string("livox.mac", "MAC地址", base.UNICODE)
local f_hms_codes = ProtoField.string("livox.hms_codes", "HMS诊断码", base.UNICODE)
local f_core_temp = ProtoField.float("livox.core_temp", "核心板温度", base.FLOAT)
local f_powerup_count = ProtoField.string("livox.powerup_count", "上电次数", base.UNICODE)
local f_local_time = ProtoField.string("livox.local_time", "雷达本地时间", base.UNICODE)
local f_last_sync_time = ProtoField.string("livox.last_sync_time", "上一次同步的master时间", base.UNICODE)
local f_time_offset = ProtoField.string("livox.time_offset", "时间偏移", base.UNICODE)
local f_time_sync_type = ProtoField.string("livox.time_sync_type", "时间同步方式", base.UNICODE)
local f_fw_type = ProtoField.string("livox.fw_type", "固件类型", base.UNICODE)
local f_error_code = ProtoField.string("livox.error_code", "异常码", base.UNICODE)
local f_loader_version = ProtoField.string("livox.loader_version", "Loader版本", base.UNICODE)
local f_hw_version = ProtoField.string("livox.hw_version", "硬件版本", base.UNICODE)
local f_work_status = ProtoField.string("livox.work_status", "当前工作状态", base.UNICODE)
local f_point_send_en = ProtoField.string("livox.point_send_en", "点云发送控制", base.UNICODE)
local f_blind_spot_set = ProtoField.string("livox.blind_spot_set", "盲区范围设置", base.UNICODE)
local f_glass_heat_support = ProtoField.string("livox.glass_heat_support", "窗口加热支持", base.UNICODE)
local f_fusa_en = ProtoField.string("livox.fusa_en", "FUSA诊断功能", base.UNICODE)
local f_force_heat_en = ProtoField.string("livox.force_heat_en", "强制加热", base.UNICODE)
local f_workmode_after_boot = ProtoField.string("livox.workmode_after_boot", "开机初始化工作模式", base.UNICODE)
local f_status_code = ProtoField.string("livox.status_code", "状态码", base.UNICODE)
local f_lidar_flash_status = ProtoField.string("livox.lidar_flash_status", "Flash状态", base.UNICODE)
local f_cur_glass_heat_state = ProtoField.string("livox.cur_glass_heat_state", "当前窗口加热状态", base.UNICODE)

livox_pushmsg_proto.fields = {
    f_pcl_type, f_pattern_mode, f_lidar_ip, f_target_push, f_target_pcl, f_target_imu, f_install_attitude,
    f_fov_cfg0, f_fov_cfg1, f_fov_en, f_detect_mode, f_func_io_cfg,
    f_work_tgt_mode, f_imu_data_en, f_rpm_mode, f_sn, f_product_info, f_version_app, f_mac,
    f_hms_codes, f_core_temp, f_powerup_count, f_local_time, f_last_sync_time,
    f_time_offset, f_time_sync_type, f_fw_type, f_error_code,
    f_loader_version, f_hw_version, f_work_status,
    f_point_send_en, f_blind_spot_set, f_glass_heat_support, f_fusa_en,
    f_force_heat_en, f_workmode_after_boot, f_status_code, f_lidar_flash_status,
    f_cur_glass_heat_state
}

local fault_id_dict = {
    ["0000"] = "无故障",
    ["0102"] = "设备运行环境温度偏高;请检查环境温度，或排查散热措施",
    ["0103"] = "设备运行环境温度较高;请检查环境温度，或排查散热措施",
    ["0104"] = "设备球罩存在脏污或附近有遮挡物，请及时清洗擦拭设备球罩，或确保球罩0.1m范围内无遮挡物",
    ["0105"] = "设备固件升级过程中出现错误;请重新进行固件升级",
    ["0111"] = "设备内部器件温度异常;请检查环境温度，或排查散热措施",
    ["0112"] = "设备内部器件温度异常;请检查环境温度，或排查散热措施",
    ["0113"] = "设备内部IMU器件暂停工作;请重启设备恢复",
    ["0114"] = "设备运行环境温度高;请检查环境温度，或排查散热措施",
    ["0115"] = "设备运行环境温度超过承受极限，设备已停止工作;请检查环境温度，或排查散热措施",
    ["0116"] = "设备外部电压异常;请检查外部电压",
    ["0117"] = "设备参数异常;请尝试重启设备恢复",
    ["0201"] = "扫描模块低温加热中",
    ["0210"] = "扫描模块异常，请尝试：1.检查供电是否正常 2.重启设备 3.更新最新固件",
    ["0211"] = "扫描模块异常，请尝试：1.检查供电是否正常 2.重启设备 3.更新最新固件",
    ["0212"] = "扫描模块异常，请尝试：1.检查供电是否正常 2.重启设备 3.更新最新固件",
    ["0213"] = "扫描模块异常，请尝试：1.检查供电是否正常 2.重启设备 3.更新最新固件",
    ["0214"] = "扫描模块异常，请尝试：1.检查供电是否正常 2.重启设备 3.更新最新固件",
    ["0215"] = "扫描模块异常，请尝试：1.检查供电是否正常 2.重启设备 3.更新最新固件",
    ["0216"] = "扫描模块异常，请尝试：1.检查供电是否正常 2.重启设备 3.更新最新固件",
    ["0217"] = "扫描模块异常，请尝试：1.检查供电是否正常 2.重启设备 3.更新最新固件",
    ["0218"] = "扫描模块异常，请尝试：1.检查供电是否正常 2.重启设备 3.更新最新固件",
    ["0219"] = "扫描模块异常，请尝试：1.检查供电是否正常 2.重启设备 3.更新最新固件",
    ["0401"] = "检测到以太网连接曾经断开过，现已恢复正常，请检查以太网链路是否存在异常",
    ["0402"] = "PTP同步中断，或者时间跳变太大，请排查PTP时钟源是否工作正常",
    ["0403"] = "PTP版本为1588-V2.1版本，设备不支持该版本，请更换1588-V2.0版本进行同步",
    ["0404"] = "PPS同步异常，请检查PPS及GPS信号",
    ["0405"] = "时间同步曾经发生过异常，现已恢复正常，请检查发生异常原因",
    ["0406"] = "时间同步精度低，请检查同步源",
    ["0407"] = "缺失GPS信号导致GPS同步失败，请检查GPS信号",
    ["0408"] = "缺失PPS信号导致GPS同步失败，请检查PPS信号",
    ["0409"] = "GPS信号异常，请检查GPS信号源",
    ["040A"] = "PTP和gPTP信号同时存在，同步存在问题；请检查网络拓扑，单独使用PTP或gPTP同步"
}

local fault_level_dict = {
    ["0000"] = "无故障",
    ["0100"] = "Info消息",
    ["0200"] = "Warning警告",
    ["0300"] = "Error错误",
    ["0400"] = "Fatal严重错误"
}

-- cmd_id 含义映射表
local cmd_id_desc = {
    [0x0000] = "广播发现",
    [0x0100] = "参数信息配置",
    [0x0101] = "雷达信息查询",
    [0x0102] = "雷达信息推送",
    [0x0200] = "请求设备重启",
    [0x0201] = "恢复出厂设置",
    [0x0202] = "设置雷达GPS时间同步时间戳",
    [0x0300] = "log文件推送",
    [0x0301] = "log采集配置",
    [0x0302] = "log系统时间同步",
    [0x0303] = "debug点云采集配置",
    [0x0400] = "请求开始升级",
    [0x0401] = "固件数据传输",
    [0x0402] = "固件传输结束",
    [0x0403] = "获取固件升级状态"
}

-- 返回码映射表
local ret_code_map = {
    [0x00] = "执行成功",
    [0x01] = "执行失败",
    [0x02] = "当前状态不支持",
    [0x03] = "设置值超出范围",
    [0x20] = "参数不支持",
    [0x21] = "参数需重启生效",
    [0x22] = "参数只读，不支持写入",
    [0x23] = "请求参数长度错误，或ack数据包超过最大长度",
    [0x24] = "参数key_num和key_list不匹配",
    [0x30] = "公钥签名验证错误",
    [0x31] = "固件摘要签名验证错误",
    [0x32] = "固件类型不匹配",
    [0x33] = "固件长度超出范围",
    [0x34] = "固件擦除中"
}

-- key 含义和格式映射表（参考336-762行）
local key_map = {
    [0x0000] = {name="点云坐标格式", fmt=function(b) local v=b(0,1):uint(); local t={[0x01]="直角坐标(32bits)",[0x02]="直角坐标(16bits)",[0x03]="球坐标"}; return t[v] or string.format("未知格式(0x%02X)",v) end, len=1},
    [0x0001] = {name="扫描模式", fmt=function(b) local v=b(0,1):uint(); local t={[0x00]="非重复扫描",[0x01]="重复扫描",[0x02]="低帧率重复扫描模式"}; return t[v] or string.format("未知格式(0x%02X)",v) end, len=1},
    [0x0003] = {name="点云发送控制", fmt=function(b) local v=b(0,1):uint(); local t={[0x00]="进入工作模式发送点云",[0x01]="进入工作模式不发送点云"}; return t[v] or string.format("未知(0x%02X)",v) end, len=1},
    [0x0004] = {name="雷达IP信息", fmt=function(b) return string.format("IP地址：%d.%d.%d.%d 子网掩码：%d.%d.%d.%d 网关：%d.%d.%d.%d",b(0,1):uint(),b(1,1):uint(),b(2,1):uint(),b(3,1):uint(),b(4,1):uint(),b(5,1):uint(),b(6,1):uint(),b(7,1):uint(),b(8,1):uint(),b(9,1):uint(),b(10,1):uint(),b(11,1):uint()) end, len=12},
    [0x0005] = {name="推送数据目标地址", fmt=function(b) return string.format("IP: %d.%d.%d.%d 端口: %d",b(0,1):uint(),b(1,1):uint(),b(2,1):uint(),b(3,1):uint(),b(4,2):le_uint()) end, len=6},
    [0x0006] = {name="点云数据目标地址", fmt=function(b) return string.format("IP: %d.%d.%d.%d 端口: %d",b(0,1):uint(),b(1,1):uint(),b(2,1):uint(),b(3,1):uint(),b(4,2):le_uint()) end, len=6},
    [0x0007] = {name="IMU数据目标地址", fmt=function(b) return string.format("IP: %d.%d.%d.%d 端口: %d",b(0,1):uint(),b(1,1):uint(),b(2,1):uint(),b(3,1):uint(),b(4,2):le_uint()) end, len=6},
    [0x0012] = {name="外参配置", fmt=function(b) return string.format("Roll: %.2f°, Pitch: %.2f°, Yaw: %.2f°, X: %dmm, Y: %dmm, Z: %dmm",b(0,4):le_float(),b(4,4):le_float(),b(8,4):le_float(),b(12,4):le_int(),b(16,4):le_int(),b(20,4):le_int()) end, len=24},
    [0x0015] = {name="FOV0配置", fmt=function(b) return string.format("水平：%d° ~ %d°, 垂直：%d° ~ %d°",b(0,4):le_int(),b(4,4):le_int(),b(8,4):le_int(),b(12,4):le_int()) end, len=16},
    [0x0016] = {name="FOV1配置", fmt=function(b) return string.format("水平：%d° ~ %d°, 垂直：%d° ~ %d°",b(0,4):le_int(),b(4,4):le_int(),b(8,4):le_int(),b(12,4):le_int()) end, len=16},
    [0x0017] = {name="FOV使能", fmt=function(b) local v=b(0,1):uint(); return string.format("FOV0:%s FOV1:%s",bit.band(v,0x01)~=0 and "开启" or "关闭",bit.band(v,0x02)~=0 and "开启" or "关闭") end, len=1},
    [0x0018] = {name="探测模式", fmt=function(b) local v=b(0,1):uint(); local t={[0x00]="正常探测模式",[0x01]="敏感探测模式"}; return t[v] or string.format("未知格式(0x%02X)",v) end, len=1},
    [0x0019] = {name="功能线配置", fmt=function(b) local s='' for i=0,b:len()-1 do s=s..tostring(b(i,1):uint()) if i<b:len()-1 then s=s..'.' end end return s end},
    [0x001A] = {name="目标工作模式", fmt=function(b) local v=b(0,1):uint(); local t={[0x01]="采样",[0x02]="待机",[0x04]="错误",[0x05]="自检",[0x06]="电机启动",[0x08]="升级",[0x09]="就绪"}; return t[v] or string.format("未知格式(0x%02X)",v) end, len=1},
    [0x001C] = {name="IMU数据输出", fmt=function(b) local v=b(0,1):uint(); local t={[0x00]="关闭",[0x01]="开启"}; return t[v] or string.format("未知格式(0x%02X)",v) end, len=1},
    [0x0021] = {name="电机转速模式", fmt=function(b) local v=b(0,1):uint(); local t={[0x00]="默认转速",[0x01]="低转速"}; return t[v] or string.format("未知格式(0x%02X)",v) end, len=1},
    [0x8000] = {name="SN号", fmt=function(b) return b:stringz() end},
    [0x8001] = {name="产品信息", fmt=function(b) return b:stringz() end},
    [0x8002] = {name="固件版本", fmt=function(b) if b:len()>=4 then return string.format("%d.%d.%04d",b(0,1):uint(),b(1,1):uint(),b(2,1):uint()*100+b(3,1):uint()) else return "" end end, len=4},
    [0x8003] = {name="Loader版本", fmt=function(b) local s='' for i=0,b:len()-1 do s=s..tostring(b(i,1):uint()) if i<b:len()-1 then s=s..'.' end end return s end},
    [0x8004] = {name="硬件版本", fmt=function(b) local s='' for i=0,b:len()-1 do s=s..tostring(b(i,1):uint()) if i<b:len()-1 then s=s..'.' end end return s end},
    [0x8005] = {name="MAC地址", fmt=function(b) local s='' for i=0,5 do s=s..string.format("%02X",b(i,1):uint()) if i<5 then s=s..":" end end return s end, len=6},
    [0x8006] = {name="当前工作状态", fmt=function(b) local v=b(0,1):uint(); local t={[0x01]="采样",[0x02]="待机",[0x04]="错误",[0x05]="自检",[0x06]="电机启动",[0x08]="升级",[0x09]="就绪"}; return t[v] or string.format("未知状态(0x%02X)",v) end, len=1},
    [0x8007] = {name="核心板温度", fmt=function(b) return string.format("%.2f ℃",b(0,4):le_int()/100.0) end, len=4},
    [0x8008] = {name="上电次数", fmt=function(b) return string.format("%d 次",b(0,4):le_uint()) end, len=4},
    [0x8009] = {name="雷达本地时间", fmt=function(b) local t=tonumber(tostring(b(0,8):le_uint64()))/1000000 return string.format("%.3f ms",t) end, len=8},
    [0x800A] = {name="上一次同步的master时间", fmt=function(b) local t=tonumber(tostring(b(0,8):le_uint64()))/1000000 return string.format("%.3f ms",t) end, len=8},
    [0x800B] = {name="时间偏移", fmt=function(b) local t=tonumber(tostring(b(0,8):le_int64()))/1000 return string.format("%.3f us",t) end, len=8},
    [0x800C] = {name="时间同步方式", fmt=function(b) local v=b(0,1):uint(); local t={[0x00]="无时间同步",[0x01]="PTP(IEEE 1588v2.0)",[0x02]="GPS"}; return t[v] or string.format("未知格式(0x%02X)",v) end, len=1},
    [0x800E] = {name="异常码", fmt=function(b) return string.format("0x%04X",b(0,2):le_uint()) end, len=2},
    [0x8010] = {name="固件类型", fmt=function(b) local v=b(0,1):uint(); local t={[0x00]="loader",[0x01]="application_image"}; return t[v] or string.format("未知格式(0x%02X)",v) end, len=1},
    [0x8012] = {name="当前窗口加热状态", fmt=function(b) local v=b(0,1):uint(); local t={[0x00]="未加热",[0x01]="正在加热"}; return t[v] or string.format("未知(0x%02X)",v) end, len=1},
    [0x800F] = {name="Flash状态", fmt=function(b) local v=b(0,1):uint(); local t={[0x00]="idle",[0x01]="busy"}; return t[v] or string.format("未知(0x%02X)",v) end, len=1},
    [0x0013] = {name="盲区范围设置", fmt=function(b) return string.format("%d cm (范围50~200cm)",b(0,4):le_uint()) end, len=4},
    [0x001B] = {name="窗口加热支持", fmt=function(b) local v=b(0,1):uint(); local t={[0x00]="禁止窗口加热功能",[0x01]="允许窗口加热功能"}; return t[v] or string.format("未知(0x%02X)",v) end, len=1},
    [0x001D] = {name="FUSA诊断功能", fmt=function(b) local v=b(0,1):uint(); local t={[0x00]="关闭fusa诊断功能",[0x01]="开启fusa诊断功能"}; return t[v] or string.format("未知(0x%02X)",v) end, len=1},
    [0x001E] = {name="强制加热", fmt=function(b) local v=b(0,1):uint(); local t={[0x00]="关闭强制加热",[0x01]="开启强制加热"}; return t[v] or string.format("未知(0x%02X)",v) end, len=1},
    [0x0020] = {name="开机初始化工作模式", fmt=function(b) local v=b(0,1):uint(); local t={[0x00]="待机状态(默认值)",[0x01]="采样状态",[0x02]="待机状态"}; return t[v] or string.format("未知(0x%02X)",v) end, len=1},
    [0x800D] = {name="状态码", fmt=function(b) local s="0x"; for i=0,7 do s=s..string.format("%02X",b(i,1):uint()) end; return s end, len=8},
    [0x8011] = {
        name = "HMS诊断码",
        fmt = function(b)
            local fault_id_dict = {
                ["0000"] = "无故障",
                ["0102"] = "设备运行环境温度偏高;请检查环境温度，或排查散热措施",
                ["0103"] = "设备运行环境温度较高;请检查环境温度，或排查散热措施",
                ["0104"] = "设备球罩存在脏污或附近有遮挡物，请及时清洗擦拭设备球罩，或确保球罩0.1m范围内无遮挡物",
                ["0105"] = "设备固件升级过程中出现错误;请重新进行固件升级",
                ["0111"] = "设备内部器件温度异常;请检查环境温度，或排查散热措施",
                ["0112"] = "设备内部器件温度异常;请检查环境温度，或排查散热措施",
                ["0113"] = "设备内部IMU器件暂停工作;请重启设备恢复",
                ["0114"] = "设备运行环境温度高;请检查环境温度，或排查散热措施",
                ["0115"] = "设备运行环境温度超过承受极限，设备已停止工作;请检查环境温度，或排查散热措施",
                ["0116"] = "设备外部电压异常;请检查外部电压",
                ["0117"] = "设备参数异常;请尝试重启设备恢复",
                ["0201"] = "扫描模块低温加热中",
                ["0210"] = "扫描模块异常，请尝试：1.检查供电是否正常 2.重启设备 3.更新最新固件",
                ["0211"] = "扫描模块异常，请尝试：1.检查供电是否正常 2.重启设备 3.更新最新固件",
                ["0212"] = "扫描模块异常，请尝试：1.检查供电是否正常 2.重启设备 3.更新最新固件",
                ["0213"] = "扫描模块异常，请尝试：1.检查供电是否正常 2.重启设备 3.更新最新固件",
                ["0214"] = "扫描模块异常，请尝试：1.检查供电是否正常 2.重启设备 3.更新最新固件",
                ["0215"] = "扫描模块异常，请尝试：1.检查供电是否正常 2.重启设备 3.更新最新固件",
                ["0216"] = "扫描模块异常，请尝试：1.检查供电是否正常 2.重启设备 3.更新最新固件",
                ["0217"] = "扫描模块异常，请尝试：1.检查供电是否正常 2.重启设备 3.更新最新固件",
                ["0218"] = "扫描模块异常，请尝试：1.检查供电是否正常 2.重启设备 3.更新最新固件",
                ["0219"] = "扫描模块异常，请尝试：1.检查供电是否正常 2.重启设备 3.更新最新固件",
                ["0401"] = "检测到以太网连接曾经断开过，现已恢复正常，请检查以太网链路是否存在异常",
                ["0402"] = "PTP同步中断，或者时间跳变太大，请排查PTP时钟源是否工作正常",
                ["0403"] = "PTP版本为1588-V2.1版本，设备不支持该版本，请更换1588-V2.0版本进行同步",
                ["0404"] = "PPS同步异常，请检查PPS及GPS信号",
                ["0405"] = "时间同步曾经发生过异常，现已恢复正常，请检查发生异常原因",
                ["0406"] = "时间同步精度低，请检查同步源",
                ["0407"] = "缺失GPS信号导致GPS同步失败，请检查GPS信号",
                ["0408"] = "缺失PPS信号导致GPS同步失败，请检查PPS信号",
                ["0409"] = "GPS信号异常，请检查GPS信号源",
                ["040A"] = "PTP和gPTP信号同时存在，同步存在问题；请检查网络拓扑，单独使用PTP或gPTP同步"
            }
            local res = {}
            local fault_count = 0
            for i = 0, 7 do
                if b:len() < (i+1)*4 then break end
                local code = b(i*4, 4):le_uint()
                if code ~= 0 then
                    fault_count = fault_count + 1
                    local fault_id = bit.rshift(code, 16)
                    local fault_level = bit.band(code, 0xFF)
                    local fault_id_str = string.format("%04X", fault_id)
                    local level_map = { [0x01] = "Info 消息", [0x02] = "Warning 警告", [0x03] = "Error 错误", [0x04] = "Fatal 严重错误" }
                    local level_desc = level_map[fault_level] or "未知等级"
                    local fault_desc = fault_id_dict[fault_id_str] or string.format("未知故障ID (0x%04X)", fault_id)
                    table.insert(res, string.format("[%d] 0x%08X [%s] %s", fault_count, code, level_desc, fault_desc))
                end
            end
            if fault_count == 0 then
                return "无故障"
            else
                return table.concat(res, "\n")
            end
        end,
        len = 32
    },
}

-- Key-Value list解析函数
local function parse_kv_list(buffer, offset, count, tree)
    for i=1,count do
        if offset+4 > buffer:len() then break end
        local key = buffer(offset,2):le_uint()
        local vlen = buffer(offset+2,2):le_uint()
        if offset+4+vlen > buffer:len() then break end
        local value_buf = buffer(offset+4, vlen)
        local key_hex = string.format("0x%04X", key)
        local desc = key_map[key] and key_map[key].name or "未知"
        local val_str = ""
        if key_map[key] then
            local fmt = key_map[key].fmt
            if key == 0x8011 then
                -- HMS诊断码特殊处理，分行显示
                local hms_tree = tree:add(buffer(offset,4+vlen), string.format("key: %s %s", key_hex, desc))
                local b = value_buf
                local fault_count = 0
                for i = 0, 7 do
                    if b:len() < (i+1)*4 then break end
                    local code = b(i*4, 4):le_uint()
                    if code ~= 0 then
                        fault_count = fault_count + 1
                        local fault_id = bit.rshift(code, 16)
                        local fault_level = bit.band(code, 0xFF)
                        local fault_id_str = string.format("%04X", fault_id)
                        local level_map = { [0x01] = "Info 消息", [0x02] = "Warning 警告", [0x03] = "Error 错误", [0x04] = "Fatal 严重错误" }
                        local level_desc = level_map[fault_level] or "未知等级"
                        local fault_desc = fault_id_dict[fault_id_str] or string.format("未知故障ID (0x%04X)", fault_id)
                        local fault_info = string.format("[诊断码%d] 0x%08X [%s] %s", fault_count, code, level_desc, fault_desc)
                        hms_tree:add(value_buf(i*4, 4), fault_info)
                    end
                end
                if fault_count == 0 then
                    hms_tree:add(value_buf(0, math.min(32, value_buf:len())), "无故障")
                end
            else
                val_str = fmt(value_buf)
                local show = string.format("key: %s %s：%s", key_hex, desc, val_str)
                tree:add(buffer(offset,4+vlen), show)
            end
        end
        offset = offset + 4 + vlen
    end
    return offset
end

-- 控制指令解析函数
local function parse_control_cmd(buffer, pinfo, tree)
    pinfo.cols.protocol = "LivoxCtrlCmd"
    local subtree = tree:add(buffer(), "Livox 控制指令帧")
    if buffer:len() < 24 then
        subtree:add_expert_info(PI_MALFORMED, PI_ERROR, "控制指令包长度不足")
        return
    end
    subtree:add(buffer(0,1), "sof: 0x" .. string.format("%02X", buffer(0,1):uint()))
    subtree:add(buffer(1,1), "version: " .. buffer(1,1):uint())
    subtree:add(buffer(2,2), "length: " .. buffer(2,2):le_uint())
    subtree:add(buffer(4,4), "seq_num: " .. buffer(4,4):le_uint())
    local cmd_id = buffer(8,2):le_uint()
    local cmd_id_hex = string.format("0x%04X", cmd_id)
    local cmd_id_str = cmd_id_desc[cmd_id] or "未知"
    subtree:add(buffer(8,2), string.format("cmd_id: %s (%s)", cmd_id_hex, cmd_id_str))
    local cmd_type = buffer(10,1):uint()
    local cmd_type_str = (cmd_type == 0x00) and "REQ（请求）" or ((cmd_type == 0x01) and "ACK（应答）" or string.format("未知(0x%02X)", cmd_type))
    subtree:add(buffer(10,1), "cmd_type: " .. cmd_type_str)
    local sender_type = buffer(11,1):uint()
    local sender_type_str = (sender_type == 0x00) and "上位机" or ((sender_type == 0x01) and "雷达" or string.format("未知(0x%02X)", sender_type))
    subtree:add(buffer(11,1), "sender_type: " .. sender_type_str)
    subtree:add(buffer(12,6), "resv:（保留位）")
    subtree:add(buffer(18,2), "crc16: 0x" .. string.format("%04X", buffer(18,2):le_uint()))
    subtree:add(buffer(20,4), "crc32: 0x" .. string.format("%08X", buffer(20,4):le_uint()))
    local data_offset = 24
    local data_len = buffer:len() - data_offset
    if data_len <= 0 then return end
    local data_buf = buffer(data_offset, data_len)
    local data_tree = subtree:add(data_buf, "Data:")
    if cmd_id == 0x0000 then -- 广播发现
        if cmd_type == 0x01 and data_len >= 24 then -- ACK
            local ret = data_buf(0,1):uint()
            local ret_str = ret_code_map[ret] or "未知"
            data_tree:add(data_buf(0,1), string.format("ret_code（返回码）: 0x%02X (%s)", ret, ret_str))
            data_tree:add(data_buf(1,1), "dev_type（设备类型）: " .. data_buf(1,1):uint())
            data_tree:add(data_buf(2,16), "serial_number（雷达SN）: " .. data_buf(2,16):string())
            local ip = string.format("%d.%d.%d.%d", data_buf(18,1):uint(), data_buf(19,1):uint(), data_buf(20,1):uint(), data_buf(21,1):uint())
            data_tree:add(data_buf(18,4), "lidar_ip（雷达IP地址）: " .. ip)
            data_tree:add(data_buf(22,2), "cmd_port（当前控制指令端口）: " .. data_buf(22,2):le_uint())
        end
    elseif cmd_id == 0x0100 then -- 参数信息配置
        if cmd_type == 0x00 and data_len >= 4 then -- REQ
            data_tree:add(data_buf(0,2), "key_num: " .. data_buf(0,2):le_uint())
            data_tree:add(data_buf(2,2), "rsvd: " .. data_buf(2,2):le_uint())
            local key_num = data_buf(0,2):le_uint()
            parse_kv_list(data_buf, 4, key_num, data_tree)
        elseif cmd_type == 0x01 and data_len >= 3 then -- ACK
            local ret = data_buf(0,1):uint()
            local ret_str = ret_code_map[ret] or "未知"
            data_tree:add(data_buf(0,1), string.format("ret_code: 0x%02X (%s)", ret, ret_str))
            data_tree:add(data_buf(1,2), "error_key: " .. data_buf(1,2):le_uint())
        end
    elseif cmd_id == 0x0101 then -- 雷达信息查询
        if cmd_type == 0x00 and data_len >= 4 then -- REQ
            data_tree:add(data_buf(0,2), "key_num: " .. data_buf(0,2):le_uint())
            data_tree:add(data_buf(2,2), "rsvd: " .. data_buf(2,2):le_uint())
            local key_num = data_buf(0,2):le_uint()
            local offset = 4
            for i=1,key_num do
                if offset+2 > data_len then break end
                local key = data_buf(offset,2):le_uint()
                local key_hex = string.format("0x%04X", key)
                local desc = key_map[key] and key_map[key].name or "未知"
                data_tree:add(data_buf(offset,2), string.format("key: %s %s", key_hex, desc))
                offset = offset + 2
            end
        elseif cmd_type == 0x01 and data_len >= 3 then -- ACK
            local ret = data_buf(0,1):uint()
            local ret_str = ret_code_map[ret] or "未知"
            data_tree:add(data_buf(0,1), string.format("ret_code: 0x%02X (%s)", ret, ret_str))
            data_tree:add(data_buf(1,2), "key_num: " .. data_buf(1,2):le_uint())
            local key_num = data_buf(1,2):le_uint()
            parse_kv_list(data_buf, 3, key_num, data_tree)
        end
    elseif cmd_id == 0x0102 then -- 雷达信息推送
        if data_len >= 4 then
            data_tree:add(data_buf(0,2), "key_num: " .. data_buf(0,2):le_uint())
            data_tree:add(data_buf(2,2), "rsvd: " .. data_buf(2,2):le_uint())
            local key_num = data_buf(0,2):le_uint()
            parse_kv_list(data_buf, 4, key_num, data_tree)
        end
    elseif cmd_id == 0x0200 then -- 请求设备重启
        if cmd_type == 0x00 and data_len >= 2 then -- REQ
            data_tree:add(data_buf(0,2), "timeout(ms): " .. data_buf(0,2):le_uint())
        elseif cmd_type == 0x01 and data_len >= 1 then -- ACK
            local ret = data_buf(0,1):uint()
            local ret_str = ret_code_map[ret] or "未知"
            data_tree:add(data_buf(0,1), string.format("ret_code: 0x%02X (%s)", ret, ret_str))
        end
    elseif cmd_id == 0x0201 then -- 恢复出厂设置
        if cmd_type == 0x00 and data_len >= 16 then -- REQ
            data_tree:add(data_buf(0,16), "SN (预留字段)")
        elseif cmd_type == 0x01 and data_len >= 1 then -- ACK
            local ret = data_buf(0,1):uint()
            local ret_str = ret_code_map[ret] or "未知"
            data_tree:add(data_buf(0,1), string.format("ret_code: 0x%02X (%s)", ret, ret_str))
        end
    elseif cmd_id == 0x0202 then -- 设置GPS时间同步时间戳
        if cmd_type == 0x00 and data_len >= 9 then -- REQ
            data_tree:add(data_buf(0,1), "type: " .. data_buf(0,1):uint())
            data_tree:add(data_buf(1,8), "time_set(ns): " .. tostring(data_buf(1,8):le_uint64()))
        elseif cmd_type == 0x01 and data_len >= 1 then -- ACK
            local ret = data_buf(0,1):uint()
            local ret_str = ret_code_map[ret] or "未知"
            data_tree:add(data_buf(0,1), string.format("ret_code: 0x%02X (%s)", ret, ret_str))
        end
    elseif cmd_id == 0x0300 then -- log文件推送
        if cmd_type == 0x00 and data_len >= 16 then -- REQ
            data_tree:add(data_buf(0,1), "log_type: " .. data_buf(0,1):uint())
            data_tree:add(data_buf(1,1), "file_index: " .. data_buf(1,1):uint())
            data_tree:add(data_buf(2,1), "file_num: " .. data_buf(2,1):uint())
            data_tree:add(data_buf(3,1), "flag: 0x" .. string.format("%02X", data_buf(3,1):uint()))
            data_tree:add(data_buf(4,4), "timestamp: " .. data_buf(4,4):le_uint())
            data_tree:add(data_buf(8,2), "rsvd: " .. data_buf(8,2):le_uint())
            data_tree:add(data_buf(10,4), "trans_index: " .. data_buf(10,4):le_uint())
            data_tree:add(data_buf(14,2), "log_data_len: " .. data_buf(14,2):le_uint())
            local log_data_len = data_buf(14,2):le_uint()
            if data_len >= 16+log_data_len then
                data_tree:add(data_buf(16,log_data_len), "log_data")
            end
        elseif cmd_type == 0x01 and data_len >= 8 then -- ACK
            data_tree:add(data_buf(0,1), "ret_code: " .. data_buf(0,1):uint())
            data_tree:add(data_buf(1,1), "log_type: " .. data_buf(1,1):uint())
            data_tree:add(data_buf(2,1), "file_index: " .. data_buf(2,1):uint())
            data_tree:add(data_buf(3,4), "trans_index: " .. data_buf(3,4):le_uint())
        end
    elseif cmd_id == 0x0301 then -- log采集配置
        if cmd_type == 0x00 and data_len >= 2 then -- REQ
            data_tree:add(data_buf(0,1), "log_type: " .. data_buf(0,1):uint())
            data_tree:add(data_buf(1,1), "enable: " .. data_buf(1,1):uint())
        elseif cmd_type == 0x01 and data_len >= 1 then -- ACK
            local ret = data_buf(0,1):uint()
            local ret_str = ret_code_map[ret] or "未知"
            data_tree:add(data_buf(0,1), string.format("ret_code: 0x%02X (%s)", ret, ret_str))
        end
    elseif cmd_id == 0x0302 then -- log系统时间同步
        if cmd_type == 0x00 and data_len >= 4 then -- REQ
            data_tree:add(data_buf(0,4), "timestamp: " .. data_buf(0,4):le_uint())
        elseif cmd_type == 0x01 and data_len >= 1 then -- ACK
            local ret = data_buf(0,1):uint()
            local ret_str = ret_code_map[ret] or "未知"
            data_tree:add(data_buf(0,1), string.format("ret_code: 0x%02X (%s)", ret, ret_str))
        end
    elseif cmd_id == 0x0303 then -- debug点云采集配置
        if cmd_type == 0x00 and data_len >= 9 then -- REQ
            data_tree:add(data_buf(0,1), "enable: " .. data_buf(0,1):uint())
            local ip = string.format("%d.%d.%d.%d", data_buf(1,1):uint(), data_buf(2,1):uint(), data_buf(3,1):uint(), data_buf(4,1):uint())
            data_tree:add(data_buf(1,4), "host_ip: " .. ip)
            data_tree:add(data_buf(5,2), "host_port: " .. data_buf(5,2):le_uint())
            data_tree:add(data_buf(7,2), "reserved: " .. data_buf(7,2):le_uint())
        elseif cmd_type == 0x01 and data_len >= 1 then -- ACK
            local ret = data_buf(0,1):uint()
            local ret_str = ret_code_map[ret] or "未知"
            data_tree:add(data_buf(0,1), string.format("ret_code: 0x%02X (%s)", ret, ret_str))
        end
    elseif cmd_id == 0x0400 then -- 请求开始升级
        if cmd_type == 0x00 and data_len >= 7 then -- REQ
            data_tree:add(data_buf(0,1), "firmware_type: " .. data_buf(0,1):uint())
            data_tree:add(data_buf(1,1), "encrypt_type: " .. data_buf(1,1):uint())
            data_tree:add(data_buf(2,4), "firmware_length: " .. data_buf(2,4):le_uint())
            data_tree:add(data_buf(6,1), "dev_type: " .. data_buf(6,1):uint())
        elseif cmd_type == 0x01 and data_len >= 1 then -- ACK
            local ret = data_buf(0,1):uint()
            local ret_str = ret_code_map[ret] or "未知"
            data_tree:add(data_buf(0,1), string.format("ret_code: 0x%02X (%s)", ret, ret_str))
        end
    elseif cmd_id == 0x0401 then -- 固件数据传输
        if cmd_type == 0x00 and data_len >= 12 then -- REQ
            data_tree:add(data_buf(0,4), "firmware_offset: " .. data_buf(0,4):le_uint())
            data_tree:add(data_buf(4,4), "current_length: " .. data_buf(4,4):le_uint())
            data_tree:add(data_buf(8,1), "encrypt_type: " .. data_buf(8,1):uint())
            data_tree:add(data_buf(9,3), "rsvd")
            local remain = data_len - 12
            if remain > 0 then
                data_tree:add(data_buf(12,remain), "data (固件内容)")
            end
        elseif cmd_type == 0x01 and data_len >= 9 then -- ACK
            data_tree:add(data_buf(0,1), "ret_code: " .. data_buf(0,1):uint())
            data_tree:add(data_buf(1,4), "current_offset: " .. data_buf(1,4):le_uint())
            data_tree:add(data_buf(5,4), "received_length: " .. data_buf(5,4):le_uint())
        end
    elseif cmd_id == 0x0402 then -- 固件传输结束
        if cmd_type == 0x00 and data_len >= 2 then -- REQ
            data_tree:add(data_buf(0,1), "checksum_type: " .. data_buf(0,1):uint())
            data_tree:add(data_buf(1,1), "checksum_length: " .. data_buf(1,1):uint())
            local remain = data_len - 2
            if remain > 0 then
                data_tree:add(data_buf(2,remain), "checksum_data")
            end
        elseif cmd_type == 0x01 and data_len >= 1 then -- ACK
            local ret = data_buf(0,1):uint()
            local ret_str = ret_code_map[ret] or "未知"
            data_tree:add(data_buf(0,1), string.format("ret_code: 0x%02X (%s)", ret, ret_str))
        end
    elseif cmd_id == 0x0403 then -- 获取固件升级状态
        if cmd_type == 0x01 and data_len >= 2 then -- ACK
            data_tree:add(data_buf(0,1), "ret_code: " .. data_buf(0,1):uint())
            data_tree:add(data_buf(1,1), "upgrade_progress: " .. data_buf(1,1):uint())
        end
    else
        -- 未知cmd_id，原始显示
        data_tree:add(data_buf, "Raw Data")
    end
end

function livox_pushmsg_proto.dissector(buffer, pinfo, tree)
    -- 新增分流判断：控制指令优先，但端口为56200时仍走推送消息解析
    if buffer:len() >= 1 and buffer(0,1):uint() == 0xAA then
        if pinfo.dst_port ~= 56200 and pinfo.src_port ~= 56200 then
            parse_control_cmd(buffer, pinfo, tree)
            return
        end
    end
    -- 原有推送消息解析逻辑
    pinfo.cols.protocol = "LivoxPushmsg"
    local subtree = tree:add(livox_pushmsg_proto, buffer(), "Livox Pushmsg Diag")
    print("Header:", tostring(buffer(0,28)))
    local index = 28
    while index < buffer:len() do
        if index + 4 > buffer:len() then break end
        local key = buffer(index, 2):le_uint()
        index = index + 2
        local length = buffer(index, 2):le_uint()
        index = index + 2
        if index + length > buffer:len() then break end
        local data_bytes = buffer(index, length)
        index = index + length
        if key == 0x0000 then
            -- 点云坐标格式
            local pcl_type_map = {[0x01]="直角坐标(32bits)", [0x02]="直角坐标(16bits)", [0x03]="球坐标"}
            local val = pcl_type_map[data_bytes(0,1):uint()] or string.format("未知格式(0x%02X)", data_bytes(0,1):uint())
            subtree:add(f_pcl_type, data_bytes(0,1), val) -- 

        elseif key == 0x0001 then
            -- 扫描模式
            local pattern_mode_map = {[0x00]="非重复扫描", [0x01]="重复扫描", [0x02]="低帧率重复扫描模式"}
            local val = pattern_mode_map[data_bytes(0,1):uint()] or string.format("未知格式(0x%02X)", data_bytes(0,1):uint())
            subtree:add(f_pattern_mode, data_bytes(0,1), val) 

        elseif key == 0x0004 then
            -- 雷达IP配置
            local ip = string.format("%d.%d.%d.%d", data_bytes(0,1):uint(), data_bytes(1,1):uint(), data_bytes(2,1):uint(), data_bytes(3,1):uint())
            local subnet = string.format("%d.%d.%d.%d", data_bytes(4,1):uint(), data_bytes(5,1):uint(), data_bytes(6,1):uint(), data_bytes(7,1):uint())
            local gateway = string.format("%d.%d.%d.%d", data_bytes(8,1):uint(), data_bytes(9,1):uint(), data_bytes(10,1):uint(), data_bytes(11,1):uint())
            local val = "IP地址："..ip.." 子网掩码："..subnet.." 网关："..gateway
            subtree:add(f_lidar_ip, data_bytes(0,12), val) 

        elseif key == 0x0005 then
            -- 推送数据目标地址
            local ip = string.format("%d.%d.%d.%d", data_bytes(0,1):uint(), data_bytes(1,1):uint(), data_bytes(2,1):uint(), data_bytes(3,1):uint())
            local port = data_bytes(4,2):le_uint()
            local val = string.format("IP: %s  端口: %d", ip, port)
            subtree:add(f_target_push, data_bytes(0,6), val) 

        elseif key == 0x0006 then
            -- 点云数据目标地址
            local ip = string.format("%d.%d.%d.%d", data_bytes(0,1):uint(), data_bytes(1,1):uint(), data_bytes(2,1):uint(), data_bytes(3,1):uint())
            local port = data_bytes(4,2):le_uint()
            local val = string.format("IP: %s  端口: %d", ip, port)
            subtree:add(f_target_pcl, data_bytes(0,6), val) 

        elseif key == 0x0007 then
            -- IMU数据目标地址
            local ip = string.format("%d.%d.%d.%d", data_bytes(0,1):uint(), data_bytes(1,1):uint(), data_bytes(2,1):uint(), data_bytes(3,1):uint())
            local port = data_bytes(4,2):le_uint()
            local val = string.format("IP: %s  端口: %d", ip, port)
            subtree:add(f_target_imu, data_bytes(0,6), val) 
            
        elseif key == 0x0012 then
            -- 外参配置
            local roll = data_bytes(0,4):le_float()
            local pitch = data_bytes(4,4):le_float()
            local yaw = data_bytes(8,4):le_float()
            local x = data_bytes(12,4):le_int()
            local y = data_bytes(16,4):le_int()
            local z = data_bytes(20,4):le_int()
            local val = string.format("Roll: %.2f°, Pitch: %.2f°, Yaw: %.2f°, X: %dmm, Y: %dmm, Z: %dmm", roll, pitch, yaw, x, y, z)
            subtree:add(f_install_attitude, data_bytes(0,24), val) 

        elseif key == 0x0015 or key == 0x0016 then
            -- FOV配置
            local yaw_start = data_bytes(0,4):le_int()
            local yaw_stop = data_bytes(4,4):le_int()
            local pitch_start = data_bytes(8,4):le_int()
            local pitch_stop = data_bytes(12,4):le_int()
            local val = string.format("水平：%d° ~ %d°, 垂直：%d° ~ %d°", yaw_start, yaw_stop, pitch_start, pitch_stop)
            if key == 0x0015 then
                subtree:add(f_fov_cfg0, data_bytes(0,16), val) 
            else
                subtree:add(f_fov_cfg1, data_bytes(0,16), val) 
            end

        elseif key == 0x0017 then
            -- FOV使能
            local val = string.format("FOV0:%s FOV1:%s", (bit.band(data_bytes(0,1):uint(), 0x01) ~= 0) and "开启" or "关闭", (bit.band(data_bytes(0,1):uint(), 0x02) ~= 0) and "开启" or "关闭")
            subtree:add(f_fov_en, data_bytes(0,1), val) 

        elseif key == 0x0018 then
            -- 探测模式
            local detect_mode_map = {[0x00]="正常探测模式", [0x01]="敏感探测模式"}
            local val = detect_mode_map[data_bytes(0,1):uint()] or string.format("未知格式(0x%02X)", data_bytes(0,1):uint())
            subtree:add(f_detect_mode, data_bytes(0,1), val) 

        elseif key == 0x0019 then
            -- 功能线配置
            local val = ""
            for i=0, data_bytes:len()-1 do
                val = val .. tostring(data_bytes(i,1):uint())
                if i < data_bytes:len()-1 then val = val .. "." end
            end
            subtree:add(f_func_io_cfg, data_bytes(0,data_bytes:len()), val) 

        elseif key == 0x001A then
            -- 目标工作模式
            local work_tgt_mode_map = {
                [0x01]="采样",
                [0x02]="待机",
                [0x04]="错误",
                [0x05]="自检",
                [0x06]="电机启动",
                [0x08]="升级",
                [0x09]="就绪"
            }
            local val = work_tgt_mode_map[data_bytes(0,1):uint()] or string.format("未知格式(0x%02X)", data_bytes(0,1):uint())
            subtree:add(f_work_tgt_mode, data_bytes(0,1), val) 

        elseif key == 0x001C then
            -- IMU数据输出使能
            local imu_data_en_map = {[0x00]="关闭", [0x01]="开启"}
            local val = imu_data_en_map[data_bytes(0,1):uint()] or string.format("未知格式(0x%02X)", data_bytes(0,1):uint())
            subtree:add(f_imu_data_en, data_bytes(0,1), val) 

        elseif key == 0x0021 then
            -- 电机转速模式（0x00:默认转速，0x01:低转速）
            local rpm_mode_map = {[0x00]="默认转速", [0x01]="低转速"}
            local val = rpm_mode_map[data_bytes(0,1):uint()] or string.format("未知格式(0x%02X)", data_bytes(0,1):uint())
            subtree:add(f_rpm_mode, data_bytes(0,1), val) 

        elseif key == 0x8000 then
            -- SN号
            local sn = data_bytes:stringz()
            subtree:add(f_sn, data_bytes(0,data_bytes:len()), sn) 

        elseif key == 0x8001 then
            -- 产品信息
            local product_info = data_bytes:stringz()
            subtree:add(f_product_info, data_bytes(0,data_bytes:len()), product_info) 

        elseif key == 0x8002 then 
            -- 固件版本
            local version_app = ""
            local version_range = nil -- Define a range variable
            if data_bytes:len() >= 4 then
                local major = data_bytes(0,1):uint()
                local minor = data_bytes(1,1):uint()
                local patch = data_bytes(2,1):uint()
                local build = data_bytes(3,1):uint()
                version_app = string.format("%d.%d.%04d", major, minor, patch * 100 + build)
                version_range = data_bytes(0,4) -- Set the range to the first 4 bytes
            end
            subtree:add(f_version_app, version_range, version_app) 

        elseif key == 0x8003 then
            -- Loader版本
            local loader_version = ""
            for i=0, data_bytes:len()-1 do
                loader_version = loader_version .. tostring(data_bytes(i,1):uint())
                if i < data_bytes:len()-1 then loader_version = loader_version .. "." end
            end
            subtree:add(f_loader_version, data_bytes(0,data_bytes:len()), loader_version) 

        elseif key == 0x8004 then
            -- 硬件版本
            local hw_version = ""
            for i=0, data_bytes:len()-1 do
                hw_version = hw_version .. tostring(data_bytes(i,1):uint())
                if i < data_bytes:len()-1 then hw_version = hw_version .. "." end
            end
            subtree:add(f_hw_version, data_bytes(0,data_bytes:len()), hw_version) 

        elseif key == 0x8005 then
            -- MAC地址
            local mac = ""
            for i=0,5 do
                mac = mac .. string.format("%02X", data_bytes(i,1):uint())
                if i < 5 then mac = mac .. ":" end
            end
            subtree:add(f_mac, data_bytes(0,6), mac) 

        elseif key == 0x8006 then
            -- 当前工作状态
            local work_status_map = {
                [0x01] = "采样",
                [0x02] = "待机",
                [0x04] = "错误",
                [0x05] = "自检",
                [0x06] = "电机启动",
                [0x08] = "升级",
                [0x09] = "就绪"
            }
            local val = work_status_map[data_bytes(0,1):uint()] or string.format("未知状态(0x%02X)", data_bytes(0,1):uint())
            subtree:add(f_work_status, data_bytes(0,1), val) 

        elseif key == 0x8007 then
            -- 温度 (0.01°C)
            local temp = data_bytes(0,4):le_int() / 100.0
            -- 将字段描述和温度值、单位组合成显示文本
            local display_val = string.format("%s: %.2f ℃", "核心板温度", temp)
            subtree:add(f_core_temp, data_bytes(0,4), temp, display_val) -- 添加浮点数值，同时指定显示文本

        elseif key == 0x8008 then
            -- 上电次数
            local powerup_count = data_bytes(0,4):le_uint()
            local val = string.format("%d 次", powerup_count)
            subtree:add(f_powerup_count, data_bytes(0,4), val) 

        elseif key == 0x8009 then
            -- 本地时间
            local local_time_now = data_bytes(0,8):le_uint64()
            local time_str = tostring(local_time_now)
            local time_num = tonumber(time_str)
            local local_time_ms = time_num / 1000000
            local seconds_total = local_time_ms / 1000
            
            -- 分离秒和毫秒部分
            local seconds_int = math.floor(seconds_total)
            local milliseconds = math.floor((seconds_total - seconds_int) * 1000)
            
            -- 转换为日期字符串（包含毫秒）
            local date_str = os.date("%Y-%m-%d %H:%M:%S", seconds_int) .. string.format(".%03d", milliseconds)
            
            local val = string.format("%.3f ms (%s)", local_time_ms, date_str)
            subtree:add(f_local_time, data_bytes(0,8), val)

        elseif key == 0x800A then
            -- 上次同步时间
            local last_sync_time = data_bytes(0,8):le_uint64()
            local time_str = tostring(last_sync_time)
            local time_num = tonumber(time_str)
            local last_sync_ms = time_num / 1000000
            local seconds_total = last_sync_ms / 1000
            
            -- 分离秒和毫秒部分
            local seconds_int = math.floor(seconds_total)
            local milliseconds = math.floor((seconds_total - seconds_int) * 1000)
            
            -- 转换为日期字符串（包含毫秒）
            local date_str = os.date("%Y-%m-%d %H:%M:%S", seconds_int) .. string.format(".%03d", milliseconds)
            
            local val = string.format("%.3f ms (%s)", last_sync_ms, date_str)
            subtree:add(f_last_sync_time, data_bytes(0,8), val) 

        elseif key == 0x800B then
            -- 时间偏移
            local time_offset = data_bytes(0,8):le_int64()
            local time_str = tostring(time_offset)
            local time_num = tonumber(time_str)
            local time_offset_us = time_num / 1000
            local val = string.format("%.3f us", time_offset_us)
            subtree:add(f_time_offset, data_bytes(0,8), val) 

        elseif key == 0x800C then
            -- 时间同步方式
            local time_sync_type_map = {
                [0x00] = "无时间同步",
                [0x01] = "PTP(IEEE 1588v2.0)",
                [0x02] = "GPS"
            }
            local val = time_sync_type_map[data_bytes(0,1):uint()] or string.format("未知格式(0x%02X)", data_bytes(0,1):uint())
            subtree:add(f_time_sync_type, data_bytes(0,1), val) 

        elseif key == 0x800E then
            -- 异常码
            local error_code = data_bytes(0,2):le_uint()
            local val = string.format("0x%04X", error_code)
            subtree:add(f_error_code, data_bytes(0,2), val) 

        elseif key == 0x8010 then
            -- 固件类型
            local fw_type_map = {
                [0x00] = "loader",
                [0x01] = "application_image"
            }
            local val = fw_type_map[data_bytes(0,1):uint()] or string.format("未知格式(0x%02X)", data_bytes(0,1):uint())
            subtree:add(f_fw_type, data_bytes(0,1), val) 

        elseif key == 0x8011 then
            -- HMS诊断码
            local fault_count = 0

            for i = 0, 7 do
                local code = data_bytes(i*4, 4):le_uint()
                if code ~= 0 then
                    fault_count = fault_count + 1
                    -- 解析诊断码
                    local fault_id = bit.rshift(code, 16)  -- 右移16位获取异常ID
                    local fault_level = bit.band(code, 0xFF)  -- 与0xFF进行与运算获取异常等级

                    -- 格式化异常ID为4位16进制，确保格式与字典中的键完全匹配
                    local fault_id_str = string.format("%04X", fault_id)

                    -- 获取异常等级描述
                    local level_map = { [0x01] = "Info 消息", [0x02] = "Warning 警告", [0x03] = "Error 错误", [0x04] = "Fatal 严重错误" }
                    local level_desc = level_map[fault_level] or "未知等级"
                    local fault_desc = fault_id_dict[fault_id_str] or string.format("未知故障ID (0x%04X)", fault_id)

                    -- 为每个故障码创建单独的子项，并指定对应的4字节范围
                    local fault_info = string.format("[%d]：0x%08X  异常等级[%s]  异常描述: %s",
                        fault_count, code, level_desc, fault_desc)
                    subtree:add(f_hms_codes, data_bytes(i*4, 4), fault_info) 
                end
            end

            if fault_count == 0 then
                subtree:add(f_hms_codes, data_bytes(0, math.min(32, data_bytes:len())), "无故障") 
            end

        elseif key == 0x0003 then
            -- 点云发送控制
            local val_map = {
                [0x00] = "进入工作模式发送点云",
                [0x01] = "进入工作模式不发送点云"
            }
            local val = val_map[data_bytes(0,1):uint()] or string.format("未知(0x%02X)", data_bytes(0,1):uint())
            subtree:add(f_point_send_en, data_bytes(0,1), val)

        elseif key == 0x0013 then
            -- 盲区范围设置
            local blind_spot = data_bytes(0,4):le_uint()
            local val = string.format("%d cm (范围50~200cm)", blind_spot)
            subtree:add(f_blind_spot_set, data_bytes(0,4), val)

        elseif key == 0x001B then
            -- 窗口加热支持
            local val_map = {
                [0x00] = "禁止窗口加热功能",
                [0x01] = "允许窗口加热功能"
            }
            local val = val_map[data_bytes(0,1):uint()] or string.format("未知(0x%02X)", data_bytes(0,1):uint())
            subtree:add(f_glass_heat_support, data_bytes(0,1), val)

        elseif key == 0x001D then
            -- fusa诊断功能
            local val_map = {
                [0x00] = "关闭fusa诊断功能",
                [0x01] = "开启fusa诊断功能"
            }
            local val = val_map[data_bytes(0,1):uint()] or string.format("未知(0x%02X)", data_bytes(0,1):uint())
            subtree:add(f_fusa_en, data_bytes(0,1), val)

        elseif key == 0x001E then
            -- 强制加热
            local val_map = {
                [0x00] = "关闭强制加热",
                [0x01] = "开启强制加热"
            }
            local val = val_map[data_bytes(0,1):uint()] or string.format("未知(0x%02X)", data_bytes(0,1):uint())
            subtree:add(f_force_heat_en, data_bytes(0,1), val)

        elseif key == 0x0020 then
            -- 开机初始化工作模式
            local val_map = {
                [0x00] = "待机状态(默认值)",
                [0x01] = "采样状态",
                [0x02] = "待机状态"
            }
            local val = val_map[data_bytes(0,1):uint()] or string.format("未知(0x%02X)", data_bytes(0,1):uint())
            subtree:add(f_workmode_after_boot, data_bytes(0,1), val)

        elseif key == 0x800D then
            -- 状态码，仅显示前8字节（byte0~byte7），每2bit详细解析
            local status_tree = subtree:add(f_status_code, data_bytes(0,8), "状态码（byte0~byte7，每2bit为一个故障）")

            local fault_labels = {
                [0] = {"system module warning", "report this issue to LIVOX with the log file"},
                [1] = {"system module warning", "report this issue to LIVOX with the log file"},
                [2] = {"system module warning", "report this issue to LIVOX with the log file"},
                [3] = {"system module warning", "report this issue to LIVOX with the log file"},
                [4] = {"system module warning", "report this issue to LIVOX with the log file"},
                [5] = {"system module warning", "report this issue to LIVOX with the log file"},
                [6] = {"system module error", "report this issue to LIVOX with the log file"},
                [7] = {"system module warning", "report this issue to LIVOX with the log file"},
                [8] = {"system module warning", "report this issue to LIVOX with the log file"},
                [9] = {"system module warning", "report this issue to LIVOX with the log file"},
                [10] = {"system module error", "report this issue to LIVOX with the log file"},
                [11] = {"system module warning", "report this issue to LIVOX with the log file"},
                [12] = {"system module warning", "report this issue to LIVOX with the log file"},
                [13] = {"system module warning", "report this issue to LIVOX with the log file"},
                [14] = {"system module warning and lidar inside sensor measured temperature is out of range", "check the lidar environment temperature is in the range of -40℃ to 85℃ and report this issue to LIVOX with the log file"},
                [15] = {"system module error", "report this issue to LIVOX with the log file"},
                [16] = {"system module warning and the window heater has fault and can't heat the window. Point cloud data could be used normally", "report this issue to LIVOX with the log file"},
                [17] = {"system module warning", "report this issue to LIVOX with the log file"},
                [18] = {"system module error", "report this issue to LIVOX with the log file"},
                [19] = {"system module warning and the network connection is link down", "check the ethernet cable connection normally and report this issue to LIVOX with the log file"},
                [20] = {"system module warning and the network connection quality is poor", "check no electromagnetic interference existed and report this issue to LIVOX with the log file"},
                [21] = {"system module warning", "report this issue to LIVOX with the log file"},
                [22] = {"system module error and and lidar inside sensor measured temperature is out of range", "check the lidar environment temperature is in the range of -40℃ to 85℃ and report this issue to LIVOX with the log file"},
                [23] = {"system module warning", "report this issue to LIVOX with the log file"},
                [24] = {"system module error and the supply voltage of the lidar is out of range", "check whether the supply voltage is normal(9.0~32v) and report this issue to LIVOX with the log file"},
                [25] = {"system module error", "report this issue to LIVOX with the log file"},
                [26] = {"system module warning and window dirty", "check whether the lidar window is dirty and try to clean the window"},
                [27] = {"system module warning and window block", "check whether the lidar window is blocked and try to remove the obstacle."},
                [28] = {"system module warning", "report this issue to LIVOX with the log file"},
                [29] = {"system module warning and lidar received ethernet message with CRC abnormal", "check whether the CRC of the command ethernet message from host is correctly and report this issue to LIVOX with the log file"},
                [30] = {"system module warning and time synchronize warning", "check whether the time synchronization master is configured correctly and report this issue to LIVOX with the log file"},
                [31] = {"system module warning", "report this issue to LIVOX with the log file"},
            }
            local bit_meaning = {
                [0] = "fault vanish in current cycle and no fault confirmed",
                [1] = "fault occur in current cycle and fault not confirmed",
                [2] = "fault vanish in current cycle and no fault not confirmed",
                [3] = "fault occur in current cycle and fault confirmed"
            }
            local function to2bitstr(val)
                local hi = bit.rshift(val,1)
                local lo = bit.band(val,1)
                return tostring(hi)..tostring(lo)
            end
            for i=0,7 do
                local byte = data_bytes(i,1):uint()
                for b=0,3 do
                    local idx = i*4 + b
                    local bits = bit.band(bit.rshift(byte, b*2), 0x03)
                    local label = fault_labels[idx] and fault_labels[idx][1] or "Reserved"
                    local suggestion = fault_labels[idx] and fault_labels[idx][2] or ""
                    local meaning = bit_meaning[bits] or "Reserved"
                    local bits_str = to2bitstr(bits)
                    local desc
                    if bits ~= 0 then
                        desc = string.format(
                            "Byte%d Bit%d-%d: [%s] Value: %s, %s. Suggestion: %s",
                            i, b*2, b*2+1, label, bits_str, meaning, suggestion
                        )
                    else
                        desc = string.format(
                            "Byte%d Bit%d-%d: [%s] Value: %s, %s",
                            i, b*2, b*2+1, label, bits_str, meaning
                        )
                    end
                    status_tree:add(data_bytes(i,1), desc)
                end
            end

        elseif key == 0x800F then
            -- Flash状态
            local val_map = {
                [0x00] = "idle",
                [0x01] = "busy"
            }
            local val = val_map[data_bytes(0,1):uint()] or string.format("未知(0x%02X)", data_bytes(0,1):uint())
            subtree:add(f_lidar_flash_status, data_bytes(0,1), val)

        elseif key == 0x8012 then
            -- 当前窗口加热状态
            local val_map = {
                [0x00] = "未加热",
                [0x01] = "正在加热"
            }
            local val = val_map[data_bytes(0,1):uint()] or string.format("未知(0x%02X)", data_bytes(0,1):uint())
            subtree:add(f_cur_glass_heat_state, data_bytes(0,1), val)

        else
            --未知字段
            subtree:add(buffer(index-length-4, length+4), string.format("未知字段_%04X", key))
        end
    end
end


local udp_port = DissectorTable.get("udp.port")
udp_port:add(56200, livox_pushmsg_proto)
udp_port:add(56000, livox_pushmsg_proto)
udp_port:add(56100, livox_pushmsg_proto)
udp_port:add(56500, livox_pushmsg_proto)

----------------------------------------------------------------------------------------------------------------
--解析点云&IMU数据

-- Livox Data协议的数据类型映射表
local livox_data_type_map = {
    [0] = "IMU数据",
    [1] = "直角坐标32bit点云",
    [2] = "直角坐标16bit点云", 
    [3] = "球坐标点云"
}

-- Livox Data协议的时间戳类型映射表
local livox_time_type_map = {
    [0] = "无同步源，时间戳为雷达自上电以来经过的时间",
    [1] = "gPTP/PTP同步，时间戳为master时钟源时间",
    [2] = "GPS时间同步",
}

local livox_data_proto = Proto("LivoxData", "Livox Data")

local f_version = ProtoField.uint8("livoxdata.version", "version")
local f_length = ProtoField.uint16("livoxdata.length", "Length", base.DEC)
local f_time_interval = ProtoField.uint16("livoxdata.time_interval", "Time Interval (0.1us)", base.DEC)
local f_dot_num = ProtoField.uint16("livoxdata.dot_num", "Dot Num", base.DEC)
local f_udp_cnt = ProtoField.uint16("livoxdata.udp_cnt", "UDP Count", base.DEC)
local f_frame_cnt = ProtoField.uint8("livoxdata.frame_cnt", "Frame Count", base.DEC)
local f_data_type = ProtoField.uint8("livoxdata.data_type", "Data Type", base.HEX)
local f_time_type = ProtoField.uint8("livoxdata.time_type", "Time Type", base.HEX)
local f_reserved = ProtoField.bytes("livoxdata.reserved", "Reserved")
local f_crc32 = ProtoField.uint32("livoxdata.crc32", "CRC32", base.HEX)
local f_timestamp = ProtoField.uint64("livoxdata.timestamp", "Timestamp", base.DEC)
local f_data = ProtoField.bytes("livoxdata.data", "Data")
local f_gyro_x = ProtoField.float("livoxdata.gyro_x", "gyro_x", base.DEC)
local f_gyro_y = ProtoField.float("livoxdata.gyro_y", "gyro_y", base.DEC)
local f_gyro_z = ProtoField.float("livoxdata.gyro_z", "gyro_z", base.DEC)
local f_acc_x  = ProtoField.float("livoxdata.acc_x",  "acc_x",  base.DEC, nil, nil, "IMU加速度X(g)")
local f_acc_y  = ProtoField.float("livoxdata.acc_y",  "acc_y",  base.DEC, nil, nil, "IMU加速度Y(g)")
local f_acc_z  = ProtoField.float("livoxdata.acc_z",  "acc_z",  base.DEC, nil, nil, "IMU加速度Z(g)")

livox_data_proto.fields = {
    f_version, f_length, f_time_interval, f_dot_num, f_udp_cnt, f_frame_cnt,
    f_data_type, f_time_type, f_reserved, f_crc32, f_timestamp, f_data,
    f_gyro_x, f_gyro_y, f_gyro_z, f_acc_x, f_acc_y, f_acc_z
}

function livox_data_proto.dissector(buffer, pinfo, tree)
    pinfo.cols.protocol = "LivoxData"
    local subtree = tree:add(livox_data_proto, buffer(), "Livox Data")

    -- 头部字段
    local version_val = buffer(0,1):uint()
    subtree:add(f_version, buffer(0,1), version_val, string.format("version (协议版本): %d", version_val))
    local length_val = buffer(1,2):le_uint()
    subtree:add(f_length, buffer(1,2), length_val, string.format("length (UDP数据段长度): %d", length_val))
    local time_interval_val = buffer(3,2):le_uint()
    subtree:add(f_time_interval, buffer(3,2), time_interval_val, string.format("time_interval (帧内点采样时间, 0.1μs): %d", time_interval_val))
    local dot_num = buffer(5,2):le_uint()
    subtree:add(f_dot_num, buffer(5,2), dot_num, string.format("dot_num (当前UDP包点数): %d", dot_num))
    local udp_cnt_val = buffer(7,2):le_uint()
    subtree:add(f_udp_cnt, buffer(7,2), udp_cnt_val, string.format("udp_cnt (UDP包计数): %d", udp_cnt_val))
    local frame_cnt_val = buffer(9,1):uint()
    subtree:add(f_frame_cnt, buffer(9,1), frame_cnt_val, string.format("frame_cnt (点云帧计数): %d", frame_cnt_val))
    local data_type = buffer(10,1):uint()
    local data_type_desc = livox_data_type_map[data_type] or string.format("未知数据类型 (0x%02X)", data_type)
    subtree:add(f_data_type, buffer(10,1), data_type, string.format("data_type (数据类型): %d (%s)", data_type, data_type_desc))
    local time_type_val = buffer(11,1):uint()
    local time_type_desc = livox_time_type_map[time_type_val] or string.format("未知时间戳类型 (0x%02X)", time_type_val)
    subtree:add(f_time_type, buffer(11,1), time_type_val, string.format("time_type (时间戳类型): %d (%s)", time_type_val, time_type_desc))
    subtree:add(f_reserved, buffer(12,12))
    local crc32_val = buffer(24,4):le_uint()
    subtree:add(f_crc32, buffer(24,4), crc32_val, string.format("crc32 (CRC32校验): 0x%08X", crc32_val))
    local ts_val = buffer(28,8):le_uint64()
    subtree:add(f_timestamp, buffer(28,8), ts_val, "timestamp (时间戳): " .. tostring(ts_val))

    -- data字段解析
    local data_offset = 36
    if buffer:len() > data_offset then
        -- 解析IMU数据
        if data_type == 0 and buffer:len() >= data_offset + 24 then
            local data_len = buffer:len() - data_offset
            if data_len > 0 then
                subtree:add(f_data, buffer(data_offset, data_len))
            end

            local gyro_x_val = buffer(data_offset+0,4):le_float()
            subtree:add(f_gyro_x, buffer(data_offset+0,4), gyro_x_val, string.format("gyro_x (rad/s): %.10f", gyro_x_val))
            local gyro_y_val = buffer(data_offset+4,4):le_float()
            subtree:add(f_gyro_y, buffer(data_offset+4,4), gyro_y_val, string.format("gyro_y (rad/s): %.10f", gyro_y_val))
            local gyro_z_val = buffer(data_offset+8,4):le_float()
            subtree:add(f_gyro_z, buffer(data_offset+8,4), gyro_z_val, string.format("gyro_z (rad/s): %.10f", gyro_z_val))
            local acc_x_val = buffer(data_offset+12,4):le_float()
            subtree:add(f_acc_x, buffer(data_offset+12,4), acc_x_val, string.format("acc_x (g): %.10f", acc_x_val))
            local acc_y_val = buffer(data_offset+16,4):le_float()
            subtree:add(f_acc_y, buffer(data_offset+16,4), acc_y_val, string.format("acc_y (g): %.10f", acc_y_val))
            local acc_z_val = buffer(data_offset+20,4):le_float()
            subtree:add(f_acc_z, buffer(data_offset+20,4), acc_z_val, string.format("acc_z (g): %.10f", acc_z_val))
            
        else --[[
            -- 点云数据结构化解析（因解析点云数据耗时过久，暂时注释掉，需要时再打开）
            local point_size = 0
            local point_type_desc = ""
            if data_type == 1 then
                point_size = 14
                point_type_desc = "直角坐标32bit"
            elseif data_type == 2 then
                point_size = 8
                point_type_desc = "直角坐标16bit"
            elseif data_type == 3 then
                point_size = 10
                point_type_desc = "球坐标"
            end

            if point_size > 0 and dot_num > 0 and buffer:len() >= data_offset + point_size * dot_num then
                local point_desc = string.format("点云数据 (类型: %d, %s, %d个点)", data_type, point_type_desc, dot_num)
                local points_tree = subtree:add(f_data, buffer(data_offset, point_size * dot_num))
                points_tree:set_text(point_desc)
                
                for i=0, dot_num-1 do
                    local base = data_offset + i * point_size
                    if base + point_size > buffer:len() then break end
                    if data_type == 1 then
                        local x = buffer(base,4):le_int()
                        local y = buffer(base+4,4):le_int()
                        local z = buffer(base+8,4):le_int()
                        local reflect = buffer(base+12,1):uint()
                        local tag = buffer(base+13,1):uint()
                        points_tree:add(buffer(base,point_size), string.format("Point %d: X=%dmm Y=%dmm Z=%dmm 反射率=%d Tag=%d", i+1, x, y, z, reflect, tag))
                    elseif data_type == 2 then
                        local x = buffer(base,2):le_int()
                        local y = buffer(base+2,2):le_int()
                        local z = buffer(base+4,2):le_int()
                        local reflect = buffer(base+6,1):uint()
                        local tag = buffer(base+7,1):uint()
                        points_tree:add(buffer(base,point_size), string.format("Point %d: X=%d*10mm Y=%d*10mm Z=%d*10mm Tag=%d 标签=%d", i+1, x, y, z, reflect, tag))
                    elseif data_type == 3 then
                        local depth = buffer(base,4):le_uint()
                        local zenith = buffer(base+4,2):le_uint()
                        local azimuth = buffer(base+6,2):le_uint()
                        local reflect = buffer(base+8,1):uint()
                        local tag = buffer(base+9,1):uint()
                        points_tree:add(buffer(base,point_size), string.format("Point %d: 深度=%dmm 天顶角=%.2f° 方位角=%.2f° 反射率=%d Tag=%d", i+1, depth, zenith/100, azimuth/100, reflect, tag))
                    end
                end
                if buffer:len() > data_offset + point_size * dot_num then
                    points_tree:add(buffer(data_offset + point_size * dot_num, buffer:len() - data_offset - point_size * dot_num), "剩余原始数据")
                end
            else
                subtree:add(f_data, buffer(data_offset, buffer:len()-data_offset))
            end --]]
        end
    end
end




udp_port:add(56300, livox_data_proto)
udp_port:add(56400, livox_data_proto)
udp_port:add(57000, livox_data_proto)
udp_port:add(58000, livox_data_proto)


local livox_old_data_proto = Proto("LivoxOldData", "Livox Old Product Data (Avia/Horizon/Tele-15/Mid-70/Mid-40)")

-- 老产品数据协议字段定义
local f_old_version = ProtoField.uint8("livoxold.version", "Version", base.DEC)
local f_slot_id = ProtoField.uint8("livoxold.slot_id", "Slot ID", base.DEC)
local f_lidar_id = ProtoField.uint8("livoxold.lidar_id", "LiDAR ID", base.DEC)
local f_reserved = ProtoField.uint8("livoxold.reserved", "Reserved", base.HEX)
local f_status_code = ProtoField.uint32("livoxold.status_code", "Status Code", base.HEX)
local f_timestamp_type = ProtoField.uint8("livoxold.timestamp_type", "Timestamp Type", base.DEC)
local f_data_type = ProtoField.uint8("livoxold.data_type", "Data Type", base.DEC)
local f_timestamp = ProtoField.uint64("livoxold.timestamp", "Timestamp", base.DEC)
local f_data = ProtoField.bytes("livoxold.data", "Data")
local f_old_gyro_x = ProtoField.float("livoxold.gyro_x", "Gyro X", base.DEC)
local f_old_gyro_y = ProtoField.float("livoxold.gyro_y", "Gyro Y", base.DEC)
local f_old_gyro_z = ProtoField.float("livoxold.gyro_z", "Gyro Z", base.DEC)
local f_old_acc_x = ProtoField.float("livoxold.acc_x", "Acc X", base.DEC)
local f_old_acc_y = ProtoField.float("livoxold.acc_y", "Acc Y", base.DEC)
local f_old_acc_z = ProtoField.float("livoxold.acc_z", "Acc Z", base.DEC)

-- 控制指令帧字段定义
local f_ctrl_sof = ProtoField.uint8("livoxoldctrl.sof", "Start of Frame", base.HEX)
local f_ctrl_version = ProtoField.uint8("livoxoldctrl.version", "Protocol Version", base.DEC)
local f_ctrl_length = ProtoField.uint16("livoxoldctrl.length", "Frame Length", base.DEC)
local f_ctrl_cmd_type = ProtoField.uint8("livoxoldctrl.cmd_type", "Command Type", base.HEX)
local f_ctrl_seq_num = ProtoField.uint16("livoxoldctrl.seq_num", "Sequence Number", base.DEC)
local f_ctrl_crc16 = ProtoField.uint16("livoxoldctrl.crc16", "Header CRC-16", base.HEX)
local f_ctrl_data = ProtoField.bytes("livoxoldctrl.data", "Data Field", base.SPACE)
local f_ctrl_crc32 = ProtoField.uint32("livoxoldctrl.crc32", "Frame CRC-32", base.HEX)

-- 控制指令数据段字段定义
local f_cmd_set = ProtoField.uint8("livoxoldctrl.cmd_set", "CMD Set", base.HEX)
local f_cmd_id = ProtoField.uint8("livoxoldctrl.cmd_id", "CMD ID", base.HEX)
local f_cmd_data = ProtoField.bytes("livoxoldctrl.cmd_data", "CMD Data")

-- 配置参数字段定义
local f_param_key = ProtoField.uint8("livoxctrl.param_key", "Parameter Key", base.HEX)
local f_param_value = ProtoField.bytes("livoxctrl.param_value", "Parameter Value")
local f_param_length = ProtoField.uint8("livoxctrl.param_length", "Parameter Length", base.DEC)

-- 通用指令集字段定义

-- 广播发现指令
local f_broadcast_code = ProtoField.string("livoxoldctrl.broadcast_code", "Broadcast Code")
local f_dev_type = ProtoField.uint8("livoxoldctrl.dev_type", "Device Type", base.HEX)
local f_reserved_16 = ProtoField.uint16("livoxoldctrl.reserved_16", "Reserved", base.HEX)

-- 网络握手确认指令
local f_user_ip = ProtoField.ipv4("livoxoldctrl.user_ip", "User IP")
local f_data_port = ProtoField.uint16("livoxoldctrl.data_port", "Data Port", base.DEC)
local f_cmd_port = ProtoField.uint16("livoxoldctrl.cmd_port", "Command Port", base.DEC)
local f_imu_port = ProtoField.uint16("livoxoldctrl.imu_port", "IMU Port", base.DEC)

-- 查询设备信息指令
local f_ret_code = ProtoField.uint8("livoxoldctrl.ret_code", "Return Code", base.HEX)
local f_firmware_version = ProtoField.string("livoxoldctrl.firmware_version", "Firmware Version")

-- 心跳数据指令
local f_work_state = ProtoField.uint8("livoxoldctrl.work_state", "Work State", base.HEX)
local f_feature_msg = ProtoField.uint8("livoxoldctrl.feature_msg", "Feature Message", base.HEX)
local f_ack_msg = ProtoField.uint32("livoxoldctrl.ack_msg", "ACK Message", base.HEX)

-- 开始/停止采样指令
local f_sample_ctrl = ProtoField.uint8("livoxoldctrl.sample_ctrl", "Sample Control", base.HEX)

-- 更改点云坐标系模式
local f_coordinate_type = ProtoField.uint8("livoxoldctrl.coordinate_type", "Coordinate Type", base.HEX)

-- 异常状态信息
local f_status_code_old = ProtoField.uint32("livoxoldctrl.old_status_code", "Status Code", base.HEX)

local f_ip_mode = ProtoField.uint8("livoxoldctrl.ip_mode", "IP Mode", base.HEX)
local f_ip_addr = ProtoField.ipv4("livoxoldctrl.ip_addr", "IP Address")
local f_net_mask = ProtoField.ipv4("livoxoldctrl.net_mask", "Net Mask")
local f_gw_addr = ProtoField.ipv4("livoxoldctrl.gw_addr", "Gateway Address")
local f_timeout = ProtoField.uint16("livoxoldctrl.timeout", "Timeout", base.DEC)


-- 雷达指令集字段定义

-- 模式切换指令
local f_lidar_mode = ProtoField.uint8("livoxoldctrl.lidar_mode", "LiDAR Mode", base.HEX)

-- 外参配置指令
local f_roll = ProtoField.float("livoxoldctrl.roll", "Roll", base.DEC)
local f_pitch = ProtoField.float("livoxoldctrl.pitch", "Pitch", base.DEC)
local f_yaw = ProtoField.float("livoxoldctrl.yaw", "Yaw", base.DEC)
local f_x = ProtoField.int32("livoxoldctrl.x", "X Translation", base.DEC)
local f_y = ProtoField.int32("livoxoldctrl.y", "Y Translation", base.DEC)
local f_z = ProtoField.int32("livoxoldctrl.z", "Z Translation", base.DEC)

local f_state = ProtoField.uint8("livoxoldctrl.state", "State", base.HEX)
local f_mode = ProtoField.uint8("livoxoldctrl.mode", "Mode", base.HEX)
local f_frequency = ProtoField.uint8("livoxoldctrl.frequency", "Frequency", base.HEX)
local f_year = ProtoField.uint8("livoxoldctrl.year", "Year", base.DEC)
local f_month = ProtoField.uint8("livoxoldctrl.month", "Month", base.DEC)
local f_day = ProtoField.uint8("livoxoldctrl.day", "Day", base.DEC)
local f_hour = ProtoField.uint8("livoxoldctrl.hour", "Hour", base.DEC)
local f_microsecond = ProtoField.uint32("livoxoldctrl.microsecond", "Microsecond", base.DEC)



livox_old_data_proto.fields = {
    f_old_version, f_slot_id, f_lidar_id, f_reserved,
    f_status_code_old, f_timestamp_type, f_data_type, f_timestamp, f_data,
    f_old_gyro_x, f_old_gyro_y, f_old_gyro_z, f_old_acc_x, f_old_acc_y, f_old_acc_z,
    f_ctrl_sof, f_ctrl_version, f_ctrl_length, f_ctrl_cmd_type, f_ctrl_seq_num,
    f_ctrl_crc16, f_ctrl_data, f_ctrl_crc32,
    f_cmd_set, f_cmd_id, f_cmd_data,
    f_broadcast_code, f_dev_type, f_reserved_16,
    f_user_ip, f_data_port, f_cmd_port, f_imu_port,
    f_ret_code, f_firmware_version, f_work_state, f_feature_msg, f_ack_msg, 
    f_sample_ctrl, f_coordinate_type, f_old_status_code, f_ip_mode, f_ip_addr, 
    f_net_mask, f_gw_addr, f_timeout, f_lidar_mode, f_roll, f_pitch, f_yaw, f_x, f_y, f_z,
    f_state, f_mode, f_frequency, f_year, f_month, f_day, f_hour, f_microsecond,
    f_param_key, f_param_value, f_param_length
}

-- LiDAR ID映射表
local lidar_id_map = {
    [1] = "Mid-100 左/Mid-40/Tele-15/Horizon/Mid-70/Avia",
    [2] = "Mid-100 中",
    [3] = "Mid-100 右"
}

-- 老产品数据协议的数据类型映射表
local old_data_type_map = {
    [0] = "单回波-直角坐标系-100点-100KHz (Mid-40)",
    [1] = "单回波-球坐标系-100点-100KHz (Mid-40)",
    [2] = "单回波-直角坐标系-96点 (Horizon/Tele-15/Avia:240KHz, Mid-70:100KHz)",
    [3] = "单回波-球坐标系-96点 (Horizon/Tele-15/Avia:240KHz, Mid-70:100KHz)",
    [4] = "双回波-直角坐标系-48点 (Horizon/Tele-15/Avia:480KHz, Mid-70:200KHz)",
    [5] = "双回波-球坐标系-48点 (Horizon/Tele-15/Avia:480KHz, Mid-70:200KHz)",
    [6] = "IMU数据 (Horizon/Tele-15/Avia)",
    [7] = "三回波-直角坐标系-30点-720KHz (Avia)",
    [8] = "三回波-球坐标系-30点-720KHz (Avia)"
}

-- 老产品数据协议的时间戳类型映射表
local old_timestamp_type_map = {
    [0] = "无同步源",
    [1] = "PTP同步",
    [2] = "保留",
    [3] = "GPS同步",
    [4] = "PPS同步 (仅雷达支持)"
}

-- 设备类型映射表
local old_dev_type_map = {
    [0x00] = "Livox Hub",
    [0x01] = "Mid-40",
    [0x02] = "Tele-15",
    [0x03] = "Horizon",
    [0x06] = "Mid-70",
    [0x07] = "Avia"
}

-- 控制指令命令类型映射表
local ctrl_cmd_type_map = {
    [0x00] = "CMD (命令)",
    [0x01] = "ACK (应答)",
    [0x02] = "MSG (消息)"
}

-- CMD Set 映射表
local cmd_set_map = {
    [0x00] = "通用指令集",
    [0x01] = "雷达指令集",
    [0x02] = "保留指令集"
}

-- 配置参数键值映射表
local param_key_map = {
    [0x00] = "保留",
    [0x01] = "高灵敏度功能 (Tele-15/07.09.0000+, Avia/11.06.0000+)",
    [0x02] = "重复/非重复扫描模式 (Avia/11.06.0000+)",
    [0x03] = "slot id配置 (Mid-70/10.03.0000+, Avia/11.06.0000+)"
}

-- 高灵敏度功能参数值映射表
local high_sensitivity_map = {
    [0x00] = "高灵敏度功能关闭",
    [0x01] = "高灵敏度功能开启(默认)"
}

-- 扫描模式参数值映射表
local scan_mode_map = {
    [0x00] = "非重复扫描模式(默认)",
    [0x01] = "重复扫描模式"
}
-- 通用指令集 (CMD Set 0x00) 映射表
local general_cmd_map = {
    [0x00] = "广播信息",
    [0x01] = "网络握手确认指令",
    [0x02] = "查询设备信息",
    [0x03] = "心跳指令",
    [0x04] = "开始/停止采样",
    [0x05] = "更改点云坐标模式",
    [0x06] = "断开连接指令",
    [0x07] = "设备异常推送",
    [0x08] = "设置静态/动态IP模式",
    [0x09] = "读取设备的IP模式",
    [0x0A] = "重启设备",
    [0x0B] = "设置设备配置参数",
    [0x0C] = "读取设备配置参数"
}

-- 返回码映射表
local ret_code_map = {
    [0x00] = "成功",
    [0x01] = "失败"
}

-- 工作状态映射表
local work_state_map = {
    [0x00] = "初始化",
    [0x01] = "正常",
    [0x02] = "低功耗",
    [0x03] = "待机",
    [0x04] = "异常"
}

-- 采样控制映射表
local sample_ctrl_map = {
    [0x00] = "停止采样",
    [0x01] = "开始采样"
}

-- 坐标系类型映射表
local coordinate_type_map = {
    [0x00] = "直角坐标系",
    [0x01] = "球坐标系"
}

-- IP模式映射表
local ip_mode_map = {
    [0x00] = "动态IP",
    [0x01] = "静态IP"
}



-- 雷达指令集 (CMD Set 0x01) 映射表
local lidar_cmd_map = {
    [0x00] = "设置模式指令",
    [0x01] = "设置雷达外部参数",
    [0x02] = "读取雷达外部参数",
    [0x03] = "开启/关闭抗雨雾功能",
    [0x04] = "设置开启/关闭风扇",
    [0x05] = "获取风扇开/关状态",
    [0x06] = "设置点云回波模式",
    [0x07] = "读取点云回波模式",
    [0x08] = "设置IMU数据推送频率",
    [0x09] = "读取IMU推送频率",
    [0x0A] = "更新UTC同步时间"
}


-- 雷达模式映射表
local lidar_mode_map = {
    [0x01] = "正常工作模式",
    [0x02] = "低功耗模式", 
    [0x03] = "待机模式"
}

-- 雷达指令集返回码映射表（扩展）
local lidar_ret_code_map = {
    [0x00] = "成功",
    [0x01] = "失败",
    [0x02] = "正在切换"
}

-- 状态映射表
local state_map = {
    [0x00] = "关闭",
    [0x01] = "开启"
}

-- 回波模式映射表
local echo_mode_map = {
    [0x00] = "第一回波 Single Return First",
    [0x01] = "最强回波 Single Return Strongest", 
    [0x02] = "双回波 Dual Return",
    [0x03] = "三回波 Triple Return"
}

-- IMU频率映射表
local imu_frequency_map = {
    [0x00] = "0Hz (关闭IMU数据推送)",
    [0x01] = "200Hz"
}

-- 解析控制指令数据段
local function dissect_control_data(buffer, subtree, cmd_type_val)
    local data_length = buffer:len()
    if data_length < 2 then
        subtree:add_expert_info(PI_MALFORMED, PI_WARN, "数据段长度不足")
        return
    end
    
    -- 解析CMD Set
    local cmd_set_val = buffer(0,1):uint()
    local cmd_set_desc = cmd_set_map[cmd_set_val] or string.format("未知CMD Set (0x%02X)", cmd_set_val)
    subtree:add(f_cmd_set, buffer(0,1), cmd_set_val, string.format("CMD Set: 0x%02X (%s)", cmd_set_val, cmd_set_desc))
    
    -- 解析CMD ID
    local cmd_id_val = buffer(1,1):uint()
    local cmd_desc = "未知命令"
    
    if cmd_set_val == 0x00 then
        cmd_desc = general_cmd_map[cmd_id_val] or string.format("未知通用命令 (0x%02X)", cmd_id_val)
    elseif cmd_set_val == 0x01 then
        cmd_desc = lidar_cmd_map[cmd_id_val] or string.format("未知雷达命令 (0x%02X)", cmd_id_val)
    else
        cmd_desc = string.format("未知指令集命令 (0x%02X)", cmd_id_val)
    end
    
    subtree:add(f_cmd_id, buffer(1,1), cmd_id_val, string.format("CMD ID: 0x%02X (%s)", cmd_id_val, cmd_desc))
    
-- 解析特定命令的数据内容
if data_length > 2 then
    local cmd_data_buffer = buffer(2, data_length - 2)
    -- 构建十六进制字符串
    local hex_data = ""
    for i = 0, cmd_data_buffer:len() - 1 do
        hex_data = hex_data .. string.format("%02X ", cmd_data_buffer(i, 1):uint())
    end
    
    -- 创建CMD Data子树
    local cmd_data_subtree = subtree:add("CMD Data")
    cmd_data_subtree:set_text("CMD Data: " .. hex_data)
    
    -- 0x00通用指令集    
        -- 广播消息 (CMD Set 0x00, CMD ID 0x00)
        if cmd_set_val == 0x00 and cmd_id_val == 0x00 then
            if data_length >= 21 then
                local broadcast_code = buffer(2,16):string()
                cmd_data_subtree:add(f_broadcast_code, buffer(2,16), broadcast_code, string.format("Broadcast Code: %s", broadcast_code))
                
                local dev_type_val = buffer(18,1):uint()
                local dev_type_desc = old_dev_type_map[dev_type_val] or string.format("未知设备类型 (0x%02X)", dev_type_val)
                cmd_data_subtree:add(f_dev_type, buffer(18,1), dev_type_val, string.format("Device Type: 0x%02X (%s)", dev_type_val, dev_type_desc))
                
                local reserved_val = buffer(19,2):le_uint()
                cmd_data_subtree:add(f_reserved_16, buffer(19,2), reserved_val, string.format("Reserved: 0x%04X", reserved_val))
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "广播消息长度不足")
            end

        -- 网络握手确认请求 (CMD Set 0x00, CMD ID 0x01, 且为CMD类型)
        elseif cmd_set_val == 0x00 and cmd_id_val == 0x01 and cmd_type_val == 0x00 then
            if data_length >= 12 then
                -- 解析IP地址 (4字节)
                local ip_bytes = buffer(2,4):bytes()
                local ip_str = string.format("%d.%d.%d.%d", ip_bytes:get_index(0), ip_bytes:get_index(1), ip_bytes:get_index(2), ip_bytes:get_index(3))
                cmd_data_subtree:add(f_user_ip, buffer(2,4))  -- 只传递字段对象和缓冲区范围
                
                -- 解析数据端口
                local data_port_val = buffer(6,2):le_uint()
                cmd_data_subtree:add(f_data_port, buffer(6,2), data_port_val)
                
                -- 解析命令端口
                local cmd_port_val = buffer(8,2):le_uint()
                cmd_data_subtree:add(f_cmd_port, buffer(8,2), cmd_port_val)
                
                -- 解析IMU端口
                local imu_port_val = buffer(10,2):le_uint()
                cmd_data_subtree:add(f_imu_port, buffer(10,2), imu_port_val)
                
                -- 添加描述信息作为单独的文本项
                cmd_data_subtree:add("User IP: " .. ip_str)
                cmd_data_subtree:add("Data Port: " .. data_port_val)
                cmd_data_subtree:add("Command Port: " .. cmd_port_val)
                cmd_data_subtree:add("IMU Port: " .. imu_port_val)
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "网络握手确认请求长度不足")
            end
        
        -- 网络握手确认应答 (CMD Set 0x00, CMD ID 0x01, 且为ACK类型)
        elseif cmd_set_val == 0x00 and cmd_id_val == 0x01 and cmd_type_val == 0x01 then
            if data_length >= 3 then
                local ret_code_val = buffer(2,1):uint()
                local ret_code_desc = ret_code_map[ret_code_val] or string.format("未知返回码 (0x%02X)", ret_code_val)
                cmd_data_subtree:add(f_ret_code, buffer(2,1), ret_code_val, string.format("Return Code: 0x%02X (%s)", ret_code_val, ret_code_desc))
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "网络握手确认应答长度不足")
            end
        
        -- 设备信息查询应答 (CMD Set 0x00, CMD ID 0x02, 且为ACK类型)
        elseif cmd_set_val == 0x00 and cmd_id_val == 0x02 and cmd_type_val == 0x01 then
            if data_length >= 7 then
                local ret_code_val = buffer(2,1):uint()
                local ret_code_desc = ret_code_map[ret_code_val] or string.format("未知返回码 (0x%02X)", ret_code_val)
                cmd_data_subtree:add(f_ret_code, buffer(2,1), ret_code_val, string.format("Return Code: 0x%02X (%s)", ret_code_val, ret_code_desc))
                
                -- 解析固件版本 (4字节)
                local version_parts = {}
                for i = 0, 3 do
                    version_parts[i+1] = buffer(3+i,1):uint()
                end
                local version_str = string.format("%d.%d.%d.%d", version_parts[1], version_parts[2], version_parts[3], version_parts[4])
                cmd_data_subtree:add(f_firmware_version, buffer(3,4), version_str, string.format("Firmware Version: %s", version_str))
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "设备信息查询应答长度不足")
            end
        
        -- 心跳应答 (CMD Set 0x00, CMD ID 0x03, 且为ACK类型)
        elseif cmd_set_val == 0x00 and cmd_id_val == 0x03 and cmd_type_val == 0x01 then
            if cmd_data_subtree then
                if data_length >= 9 then
                    local ret_code_val = buffer(2,1):uint()
                    local ret_code_desc = ret_code_map[ret_code_val] or string.format("未知返回码 (0x%02X)", ret_code_val)
                    
                    -- 安全地添加字段
                    if f_ret_code then
                        cmd_data_subtree:add(f_ret_code, buffer(2,1), ret_code_val, string.format("Return Code: 0x%02X (%s)", ret_code_val, ret_code_desc))
                    else
                        cmd_data_subtree:add(string.format("Return Code: 0x%02X (%s)", ret_code_val, ret_code_desc))
                    end
                    
                    local work_state_val = buffer(3,1):uint()
                    local work_state_desc = work_state_map[work_state_val] or string.format("未知工作状态 (0x%02X)", work_state_val)
                    
                    if f_work_state then
                        cmd_data_subtree:add(f_work_state, buffer(3,1), work_state_val, string.format("Work State: 0x%02X (%s)", work_state_val, work_state_desc))
                    else
                        cmd_data_subtree:add(string.format("Work State: 0x%02X (%s)", work_state_val, work_state_desc))
                    end
                    
                    local feature_msg_val = buffer(4,1):uint()
                    local rain_fog_status = (feature_msg_val & 0x01) > 0 and "开启" or "关闭"
                    
                    if f_feature_msg then
                        cmd_data_subtree:add(f_feature_msg, buffer(4,1), feature_msg_val, string.format("Feature Message: 0x%02X (抗雨雾: %s)", feature_msg_val, rain_fog_status))
                    else
                        cmd_data_subtree:add(string.format("Feature Message: 0x%02X (抗雨雾: %s)", feature_msg_val, rain_fog_status))
                    end
                    
                    local ack_msg_val = buffer(5,4):le_uint()

                    -- 根据工作状态解析ACK信息
                    if work_state_val == 0x00 then
                        -- 初始化状态：显示初始化百分比
                        local init_percentage = ack_msg_val
                        if f_ack_msg then
                            cmd_data_subtree:add(f_ack_msg, buffer(5,4), ack_msg_val, string.format("%d%% (初始化百分比)", init_percentage))
                        else
                            cmd_data_subtree:add(string.format("ACK Message: %d%% (初始化百分比)", init_percentage))
                        end
                    else
                        -- 其他状态：按照异常状态码解析
                        if f_ack_msg then
                            cmd_data_subtree:add(f_ack_msg, buffer(5,4), ack_msg_val, string.format("ACK Message: 0x%08X", ack_msg_val))
                        else
                            cmd_data_subtree:add(string.format("ACK Message: 0x%08X", ack_msg_val))
                        end
                        
                        -- 详细解析状态码（类似于异常状态推送信息的解析）
                        local status_details = {}
                        
                        -- 温度状态 (Bit0-1)
                        local temp_status = (ack_msg_val >> 0) & 0x3
                        if temp_status == 0 then
                            table.insert(status_details, "温度正常")
                        elseif temp_status == 1 then
                            table.insert(status_details, "温度偏高或偏低")
                        elseif temp_status == 2 then
                            table.insert(status_details, "温度极高或极低")
                        end
                        
                        -- 电压状态 (Bit2-3)
                        local volt_status = (ack_msg_val >> 2) & 0x3
                        if volt_status == 0 then
                            table.insert(status_details, "电压正常")
                        elseif volt_status == 1 then
                            table.insert(status_details, "电压偏高")
                        elseif volt_status == 2 then
                            table.insert(status_details, "电压极高")
                        end
                        
                        -- 电机状态 (Bit4-5)
                        local motor_status = (ack_msg_val >> 4) & 0x3
                        if motor_status == 0 then
                            table.insert(status_details, "电机正常")
                        elseif motor_status == 1 then
                            table.insert(status_details, "电机警告")
                        elseif motor_status == 2 then
                            table.insert(status_details, "电机错误，无法工作")
                        end
                        
                        -- 脏污警告 (Bit6-7)
                        local dirty_warn = (ack_msg_val >> 6) & 0x3
                        if dirty_warn == 0 then
                            table.insert(status_details, "无脏污和遮挡")
                        elseif dirty_warn >= 1 then
                            table.insert(status_details, "有脏污和遮挡")
                        end
                        
                        -- 固件状态 (Bit8)
                        local firmware_status = (ack_msg_val >> 8) & 0x1
                        if firmware_status == 0 then
                            table.insert(status_details, "固件正常")
                        else
                            table.insert(status_details, "固件出错，需要升级")
                        end
                        
                        -- PPS状态 (Bit9)
                        local pps_status = (ack_msg_val >> 9) & 0x1
                        if pps_status == 0 then
                            table.insert(status_details, "无PPS信号")
                        else
                            table.insert(status_details, "PPS信号正常")
                        end
                        
                        -- 设备状态 (Bit10)
                        local device_status = (ack_msg_val >> 10) & 0x1
                        if device_status == 0 then
                            table.insert(status_details, "设备正常")
                        else
                            table.insert(status_details, "设备寿命警告")
                        end
                        
                        -- 风扇状态 (Bit11)
                        local fan_status = (ack_msg_val >> 11) & 0x1
                        if fan_status == 0 then
                            table.insert(status_details, "风扇正常")
                        else
                            table.insert(status_details, "风扇警告（异常或用户设置停止）")
                        end
                        
                        -- 自加热状态 (Bit12)
                        local self_heating = (ack_msg_val >> 12) & 0x1
                        if self_heating == 0 then
                            table.insert(status_details, "低温自加热关闭")
                        else
                            table.insert(status_details, "低温自加热开启")
                        end
                        
                        -- PTP状态 (Bit13)
                        local ptp_status = (ack_msg_val >> 13) & 0x1
                        if ptp_status == 0 then
                            table.insert(status_details, "无1588信号")
                        else
                            table.insert(status_details, "1588信号正常")
                        end
                        
                        -- 时间同步状态 (Bit14-16)
                        local time_sync_status = (ack_msg_val >> 14) & 0x7
                        if time_sync_status == 0 then
                            table.insert(status_details, "未开始时间同步")
                        elseif time_sync_status == 1 then
                            table.insert(status_details, "使用PTP 1588同步")
                        elseif time_sync_status == 2 then
                            table.insert(status_details, "使用GPS同步")
                        elseif time_sync_status == 3 then
                            table.insert(status_details, "使用PPS同步")
                        elseif time_sync_status == 4 then
                            table.insert(status_details, "系统时间同步异常（最高优先级信号异常）")
                        end
                        
                        -- 系统状态 (Bit30-31)
                        local system_status = (ack_msg_val >> 30) & 0x3
                        if system_status == 0 then
                            table.insert(status_details, "系统正常")
                        elseif system_status == 1 then
                            table.insert(status_details, "系统警告")
                        elseif system_status == 2 then
                            table.insert(status_details, "系统错误，雷达停机")
                        end
                        
                        -- 显示详细状态信息
                        if #status_details > 0 then
                            local status_tree = cmd_data_subtree:add("Status Details")
                            for i, detail in ipairs(status_details) do
                                status_tree:add(string.format("[%d] %s", i, detail))
                            end
                        end
                    end
                else
                    if cmd_data_subtree.add_expert_info then
                        cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "心跳应答长度不足")
                    end
                end
            end        

        -- 开始/停止采样请求 (CMD Set 0x00, CMD ID 0x04, 且为CMD类型)
        elseif cmd_set_val == 0x00 and cmd_id_val == 0x04 and cmd_type_val == 0x00 then
            if data_length >= 3 then
                local sample_ctrl_val = buffer(2,1):uint()
                local sample_ctrl_desc = sample_ctrl_map[sample_ctrl_val] or string.format("未知采样控制 (0x%02X)", sample_ctrl_val)
                cmd_data_subtree:add(f_sample_ctrl, buffer(2,1), sample_ctrl_val, string.format("Sample Control: 0x%02X (%s)", sample_ctrl_val, sample_ctrl_desc))
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "开始/停止采样请求长度不足")
            end
        
        -- 开始/停止采样应答 (CMD Set 0x00, CMD ID 0x04, 且为ACK类型)
        elseif cmd_set_val == 0x00 and cmd_id_val == 0x04 and cmd_type_val == 0x01 then
            if data_length >= 3 then
                local ret_code_val = buffer(2,1):uint()
                local ret_code_desc = ret_code_map[ret_code_val] or string.format("未知返回码 (0x%02X)", ret_code_val)
                cmd_data_subtree:add(f_ret_code, buffer(2,1), ret_code_val, string.format("Return Code: 0x%02X (%s)", ret_code_val, ret_code_desc))
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "开始/停止采样应答长度不足")
            end
        
        -- 更改坐标系请求 (CMD Set 0x00, CMD ID 0x05, 且为CMD类型)
        elseif cmd_set_val == 0x00 and cmd_id_val == 0x05 and cmd_type_val == 0x00 then
            if data_length >= 3 then
                local coordinate_type_val = buffer(2,1):uint()
                local coordinate_type_desc = coordinate_type_map[coordinate_type_val] or string.format("未知坐标系类型 (0x%02X)", coordinate_type_val)
                cmd_data_subtree:add(f_coordinate_type, buffer(2,1), coordinate_type_val, string.format("Coordinate Type: 0x%02X (%s)", coordinate_type_val, coordinate_type_desc))
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "更改坐标系请求长度不足")
            end
        
        -- 更改坐标系应答 (CMD Set 0x00, CMD ID 0x05, 且为ACK类型)
        elseif cmd_set_val == 0x00 and cmd_id_val == 0x05 and cmd_type_val == 0x01 then
            if data_length >= 3 then
                local ret_code_val = buffer(2,1):uint()
                local ret_code_desc = ret_code_map[ret_code_val] or string.format("未知返回码 (0x%02X)", ret_code_val)
                cmd_data_subtree:add(f_ret_code, buffer(2,1), ret_code_val, string.format("Return Code: 0x%02X (%s)", ret_code_val, ret_code_desc))
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "更改坐标系应答长度不足")
            end

        -- 断开连接请求 (CMD Set 0x00, CMD ID 0x06, 且为CMD类型)
        elseif cmd_set_val == 0x00 and cmd_id_val == 0x06 and cmd_type_val == 0x00 then
            -- 断开连接请求没有额外数据字段
            if data_length > 2 then
                cmd_data_subtree:add("No additional data expected for disconnect request")
            end

        -- 断开连接应答 (CMD Set 0x00, CMD ID 0x06, 且为ACK类型)
        elseif cmd_set_val == 0x00 and cmd_id_val == 0x06 and cmd_type_val == 0x01 then
            if data_length >= 3 then
                local ret_code_val = buffer(2,1):uint()
                local ret_code_desc = ret_code_map[ret_code_val] or string.format("未知返回码 (0x%02X)", ret_code_val)
                cmd_data_subtree:add(f_ret_code, buffer(2,1), ret_code_val)
                cmd_data_subtree:add("Return Code: 0x%02X (%s)", ret_code_val, ret_code_desc)
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "断开连接应答长度不足")
            end

        -- 异常状态推送信息 (CMD Set 0x00, CMD ID 0x07, 且为MSG类型)
        elseif cmd_set_val == 0x00 and cmd_id_val == 0x07 and cmd_type_val == 0x02 then
            if data_length >= 6 then
                local status_code_val = buffer(2,4):le_uint()
                cmd_data_subtree:add(f_status_code_old, buffer(2,4), status_code_val)
                              
                
                -- 详细解析状态码
                local status_details = {}
                
                -- 温度状态 (Bit0-1)
                local temp_status = (status_code_val >> 0) & 0x3
                if temp_status == 0 then
                    table.insert(status_details, "温度正常")
                elseif temp_status == 1 then
                    table.insert(status_details, "温度偏高或偏低")
                elseif temp_status == 2 then
                    table.insert(status_details, "温度极高或极低")
                end
                
                -- 电压状态 (Bit2-3)
                local volt_status = (status_code_val >> 2) & 0x3
                if volt_status == 0 then
                    table.insert(status_details, "电压正常")
                elseif volt_status == 1 then
                    table.insert(status_details, "电压偏高")
                elseif volt_status == 2 then
                    table.insert(status_details, "电压极高")
                end
                
                -- 电机状态 (Bit4-5)
                local motor_status = (status_code_val >> 4) & 0x3
                if motor_status == 0 then
                    table.insert(status_details, "电机正常")
                elseif motor_status == 1 then
                    table.insert(status_details, "电机警告")
                elseif motor_status == 2 then
                    table.insert(status_details, "电机错误，无法工作")
                end
                
                -- 脏污警告 (Bit6-7)
                local dirty_warn = (status_code_val >> 6) & 0x3
                if dirty_warn == 0 then
                    table.insert(status_details, "无脏污和遮挡")
                elseif dirty_warn >= 1 then
                    table.insert(status_details, "有脏污和遮挡")
                end
                
                -- 固件状态 (Bit8)
                local firmware_status = (status_code_val >> 8) & 0x1
                if firmware_status == 0 then
                    table.insert(status_details, "固件正常")
                else
                    table.insert(status_details, "固件出错，需要升级")
                end
                
                -- PPS状态 (Bit9)
                local pps_status = (status_code_val >> 9) & 0x1
                if pps_status == 0 then
                    table.insert(status_details, "无PPS信号")
                else
                    table.insert(status_details, "PPS信号正常")
                end
                
                -- 设备状态 (Bit10)
                local device_status = (status_code_val >> 10) & 0x1
                if device_status == 0 then
                    table.insert(status_details, "设备正常")
                else
                    table.insert(status_details, "设备寿命警告")
                end
                
                -- 风扇状态 (Bit11)
                local fan_status = (status_code_val >> 11) & 0x1
                if fan_status == 0 then
                    table.insert(status_details, "风扇正常")
                else
                    table.insert(status_details, "风扇警告（异常或用户设置停止）")
                end
                
                -- 自加热状态 (Bit12)
                local self_heating = (status_code_val >> 12) & 0x1
                if self_heating == 0 then
                    table.insert(status_details, "低温自加热关闭")
                else
                    table.insert(status_details, "低温自加热开启")
                end
                
                -- PTP状态 (Bit13)
                local ptp_status = (status_code_val >> 13) & 0x1
                if ptp_status == 0 then
                    table.insert(status_details, "无1588信号")
                else
                    table.insert(status_details, "1588信号正常")
                end
                
                -- 时间同步状态 (Bit14-16)
                local time_sync_status = (status_code_val >> 14) & 0x7
                if time_sync_status == 0 then
                    table.insert(status_details, "未开始时间同步")
                elseif time_sync_status == 1 then
                    table.insert(status_details, "使用PTP 1588同步")
                elseif time_sync_status == 2 then
                    table.insert(status_details, "使用GPS同步")
                elseif time_sync_status == 3 then
                    table.insert(status_details, "使用PPS同步")
                elseif time_sync_status == 4 then
                    table.insert(status_details, "系统时间同步异常")
                end
                
                -- 系统状态 (Bit30-31)
                local system_status = (status_code_val >> 30) & 0x3
                if system_status == 0 then
                    table.insert(status_details, "系统正常")
                elseif system_status == 1 then
                    table.insert(status_details, "系统警告")
                elseif system_status == 2 then
                    table.insert(status_details, "系统错误，雷达停机")
                end
                
                -- 显示详细状态信息
                if #status_details > 0 then
                    local status_tree = cmd_data_subtree:add("Status Details")
                    for i, detail in ipairs(status_details) do
                        status_tree:add(string.format("[%d] %s", i, detail))
                    end
                end
                
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "异常状态推送信息长度不足")
            end

        -- 配置IP请求 (CMD Set 0x00, CMD ID 0x08, 且为CMD类型)
        elseif cmd_set_val == 0x00 and cmd_id_val == 0x08 and cmd_type_val == 0x00 then
            if data_length >= 3 then
                local ip_mode_val = buffer(2,1):uint()
                local ip_mode_desc = ip_mode_map[ip_mode_val] or string.format("未知IP模式 (0x%02X)", ip_mode_val)
                cmd_data_subtree:add(f_ip_mode, buffer(2,1), ip_mode_val)
                cmd_data_subtree:add("IP Mode: 0x%02X (%s)", ip_mode_val, ip_mode_desc)
                
                -- 解析IP地址
                if data_length >= 7 then
                    local ip_bytes = buffer(3,4):bytes()
                    local ip_str = string.format("%d.%d.%d.%d", ip_bytes:get_index(0), ip_bytes:get_index(1), ip_bytes:get_index(2), ip_bytes:get_index(3))
                    cmd_data_subtree:add(f_ip_addr, buffer(3,4))
                    cmd_data_subtree:add("IP Address: %s", ip_str)
                end
                
                -- 解析子网掩码（静态IP模式下有效）
                if data_length >= 11 and ip_mode_val == 0x01 then
                    local netmask_bytes = buffer(7,4):bytes()
                    local netmask_str = string.format("%d.%d.%d.%d", netmask_bytes:get_index(0), netmask_bytes:get_index(1), netmask_bytes:get_index(2), netmask_bytes:get_index(3))
                    cmd_data_subtree:add(f_net_mask, buffer(7,4))
                    cmd_data_subtree:add("Net Mask: %s", netmask_str)
                end
                
                -- 解析网关地址（静态IP模式下有效）
                if data_length >= 15 and ip_mode_val == 0x01 then
                    local gw_bytes = buffer(11,4):bytes()
                    local gw_str = string.format("%d.%d.%d.%d", gw_bytes:get_index(0), gw_bytes:get_index(1), gw_bytes:get_index(2), gw_bytes:get_index(3))
                    cmd_data_subtree:add(f_gw_addr, buffer(11,4))
                    cmd_data_subtree:add("Gateway: %s", gw_str)
                end
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "配置IP请求长度不足")
            end

        -- 配置IP应答 (CMD Set 0x00, CMD ID 0x08, 且为ACK类型)
        elseif cmd_set_val == 0x00 and cmd_id_val == 0x08 and cmd_type_val == 0x01 then
            if data_length >= 3 then
                local ret_code_val = buffer(2,1):uint()
                local ret_code_desc = ret_code_map[ret_code_val] or string.format("未知返回码 (0x%02X)", ret_code_val)
                cmd_data_subtree:add(f_ret_code, buffer(2,1), ret_code_val)
                cmd_data_subtree:add("Return Code: 0x%02X (%s)", ret_code_val, ret_code_desc)
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "配置IP应答长度不足")
            end

        -- 获取IP信息请求 (CMD Set 0x00, CMD ID 0x09, 且为CMD类型)
        elseif cmd_set_val == 0x00 and cmd_id_val == 0x09 and cmd_type_val == 0x00 then
            -- 获取IP信息请求没有额外数据字段
            if data_length > 2 then
                cmd_data_subtree:add("No additional data expected for get IP info request")
            end

        -- 获取IP信息应答 (CMD Set 0x00, CMD ID 0x09, 且为ACK类型)
        elseif cmd_set_val == 0x00 and cmd_id_val == 0x09 and cmd_type_val == 0x01 then
            if data_length >= 16 then
                local ret_code_val = buffer(2,1):uint()
                local ret_code_desc = ret_code_map[ret_code_val] or string.format("未知返回码 (0x%02X)", ret_code_val)
                cmd_data_subtree:add(f_ret_code, buffer(2,1), ret_code_val)
                cmd_data_subtree:add("Return Code: 0x%02X (%s)", ret_code_val, ret_code_desc)
                
                local ip_mode_val = buffer(3,1):uint()
                local ip_mode_desc = ip_mode_map[ip_mode_val] or string.format("未知IP模式 (0x%02X)", ip_mode_val)
                cmd_data_subtree:add(f_ip_mode, buffer(3,1), ip_mode_val)
                cmd_data_subtree:add("IP Mode: 0x%02X (%s)", ip_mode_val, ip_mode_desc)
                
                -- 解析IP地址
                local ip_bytes = buffer(4,4):bytes()
                local ip_str = string.format("%d.%d.%d.%d", ip_bytes:get_index(0), ip_bytes:get_index(1), ip_bytes:get_index(2), ip_bytes:get_index(3))
                cmd_data_subtree:add(f_ip_addr, buffer(4,4))
                cmd_data_subtree:add("IP Address: %s", ip_str)
                
                -- 解析子网掩码
                local netmask_bytes = buffer(8,4):bytes()
                local netmask_str = string.format("%d.%d.%d.%d", netmask_bytes:get_index(0), netmask_bytes:get_index(1), netmask_bytes:get_index(2), netmask_bytes:get_index(3))
                cmd_data_subtree:add(f_net_mask, buffer(8,4))
                cmd_data_subtree:add("Net Mask: %s", netmask_str)
                
                -- 解析网关地址
                local gw_bytes = buffer(12,4):bytes()
                local gw_str = string.format("%d.%d.%d.%d", gw_bytes:get_index(0), gw_bytes:get_index(1), gw_bytes:get_index(2), gw_bytes:get_index(3))
                cmd_data_subtree:add(f_gw_addr, buffer(12,4))
                cmd_data_subtree:add("Gateway: %s", gw_str)
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "获取IP信息应答长度不足")
            end

        -- 重启设备请求 (CMD Set 0x00, CMD ID 0x0A, 且为CMD类型)
        elseif cmd_set_val == 0x00 and cmd_id_val == 0x0A and cmd_type_val == 0x00 then
            if data_length >= 4 then
                local timeout_val = buffer(2,2):le_uint()
                cmd_data_subtree:add(f_timeout, buffer(2,2), timeout_val)
                cmd_data_subtree:add("Timeout: %d ms", timeout_val)
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "重启设备请求长度不足")
            end

        -- 重启设备应答 (CMD Set 0x00, CMD ID 0x0A, 且为ACK类型)
        elseif cmd_set_val == 0x00 and cmd_id_val == 0x0A and cmd_type_val == 0x01 then
            if data_length >= 3 then
                local ret_code_val = buffer(2,1):uint()
                local ret_code_desc = ret_code_map[ret_code_val] or string.format("未知返回码 (0x%02X)", ret_code_val)
                cmd_data_subtree:add(f_ret_code, buffer(2,1), ret_code_val)
                cmd_data_subtree:add("Return Code: 0x%02X (%s)", ret_code_val, ret_code_desc)
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "重启设备应答长度不足")
            end

        -- 写配置参数请求 (CMD Set 0x00, CMD ID 0x0B, 且为CMD类型)
        elseif cmd_set_val == 0x00 and cmd_id_val == 0x0B and cmd_type_val == 0x00 then
            if data_length >= 4 then
                local param_key_val = buffer(2,1):uint()
                local param_key_desc = param_key_map[param_key_val] or string.format("未知参数键 (0x%02X)", param_key_val)
                cmd_data_subtree:add(f_param_key, buffer(2,1), param_key_val)
                cmd_data_subtree:add("Parameter Key: 0x%02X (%s)", param_key_val, param_key_desc)
                
                local param_length_val = buffer(3,1):uint()
                cmd_data_subtree:add(f_param_length, buffer(3,1), param_length_val)
                cmd_data_subtree:add("Parameter Length: %d bytes", param_length_val)
                
                if data_length >= 4 + param_length_val then
                    local param_value_buffer = buffer(4, param_length_val)
                    cmd_data_subtree:add(f_param_value, param_value_buffer)
                    
                    -- 根据参数键解析参数值
                    if param_key_val == 0x01 and param_length_val >= 1 then
                        local sensitivity_val = param_value_buffer(0,1):uint()
                        local sensitivity_desc = high_sensitivity_map[sensitivity_val] or string.format("未知灵敏度值 (0x%02X)", sensitivity_val)
                        cmd_data_subtree:add("High Sensitivity: 0x%02X (%s)", sensitivity_val, sensitivity_desc)
                    elseif param_key_val == 0x02 and param_length_val >= 1 then
                        local scan_mode_val = param_value_buffer(0,1):uint()
                        local scan_mode_desc = scan_mode_map[scan_mode_val] or string.format("未知扫描模式 (0x%02X)", scan_mode_val)
                        cmd_data_subtree:add("Scan Mode: 0x%02X (%s)", scan_mode_val, scan_mode_desc)
                    elseif param_key_val == 0x03 and param_length_val >= 1 then
                        local slot_id_val = param_value_buffer(0,1):uint()
                        cmd_data_subtree:add("Slot ID: %d", slot_id_val)
                    else
                        -- 显示原始参数值
                        if param_length_val <= 16 then
                            cmd_data_subtree:add("Parameter Value: " .. tostring(param_value_buffer:bytes()))
                        else
                            cmd_data_subtree:add("Parameter Value: " .. tostring(param_value_buffer(0,16):bytes()) .. "...")
                        end
                    end
                else
                    cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "参数值长度不足")
                end
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "写配置参数请求长度不足")
            end

        -- 写配置参数应答 (CMD Set 0x00, CMD ID 0x0B, 且为ACK类型)
        elseif cmd_set_val == 0x00 and cmd_id_val == 0x0B and cmd_type_val == 0x01 then
            if data_length >= 3 then
                local ret_code_val = buffer(2,1):uint()
                local ret_code_desc = ret_code_map[ret_code_val] or string.format("未知返回码 (0x%02X)", ret_code_val)
                cmd_data_subtree:add(f_ret_code, buffer(2,1), ret_code_val)
                cmd_data_subtree:add("Return Code: 0x%02X (%s)", ret_code_val, ret_code_desc)
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "写配置参数应答长度不足")
            end

        -- 读配置参数请求 (CMD Set 0x00, CMD ID 0x0C, 且为CMD类型)
        elseif cmd_set_val == 0x00 and cmd_id_val == 0x0C and cmd_type_val == 0x00 then
            if data_length >= 3 then
                local param_key_val = buffer(2,1):uint()
                local param_key_desc = param_key_map[param_key_val] or string.format("未知参数键 (0x%02X)", param_key_val)
                cmd_data_subtree:add(f_param_key, buffer(2,1), param_key_val)
                cmd_data_subtree:add("Parameter Key: 0x%02X (%s)", param_key_val, param_key_desc)
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "读配置参数请求长度不足")
            end

        -- 读配置参数应答 (CMD Set 0x00, CMD ID 0x0C, 且为ACK类型)
        elseif cmd_set_val == 0x00 and cmd_id_val == 0x0C and cmd_type_val == 0x01 then
            if data_length >= 4 then
                local ret_code_val = buffer(2,1):uint()
                local ret_code_desc = ret_code_map[ret_code_val] or string.format("未知返回码 (0x%02X)", ret_code_val)
                cmd_data_subtree:add(f_ret_code, buffer(2,1), ret_code_val)
                cmd_data_subtree:add("Return Code: 0x%02X (%s)", ret_code_val, ret_code_desc)
                
                local param_key_val = buffer(3,1):uint()
                local param_key_desc = param_key_map[param_key_val] or string.format("未知参数键 (0x%02X)", param_key_val)
                cmd_data_subtree:add(f_param_key, buffer(3,1), param_key_val)
                cmd_data_subtree:add("Parameter Key: 0x%02X (%s)", param_key_val, param_key_desc)
                
                if data_length >= 5 then
                    local param_length_val = buffer(4,1):uint()
                    cmd_data_subtree:add(f_param_length, buffer(4,1), param_length_val)
                    cmd_data_subtree:add("Parameter Length: %d bytes", param_length_val)
                    
                    if data_length >= 5 + param_length_val then
                        local param_value_buffer = buffer(5, param_length_val)
                        cmd_data_subtree:add(f_param_value, param_value_buffer)
                        
                        -- 根据参数键解析参数值
                        if param_key_val == 0x01 and param_length_val >= 1 then
                            local sensitivity_val = param_value_buffer(0,1):uint()
                            local sensitivity_desc = high_sensitivity_map[sensitivity_val] or string.format("未知灵敏度值 (0x%02X)", sensitivity_val)
                            cmd_data_subtree:add("High Sensitivity: 0x%02X (%s)", sensitivity_val, sensitivity_desc)
                        elseif param_key_val == 0x02 and param_length_val >= 1 then
                            local scan_mode_val = param_value_buffer(0,1):uint()
                            local scan_mode_desc = scan_mode_map[scan_mode_val] or string.format("未知扫描模式 (0x%02X)", scan_mode_val)
                            cmd_data_subtree:add("Scan Mode: 0x%02X (%s)", scan_mode_val, scan_mode_desc)
                        elseif param_key_val == 0x03 and param_length_val >= 1 then
                            local slot_id_val = param_value_buffer(0,1):uint()
                            cmd_data_subtree:add("Slot ID: %d", slot_id_val)
                        else
                            -- 显示原始参数值
                            if param_length_val <= 16 then
                                cmd_data_subtree:add("Parameter Value: " .. tostring(param_value_buffer:bytes()))
                            else
                                cmd_data_subtree:add("Parameter Value: " .. tostring(param_value_buffer(0,16):bytes()) .. "...")
                            end
                        end
                    else
                        cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "参数值长度不足")
                    end
                end
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "读配置参数应答长度不足")
            end


    -- 0x01 雷达指令集        
        -- 模式切换请求 (CMD Set 0x01, CMD ID 0x00, 且为CMD类型)
        elseif cmd_set_val == 0x01 and cmd_id_val == 0x00 and cmd_type_val == 0x00 then
            if data_length >= 3 then
                local lidar_mode_val = buffer(2,1):uint()
                local lidar_mode_desc = lidar_mode_map[lidar_mode_val] or string.format("未知雷达模式 (0x%02X)", lidar_mode_val)
                cmd_data_subtree:add(f_lidar_mode, buffer(2,1), lidar_mode_val)
                cmd_data_subtree:add("LiDAR Mode: 0x%02X (%s)", lidar_mode_val, lidar_mode_desc)
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "模式切换请求长度不足")
            end

        -- 模式切换应答 (CMD Set 0x01, CMD ID 0x00, 且为ACK类型)
        elseif cmd_set_val == 0x01 and cmd_id_val == 0x00 and cmd_type_val == 0x01 then
            if data_length >= 3 then
                local ret_code_val = buffer(2,1):uint()
                local ret_code_desc = lidar_ret_code_map[ret_code_val] or string.format("未知返回码 (0x%02X)", ret_code_val)
                cmd_data_subtree:add(f_ret_code, buffer(2,1), ret_code_val)
                cmd_data_subtree:add("Return Code: 0x%02X (%s)", ret_code_val, ret_code_desc)
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "模式切换应答长度不足")
            end

        -- 写入外部参数请求 (CMD Set 0x01, CMD ID 0x01, 且为CMD类型)
        elseif cmd_set_val == 0x01 and cmd_id_val == 0x01 and cmd_type_val == 0x00 then
            if data_length >= 26 then
                local roll_val = buffer(2,4):le_float()
                cmd_data_subtree:add(f_roll, buffer(2,4), roll_val)
                cmd_data_subtree:add("Roll: %.3f degrees", roll_val)
                
                local pitch_val = buffer(6,4):le_float()
                cmd_data_subtree:add(f_pitch, buffer(6,4), pitch_val)
                cmd_data_subtree:add("Pitch: %.3f degrees", pitch_val)
                
                local yaw_val = buffer(10,4):le_float()
                cmd_data_subtree:add(f_yaw, buffer(10,4), yaw_val)
                cmd_data_subtree:add("Yaw: %.3f degrees", yaw_val)
                
                local x_val = buffer(14,4):le_int()
                cmd_data_subtree:add(f_x, buffer(14,4), x_val)
                cmd_data_subtree:add("X: %d mm", x_val)
                
                local y_val = buffer(18,4):le_int()
                cmd_data_subtree:add(f_y, buffer(18,4), y_val)
                cmd_data_subtree:add("Y: %d mm", y_val)
                
                local z_val = buffer(22,4):le_int()
                cmd_data_subtree:add(f_z, buffer(22,4), z_val)
                cmd_data_subtree:add("Z: %d mm", z_val)
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "写入外部参数请求长度不足")
            end

        -- 写入外部参数应答 (CMD Set 0x01, CMD ID 0x01, 且为ACK类型)
        elseif cmd_set_val == 0x01 and cmd_id_val == 0x01 and cmd_type_val == 0x01 then
            if data_length >= 3 then
                local ret_code_val = buffer(2,1):uint()
                local ret_code_desc = lidar_ret_code_map[ret_code_val] or string.format("未知返回码 (0x%02X)", ret_code_val)
                cmd_data_subtree:add(f_ret_code, buffer(2,1), ret_code_val)
                cmd_data_subtree:add("Return Code: 0x%02X (%s)", ret_code_val, ret_code_desc)
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "写入外部参数应答长度不足")
            end

        -- 读取外部参数请求 (CMD Set 0x01, CMD ID 0x02, 且为CMD类型)
        elseif cmd_set_val == 0x01 and cmd_id_val == 0x02 and cmd_type_val == 0x00 then
            -- 读取外部参数请求没有额外数据字段
            if data_length > 2 then
                cmd_data_subtree:add("No additional data expected for read external parameters request")
            end

        -- 读取外部参数应答 (CMD Set 0x01, CMD ID 0x02, 且为ACK类型)
        elseif cmd_set_val == 0x01 and cmd_id_val == 0x02 and cmd_type_val == 0x01 then
            if data_length >= 27 then
                local ret_code_val = buffer(2,1):uint()
                local ret_code_desc = lidar_ret_code_map[ret_code_val] or string.format("未知返回码 (0x%02X)", ret_code_val)
                cmd_data_subtree:add(f_ret_code, buffer(2,1), ret_code_val)
                cmd_data_subtree:add("Return Code: 0x%02X (%s)", ret_code_val, ret_code_desc)
                
                local roll_val = buffer(3,4):le_float()
                cmd_data_subtree:add(f_roll, buffer(3,4), roll_val)
                cmd_data_subtree:add("Roll: %.3f degrees", roll_val)
                
                local pitch_val = buffer(7,4):le_float()
                cmd_data_subtree:add(f_pitch, buffer(7,4), pitch_val)
                cmd_data_subtree:add("Pitch: %.3f degrees", pitch_val)
                
                local yaw_val = buffer(11,4):le_float()
                cmd_data_subtree:add(f_yaw, buffer(11,4), yaw_val)
                cmd_data_subtree:add("Yaw: %.3f degrees", yaw_val)
                
                local x_val = buffer(15,4):le_int()
                cmd_data_subtree:add(f_x, buffer(15,4), x_val)
                cmd_data_subtree:add("X: %d mm", x_val)
                
                local y_val = buffer(19,4):le_int()
                cmd_data_subtree:add(f_y, buffer(19,4), y_val)
                cmd_data_subtree:add("Y: %d mm", y_val)
                
                local z_val = buffer(23,4):le_int()
                cmd_data_subtree:add(f_z, buffer(23,4), z_val)
                cmd_data_subtree:add("Z: %d mm", z_val)
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "读取外部参数应答长度不足")
            end

        -- 抗雨雾功能请求 (CMD Set 0x01, CMD ID 0x03, 且为CMD类型)
        elseif cmd_set_val == 0x01 and cmd_id_val == 0x03 and cmd_type_val == 0x00 then
            if data_length >= 3 then
                local state_val = buffer(2,1):uint()
                local state_desc = state_map[state_val] or string.format("未知状态 (0x%02X)", state_val)
                cmd_data_subtree:add(f_state, buffer(2,1), state_val)
                cmd_data_subtree:add("Rain Fog State: 0x%02X (%s)", state_val, state_desc)
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "抗雨雾功能请求长度不足")
            end

        -- 抗雨雾功能应答 (CMD Set 0x01, CMD ID 0x03, 且为ACK类型)
        elseif cmd_set_val == 0x01 and cmd_id_val == 0x03 and cmd_type_val == 0x01 then
            if data_length >= 3 then
                local ret_code_val = buffer(2,1):uint()
                local ret_code_desc = lidar_ret_code_map[ret_code_val] or string.format("未知返回码 (0x%02X)", ret_code_val)
                cmd_data_subtree:add(f_ret_code, buffer(2,1), ret_code_val)
                cmd_data_subtree:add("Return Code: 0x%02X (%s)", ret_code_val, ret_code_desc)
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "抗雨雾功能应答长度不足")
            end

        -- 风扇控制请求 (CMD Set 0x01, CMD ID 0x04, 且为CMD类型)
        elseif cmd_set_val == 0x01 and cmd_id_val == 0x04 and cmd_type_val == 0x00 then
            if data_length >= 3 then
                local state_val = buffer(2,1):uint()
                local state_desc = state_map[state_val] or string.format("未知状态 (0x%02X)", state_val)
                cmd_data_subtree:add(f_state, buffer(2,1), state_val)
                cmd_data_subtree:add("Fan State: 0x%02X (%s)", state_val, state_desc)
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "风扇控制请求长度不足")
            end

        -- 风扇控制应答 (CMD Set 0x01, CMD ID 0x04, 且为ACK类型)
        elseif cmd_set_val == 0x01 and cmd_id_val == 0x04 and cmd_type_val == 0x01 then
            if data_length >= 3 then
                local ret_code_val = buffer(2,1):uint()
                local ret_code_desc = lidar_ret_code_map[ret_code_val] or string.format("未知返回码 (0x%02X)", ret_code_val)
                cmd_data_subtree:add(f_ret_code, buffer(2,1), ret_code_val)
                cmd_data_subtree:add("Return Code: 0x%02X (%s)", ret_code_val, ret_code_desc)
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "风扇控制应答长度不足")
            end

        -- 读取风扇状态请求 (CMD Set 0x01, CMD ID 0x05, 且为CMD类型)
        elseif cmd_set_val == 0x01 and cmd_id_val == 0x05 and cmd_type_val == 0x00 then
            -- 读取风扇状态请求没有额外数据字段
            if data_length > 2 then
                cmd_data_subtree:add("No additional data expected for read fan state request")
            end

        -- 读取风扇状态应答 (CMD Set 0x01, CMD ID 0x05, 且为ACK类型)
        elseif cmd_set_val == 0x01 and cmd_id_val == 0x05 and cmd_type_val == 0x01 then
            if data_length >= 4 then
                local ret_code_val = buffer(2,1):uint()
                local ret_code_desc = lidar_ret_code_map[ret_code_val] or string.format("未知返回码 (0x%02X)", ret_code_val)
                cmd_data_subtree:add(f_ret_code, buffer(2,1), ret_code_val)
                cmd_data_subtree:add("Return Code: 0x%02X (%s)", ret_code_val, ret_code_desc)
                
                local state_val = buffer(3,1):uint()
                local state_desc = state_map[state_val] or string.format("未知状态 (0x%02X)", state_val)
                cmd_data_subtree:add(f_state, buffer(3,1), state_val)
                cmd_data_subtree:add("Fan State: 0x%02X (%s)", state_val, state_desc)
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "读取风扇状态应答长度不足")
            end

        -- 设置回波模式请求 (CMD Set 0x01, CMD ID 0x06, 且为CMD类型)
        elseif cmd_set_val == 0x01 and cmd_id_val == 0x06 and cmd_type_val == 0x00 then
            if data_length >= 3 then
                local mode_val = buffer(2,1):uint()
                local mode_desc = echo_mode_map[mode_val] or string.format("未知模式 (0x%02X)", mode_val)
                cmd_data_subtree:add(f_mode, buffer(2,1), mode_val)
                cmd_data_subtree:add("Echo Mode: 0x%02X (%s)", mode_val, mode_desc)
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "设置回波模式请求长度不足")
            end

        -- 设置回波模式应答 (CMD Set 0x01, CMD ID 0x06, 且为ACK类型)
        elseif cmd_set_val == 0x01 and cmd_id_val == 0x06 and cmd_type_val == 0x01 then
            if data_length >= 3 then
                local ret_code_val = buffer(2,1):uint()
                local ret_code_desc = lidar_ret_code_map[ret_code_val] or string.format("未知返回码 (0x%02X)", ret_code_val)
                cmd_data_subtree:add(f_ret_code, buffer(2,1), ret_code_val)
                cmd_data_subtree:add("Return Code: 0x%02X (%s)", ret_code_val, ret_code_desc)
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "设置回波模式应答长度不足")
            end

        -- 获取回波模式请求 (CMD Set 0x01, CMD ID 0x07, 且为CMD类型)
        elseif cmd_set_val == 0x01 and cmd_id_val == 0x07 and cmd_type_val == 0x00 then
            -- 获取回波模式请求没有额外数据字段
            if data_length > 2 then
                cmd_data_subtree:add("No additional data expected for get echo mode request")
            end

        -- 获取回波模式应答 (CMD Set 0x01, CMD ID 0x07, 且为ACK类型)
        elseif cmd_set_val == 0x01 and cmd_id_val == 0x07 and cmd_type_val == 0x01 then
            if data_length >= 4 then
                local ret_code_val = buffer(2,1):uint()
                local ret_code_desc = lidar_ret_code_map[ret_code_val] or string.format("未知返回码 (0x%02X)", ret_code_val)
                cmd_data_subtree:add(f_ret_code, buffer(2,1), ret_code_val)
                cmd_data_subtree:add("Return Code: 0x%02X (%s)", ret_code_val, ret_code_desc)
                
                local mode_val = buffer(3,1):uint()
                local mode_desc = echo_mode_map[mode_val] or string.format("未知模式 (0x%02X)", mode_val)
                cmd_data_subtree:add(f_mode, buffer(3,1), mode_val)
                cmd_data_subtree:add("Echo Mode: 0x%02X (%s)", mode_val, mode_desc)
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "获取回波模式应答长度不足")
            end

        -- 设置IMU频率请求 (CMD Set 0x01, CMD ID 0x08, 且为CMD类型)
        elseif cmd_set_val == 0x01 and cmd_id_val == 0x08 and cmd_type_val == 0x00 then
            if data_length >= 3 then
                local frequency_val = buffer(2,1):uint()
                local frequency_desc = imu_frequency_map[frequency_val] or string.format("未知频率 (0x%02X)", frequency_val)
                cmd_data_subtree:add(f_frequency, buffer(2,1), frequency_val)
                cmd_data_subtree:add("IMU Frequency: 0x%02X (%s)", frequency_val, frequency_desc)
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "设置IMU频率请求长度不足")
            end

        -- 设置IMU频率应答 (CMD Set 0x01, CMD ID 0x08, 且为ACK类型)
        elseif cmd_set_val == 0x01 and cmd_id_val == 0x08 and cmd_type_val == 0x01 then
            if data_length >= 3 then
                local ret_code_val = buffer(2,1):uint()
                local ret_code_desc = lidar_ret_code_map[ret_code_val] or string.format("未知返回码 (0x%02X)", ret_code_val)
                cmd_data_subtree:add(f_ret_code, buffer(2,1), ret_code_val)
                cmd_data_subtree:add("Return Code: 0x%02X (%s)", ret_code_val, ret_code_desc)
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "设置IMU频率应答长度不足")
            end

        -- 获取IMU频率请求 (CMD Set 0x01, CMD ID 0x09, 且为CMD类型)
        elseif cmd_set_val == 0x01 and cmd_id_val == 0x09 and cmd_type_val == 0x00 then
            -- 获取IMU频率请求没有额外数据字段
            if data_length > 2 then
                cmd_data_subtree:add("No additional data expected for get IMU frequency request")
            end

        -- 获取IMU频率应答 (CMD Set 0x01, CMD ID 0x09, 且为ACK类型)
        elseif cmd_set_val == 0x01 and cmd_id_val == 0x09 and cmd_type_val == 0x01 then
            if data_length >= 4 then
                local ret_code_val = buffer(2,1):uint()
                local ret_code_desc = lidar_ret_code_map[ret_code_val] or string.format("未知返回码 (0x%02X)", ret_code_val)
                cmd_data_subtree:add(f_ret_code, buffer(2,1), ret_code_val)
                cmd_data_subtree:add("Return Code: 0x%02X (%s)", ret_code_val, ret_code_desc)
                
                local frequency_val = buffer(3,1):uint()
                local frequency_desc = imu_frequency_map[frequency_val] or string.format("未知频率 (0x%02X)", frequency_val)
                cmd_data_subtree:add(f_frequency, buffer(3,1), frequency_val)
                cmd_data_subtree:add("IMU Frequency: 0x%02X (%s)", frequency_val, frequency_desc)
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "获取IMU频率应答长度不足")
            end

        -- 更新UTC时间请求 (CMD Set 0x01, CMD ID 0x0A, 且为CMD类型)
        elseif cmd_set_val == 0x01 and cmd_id_val == 0x0A and cmd_type_val == 0x00 then
            if data_length >= 10 then
                local year_val = buffer(2,1):uint()
                cmd_data_subtree:add(f_year, buffer(2,1), year_val)
                cmd_data_subtree:add("Year: %d (代表 %d 年)", year_val, 2000 + year_val)
                
                local month_val = buffer(3,1):uint()
                cmd_data_subtree:add(f_month, buffer(3,1), month_val)
                cmd_data_subtree:add("Month: %d", month_val)
                
                local day_val = buffer(4,1):uint()
                cmd_data_subtree:add(f_day, buffer(4,1), day_val)
                cmd_data_subtree:add("Day: %d", day_val)
                
                local hour_val = buffer(5,1):uint()
                cmd_data_subtree:add(f_hour, buffer(5,1), hour_val)
                cmd_data_subtree:add("Hour: %d", hour_val)
                
                local microsecond_val = buffer(6,4):le_uint()
                cmd_data_subtree:add(f_microsecond, buffer(6,4), microsecond_val)
                cmd_data_subtree:add("Microsecond: %d us", microsecond_val)
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "更新UTC时间请求长度不足")
            end

        -- 更新UTC时间应答 (CMD Set 0x01, CMD ID 0x0A, 且为ACK类型)
        elseif cmd_set_val == 0x01 and cmd_id_val == 0x0A and cmd_type_val == 0x01 then
            if data_length >= 3 then
                local ret_code_val = buffer(2,1):uint()
                local ret_code_desc = lidar_ret_code_map[ret_code_val] or string.format("未知返回码 (0x%02X)", ret_code_val)
                cmd_data_subtree:add(f_ret_code, buffer(2,1), ret_code_val)
                cmd_data_subtree:add("Return Code: 0x%02X (%s)", ret_code_val, ret_code_desc)
            else
                cmd_data_subtree:add_expert_info(PI_MALFORMED, PI_WARN, "更新UTC时间应答长度不足")
            end
        
        else
            -- 其他命令的通用数据显示
            if data_length - 2 <= 32 then
                cmd_data_subtree:add("Data: " .. tostring(cmd_data_buffer:bytes()))
            else
                cmd_data_subtree:add("Data: " .. tostring(cmd_data_buffer(0,32):bytes()) .. "...")
            end
        end
    end
end

-- 解析控制指令帧
local function dissect_control_frame(buffer, pinfo, tree)
    pinfo.cols.protocol = "LivoxOldCtrl"
    local subtree = tree:add(livox_old_data_proto, buffer(), "Livox 控制指令帧（旧）")
    
    -- 检查最小长度
    if buffer:len() < 13 then
        subtree:add_expert_info(PI_MALFORMED, PI_ERROR, "控制帧长度不足")
        return
    end
    
    -- 解析SOF字段
    local sof_val = buffer(0,1):uint()
    if sof_val ~= 0xAA then
        subtree:add_expert_info(PI_MALFORMED, PI_WARN, "无效的起始字节")
    end
    subtree:add(f_ctrl_sof, buffer(0,1), sof_val, string.format("Start of Frame: 0x%02X", sof_val))
    
    -- 解析版本字段
    local version_val = buffer(1,1):uint()
    subtree:add(f_ctrl_version, buffer(1,1), version_val, string.format("Protocol Version: %d", version_val))
    
    -- 解析长度字段
    local length_val = buffer(2,2):le_uint()
    subtree:add(f_ctrl_length, buffer(2,2), length_val, string.format("Frame Length: %d bytes", length_val))
    
    -- 检查长度是否匹配
    if buffer:len() ~= length_val then
        subtree:add_expert_info(PI_MALFORMED, PI_WARN, string.format("长度不匹配: 实际%d字节, 声明%d字节", buffer:len(), length_val))
    end
    
    -- 解析命令类型字段
    local cmd_type_val = buffer(4,1):uint()
    local cmd_type_desc = ctrl_cmd_type_map[cmd_type_val] or string.format("未知命令类型 (0x%02X)", cmd_type_val)
    subtree:add(f_ctrl_cmd_type, buffer(4,1), cmd_type_val, string.format("Command Type: 0x%02X (%s)", cmd_type_val, cmd_type_desc))
    
    -- 解析序列号字段
    local seq_num_val = buffer(5,2):le_uint()
    subtree:add(f_ctrl_seq_num, buffer(5,2), seq_num_val, string.format("Sequence Number: %d", seq_num_val))
    
    -- 解析CRC16字段
    local crc16_val = buffer(7,2):le_uint()
    subtree:add(f_ctrl_crc16, buffer(7,2), crc16_val, string.format("Header CRC-16: 0x%04X", crc16_val))
    
    -- 解析数据域
    local data_length = length_val - 13
    if data_length > 0 then
        if (9 + data_length) <= buffer:len() then
            local data_buffer = buffer(9, data_length)
            
            -- 显示原始字节（不使用ProtoField.bytes）
            local hex_str = ""
            for i = 0, data_length-1 do
                hex_str = hex_str .. string.format("%02X ", data_buffer(i,1):uint())
            end
            
            -- 创建数据字段子树
            local data_subtree = subtree:add("Data Field: " .. hex_str)
            
            -- 在子树内部使用ProtoField来解析结构
            dissect_control_data(data_buffer, data_subtree, cmd_type_val)
        else
            subtree:add_expert_info(PI_MALFORMED, PI_WARN, "数据字段长度超出缓冲区范围")
        end
    end
    
    -- 解析CRC32字段
    if buffer:len() >= length_val then
        local crc32_offset = length_val - 4
        local crc32_val = buffer(crc32_offset,4):le_uint()
        subtree:add(f_ctrl_crc32, buffer(crc32_offset,4), crc32_val, string.format("Frame CRC-32: 0x%08X", crc32_val))
    end
end

-- 解析老产品点云/IMU数据帧
local function dissect_old_data_frame(buffer, pinfo, tree)
    pinfo.cols.protocol = "LivoxOldData"
    local subtree = tree:add(livox_old_data_proto, buffer(), "Livox Old Product Data (Avia/Horizon/Tele-15/Mid-70/Mid-40)")

    -- 检查最小长度
    if buffer:len() < 18 then
        subtree:add_expert_info(PI_MALFORMED, PI_ERROR, "数据包长度不足")
        return
    end

    -- 解析头部字段
    local version_val = buffer(0,1):uint()
    subtree:add(f_old_version, buffer(0,1), version_val, string.format("Version (协议版本): %d", version_val))

    local slot_id_val = buffer(1,1):uint()
    subtree:add(f_slot_id, buffer(1,1), slot_id_val, string.format("Slot ID (端口号): %d", slot_id_val))

    local lidar_id_val = buffer(2,1):uint()
    local lidar_desc = lidar_id_map[lidar_id_val] or string.format("未知LiDAR ID (0x%02X)", lidar_id_val)
    subtree:add(f_lidar_id, buffer(2,1), lidar_id_val, string.format("LiDAR ID: %d (%s)", lidar_id_val, lidar_desc))

    local reserved_val = buffer(3,1):uint()
    subtree:add(f_reserved, buffer(3,1), reserved_val, string.format("Reserved: 0x%02X", reserved_val))

    local status_code_val = buffer(4,4):le_uint()
    subtree:add(f_status_code, buffer(4,4), status_code_val, string.format("Status Code: 0x%08X", status_code_val))

    local timestamp_type_val = buffer(8,1):uint()
    local timestamp_type_desc = old_timestamp_type_map[timestamp_type_val] or string.format("未知时间戳类型 (0x%02X)", timestamp_type_val)
    subtree:add(f_timestamp_type, buffer(8,1), timestamp_type_val, string.format("Timestamp Type: %d (%s)", timestamp_type_val, timestamp_type_desc))

    local data_type_val = buffer(9,1):uint()
    local data_type_desc = old_data_type_map[data_type_val] or string.format("未知数据类型 (0x%02X)", data_type_val)
    subtree:add(f_data_type, buffer(9,1), data_type_val, string.format("Data Type: %d (%s)", data_type_val, data_type_desc))

    local timestamp_val = buffer(10,8):le_uint64()
    subtree:add(f_timestamp, buffer(10,8), timestamp_val, string.format("Timestamp: %s", tostring(timestamp_val)))

    -- 解析数据部分
    local data_offset = 18
    if buffer:len() > data_offset then
        local data_len = buffer:len() - data_offset
        if data_len > 0 then
            subtree:add(f_data, buffer(data_offset, data_len))
        end

        -- 解析IMU数据 (data_type = 6)
        if data_type_val == 6 and data_len >= 24 then
            local imu_tree = subtree:add(buffer(data_offset, 24), "IMU Data (数据类型6)")
            
            local gyro_x_val = buffer(data_offset+0,4):le_float()
            imu_tree:add(f_old_gyro_x, buffer(data_offset+0,4), gyro_x_val, string.format("Gyro X (rad/s): %.10f", gyro_x_val))
            
            local gyro_y_val = buffer(data_offset+4,4):le_float()
            imu_tree:add(f_old_gyro_y, buffer(data_offset+4,4), gyro_y_val, string.format("Gyro Y (rad/s): %.10f", gyro_y_val))
            
            local gyro_z_val = buffer(data_offset+8,4):le_float()
            imu_tree:add(f_old_gyro_z, buffer(data_offset+8,4), gyro_z_val, string.format("Gyro Z (rad/s): %.10f", gyro_z_val))
            
            local acc_x_val = buffer(data_offset+12,4):le_float()
            imu_tree:add(f_old_acc_x, buffer(data_offset+12,4), acc_x_val, string.format("Acc X (g): %.10f", acc_x_val))
            
            local acc_y_val = buffer(data_offset+16,4):le_float()
            imu_tree:add(f_old_acc_y, buffer(data_offset+16,4), acc_y_val, string.format("Acc Y (g): %.10f", acc_y_val))
            
            local acc_z_val = buffer(data_offset+20,4):le_float()
            imu_tree:add(f_old_acc_z, buffer(data_offset+20,4), acc_z_val, string.format("Acc Z (g): %.10f", acc_z_val))
        end
    end
end

function livox_old_data_proto.dissector(buffer, pinfo, tree)
    -- 根据端口号判断帧类型
    if pinfo.dst_port == 65000 or pinfo.src_port == 65000 then
        -- 控制指令帧（65000端口）
        dissect_control_frame(buffer, pinfo, tree)
    else
        -- 老产品数据帧（60001/60003端口）
        dissect_old_data_frame(buffer, pinfo, tree)
    end
end

-- 注册协议到不同端口
udp_port = DissectorTable.get("udp.port")
udp_port:add(60001, livox_old_data_proto) -- 点云数据
udp_port:add(60003, livox_old_data_proto) -- IMU数据
udp_port:add(65000, livox_old_data_proto) -- 控制指令