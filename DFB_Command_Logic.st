(*
===============================================================================
DFB: DB_Command_Logic - 命令逻辑转换模块
===============================================================================
功能描述：
- 将遥控/键盘输入信号转换为开门/关门命令
- 根据门的当前状态决定执行开门还是关门操作

逻辑规则：
- 门开状态时：cmd_v1_tele_digi=1 → 发出关门命令
- 门关状态时：cmd_v1_tele_digi=1 → 发出开门命令
- 门中间状态时：cmd_v1_tele_digi=1 → 发出关门命令

输入参数：
- cmd_v1_tele_digi: 遥控/键盘命令信号
- Gate_State: 门板状态（0=关闭，1=开启中，2=开启，3=关闭中）

输出参数：
- Open_Command: 开门命令输出
- Close_Command: 关门命令输出

作者: Claude Code Assistant
日期: 2025-09-24
版本: 1.0
===============================================================================
*)

FUNCTION_BLOCK DB_Command_Logic

VAR_INPUT
    Enable              : BOOL;     (* 使能信号 *)
    cmd_v1_tele_digi    : BOOL;     (* 遥控/键盘命令输入信号 *)
    Gate_State          : INT;      (* 门板状态：0=关闭，1=开启中，2=开启，3=关闭中 *)
END_VAR

VAR_OUTPUT
    Open_Command        : BOOL;     (* 开门命令输出 *)
    Close_Command       : BOOL;     (* 关门命令输出 *)
END_VAR

VAR
    (* 边沿检测变量 *)
    cmd_prev            : BOOL := FALSE;    (* 命令信号前一状态 *)
    cmd_edge            : BOOL;             (* 命令信号上升沿 *)

    (* 门状态判断 *)
    Gate_Is_Open        : BOOL;     (* 门处于开启状态 *)
    Gate_Is_Closed      : BOOL;     (* 门处于关闭状态 *)
    Gate_Is_Moving      : BOOL;     (* 门处于运动状态（中间状态） *)
END_VAR

(* ============================================================================ *)
(* 边沿检测 *)
(* ============================================================================ *)

(* 检测命令信号的上升沿 *)
cmd_edge := cmd_v1_tele_digi AND NOT cmd_prev;
cmd_prev := cmd_v1_tele_digi;

(* ============================================================================ *)
(* 门状态判断 *)
(* ============================================================================ *)

(* 根据Gate_State整型变量判断门的状态 *)
Gate_Is_Closed := (Gate_State = 0);    (* 0=关闭 *)
Gate_Is_Open := (Gate_State = 2);      (* 2=开启 *)
Gate_Is_Moving := (Gate_State = 1) OR (Gate_State = 3);  (* 1=开启中，3=关闭中 *)

(* ============================================================================ *)
(* 命令逻辑处理 *)
(* ============================================================================ *)

(* 清除输出命令 *)
Open_Command := FALSE;
Close_Command := FALSE;

(* 只有在系统使能且检测到命令边沿时才处理 *)
IF Enable AND cmd_edge THEN

    (* 根据门的当前状态决定输出命令 *)
    IF Gate_Is_Open THEN
        (* 门开状态时：发出关门命令 *)
        Close_Command := TRUE;

    ELSIF Gate_Is_Closed THEN
        (* 门关状态时：发出开门命令 *)
        Open_Command := TRUE;

    ELSIF Gate_Is_Moving THEN
        (* 门中间状态时：发出关门命令 *)
        Close_Command := TRUE;

    ELSE
        (* 未知状态时：默认发出关门命令 *)
        Close_Command := TRUE;

    END_IF;

END_IF;

(* ============================================================================ *)
(* 系统未使能时的处理 *)
(* ============================================================================ *)

IF NOT Enable THEN
    Open_Command := FALSE;
    Close_Command := FALSE;
END_IF;

END_FUNCTION_BLOCK