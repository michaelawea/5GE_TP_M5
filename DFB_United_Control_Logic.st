(*
===============================================================================
DFB: DB_United_Control_Logic - 统一门控制命令逻辑模块
===============================================================================
功能描述：
- 统一处理单门和双门的命令逻辑
- 处理遥控/键盘命令（cmd_v1_tele_digi, cmd_v12_tele_digi）
- 处理对讲命令（cmd_v1_interphone, cmd_v12_interphone）
- 根据Gate_Control DFB的状态输出相应的开关命令
- 实现安全保护功能（通道检测、过流保护）
- 控制辅助设备（警告灯、区域照明）

控制逻辑：
单门模式（V1）：
- 门关状态 + 单门命令 → 输出门1开启命令
- 门开状态 + 单门命令 → 输出门1关闭命令
- 门开启中 + 单门命令 → 持续输出开启命令（支持Bar_Lumineuse暂停恢复）
- 门关闭中 + 单门命令 → 输出关闭命令（Bar_Lumineuse时停止输出）
- 门中间停止（状态4）+ 单门命令 → 输出开启命令（恢复运动）

双门模式（V12）：
- 两门全关 + 双门命令 → 输出两门开启命令（先门1后门2，延时1000周期）
- 两门全开 + 双门命令 → 输出两门关闭命令（先门2后门1，延时1000周期）

安全功能：
- Bar_Lumineuse=TRUE：传递给Gate_Control处理
  - 开门时：暂停，人离开后自动恢复
  - 关门时：停止，需重新发送命令
- Overcurrent=TRUE：检测到过流（防夹），立即停止所有门运动
- 警告灯在运动、过流或检测到人时点亮

优先级：
1. 系统未使能（最高）
2. 过流保护（Safety_Stop）
3. 用户命令（最低）
注：Bar_Lumineuse由Gate_Control内部处理

输入参数：
- Enable: 系统使能信号
- cmd_v1_tele_digi: 单门遥控/键盘命令
- cmd_v12_tele_digi: 双门遥控/键盘命令
- cmd_v1_interphone: 单门对讲命令
- cmd_v12_interphone: 双门对讲命令
- Gate1_State: 门1状态（来自Gate_Control DFB）
- Gate2_State: 门2状态（来自Gate_Control DFB）
- Bar_Lumineuse: 通道传感器
- Capt_Surintens_V1: 门1过流传感器
- Capt_Surintens_V2: 门2过流传感器

输出参数：
- Open_Command_V1: 门1开启命令输出
- Close_Command_V1: 门1关闭命令输出
- Open_Command_V2: 门2开启命令输出
- Close_Command_V2: 门2关闭命令输出
- Warning_Light: 警告灯输出
- Area_Light: 区域照明输出

作者: Claude Code Assistant
日期: 2025-09-25
版本: 3.2 (修复状态4处理逻辑版)
===============================================================================
*)

FUNCTION_BLOCK DB_United_Control_Logic

VAR_INPUT
    Enable              : BOOL;     (* 系统使能信号 *)

    (* 命令输入信号 *)
    cmd_v1_tele_digi    : BOOL;     (* 单门遥控/键盘命令 *)
    cmd_v12_tele_digi   : BOOL;     (* 双门遥控/键盘命令 *)
    cmd_v1_interphone   : BOOL;     (* 单门对讲命令 *)
    cmd_v12_interphone  : BOOL;     (* 双门对讲命令 *)

    (* 门状态输入（来自Gate_Control DFB） *)
    Gate1_State         : INT;      (* 门1状态：0=关闭，1=开启中，2=开启，3=关闭中 *)
    Gate2_State         : INT;      (* 门2状态 *)

    (* 安全传感器输入 *)
    Bar_Lumineuse       : BOOL;     (* 通道传感器：TRUE=检测到有人/物体在移动区域 *)
    Capt_Surintens_V1   : BOOL;     (* 门1过流传感器：TRUE=门1电机过流 *)
    Capt_Surintens_V2   : BOOL;     (* 门2过流传感器：TRUE=门2电机过流 *)
END_VAR

VAR_OUTPUT
    (* 门控制命令输出 *)
    Open_Command_V1     : BOOL;     (* 门1开启命令输出 *)
    Close_Command_V1    : BOOL;     (* 门1关闭命令输出 *)
    Open_Command_V2     : BOOL;     (* 门2开启命令输出 *)
    Close_Command_V2    : BOOL;     (* 门2关闭命令输出 *)

    (* 辅助设备输出 *)
    Warning_Light       : BOOL;     (* 警告灯输出 *)
    Area_Light          : BOOL;     (* 区域照明输出 *)
END_VAR

VAR
    (* 命令合并信号 *)
    cmd_v1_combined     : BOOL;     (* 单门命令合并（遥控+对讲） *)
    cmd_v12_combined    : BOOL;     (* 双门命令合并（遥控+对讲） *)

    (* 边沿检测变量 *)
    cmd_v1_prev         : BOOL := FALSE;
    cmd_v12_prev        : BOOL := FALSE;
    cmd_v1_edge         : BOOL;
    cmd_v12_edge        : BOOL;

    (* 状态判断变量 *)
    Gate1_Is_Open       : BOOL;
    Gate1_Is_Closed     : BOOL;
    Gate1_Is_Moving     : BOOL;
    Gate2_Is_Open       : BOOL;
    Gate2_Is_Closed     : BOOL;
    Gate2_Is_Moving     : BOOL;

    (* 双门组合状态 *)
    Both_Gates_Closed   : BOOL;
    Both_Gates_Open     : BOOL;
    Any_Gate_Moving     : BOOL;

    (* 双门延时控制 *)
    Dual_Open_Counter     : INT := 0;        (* 双门开启延时计数器 *)
    Dual_Close_Counter    : INT := 0;        (* 双门关闭延时计数器 *)
    Delay_Cycles          : INT := 1000;     (* 延时周期数：1000个周期 *)

    (* 双门命令状态 *)
    Dual_Open_Active      : BOOL;     (* 双门开启过程激活 *)
    Dual_Close_Active     : BOOL;     (* 双门关闭过程激活 *)

    (* 延时完成标志 *)
    Dual_Open_Delay_Done  : BOOL;     (* 双门开启延时完成 *)
    Dual_Close_Delay_Done : BOOL;     (* 双门关闭延时完成 *)

    (* 安全控制变量 *)
    Movement_Blocked      : BOOL;     (* 移动被阻塞（通道有人） *)
    Overcurrent_Detected  : BOOL;     (* 检测到过流 *)
    Safety_Stop          : BOOL;     (* 安全停止标志 *)
END_VAR

(* ============================================================================ *)
(* 命令信号合并处理 *)
(* ============================================================================ *)

(* 单门命令合并：遥控/键盘 OR 对讲 *)
cmd_v1_combined := cmd_v1_tele_digi OR cmd_v1_interphone;

(* 双门命令合并：遥控/键盘 OR 对讲 *)
cmd_v12_combined := cmd_v12_tele_digi OR cmd_v12_interphone;

(* ============================================================================ *)
(* 边沿检测 *)
(* ============================================================================ *)

(* 单门命令边沿检测 *)
cmd_v1_edge := cmd_v1_combined AND NOT cmd_v1_prev;
cmd_v1_prev := cmd_v1_combined;

(* 双门命令边沿检测 *)
cmd_v12_edge := cmd_v12_combined AND NOT cmd_v12_prev;
cmd_v12_prev := cmd_v12_combined;


(* ============================================================================ *)
(* 门状态判断（基于输入的Gate_State） *)
(* ============================================================================ *)

(* 门1状态判断 *)
Gate1_Is_Closed := (Gate1_State = 0);    (* 0=关闭 *)
Gate1_Is_Open := (Gate1_State = 2);      (* 2=开启 *)
Gate1_Is_Moving := (Gate1_State = 1) OR (Gate1_State = 3);  (* 1=开启中，3=关闭中 *)

(* 门2状态判断 *)
Gate2_Is_Closed := (Gate2_State = 0);    (* 0=关闭 *)
Gate2_Is_Open := (Gate2_State = 2);      (* 2=开启 *)
Gate2_Is_Moving := (Gate2_State = 1) OR (Gate2_State = 3);  (* 1=开启中，3=关闭中 *)

(* 双门组合状态 *)
Both_Gates_Closed := Gate1_Is_Closed AND Gate2_Is_Closed;
Both_Gates_Open := Gate1_Is_Open AND Gate2_Is_Open;
Any_Gate_Moving := Gate1_Is_Moving OR Gate2_Is_Moving OR (Gate1_State = 4) OR (Gate2_State = 4);

(* ============================================================================ *)
(* 安全检测和处理（最高优先级） *)
(* ============================================================================ *)

(* 检测通道是否有人/物体 - 现在由Gate_Control直接处理 *)
Movement_Blocked := Bar_Lumineuse;

(* 检测过流（防夹/受阻） *)
Overcurrent_Detected := Capt_Surintens_V1 OR Capt_Surintens_V2;

(* 安全停止条件：仅过流时停止（Bar_Lumineuse由Gate_Control处理） *)
Safety_Stop := Overcurrent_Detected;

(* ============================================================================ *)
(* 命令逻辑处理（死逻辑版本，无边沿检测） *)
(* ============================================================================ *)

(* 初始化清除所有输出命令 *)
Open_Command_V1 := FALSE;
Close_Command_V1 := FALSE;
Open_Command_V2 := FALSE;
Close_Command_V2 := FALSE;

(* 只有在系统使能且没有安全停止时才处理 *)
IF Enable AND NOT Safety_Stop THEN

    (* 单门命令处理（直接响应信号） *)
    IF cmd_v1_combined AND NOT Dual_Open_Active AND NOT Dual_Close_Active THEN
        IF Gate1_Is_Closed THEN
            (* 门1关闭状态：发出开门命令 *)
            Open_Command_V1 := TRUE;
        ELSIF Gate1_Is_Open THEN
            (* 门1开启状态：发出关门命令 *)
            Close_Command_V1 := TRUE;
        ELSIF Gate1_State = 4 THEN
            (* 门1中间停止状态（关门被Bar_Lumineuse中断）：发出开门命令 *)
            Open_Command_V1 := TRUE;
        ELSIF Gate1_Is_Moving THEN
            (* 门1运动状态的智能处理 *)
            IF Gate1_State = 1 THEN
                (* 正在开启中：继续发送开门命令（即使Bar_Lumineuse阻塞） *)
                Open_Command_V1 := TRUE;
            ELSIF Gate1_State = 3 THEN
                (* 正在关闭中：继续发送关门命令（除非Bar_Lumineuse阻塞） *)
                IF NOT Bar_Lumineuse THEN
                    Close_Command_V1 := TRUE;
                END_IF;
            ELSE
                (* 其他运动状态：默认关门 *)
                Close_Command_V1 := TRUE;
            END_IF;
        ELSE
            (* 真正的未知状态：默认关门命令 *)
            Close_Command_V1 := TRUE;
        END_IF;
    END_IF;

    (* 双门命令处理（直接响应信号） *)
    IF cmd_v12_combined AND NOT Dual_Open_Active AND NOT Dual_Close_Active THEN
        IF Both_Gates_Closed THEN
            (* 两门全关状态：启动双门开启过程 *)
            Dual_Open_Active := TRUE;
            Dual_Open_Counter := 0;       (* 重置计数器 *)
            Dual_Open_Delay_Done := FALSE;
        ELSIF Both_Gates_Open THEN
            (* 两门全开状态：启动双门关闭过程 *)
            Dual_Close_Active := TRUE;
            Dual_Close_Counter := 0;      (* 重置计数器 *)
            Dual_Close_Delay_Done := FALSE;
        END_IF;
    END_IF;

END_IF;

(* 安全停止时立即停止所有正在进行的操作 *)
IF Safety_Stop THEN
    (* 重置所有双门控制状态 *)
    Dual_Open_Active := FALSE;
    Dual_Close_Active := FALSE;
    Dual_Open_Counter := 0;
    Dual_Close_Counter := 0;
    Dual_Open_Delay_Done := FALSE;
    Dual_Close_Delay_Done := FALSE;
END_IF;

(* ============================================================================ *)
(* 双门延时控制逻辑（死逻辑版本） *)
(* ============================================================================ *)

(* 双门开启过程控制：门关状态先1后2 *)
IF Dual_Open_Active AND NOT Safety_Stop THEN
    (* 立即启动门1 *)
    Open_Command_V1 := TRUE;

    (* 延时计数器递增 *)
    IF Dual_Open_Counter < Delay_Cycles THEN
        Dual_Open_Counter := Dual_Open_Counter + 1;
        Dual_Open_Delay_Done := FALSE;
    ELSE
        Dual_Open_Delay_Done := TRUE;
    END_IF;

    (* 延时完成后启动门2 *)
    IF Dual_Open_Delay_Done THEN
        Open_Command_V2 := TRUE;
    END_IF;

    (* 重置条件：没有双门命令信号时重置 *)
    IF NOT cmd_v12_combined THEN
        Dual_Open_Active := FALSE;
        Dual_Open_Counter := 0;
        Dual_Open_Delay_Done := FALSE;
    END_IF;
END_IF;

(* 双门关闭过程控制：门开状态先2后1 *)
IF Dual_Close_Active AND NOT Safety_Stop THEN
    (* 立即启动门2 *)
    Close_Command_V2 := TRUE;

    (* 延时计数器递增 *)
    IF Dual_Close_Counter < Delay_Cycles THEN
        Dual_Close_Counter := Dual_Close_Counter + 1;
        Dual_Close_Delay_Done := FALSE;
    ELSE
        Dual_Close_Delay_Done := TRUE;
    END_IF;

    (* 延时完成后启动门1 *)
    IF Dual_Close_Delay_Done THEN
        Close_Command_V1 := TRUE;
    END_IF;

    (* 重置条件：没有双门命令信号时重置 *)
    IF NOT cmd_v12_combined THEN
        Dual_Close_Active := FALSE;
        Dual_Close_Counter := 0;
        Dual_Close_Delay_Done := FALSE;
    END_IF;
END_IF;

(* ============================================================================ *)
(* 辅助设备控制 *)
(* ============================================================================ *)

(* 警告灯控制：任一门运动时、过流或通道有人时点亮 *)
Warning_Light := Any_Gate_Moving OR Overcurrent_Detected OR Bar_Lumineuse;

(* 区域照明控制：暂时不管，保持原逻辑 *)
Area_Light := cmd_v1_combined OR cmd_v12_combined;

(* ============================================================================ *)
(* 系统未使能或安全停止时的最终处理 *)
(* ============================================================================ *)

IF NOT Enable THEN
    (* 系统未使能时关闭所有输出 *)
    Open_Command_V1 := FALSE;
    Close_Command_V1 := FALSE;
    Open_Command_V2 := FALSE;
    Close_Command_V2 := FALSE;
    Warning_Light := FALSE;
ELSIF Safety_Stop THEN
    (* 安全停止时停止所有门命令但保持警告灯 *)
    Open_Command_V1 := FALSE;
    Close_Command_V1 := FALSE;
    Open_Command_V2 := FALSE;
    Close_Command_V2 := FALSE;
    (* Warning_Light保持之前的逻辑：Safety_Stop时点亮 *)
END_IF;

END_FUNCTION_BLOCK