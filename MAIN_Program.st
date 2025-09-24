(*
===============================================================================
主控制程序 - MAIN
===============================================================================
功能描述：
这是双摆门控制系统的主控制程序，集成了所有功能模块：
- 双门板控制（单门/双门模式）
- 多种控制方式（遥控器、键盘、对讲机）
- 安全保护系统
- 照明和信号灯控制
- 故障诊断和报警

系统架构：
1. 安全检测模块 (Safety_Check)
2. 密码验证模块 (Keypad_Validation)
3. 命令管理模块 (Command_Manager)
4. 门板控制模块 (Gate1_Control, Gate2_Control)
5. 辅助设备控制（照明、信号灯）

I/O地址映射（基于CLAUDE.md）：
输出：
- %Q0.3.0: 门板1开启命令
- %Q0.3.1: 门板1关闭命令
- %Q0.3.2: 门板2开启命令
- %Q0.3.3: 门板2关闭命令
- %Q0.3.4: 警告信号灯
- %Q0.3.5: 区域照明

输入：
- %I0.2.0: 通道光栅传感器
- %I0.2.1: 门板2全开传感器
- %I0.2.2: 门板1全开传感器
- %I0.2.3: 门板1全关传感器
- %I0.2.4: 门板2全关传感器
- %I0.2.5: 门板2过流传感器
- %I0.2.6: 门板1过流传感器
- %I0.2.7: 对讲机单门命令
- %I0.2.8: 对讲机双门命令
- %I0.2.9: 遥控/键盘单门命令
- %I0.2.10: 遥控/键盘双门命令
- %I0.2.11: 市电故障报警

作者: Claude Code Assistant
日期: 2025-09-23
版本: 1.0
===============================================================================
*)

PROGRAM MAIN

VAR
    (*  ======================================================================== *)
    (*  系统控制变量 *)
    (*  ======================================================================== *)
    System_Enable           : BOOL := TRUE;     (*  系统总使能 *)
    First_Scan              : BOOL := TRUE;     (*  首次扫描标志 *)
    System_Ready            : BOOL;             (*  系统就绪状态 *)
    Emergency_Stop_Global   : BOOL;             (*  全局紧急停止 *)

    (*  ======================================================================== *)
    (* I/O映射变量（根据CLAUDE.md配置） *)
    (*  ======================================================================== *)

    (*  输入信号映射 *)
    Passage_Sensor          AT %I0.2.0  : BOOL; (*  通道光栅传感器 *)
    Gate2_Sensor_Open       AT %I0.2.1  : BOOL; (*  门板2全开传感器 *)
    Gate1_Sensor_Open       AT %I0.2.2  : BOOL; (*  门板1全开传感器 *)
    Gate1_Sensor_Close      AT %I0.2.3  : BOOL; (*  门板1全关传感器 *)
    Gate2_Sensor_Close      AT %I0.2.4  : BOOL; (*  门板2全关传感器 *)
    Gate2_Overcurrent       AT %I0.2.5  : BOOL; (*  门板2过流传感器 *)
    Gate1_Overcurrent       AT %I0.2.6  : BOOL; (*  门板1过流传感器 *)
    Intercom_Single_Cmd     AT %I0.2.7  : BOOL; (*  对讲机单门命令 *)
    Intercom_Dual_Cmd       AT %I0.2.8  : BOOL; (*  对讲机双门命令 *)
    Remote_Single_Cmd       AT %I0.2.9  : BOOL; (* 遥控/键盘单门命令 *)
    Remote_Dual_Cmd         AT %I0.2.10 : BOOL; (* 遥控/键盘双门命令 *)
    Power_Loss_Alarm        AT %I0.2.11 : BOOL; (*  市电故障报警 *)

    (*  输出信号映射 *)
    Gate1_Motor_Open        AT %Q0.3.0  : BOOL; (*  门板1开启命令 *)
    Gate1_Motor_Close       AT %Q0.3.1  : BOOL; (*  门板1关闭命令 *)
    Gate2_Motor_Open        AT %Q0.3.2  : BOOL; (*  门板2开启命令 *)
    Gate2_Motor_Close       AT %Q0.3.3  : BOOL; (*  门板2关闭命令 *)
    Warning_Light           AT %Q0.3.4  : BOOL; (*  警告信号灯 *)
    Area_Lighting           AT %Q0.3.5  : BOOL; (*  区域照明 *)

    (*  ======================================================================== *)
    (*  功能模块实例 *)
    (*  ======================================================================== *)

    (*  安全检测模块 *)
    Safety_Check            : DB_Safety_Check;

    (*  密码验证模块 *)
    Keypad_Validation       : DB_Keypad_Validation;

    (*  命令管理模块 *)
    Command_Manager         : DB_Command_Manager;

    (*  门板控制模块 *)
    Gate1_Control           : DB_Gate_Control;
    Gate2_Control           : DB_Gate_Control;

    (*  ======================================================================== *)
    (*  键盘接口变量（模拟键盘输入，实际应用中需要硬件接口） *)
    (*  ======================================================================== *)
    Keypad_Key_0            : BOOL; (*  数字键0-9 *)
    Keypad_Key_1            : BOOL;
    Keypad_Key_2            : BOOL;
    Keypad_Key_3            : BOOL;
    Keypad_Key_4            : BOOL;
    Keypad_Key_5            : BOOL;
    Keypad_Key_6            : BOOL;
    Keypad_Key_7            : BOOL;
    Keypad_Key_8            : BOOL;
    Keypad_Key_9            : BOOL;
    Keypad_Key_Clear        : BOOL; (*  清除键* *)
    Keypad_Key_Enter        : BOOL; (*  确认键# *)

    (*  ======================================================================== *)
    (*  系统状态和诊断变量 *)
    (*  ======================================================================== *)
    System_Status           : INT;   (*  系统状态：0=停止，1=运行，2=故障 *)
    Total_Error_Count       : INT;   (*  总错误计数 *)
    Last_Operation_Time     : TIME;  (*  最后操作时间 *)
    Operation_Counter       : DINT;  (*  操作计数器 *)

    (*  ======================================================================== *)
    (*  照明和信号控制变量 *)
    (*  ======================================================================== *)
    Lighting_Timer          : TON;   (*  照明延时关闭定时器 *)
    Lighting_Delay          : TIME := T#5m;    (*  照明延时时间 *)
    Warning_Blink_Timer     : TOF;   (*  警告灯闪烁定时器 *)
    Warning_Blink_Cycle     : TIME := T#500ms; (*  闪烁周期 *)

    (*  ======================================================================== *)
    (*  内部连接变量 *)
    (*  ======================================================================== *)
    Safety_Status           : BOOL;  (*  安全状态 *)
    Command_Valid           : BOOL;  (*  命令有效 *)
    Gate1_Moving            : BOOL;  (*  门板1运动状态 *)
    Gate2_Moving            : BOOL;  (*  门板2运动状态 *)
    Any_Gate_Moving         : BOOL;  (*  任意门板运动 *)
    Keypad_Access_Single    : BOOL;  (*  键盘单门权限 *)
    Keypad_Access_Dual      : BOOL;  (*  键盘双门权限 *)
END_VAR

(*  ============================================================================ *)
(*  系统初始化 *)
(*  ============================================================================ *)

IF First_Scan THEN
    (*  系统启动初始化 *)
    System_Enable := TRUE;
    System_Status := 0; (*  系统停止状态 *)
    Total_Error_Count := 0;
    Operation_Counter := 0;

    (*  输出安全状态 *)
    Gate1_Motor_Open := FALSE;
    Gate1_Motor_Close := FALSE;
    Gate2_Motor_Open := FALSE;
    Gate2_Motor_Close := FALSE;
    Warning_Light := FALSE;
    Area_Lighting := FALSE;

    First_Scan := FALSE;
END_IF;

(*  ============================================================================ *)
(*  安全检测模块 *)
(*  ============================================================================ *)

Safety_Check(
    Enable := System_Enable,
    Passage_Sensor := Passage_Sensor,
    Overcurrent_V1 := Gate1_Overcurrent,
    Overcurrent_V2 := Gate2_Overcurrent,
    Power_Loss_Alarm := Power_Loss_Alarm,
    Gate1_Moving := Gate1_Moving,
    Gate2_Moving := Gate2_Moving,
    Safety_Reset := FALSE (*  可以连接到维护面板的复位按钮 *)
);

(*  获取安全状态 *)
Safety_Status := Safety_Check.Safe_To_Operate;
Emergency_Stop_Global := Safety_Check.Emergency_Stop;

(*  ============================================================================ *)
(*  密码验证模块（键盘接口） *)
(*  ============================================================================ *)

(*  注意：实际应用中需要通过FBD连接键盘扫描电路 *)
(*  这里提供了接口变量，需要在FBD中实现键盘扫描逻辑 *)

Keypad_Validation(
    Enable := System_Enable,
    Key_0 := Keypad_Key_0,
    Key_1 := Keypad_Key_1,
    Key_2 := Keypad_Key_2,
    Key_3 := Keypad_Key_3,
    Key_4 := Keypad_Key_4,
    Key_5 := Keypad_Key_5,
    Key_6 := Keypad_Key_6,
    Key_7 := Keypad_Key_7,
    Key_8 := Keypad_Key_8,
    Key_9 := Keypad_Key_9,
    Key_Clear := Keypad_Key_Clear,
    Key_Enter := Keypad_Key_Enter,
    Reset_Lock := FALSE (*  可以连接到管理员复位按钮 *)
);

(*  获取键盘访问权限 *)
Keypad_Access_Single := Keypad_Validation.Single_Gate_Access;
Keypad_Access_Dual := Keypad_Validation.Dual_Gate_Access;

(*  ============================================================================ *)
(*  命令管理模块 *)
(*  ============================================================================ *)

Command_Manager(
    Enable := System_Enable,
    (* 遥控器/键盘命令（通过权限验证） *)
    Remote_Single_Gate := Remote_Single_Cmd,
    Remote_Dual_Gate := Remote_Dual_Cmd,
    Keypad_Single_Gate := Keypad_Access_Single,
    Keypad_Dual_Gate := Keypad_Access_Dual,
    (*  对讲机命令（直接连接） *)
    Intercom_Single_Gate := Intercom_Single_Cmd,
    Intercom_Dual_Gate := Intercom_Dual_Cmd,
    (*  安全状态 *)
    Safety_OK := Safety_Status,
    Gate1_Status_Closed := Gate1_Control.Status_Closed,
    Gate1_Status_Open := Gate1_Control.Status_Open,
    Gate2_Status_Closed := Gate2_Control.Status_Closed,
    Gate2_Status_Open := Gate2_Control.Status_Open
);

(*  获取命令状态 *)
Command_Valid := Command_Manager.Command_Valid;

(*  ============================================================================ *)
(*  门板1控制模块 *)
(*  ============================================================================ *)

Gate1_Control(
    Enable := System_Enable,
    Open_Cmd := Command_Manager.Gate1_Open_Command,
    Close_Cmd := Command_Manager.Gate1_Close_Command,
    Emergency_Stop := NOT Emergency_Stop_Global,
    Sensor_Open := Gate1_Sensor_Open,
    Sensor_Close := Gate1_Sensor_Close,
    Overcurrent := Gate1_Overcurrent OR Safety_Check.Overcurrent_Gate1,
    Max_Open_Time := T#25s,
    Max_Close_Time := T#25s
);

(*  获取门板1状态 *)
Gate1_Moving := Gate1_Control.Status_Opening OR Gate1_Control.Status_Closing;

(*  ============================================================================ *)
(*  门板2控制模块 *)
(*  ============================================================================ *)

Gate2_Control(
    Enable := System_Enable,
    Open_Cmd := Command_Manager.Gate2_Open_Command,
    Close_Cmd := Command_Manager.Gate2_Close_Command,
    Emergency_Stop := NOT Emergency_Stop_Global,
    Sensor_Open := Gate2_Sensor_Open,
    Sensor_Close := Gate2_Sensor_Close,
    Overcurrent := Gate2_Overcurrent OR Safety_Check.Overcurrent_Gate2,
    Max_Open_Time := T#25s,
    Max_Close_Time := T#25s
);

(*  获取门板2状态 *)
Gate2_Moving := Gate2_Control.Status_Opening OR Gate2_Control.Status_Closing;

(*  ============================================================================ *)
(*  电机输出控制 *)
(*  ============================================================================ *)

(*  门板1电机控制（带安全保护） *)
IF System_Enable AND NOT Emergency_Stop_Global THEN
    Gate1_Motor_Open := Gate1_Control.Motor_Open;
    Gate1_Motor_Close := Gate1_Control.Motor_Close;

    (*  防夹保护：过流时反向 *)
    IF Safety_Check.Reverse_Gate1 THEN
        IF Gate1_Control.Status_Opening THEN
            Gate1_Motor_Open := FALSE;
            Gate1_Motor_Close := TRUE;
        ELSIF Gate1_Control.Status_Closing THEN
            Gate1_Motor_Close := FALSE;
            Gate1_Motor_Open := TRUE;
        END_IF;
    END_IF;
ELSE
    Gate1_Motor_Open := FALSE;
    Gate1_Motor_Close := FALSE;
END_IF;

(*  门板2电机控制（带安全保护） *)
IF System_Enable AND NOT Emergency_Stop_Global THEN
    Gate2_Motor_Open := Gate2_Control.Motor_Open;
    Gate2_Motor_Close := Gate2_Control.Motor_Close;

    (*  防夹保护：过流时反向 *)
    IF Safety_Check.Reverse_Gate2 THEN
        IF Gate2_Control.Status_Opening THEN
            Gate2_Motor_Open := FALSE;
            Gate2_Motor_Close := TRUE;
        ELSIF Gate2_Control.Status_Closing THEN
            Gate2_Motor_Close := FALSE;
            Gate2_Motor_Open := TRUE;
        END_IF;
    END_IF;
ELSE
    Gate2_Motor_Open := FALSE;
    Gate2_Motor_Close := FALSE;
END_IF;

(*  ============================================================================ *)
(*  警告信号灯控制 *)
(*  ============================================================================ *)

Any_Gate_Moving := Gate1_Moving OR Gate2_Moving;

(*  警告灯闪烁控制 *)
Warning_Blink_Timer(
    IN := Any_Gate_Moving,
    PT := Warning_Blink_Cycle
);

(*  门板运动时警告灯闪烁，故障时常亮 *)
IF Any_Gate_Moving THEN
    Warning_Light := NOT Warning_Blink_Timer.Q; (*  闪烁 *)
ELSIF Safety_Check.Emergency_Stop OR
      Gate1_Control.Error OR
      Gate2_Control.Error THEN
    Warning_Light := TRUE; (*  故障时常亮 *)
ELSE
    Warning_Light := FALSE;
END_IF;

(*  ============================================================================ *)
(*  区域照明控制 *)
(*  ============================================================================ *)

(*  照明延时关闭定时器 *)
Lighting_Timer(
    IN := NOT (Any_Gate_Moving OR Command_Manager.Command_Active),
    PT := Lighting_Delay
);

(*  照明控制逻辑：有活动时开启，延时后关闭 *)
IF Any_Gate_Moving OR
   Command_Manager.Command_Active OR
   Safety_Check.Obstacle_Detected THEN
    Area_Lighting := TRUE;
ELSIF Lighting_Timer.Q THEN
    Area_Lighting := FALSE;
END_IF;

(*  ============================================================================ *)
(*  系统状态管理和诊断 *)
(*  ============================================================================ *)

(*  计算系统状态 *)
IF NOT System_Enable THEN
    System_Status := 0; (*  系统停止 *)
ELSIF Safety_Check.Emergency_Stop OR
      Gate1_Control.Error OR
      Gate2_Control.Error OR
      Keypad_Validation.System_Locked THEN
    System_Status := 2; (*  系统故障 *)
ELSE
    System_Status := 1; (*  系统正常运行 *)
END_IF;

(*  系统就绪状态 *)
System_Ready := (System_Status = 1) AND NOT Any_Gate_Moving;

(*  错误计数统计 *)
IF Gate1_Control.Error OR
   Gate2_Control.Error OR
   Safety_Check.Emergency_Stop THEN
    Total_Error_Count := Total_Error_Count + 1;
    (*  防止计数溢出 *)
    IF Total_Error_Count > 9999 THEN
        Total_Error_Count := 0;
    END_IF;
END_IF;

(*  操作计数（每次门操作） *)
IF Command_Manager.Command_Active THEN
    Operation_Counter := Operation_Counter + 1;
    Last_Operation_Time := TIME(); (*  需要系统时间函数支持 *)
    (*  防止计数溢出 *)
    IF Operation_Counter > 999999 THEN
        Operation_Counter := 0;
    END_IF;
END_IF;

(*  ============================================================================ *)
(*  系统关闭处理 *)
(*  ============================================================================ *)

IF NOT System_Enable THEN
    (*  安全关闭所有输出 *)
    Gate1_Motor_Open := FALSE;
    Gate1_Motor_Close := FALSE;
    Gate2_Motor_Open := FALSE;
    Gate2_Motor_Close := FALSE;
    Warning_Light := FALSE;
    Area_Lighting := FALSE;
END_IF;

END_PROGRAM

(*
===============================================================================
FBD 连接说明
===============================================================================

在Unity Pro中，需要在FBD（功能块图）中实现以下硬件接口连接：

1. 键盘扫描模块：
   - 使用矩阵键盘扫描FFB
   - 连接Keypad_Key_0到Keypad_Key_9变量
   - 连接Keypad_Key_Clear和Keypad_Key_Enter变量

2. 通信模块：
   - 如需远程监控，可添加以太网通信FFB
   - 连接到NOE 100.2模块（IP: 134.214.184.171）
   - 实现远程诊断和控制接口

3. HMI接口：
   - 连接人机界面显示模块
   - 显示系统状态、错误代码、操作计数等
   - 提供手动控制和参数设置界面

4. 数据记录：
   - 可选添加数据记录FFB
   - 记录操作历史、故障日志等

使用方法：
1. 在Unity Pro中创建新项目
2. 导入各个DFB文件
3. 创建MAIN程序并粘贴上述代码
4. 在FBD中添加必要的硬件接口连接
5. 配置I/O地址映射
6. 编译并下载到PLC

===============================================================================
*)