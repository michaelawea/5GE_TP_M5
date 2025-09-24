(*
===============================================================================
DFB: DB_Gate_Control - 单门控制逻辑模块
===============================================================================
功能描述：
- 控制单个门板的开关动作
- 管理门板状态（关闭/开启中/开启/关闭中）
- 处理位置反馈和安全保护
- 支持紧急停止和手动控制

输入参数：
- Enable: 使能信号
- Open_Cmd: 开门命令
- Close_Cmd: 关门命令
- Emergency_Stop: 紧急停止
- Sensor_Open: 全开位置传感器
- Sensor_Close: 全关位置传感器
- Overcurrent: 过流检测信号

输出参数：
- Motor_Open: 开门电机输出
- Motor_Close: 关门电机输出
- Status_Opening: 正在开启状态
- Status_Closing: 正在关闭状态
- Status_Open: 全开状态
- Status_Closed: 全关状态
- Error: 故障指示

作者: Claude Code Assistant
日期: 2025-09-23
版本: 1.0
===============================================================================
*)

FUNCTION_BLOCK DB_Gate_Control

VAR_INPUT
    Enable          : BOOL;     (* 使能信号 *)
    Open_Cmd        : BOOL;     (* 开门命令 *)
    Close_Cmd       : BOOL;     (* 关门命令 *)
    Emergency_Stop  : BOOL;     (* 紧急停止信号（常闭触点，TRUE=正常） *)
    Sensor_Open     : BOOL;     (* 全开位置传感器 *)
    Sensor_Close    : BOOL;     (* 全关位置传感器 *)
    Overcurrent     : BOOL;     (* 过流检测信号 *)
    Max_Open_Time   : TIME := T#30s;   (* 最大开门时间 *)
    Max_Close_Time  : TIME := T#30s;   (* 最大关门时间 *)
END_VAR

VAR_OUTPUT
    Motor_Open      : BOOL;     (* 开门电机输出 *)
    Motor_Close     : BOOL;     (* 关门电机输出 *)
    Status_Opening  : BOOL;     (* 正在开启状态 *)
    Status_Closing  : BOOL;     (* 正在关闭状态 *)
    Status_Open     : BOOL;     (* 全开状态 *)
    Status_Closed   : BOOL;     (* 全关状态 *)
    Status_Unknown  : BOOL;     (* 位置未知状态 *)
    Error           : BOOL;     (* 故障指示 *)
    Error_Code      : INT;      (* 故障代码 *)
END_VAR

VAR
    (* 内部状态变量 *)
    Gate_State      : INT := 0; (* 门板状态：0=关闭，1=开启中，2=开启，3=关闭中 *)

    (* 边沿检测变量 - 替代R_TRIG *)
    Open_Cmd_Prev   : BOOL := FALSE;    (* 开门命令前一状态 *)
    Close_Cmd_Prev  : BOOL := FALSE;    (* 关门命令前一状态 *)
    Open_Edge       : BOOL;              (* 开门命令上升沿 *)
    Close_Edge      : BOOL;              (* 关门命令上升沿 *)

    (* 定时器变量 - 替代TON *)
    Open_Timer_Enable  : BOOL := FALSE;  (* 开门定时器使能 *)
    Open_Timer_Start   : TIME;           (* 开门定时器起始时间 *)
    Open_Timer_Elapsed : TIME;           (* 开门已用时间 *)
    Open_Timer_Q       : BOOL := FALSE;  (* 开门超时标志 *)

    Close_Timer_Enable : BOOL := FALSE;  (* 关门定时器使能 *)
    Close_Timer_Start  : TIME;           (* 关门定时器起始时间 *)
    Close_Timer_Elapsed: TIME;           (* 关门已用时间 *)
    Close_Timer_Q      : BOOL := FALSE;  (* 关门超时标志 *)

    (* 系统时间变量 *)
    Current_Time    : TIME;              (* 当前系统时间 *)

    (* 故障检测 *)
    Timeout_Error   : BOOL;     (* 超时故障 *)
    Safety_Error    : BOOL;     (* 安全故障 *)

    (* 内部标志 *)
    Start_Opening   : BOOL;     (* 开始开门标志 *)
    Start_Closing   : BOOL;     (* 开始关门标志 *)
    Force_Stop      : BOOL;     (* 强制停止标志 *)
END_VAR

(* ============================================================================ *)
(* 获取系统时间 - 实际应用中需要连接系统时钟 *)
(* ============================================================================ *)
Current_Time := TIME();  (* 需要在实际PLC中映射到系统时间 *)

(* ============================================================================ *)
(* 边沿检测实现 *)
(* ============================================================================ *)

(* 开门命令边沿检测 *)
Open_Edge := Open_Cmd AND NOT Open_Cmd_Prev;
Open_Cmd_Prev := Open_Cmd;

(* 关门命令边沿检测 *)
Close_Edge := Close_Cmd AND NOT Close_Cmd_Prev;
Close_Cmd_Prev := Close_Cmd;

(* ============================================================================ *)
(* 定时器实现 - 开门定时器 *)
(* ============================================================================ *)

IF Status_Opening THEN
    IF NOT Open_Timer_Enable THEN
        (* 定时器启动 *)
        Open_Timer_Enable := TRUE;
        Open_Timer_Start := Current_Time;
        Open_Timer_Q := FALSE;
    ELSE
        (* 计算已用时间 *)
        Open_Timer_Elapsed := Current_Time - Open_Timer_Start;
        (* 检查超时 *)
        IF Open_Timer_Elapsed >= Max_Open_Time THEN
            Open_Timer_Q := TRUE;
        END_IF;
    END_IF;
ELSE
    (* 复位定时器 *)
    Open_Timer_Enable := FALSE;
    Open_Timer_Q := FALSE;
    Open_Timer_Elapsed := T#0s;
END_IF;

(* ============================================================================ *)
(* 定时器实现 - 关门定时器 *)
(* ============================================================================ *)

IF Status_Closing THEN
    IF NOT Close_Timer_Enable THEN
        (* 定时器启动 *)
        Close_Timer_Enable := TRUE;
        Close_Timer_Start := Current_Time;
        Close_Timer_Q := FALSE;
    ELSE
        (* 计算已用时间 *)
        Close_Timer_Elapsed := Current_Time - Close_Timer_Start;
        (* 检查超时 *)
        IF Close_Timer_Elapsed >= Max_Close_Time THEN
            Close_Timer_Q := TRUE;
        END_IF;
    END_IF;
ELSE
    (* 复位定时器 *)
    Close_Timer_Enable := FALSE;
    Close_Timer_Q := FALSE;
    Close_Timer_Elapsed := T#0s;
END_IF;

(* ============================================================================ *)
(* 故障检测逻辑 *)
(* ============================================================================ *)

Safety_Error := NOT Emergency_Stop OR Overcurrent;

(* 超时检测 *)
Timeout_Error := (Open_Timer_Q AND Status_Opening) OR
                 (Close_Timer_Q AND Status_Closing);

(* 总体故障状态 *)
Error := Safety_Error OR Timeout_Error OR NOT Enable;

(* 故障代码生成 *)
IF Safety_Error THEN
    Error_Code := 1001;  (* 安全故障 *)
ELSIF Timeout_Error THEN
    Error_Code := 1002;  (* 超时故障 *)
ELSIF NOT Enable THEN
    Error_Code := 1003;  (* 系统未使能 *)
ELSE
    Error_Code := 0;     (* 无故障 *)
END_IF;

(* 强制停止条件 *)
Force_Stop := Error OR (Overcurrent AND (Status_Opening OR Status_Closing));

(* ============================================================================ *)
(* 主状态机逻辑 *)
(* ============================================================================ *)

CASE Gate_State OF

    0: (* 关闭状态 *)
        Status_Closed := TRUE;
        Status_Open := FALSE;
        Status_Opening := FALSE;
        Status_Closing := FALSE;
        Status_Unknown := FALSE;
        Motor_Open := FALSE;
        Motor_Close := FALSE;

        (* 状态转换：关闭 -> 开启中 *)
        IF Open_Edge AND Enable AND NOT Error THEN
            Gate_State := 1;
            Start_Opening := TRUE;
        END_IF;

        (* 确认关闭位置 *)
        IF NOT Sensor_Close THEN
            Status_Unknown := TRUE;
        END_IF;

    1: (* 开启中状态 *)
        Status_Closed := FALSE;
        Status_Open := FALSE;
        Status_Opening := TRUE;
        Status_Closing := FALSE;
        Status_Unknown := FALSE;
        Motor_Close := FALSE;

        (* 电机控制 *)
        IF NOT Force_Stop THEN
            Motor_Open := TRUE;
        ELSE
            Motor_Open := FALSE;
        END_IF;

        (* 状态转换：开启中 -> 开启 *)
        IF Sensor_Open THEN
            Gate_State := 2;
            Motor_Open := FALSE;
        END_IF;

        (* 状态转换：开启中 -> 关闭中（遇到障碍物或关门命令） *)
        IF Force_Stop OR Close_Edge THEN
            Gate_State := 3;
            Start_Closing := TRUE;
            Motor_Open := FALSE;
        END_IF;

        (* 超时处理 *)
        IF Open_Timer_Q THEN
            Gate_State := 2; (* 假设已开启（传感器可能故障） *)
            Motor_Open := FALSE;
        END_IF;

    2: (* 开启状态 *)
        Status_Closed := FALSE;
        Status_Open := TRUE;
        Status_Opening := FALSE;
        Status_Closing := FALSE;
        Status_Unknown := FALSE;
        Motor_Open := FALSE;
        Motor_Close := FALSE;

        (* 状态转换：开启 -> 关闭中 *)
        IF (Close_Edge OR Open_Edge) AND Enable AND NOT Error THEN
            Gate_State := 3;
            Start_Closing := TRUE;
        END_IF;

        (* 确认开启位置 *)
        IF NOT Sensor_Open THEN
            Status_Unknown := TRUE;
        END_IF;

    3: (* 关闭中状态 *)
        Status_Closed := FALSE;
        Status_Open := FALSE;
        Status_Opening := FALSE;
        Status_Closing := TRUE;
        Status_Unknown := FALSE;
        Motor_Open := FALSE;

        (* 电机控制 *)
        IF NOT Force_Stop THEN
            Motor_Close := TRUE;
        ELSE
            Motor_Close := FALSE;
        END_IF;

        (* 状态转换：关闭中 -> 关闭 *)
        IF Sensor_Close THEN
            Gate_State := 0;
            Motor_Close := FALSE;
        END_IF;

        (* 状态转换：关闭中 -> 开启中（遇到障碍物或开门命令） *)
        IF Force_Stop OR Open_Edge THEN
            Gate_State := 1;
            Start_Opening := TRUE;
            Motor_Close := FALSE;
        END_IF;

        (* 超时处理 *)
        IF Close_Timer_Q THEN
            Gate_State := 0; (* 假设已关闭（传感器可能故障） *)
            Motor_Close := FALSE;
        END_IF;

    ELSE (* 未知状态，重置到关闭状态 *)
        Gate_State := 0;

END_CASE;

(* 重置启动标志 *)
Start_Opening := FALSE;
Start_Closing := FALSE;

(* ============================================================================ *)
(* 系统未使能时的处理 *)
(* ============================================================================ *)

IF NOT Enable THEN
    Motor_Open := FALSE;
    Motor_Close := FALSE;
    Status_Opening := FALSE;
    Status_Closing := FALSE;

    (* 保持位置状态，但标记为未知 *)
    IF NOT (Sensor_Open OR Sensor_Close) THEN
        Status_Unknown := TRUE;
        Status_Open := FALSE;
        Status_Closed := FALSE;
    END_IF;
END_IF;

END_FUNCTION_BLOCK