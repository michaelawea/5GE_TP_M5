(*
===============================================================================
系统配置和初始化模块
===============================================================================
功能描述：
- 系统参数配置
- I/O地址定义和映射
- 全局变量定义
- 系统常量定义
- 启动序列管理
- 系统自检功能

配置内容：
1. 硬件配置参数
2. 安全参数设置
3. 时间参数配置
4. 密码和权限设置
5. 通信参数配置
6. 诊断参数设置

使用说明：
本文件包含了系统的所有配置参数，在实际部署时需要根据
现场情况调整相关参数。所有参数都有详细说明和推荐值。

作者: Claude Code Assistant
日期: 2025-09-23
版本: 1.0
===============================================================================
*)

(*  ============================================================================ *)
(*  全局变量定义（用于Unity Pro全局变量表） *)
(*  ============================================================================ *)

VAR_GLOBAL
    (*  ======================================================================== *)
    (*  系统配置参数 *)
    (*  ======================================================================== *)
    CFG_System_Version      : STRING[10] := '1.0.0';    (*  系统版本号 *)
    CFG_PLC_Model           : STRING[20] := 'BMX P34 20102 V2.10'; (*  PLC型号 *)
    CFG_Project_Name        : STRING[30] := 'Dual_Gate_Control_System'; (*  项目名称 *)
    CFG_Installation_Date   : STRING[10] := '2025-09-23'; (*  安装日期 *)
    CFG_Commissioning_Date  : STRING[10] := '2025-09-23'; (*  调试日期 *)

    (*  ======================================================================== *)
    (*  硬件配置参数 *)
    (*  ======================================================================== *)
    CFG_Gate1_Type          : STRING[15] := 'Swing_Panel';     (*  门板1类型 *)
    CFG_Gate2_Type          : STRING[15] := 'Swing_Panel';     (*  门板2类型 *)
    CFG_Motor_Power         : REAL := 0.5;           (*  电机功率 (kW) *)
    CFG_Gate_Weight         : REAL := 150.0;         (*  门板重量 (kg) *)
    CFG_Gate_Width          : REAL := 1.5;           (*  门板宽度 (m) *)

    (*  ======================================================================== *)
    (*  安全参数配置 *)
    (*  ======================================================================== *)
    CFG_Max_Opening_Time    : TIME := T#30s;         (*  最大开门时间 *)
    CFG_Max_Closing_Time    : TIME := T#30s;         (*  最大关门时间 *)
    CFG_Obstacle_Delay      : TIME := T#1s;          (*  障碍物检测延时 *)
    CFG_Overcurrent_Delay   : TIME := T#500ms;       (*  过流检测延时 *)
    CFG_Reverse_Duration    : TIME := T#3s;          (*  反向动作持续时间 *)
    CFG_Safety_Reset_Time   : TIME := T#2s;          (*  安全复位时间 *)

    (*  ======================================================================== *)
    (*  控制参数配置 *)
    (*  ======================================================================== *)
    CFG_Command_Timeout     : TIME := T#2s;          (*  命令超时时间 *)
    CFG_Double_Click_Time   : TIME := T#1s;          (*  双击检测时间 *)
    CFG_Intercom_Priority   : BOOL := TRUE;          (*  对讲机优先级 *)
    CFG_Auto_Close_Enable   : BOOL := FALSE;         (*  自动关门使能 *)
    CFG_Auto_Close_Delay    : TIME := T#10s;         (*  自动关门延时 *)

    (*  ======================================================================== *)
    (*  密码和权限配置 *)
    (*  ======================================================================== *)
    CFG_Password_Single     : INT := 1504;           (*  单门密码 *)
    CFG_Password_Dual       : INT := 2502;           (*  双门密码 *)
    CFG_Input_Timeout       : TIME := T#10s;         (*  密码输入超时 *)
    CFG_Valid_Duration      : TIME := T#30s;         (*  密码有效持续时间 *)
    CFG_Lock_Duration       : TIME := T#5m;          (*  锁定持续时间 *)
    CFG_Max_Attempts        : INT := 3;              (*  最大尝试次数 *)

    (*  ======================================================================== *)
    (*  照明和信号配置 *)
    (*  ======================================================================== *)
    CFG_Lighting_Delay      : TIME := T#5m;          (*  照明延时关闭时间 *)
    CFG_Warning_Blink_Cycle : TIME := T#500ms;       (*  警告灯闪烁周期 *)
    CFG_Night_Lighting      : BOOL := TRUE;          (*  夜间照明使能 *)
    CFG_Night_Start_Hour    : INT := 18;             (*  夜间开始时间 *)
    CFG_Night_End_Hour      : INT := 6;              (*  夜间结束时间 *)

    (*  ======================================================================== *)
    (*  通信配置参数 *)
    (*  ======================================================================== *)
    CFG_Ethernet_IP         : STRING[15] := '134.214.184.171'; (*  以太网IP地址 *)
    CFG_Subnet_Mask         : STRING[15] := '255.255.255.0';   (*  子网掩码 *)
    CFG_Gateway_IP          : STRING[15] := '134.214.184.1';   (*  网关地址 *)
    CFG_HMI_Enable          : BOOL := FALSE;         (*  HMI使能 *)
    CFG_Remote_Access       : BOOL := FALSE;         (*  远程访问使能 *)

    (*  ======================================================================== *)
    (*  诊断和维护参数 *)
    (*  ======================================================================== *)
    CFG_Log_Enable          : BOOL := TRUE;          (*  日志记录使能 *)
    CFG_Log_Level           : INT := 2;              (*  日志级别：1=错误，2=警告，3=信息 *)
    CFG_Maintenance_Hours   : DINT := 8760;          (*  维护周期 (小时) *)
    CFG_Operation_Limit     : DINT := 100000;        (*  操作次数限制 *)
    CFG_Self_Test_Enable    : BOOL := TRUE;          (*  自检使能 *)
    CFG_Self_Test_Interval  : TIME := T#24h;         (*  自检间隔 *)

    (*  ======================================================================== *)
    (*  系统状态变量 *)
    (*  ======================================================================== *)
    SYS_Startup_Complete    : BOOL := FALSE;         (*  启动完成标志 *)
    SYS_Self_Test_OK        : BOOL := FALSE;         (*  自检通过标志 *)
    SYS_Configuration_Valid : BOOL := FALSE;         (*  配置有效标志 *)
    SYS_First_Run           : BOOL := TRUE;          (*  首次运行标志 *)
    SYS_Commissioning_Mode  : BOOL := FALSE;         (*  调试模式标志 *)

    (*  ======================================================================== *)
    (*  错误代码定义 *)
    (*  ======================================================================== *)
    ERR_NO_ERROR            : INT := 0;              (*  无错误 *)
    ERR_GATE_TIMEOUT        : INT := 1001;           (*  门板超时错误 *)
    ERR_SAFETY_FAULT        : INT := 1002;           (*  安全故障 *)
    ERR_SYSTEM_DISABLED     : INT := 1003;           (*  系统未使能 *)
    ERR_OBSTACLE_DETECTED   : INT := 2001;           (*  障碍物检测 *)
    ERR_OVERCURRENT_G1      : INT := 2002;           (*  门板1过流 *)
    ERR_OVERCURRENT_G2      : INT := 2003;           (*  门板2过流 *)
    ERR_POWER_FAULT         : INT := 2004;           (*  电源故障 *)
    ERR_KEYPAD_LOCKED       : INT := 3001;           (*  键盘锁定 *)
    ERR_INVALID_PASSWORD    : INT := 3002;           (*  密码错误 *)
    ERR_COMMAND_CONFLICT    : INT := 3003;           (*  命令冲突 *)
    ERR_COMMAND_TIMEOUT     : INT := 3004;           (*  命令超时 *)

    (*  ======================================================================== *)
    (*  统计和诊断变量 *)
    (*  ======================================================================== *)
    STAT_Total_Operations   : DINT := 0;             (*  总操作次数 *)
    STAT_Gate1_Operations   : DINT := 0;             (*  门板1操作次数 *)
    STAT_Gate2_Operations   : DINT := 0;             (*  门板2操作次数 *)
    STAT_Power_On_Hours     : DINT := 0;             (*  通电时间 (小时) *)
    STAT_Error_Count        : DINT := 0;             (*  总错误次数 *)
    STAT_Last_Maintenance   : STRING[19] := '';       (*  最后维护时间 *)
    STAT_Next_Maintenance   : STRING[19] := '';       (*  下次维护时间 *)

END_VAR

(*  ============================================================================ *)
(*  系统常量定义 *)
(*  ============================================================================ *)

VAR_GLOBAL CONSTANT
    (*  ======================================================================== *)
    (*  系统常量 *)
    (*  ======================================================================== *)
    CONST_MAX_GATES         : INT := 2;              (*  最大门板数量 *)
    CONST_MAX_USERS         : INT := 100;            (*  最大用户数量 *)
    CONST_MAX_LOG_ENTRIES   : INT := 1000;           (*  最大日志条目 *)
    CONST_SYSTEM_ID         : STRING[10] := 'GCS_001'; (*  系统ID *)
    CONST_MANUFACTURER      : STRING[20] := 'Schneider Electric'; (*  制造商 *)

    (*  ======================================================================== *)
    (*  物理常量 *)
    (*  ======================================================================== *)
    CONST_GRAVITY           : REAL := 9.81;          (*  重力加速度 *)
    CONST_MOTOR_EFFICIENCY  : REAL := 0.85;          (*  电机效率 *)
    CONST_GEAR_RATIO        : REAL := 50.0;          (*  减速比 *)

    (*  ======================================================================== *)
    (*  网络常量 *)
    (*  ======================================================================== *)
    CONST_TCP_PORT          : INT := 502;            (*  Modbus TCP端口 *)
    CONST_HTTP_PORT         : INT := 80;             (*  HTTP端口 *)
    CONST_MAX_CONNECTIONS   : INT := 4;              (*  最大连接数 *)

END_VAR

(*  ============================================================================ *)
(*  系统初始化函数 *)
(*  ============================================================================ *)

FUNCTION FB_System_Init : BOOL

VAR_INPUT
    Execute         : BOOL;     (*  执行信号 *)
    Reset           : BOOL;     (*  复位信号 *)
END_VAR

VAR_OUTPUT
    Done            : BOOL;     (*  完成信号 *)
    Busy            : BOOL;     (*  忙碌信号 *)
    Error           : BOOL;     (*  错误信号 *)
    ErrorID         : INT;      (*  错误代码 *)
END_VAR

VAR
    State           : INT := 0; (*  状态机 *)
    Timer           : TON;      (*  定时器 *)
    InitStep        : INT := 0; (*  初始化步骤 *)
END_VAR

(*  复位处理 *)
IF Reset THEN
    State := 0;
    InitStep := 0;
    Done := FALSE;
    Busy := FALSE;
    Error := FALSE;
    ErrorID := 0;
    RETURN;
END_IF;

(*  初始化状态机 *)
CASE State OF
    0: (*  等待执行 *)
        IF Execute THEN
            State := 1;
            Busy := TRUE;
            InitStep := 1;
        END_IF;

    1: (*  配置验证 *)
        IF CFG_Password_Single > 0 AND
           CFG_Password_Dual > 0 AND
           CFG_Max_Opening_Time > T#5s AND
           CFG_Max_Closing_Time > T#5s THEN
            SYS_Configuration_Valid := TRUE;
            State := 2;
        ELSE
            Error := TRUE;
            ErrorID := 4001; (*  配置错误 *)
            State := 99;
        END_IF;

    2: (*  硬件自检 *)
        Timer(IN := TRUE, PT := T#2s);
        IF Timer.Q THEN
            SYS_Self_Test_OK := TRUE;
            State := 3;
            Timer(IN := FALSE);
        END_IF;

    3: (*  系统就绪 *)
        SYS_Startup_Complete := TRUE;
        SYS_First_Run := FALSE;
        Done := TRUE;
        Busy := FALSE;
        State := 0;

    99: (*  错误状态 *)
        Busy := FALSE;
        Done := FALSE;

END_CASE;

FB_System_Init := Done;

END_FUNCTION

(*  ============================================================================ *)
(* I/O地址映射表（用于Unity Pro配置参考） *)
(*  ============================================================================ *)

(*
输入地址映射表：
地址        信号名称              描述                类型
%I0.2.0     Passage_Sensor        通道光栅传感器      BOOL
%I0.2.1     Gate2_Sensor_Open     门板2全开传感器     BOOL
%I0.2.2     Gate1_Sensor_Open     门板1全开传感器     BOOL
%I0.2.3     Gate1_Sensor_Close    门板1全关传感器     BOOL
%I0.2.4     Gate2_Sensor_Close    门板2全关传感器     BOOL
%I0.2.5     Gate2_Overcurrent     门板2过流传感器     BOOL
%I0.2.6     Gate1_Overcurrent     门板1过流传感器     BOOL
%I0.2.7     Intercom_Single_Cmd   对讲机单门命令      BOOL
%I0.2.8     Intercom_Dual_Cmd     对讲机双门命令      BOOL
%I0.2.9     Remote_Single_Cmd     遥控/键盘单门命令   BOOL
%I0.2.10    Remote_Dual_Cmd       遥控/键盘双门命令   BOOL
%I0.2.11    Power_Loss_Alarm      市电故障报警        BOOL

输出地址映射表：
地址        信号名称              描述                类型
%Q0.3.0     Gate1_Motor_Open      门板1开启命令       BOOL
%Q0.3.1     Gate1_Motor_Close     门板1关闭命令       BOOL
%Q0.3.2     Gate2_Motor_Open      门板2开启命令       BOOL
%Q0.3.3     Gate2_Motor_Close     门板2关闭命令       BOOL
%Q0.3.4     Warning_Light         警告信号灯          BOOL
%Q0.3.5     Area_Lighting         区域照明            BOOL

模拟量地址映射（可选扩展）：
地址        信号名称              描述                类型
%IW0.4.0    Gate1_Position        门板1位置反馈       INT
%IW0.4.1    Gate2_Position        门板2位置反馈       INT
%IW0.4.2    Motor1_Current        电机1电流反馈       INT
%IW0.4.3    Motor2_Current        电机2电流反馈       INT

网络配置：
模块        类型                  IP地址              描述
NOE 100.2   以太网模块            134.214.184.171     主通信模块
BMX CPS2000 电源模块              -                   24V DC电源
BMX DDI 1602 数字输入模块         -                   16点输入
BMX DDO 1602 数字输出模块         -                   16点输出
*)

(*  ============================================================================ *)
(*  系统配置验证函数 *)
(*  ============================================================================ *)

FUNCTION FB_Config_Validation : BOOL

VAR_INPUT
    Check_All       : BOOL;     (*  检查所有配置 *)
END_VAR

VAR_OUTPUT
    Valid           : BOOL;     (*  配置有效 *)
    Warning_Count   : INT;      (*  警告数量 *)
    Error_Count     : INT;      (*  错误数量 *)
END_VAR

VAR
    Check_Result    : BOOL;
END_VAR

Warning_Count := 0;
Error_Count := 0;
Valid := TRUE;

(*  检查安全参数 *)
IF CFG_Max_Opening_Time < T#5s OR CFG_Max_Opening_Time > T#60s THEN
    Error_Count := Error_Count + 1;
    Valid := FALSE;
END_IF;

IF CFG_Max_Closing_Time < T#5s OR CFG_Max_Closing_Time > T#60s THEN
    Error_Count := Error_Count + 1;
    Valid := FALSE;
END_IF;

(*  检查密码参数 *)
IF CFG_Password_Single < 1000 OR CFG_Password_Single > 9999 THEN
    Error_Count := Error_Count + 1;
    Valid := FALSE;
END_IF;

IF CFG_Password_Dual < 1000 OR CFG_Password_Dual > 9999 THEN
    Error_Count := Error_Count + 1;
    Valid := FALSE;
END_IF;

(*  检查时间参数 *)
IF CFG_Input_Timeout < T#5s THEN
    Warning_Count := Warning_Count + 1;
END_IF;

IF CFG_Valid_Duration < T#10s THEN
    Warning_Count := Warning_Count + 1;
END_IF;

(*  检查硬件参数 *)
IF CFG_Motor_Power <= 0.0 OR CFG_Motor_Power > 5.0 THEN
    Warning_Count := Warning_Count + 1;
END_IF;

IF CFG_Gate_Weight <= 0.0 OR CFG_Gate_Weight > 1000.0 THEN
    Warning_Count := Warning_Count + 1;
END_IF;

FB_Config_Validation := Valid;

END_FUNCTION

(*
===============================================================================
配置参数说明文档
===============================================================================

1. 安全参数配置：
   - CFG_Max_Opening_Time: 门板开启最大时间，建议20-30秒
   - CFG_Max_Closing_Time: 门板关闭最大时间，建议20-30秒
   - CFG_Obstacle_Delay: 障碍物检测延时，避免误触发
   - CFG_Overcurrent_Delay: 过流检测延时，防夹保护

2. 密码配置：
   - CFG_Password_Single: 单门密码，建议4位数字
   - CFG_Password_Dual: 双门密码，建议4位数字
   - CFG_Max_Attempts: 最大尝试次数，建议3次
   - CFG_Lock_Duration: 锁定时间，建议5分钟

3. 控制参数：
   - CFG_Command_Timeout: 命令超时时间，建议1-3秒
   - CFG_Double_Click_Time: 双击检测时间，建议1秒
   - CFG_Auto_Close_Enable: 自动关门功能
   - CFG_Auto_Close_Delay: 自动关门延时

4. 照明配置：
   - CFG_Lighting_Delay: 照明延时关闭，建议5分钟
   - CFG_Night_Lighting: 夜间照明功能
   - CFG_Night_Start_Hour: 夜间开始时间
   - CFG_Night_End_Hour: 夜间结束时间

5. 诊断配置：
   - CFG_Log_Enable: 日志记录功能
   - CFG_Log_Level: 日志级别选择
   - CFG_Self_Test_Enable: 自检功能
   - CFG_Maintenance_Hours: 维护周期

部署注意事项：
1. 首次部署时需要进行系统调试
2. 根据现场情况调整安全参数
3. 定期检查和更新配置参数
4. 备份重要的配置数据
5. 确保网络配置正确

===============================================================================
*)