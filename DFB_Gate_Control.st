(*
===============================================================================
DFB: DB_Gate_Control - 单门控制逻辑模块（安全增强版）
===============================================================================
功能描述：
- 控制单个门板的开关动作
- 管理门板状态（关闭/开启中/开启/关闭中/中间停止）
- 处理位置反馈和安全保护
- 支持紧急停止和手动控制
- 命令信号支持：
  - 静态状态转换：支持边沿或持续信号（兼容United_Control_Logic）
  - 运动状态转换：仅支持边沿信号（避免意外触发）
- Bar_Lumineuse安全响应：
  - 开门时检测到人：暂停，人离开后自动恢复
  - 关门时检测到人：停止，需重新发送命令

状态说明：
- 0: 关闭状态
- 1: 开启中（Bar_Lumineuse暂停可自动恢复）
- 2: 开启状态
- 3: 关闭中（Bar_Lumineuse停止需重新确认）
- 4: 中间停止状态（关门被Bar_Lumineuse中断）

输入参数：
- Enable: 使能信号
- Open_Cmd: 开门命令
- Close_Cmd: 关门命令
- Emergency_Stop: 紧急停止
- Sensor_Open: 全开位置传感器
- Sensor_Close: 全关位置传感器
- Overcurrent: 过流检测信号
- Bar_Lumineuse: 通道传感器

输出参数：
- Motor_Open: 开门电机输出
- Motor_Close: 关门电机输出
- Status_Opening: 正在开启状态
- Status_Closing: 正在关闭状态
- Status_Open: 全开状态
- Status_Closed: 全关状态
- Error: 故障指示

作者: Claude Code Assistant
日期: 2025-09-25
版本: 3.0 (安全增强版)
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
    Bar_Lumineuse   : BOOL;     (* 通道传感器：TRUE=检测到有人/物体 *)
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
    Gate_State_Out  : INT;      (* 调试：当前状态输出 *)
END_VAR

VAR
    (* 内部状态变量 *)
    Gate_State      : INT := 0; (* 门板状态：0=关闭，1=开启中，2=开启，3=关闭中 *)

    (* 边沿检测变量 *)
    Open_Cmd_Prev   : BOOL := FALSE;    (* 开门命令前一状态 *)
    Close_Cmd_Prev  : BOOL := FALSE;    (* 关门命令前一状态 *)
    Open_Edge       : BOOL;              (* 开门命令上升沿 *)
    Close_Edge      : BOOL;              (* 关门命令上升沿 *)

    (* 故障检测 *)
    Safety_Error    : BOOL;     (* 安全故障 *)
    Force_Stop      : BOOL;     (* 强制停止标志 *)

    (* Bar_Lumineuse处理变量 *)
    Movement_Paused : BOOL;      (* 运动暂停标志 *)
    Bar_Lumineuse_Prev : BOOL := FALSE;  (* Bar_Lumineuse前一状态 *)
END_VAR

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
(* 故障检测逻辑 *)
(* ============================================================================ *)

Safety_Error := NOT Emergency_Stop OR Overcurrent;

(* 总体故障状态 *)
Error := Safety_Error OR NOT Enable;

(* 故障代码生成 *)
IF Safety_Error THEN
    Error_Code := 1001;  (* 安全故障 *)
ELSIF NOT Enable THEN
    Error_Code := 1003;  (* 系统未使能 *)
ELSE
    Error_Code := 0;     (* 无故障 *)
END_IF;

(* 强制停止条件 *)
Force_Stop := Error OR Overcurrent;

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
        (* 支持脉冲（边沿）或持续信号 *)
        IF (Open_Edge OR (Open_Cmd AND Enable)) AND NOT Error AND NOT Bar_Lumineuse THEN
            Gate_State := 1;
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

        (* 电机控制：Bar_Lumineuse暂停，解除后自动恢复 *)
        IF Bar_Lumineuse THEN
            Motor_Open := FALSE;
            Movement_Paused := TRUE;
        ELSIF NOT Force_Stop THEN
            Motor_Open := TRUE;
            Movement_Paused := FALSE;
        ELSE
            Motor_Open := FALSE;
        END_IF;

        (* 状态转换：开启中 -> 开启 *)
        IF Sensor_Open THEN
            Gate_State := 2;
            Motor_Open := FALSE;
            Movement_Paused := FALSE;
        END_IF;

        (* 状态转换：开启中 -> 关闭中（遇到过流或关门命令） *)
        IF Overcurrent OR Close_Edge THEN
            Gate_State := 3;
            Motor_Open := FALSE;
            Movement_Paused := FALSE;
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
        (* 仅使用边沿检测，避免持续信号导致的意外触发 *)
        IF (Close_Edge OR Open_Edge) AND Enable AND NOT Error AND NOT Bar_Lumineuse THEN
            Gate_State := 3;
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

        (* 电机控制：Bar_Lumineuse停止，需重新发送命令 *)
        IF Bar_Lumineuse THEN
            Motor_Close := FALSE;
            Movement_Paused := TRUE;
            (* 关门时检测到人，转到停止状态，保持当前位置 *)
            Gate_State := 4;  (* 转到中间停止状态 *)
        ELSIF NOT Force_Stop THEN
            Motor_Close := TRUE;
            Movement_Paused := FALSE;
        ELSE
            Motor_Close := FALSE;
        END_IF;

        (* 状态转换：关闭中 -> 关闭 *)
        IF Sensor_Close THEN
            Gate_State := 0;
            Motor_Close := FALSE;
            Movement_Paused := FALSE;
        END_IF;

        (* 状态转换：关闭中 -> 开启中（遇到过流或开门命令） *)
        IF Overcurrent OR Open_Edge THEN
            Gate_State := 1;
            Motor_Close := FALSE;
            Movement_Paused := FALSE;
        END_IF;

    4: (* 中间停止状态 - 关门时因Bar_Lumineuse停止 *)
        Status_Closed := FALSE;
        Status_Open := FALSE;
        Status_Opening := FALSE;
        Status_Closing := FALSE;
        Status_Unknown := TRUE;
        Motor_Open := FALSE;
        Motor_Close := FALSE;
        Movement_Paused := TRUE;

        (* 需要新的命令才能继续 *)
        (* 支持脉冲（边沿）或持续信号 *)
        IF (Open_Edge OR (Open_Cmd AND Enable)) AND NOT Error THEN
            Gate_State := 1;  (* 开门命令 -> 开启中 *)
            Movement_Paused := FALSE;
        ELSIF (Close_Edge OR (Close_Cmd AND Enable)) AND NOT Error AND NOT Bar_Lumineuse THEN
            Gate_State := 3;  (* 关门命令且无障碍 -> 关闭中 *)
            Movement_Paused := FALSE;
        END_IF;

    ELSE (* 未知状态，重置到关闭状态 *)
        Gate_State := 0;

END_CASE;

(* 输出当前状态用于调试 *)
Gate_State_Out := Gate_State;

(* ============================================================================ *)
(* 系统未使能时的处理 *)
(* ============================================================================ *)

IF NOT Enable THEN
    (* 系统未使能时停止所有电机 *)
    Motor_Open := FALSE;
    Motor_Close := FALSE;
    Status_Opening := FALSE;
    Status_Closing := FALSE;

    (* 只有在未使能时才检查位置并设置为未知 *)
    IF NOT (Sensor_Open OR Sensor_Close) THEN
        Status_Unknown := TRUE;
        Status_Open := FALSE;
        Status_Closed := FALSE;
    ELSE
        (* 根据传感器设置正确状态 *)
        Status_Open := Sensor_Open;
        Status_Closed := Sensor_Close;
        Status_Unknown := FALSE;
    END_IF;
END_IF;

END_FUNCTION_BLOCK