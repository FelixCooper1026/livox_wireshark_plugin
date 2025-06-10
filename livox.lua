-------------------------------------------------------------------------------
-- File: livox.lua
-- Description: Wireshark Lua Plugin for Livox Mid-360 Pushmsg Diagnostic
-- Author: FelixCooper1026
-- Date: 2025-05-22
-- Version: 1.2
-------------------------------------------------------------------------------
-- History:
-- 2025-05-26: 增加对应字段高亮显示功能
-- beta modify：将core_temp改为float
-- 2025-06-03：修复端口号解析错误，应为小端序
-- 2025-06-09：修复time_offset数据类型解析错误，应为 int64_t
-------------------------------------------------------------------------------


local livox_proto = Proto("Livox", "Livox Pushmsg Diag")

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

livox_proto.fields = {
    f_pcl_type, f_pattern_mode, f_lidar_ip, f_target_push, f_target_pcl, f_target_imu, f_install_attitude,
    f_fov_cfg0, f_fov_cfg1, f_fov_en, f_detect_mode, f_func_io_cfg,
    f_work_tgt_mode, f_imu_data_en, f_sn, f_product_info, f_version_app, f_mac,
    f_hms_codes, f_core_temp, f_powerup_count, f_local_time, f_last_sync_time,
    f_time_offset, f_time_sync_type, f_fw_type, f_error_code,
    f_loader_version, f_hw_version, f_work_status
}

local fault_id_dict = {
    ["0000"] = "无故障",
    ["0102"] = "设备运行环境温度偏高;请检查环境温度，或排查散热措施",
    ["0103"] = "设备运行环境温度较高;请检查环境温度，或排查散热措施",
    ["0104"] = "设备球形光窗存在脏污,设备点云数据可信度较差;请及时清洗擦拭设备的球形光窗",
    ["0105"] = "设备升级过程中出现错误;请重新进行升级",
    ["0111"] = "设备内部器件温度异常;请检查环境温度，或排查散热措施",
    ["0112"] = "设备内部器件温度异常;请检查环境温度，或排查散热措施",
    ["0113"] = "设备内部IMU器件暂停工作;请重启设备恢复",
    ["0114"] = "设备运行环境温度高;请检查环境温度，或排查散热措施",
    ["0115"] = "设备运行环境温度超过承受极限，设备已停止工作;请检查环境温度，或排查散热措施",
    ["0116"] = "设备外部电压异常;请检查外部电压",
    ["0117"] = "设备参数异常;请尝试重启设备恢复",
    ["0201"] = "扫描模块低温加热中",
    ["0210"] = "扫描模块异常",
    ["0211"] = "扫描模块异常",
    ["0212"] = "扫描模块异常",
    ["0213"] = "扫描模块异常",
    ["0214"] = "扫描模块异常",
    ["0215"] = "扫描模块异常",
    ["0216"] = "扫描模块异常",
    ["0217"] = "扫描模块异常",
    ["0218"] = "扫描模块异常",
    ["0219"] = "扫描模块异常",
    ["0401"] = "检测到以太网连接曾断开过，请检查以太网链路是否存在异常",
    ["0402"] = "ptp同步中断，或者时间跳变太大，请排查ptp时钟源是否工作正常",
    ["0403"] = "PTP版本为1588-V2.1版本，设备不支持该版本，请更换1588-V2.0版本进行同步",
    ["0404"] = "PPS同步异常，请检查PPS及GPS信号",
    ["0405"] = "时间同步曾经发生过异常，请检查发生异常原因",
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

function livox_proto.dissector(buffer, pinfo, tree)
    pinfo.cols.protocol = "Livox"
    local subtree = tree:add(livox_proto, buffer(), "Livox Pushmsg Diag")

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
            local val = string.format("%.3f ms", local_time_ms)
            subtree:add(f_local_time, data_bytes(0,8), val) 

        elseif key == 0x800A then
            -- 上次同步时间
            local last_sync_time = data_bytes(0,8):le_uint64()
            local time_str = tostring(last_sync_time)
            local time_num = tonumber(time_str)
            local last_sync_ms = time_num / 1000000
            local val = string.format("%.3f ms", last_sync_ms)
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
                    local level_desc = ""
                    if fault_level == 0x01 then
                        level_desc = "Info 消息"
                    elseif fault_level == 0x02 then
                        level_desc = "Warning 警告"
                    elseif fault_level == 0x03 then
                        level_desc = "Error 错误"
                    elseif fault_level == 0x04 then
                        level_desc = "Fatal 严重错误"
                    else
                        level_desc = "未知等级"
                    end

                    -- 获取异常描述
                    local fault_desc = fault_id_dict[fault_id_str] or string.format("未知故障ID (0x%04X)", fault_id)

                    -- 为每个故障码创建单独的子项，并指定对应的4字节范围
                    local fault_info = string.format("[%d]：0x%08X  异常等级[%s]\n异常描述: %s",
                        fault_count, code, level_desc, fault_desc)
                    subtree:add(f_hms_codes, data_bytes(i*4, 4), fault_info) 
                end
            end

            if fault_count == 0 then
                subtree:add(f_hms_codes, data_bytes(0, math.min(32, data_bytes:len())), "无故障") 
            end

        else
            -- 未知字段
            -- subtree:add(buffer(index-length-4, length+4), string.format("未知字段_%04X", key))
        end
    end
end


local udp_port = DissectorTable.get("udp.port")
udp_port:add(56200, livox_proto)
udp_port:add(56201, livox_proto)
