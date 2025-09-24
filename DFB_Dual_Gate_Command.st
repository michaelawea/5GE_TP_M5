(*
===============================================================================
DFB: DB_Dual_Gate_Command - 双门命令逻辑控制模块
===============================================================================
功能描述：
- 处理双门遥控/键盘命令信号（cmd_v12_tele_digi）
- 根据两门的当前状态决定双门动作策略
- 输出两个门的开关命令给各自的Gate_Control DFB

双门控制逻辑：
- 两门全关状态：双门命令 → 两门开启
- 两门全开状态：双门命令 → 两门关闭
- 混合状态（一开一关）：双门命令 → 两门关闭（极限情况处理）
- 运动状态（任一门运动）：双门命令 → 两门关闭

输入参数：
- Enable: 使能信号
- cmd_v12_tele_digi: 双门遥控/键盘命令信号
- Gate1_State: 门1状态（0=关闭，1=开启中，2=开启，3=关闭中）
- Gate2_State: 门2状态（0=关闭，1=开启中，2=开启，3=关闭中）

输出参数：
- Gate1_Open_Command: 门1开门命令
- Gate1_Close_Command: 门1关门命令
- Gate2_Open_Command: 门2开门命令
- Gate2_Close_Command: 门2关门命令

作者: Claude Code Assistant
日期: 2025-09-24
版本: 1.0
===============================================================================
*)

FUNCTION_BLOCK DB_Dual_Gate_Command

VAR_INPUT
    Enable              : BOOL;     (* 使能信号 *)
    cmd_v12_tele_digi   : BOOL;     (* 双门遥控/键盘命令输入信号 *)
    Gate1_State         : INT;      (* 门1状态：0=关闭，1=开启中，2=开启，3=关闭中 *)
    Gate2_State         : INT;      (* 门2状态：0=关闭，1=开启中，2=开启，3=关闭中 *)
END_VAR

VAR_OUTPUT
    Gate1_Open_Command  : BOOL;     (* 门1开门命令输出 *)
    Gate1_Close_Command : BOOL;     (* 门1关门命令输出 *)
    Gate2_Open_Command  : BOOL;     (* 门2开门命令输出 *)
    Gate2_Close_Command : BOOL;     (* 门2关门命令输出 *)
END_VAR

VAR
    (* 边沿检测变量 *)
    cmd_prev            : BOOL := FALSE;    (* 命令信号前一状态 *)
    cmd_edge            : BOOL;             (* 命令信号上升沿 *)

    (* 门1状态判断 *)
    Gate1_Is_Open       : BOOL;     (* 门1处于开启状态 *)
    Gate1_Is_Closed     : BOOL;     (* 门1处于关闭状态 *)
    Gate1_Is_Moving     : BOOL;     (* 门1处于运动状态 *)

    (* 门2状态判断 *)
    Gate2_Is_Open       : BOOL;     (* 门2处于开启状态 *)
    Gate2_Is_Closed     : BOOL;     (* 门2处于关闭状态 *)
    Gate2_Is_Moving     : BOOL;     (* 门2处于运动状态 *)

    (* 双门组合状态 *)
    Both_Gates_Closed   : BOOL;     (* 两门都关闭 *)
    Both_Gates_Open     : BOOL;     (* 两门都开启 *)
    Mixed_State         : BOOL;     (* 混合状态（一开一关） *)
    Any_Gate_Moving     : BOOL;     (* 任一门在运动 *)
END_VAR

(* ============================================================================ *)
(* 边沿检测 *)
(* ============================================================================ *)

(* 检测双门命令信号的上升沿 *)
cmd_edge := cmd_v12_tele_digi AND NOT cmd_prev;
cmd_prev := cmd_v12_tele_digi;

(* ============================================================================ *)
(* 单门状态判断 *)
(* ============================================================================ *)

(* 门1状态判断 *)
Gate1_Is_Closed := (Gate1_State = 0);    (* 0=关闭 *)
Gate1_Is_Open := (Gate1_State = 2);      (* 2=开启 *)
Gate1_Is_Moving := (Gate1_State = 1) OR (Gate1_State = 3);  (* 1=开启中，3=关闭中 *)

(* 门2状态判断 *)
Gate2_Is_Closed := (Gate2_State = 0);    (* 0=关闭 *)
Gate2_Is_Open := (Gate2_State = 2);      (* 2=开启 *)
Gate2_Is_Moving := (Gate2_State = 1) OR (Gate2_State = 3);  (* 1=开启中，3=关闭中 *)

(* ============================================================================ *)
(* 双门组合状态判断 *)
(* ============================================================================ *)

(* 两门都关闭 *)
Both_Gates_Closed := Gate1_Is_Closed AND Gate2_Is_Closed;

(* 两门都开启 *)
Both_Gates_Open := Gate1_Is_Open AND Gate2_Is_Open;

(* 混合状态：一开一关（极限情况） *)
Mixed_State := (Gate1_Is_Open AND Gate2_Is_Closed) OR (Gate1_Is_Closed AND Gate2_Is_Open);

(* 任一门在运动 *)
Any_Gate_Moving := Gate1_Is_Moving OR Gate2_Is_Moving;

(* ============================================================================ *)
(* 双门命令逻辑处理 *)
(* ============================================================================ *)

(* 清除所有输出命令 *)
Gate1_Open_Command := FALSE;
Gate1_Close_Command := FALSE;
Gate2_Open_Command := FALSE;
Gate2_Close_Command := FALSE;

(* 只有在系统使能且检测到命令边沿时才处理 *)
IF Enable AND cmd_edge THEN

    IF Both_Gates_Closed THEN
        (* 两门全关状态：双门命令 → 两门开启 *)
        Gate1_Open_Command := TRUE;
        Gate2_Open_Command := TRUE;

    ELSIF Both_Gates_Open THEN
        (* 两门全开状态：双门命令 → 两门关闭 *)
        Gate1_Close_Command := TRUE;
        Gate2_Close_Command := TRUE;

    ELSIF Mixed_State THEN
        (* 混合状态（一开一关）：双门命令 → 两门关闭（极限情况处理） *)
        Gate1_Close_Command := TRUE;
        Gate2_Close_Command := TRUE;

    ELSIF Any_Gate_Moving THEN
        (* 运动状态（任一门运动）：双门命令 → 两门关闭 *)
        Gate1_Close_Command := TRUE;
        Gate2_Close_Command := TRUE;

    ELSE
        (* 未知状态：默认两门关闭 *)
        Gate1_Close_Command := TRUE;
        Gate2_Close_Command := TRUE;

    END_IF;

END_IF;

(* ============================================================================ *)
(* 系统未使能时的处理 *)
(* ============================================================================ *)

IF NOT Enable THEN
    Gate1_Open_Command := FALSE;
    Gate1_Close_Command := FALSE;
    Gate2_Open_Command := FALSE;
    Gate2_Close_Command := FALSE;
END_IF;

END_FUNCTION_BLOCK