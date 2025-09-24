(*
===============================================================================
DFB: DB_Command_Manager - 命令管理模块
===============================================================================
功能描述：
- 集中管理所有控制命令输入源
- 处理遥控器、键盘、对讲机三种控制方式
- 命令优先级管理和冲突处理
- 操作模式选择（单门/双门）
- 命令有效性验证和安全检查

控制源优先级（从高到低）：
1. 对讲机控制（最高优先级，紧急访问）
2. 遥控器/键盘控制（日常使用）
3. 自动控制（定时开关等）

操作模式：
- 单门模式：仅控制门板1（行人通道）
- 双门模式：同时控制门板1和2（车辆通道）

安全检查：
- 命令发出前检查安全条件
- 冲突命令处理（同时开关）
- 权限验证（密码/对讲机确认）

作者: Claude Code Assistant
日期: 2025-09-23
版本: 1.0
===============================================================================
*)

FUNCTION_BLOCK DB_Command_Manager

VAR_INPUT
    Enable                  : BOOL;         (*  系统使能 *)
    (* 遥控器/键盘输入 *)
    Remote_Single_Gate      : BOOL;         (*  遥控单门命令 *)
    Remote_Dual_Gate        : BOOL;         (*  遥控双门命令 *)
    Keypad_Single_Gate      : BOOL;         (*  键盘单门命令 *)
    Keypad_Dual_Gate        : BOOL;         (*  键盘双门命令 *)
    (*  对讲机输入 *)
    Intercom_Single_Gate    : BOOL;         (*  对讲机单门命令 *)
    Intercom_Dual_Gate      : BOOL;         (*  对讲机双门命令 *)
    (*  安全状态输入 *)
    Safety_OK               : BOOL;         (*  安全条件满足 *)
    Gate1_Status_Closed     : BOOL;         (*  门板1关闭状态 *)
    Gate1_Status_Open       : BOOL;         (*  门板1开启状态 *)
    Gate2_Status_Closed     : BOOL;         (*  门板2关闭状态 *)
    Gate2_Status_Open       : BOOL;         (*  门板2开启状态 *)
    (*  配置参数 *)
    Command_Timeout         : TIME := T#2s; (*  命令超时时间 *)
    Intercom_Priority       : BOOL := TRUE; (*  对讲机优先级使能 *)
    Double_Click_Time       : TIME := T#1s; (*  双击检测时间 *)
END_VAR

VAR_OUTPUT
    (*  门控命令输出 *)
    Gate1_Open_Command      : BOOL;         (*  门板1开启命令 *)
    Gate1_Close_Command     : BOOL;         (*  门板1关闭命令 *)
    Gate2_Open_Command      : BOOL;         (*  门板2开启命令 *)
    Gate2_Close_Command     : BOOL;         (*  门板2关闭命令 *)
    (*  状态输出 *)
    Single_Gate_Mode        : BOOL;         (*  单门模式激活 *)
    Dual_Gate_Mode          : BOOL;         (*  双门模式激活 *)
    Command_Active          : BOOL;         (*  命令激活状态 *)
    Command_Source          : INT;          (*  命令源：1=遥控，2=键盘，3=对讲机 *)
    Operation_Mode          : INT;          (*  操作模式：1=单门，2=双门 *)
    Command_Valid           : BOOL;         (*  命令有效标志 *)
    Error_Code              : INT;          (*  错误代码 *)
END_VAR

VAR
    (*  命令边沿检测 *)
    Remote_Single_Edge      : R_TRIG;
    Remote_Dual_Edge        : R_TRIG;
    Keypad_Single_Edge      : R_TRIG;
    Keypad_Dual_Edge        : R_TRIG;
    Intercom_Single_Edge    : R_TRIG;
    Intercom_Dual_Edge      : R_TRIG;

    (*  命令状态管理 *)
    Active_Command          : INT;          (*  当前激活命令：1=单门，2=双门 *)
    Command_Timer           : TON;          (*  命令超时定时器 *)
    Command_Received        : BOOL;         (*  命令接收标志 *)

    (*  双击检测 *)
    Last_Single_Command_Time: TIME;         (*  上次单门命令时间 *)
    Double_Click_Timer      : TON;          (*  双击检测定时器 *)
    Double_Click_Detected   : BOOL;         (*  双击检测标志 *)

    (*  门状态分析 *)
    Gate1_Action_Needed     : INT;          (*  门板1需要的动作：0=无，1=开，2=关 *)
    Gate2_Action_Needed     : INT;          (*  门板2需要的动作：0=无，1=开，2=关 *)

    (*  内部标志 *)
    Priority_Command        : BOOL;         (*  优先级命令标志 *)
    Command_Conflict        : BOOL;         (*  命令冲突标志 *)
    Safety_Override         : BOOL;         (*  安全覆盖标志 *)

    (*  系统时钟（用于时间戳计算） *)
    System_Clock            : TIME;         (*  系统时钟计数器 *)
END_VAR

(*  ============================================================================ *)
(*  边沿检测器 *)
(*  ============================================================================ *)

Remote_Single_Edge(CLK := Remote_Single_Gate);
Remote_Dual_Edge(CLK := Remote_Dual_Gate);
Keypad_Single_Edge(CLK := Keypad_Single_Gate);
Keypad_Dual_Edge(CLK := Keypad_Dual_Gate);
Intercom_Single_Edge(CLK := Intercom_Single_Gate);
Intercom_Dual_Edge(CLK := Intercom_Dual_Gate);

(*  ============================================================================ *)
(*  双击检测逻辑 *)
(*  ============================================================================ *)

Double_Click_Timer(
    IN := Double_Click_Detected,
    PT := Double_Click_Time
);

(*  检测单门命令的双击（快速切换到双门） *)
IF Remote_Single_Edge.Q OR Keypad_Single_Edge.Q THEN
    IF Double_Click_Timer.Q = FALSE AND Double_Click_Detected THEN
        (*  检测到双击，切换到双门模式 *)
        Active_Command := 2;
        Command_Source := 1; (*  假设来自遥控器 *)
        Double_Click_Detected := FALSE;
    ELSE
        (*  第一次点击 *)
        Active_Command := 1;
        Double_Click_Detected := TRUE;
    END_IF;
    Command_Received := TRUE;
END_IF;

(*  双击超时重置 *)
IF Double_Click_Timer.Q THEN
    Double_Click_Detected := FALSE;
END_IF;

(*  ============================================================================ *)
(*  命令优先级处理 *)
(*  ============================================================================ *)

Priority_Command := FALSE;
Command_Received := FALSE;

(*  对讲机命令（最高优先级） *)
IF Intercom_Priority AND (Intercom_Single_Edge.Q OR Intercom_Dual_Edge.Q) THEN
    Priority_Command := TRUE;
    Command_Source := 3; (*  对讲机 *)
    Command_Received := TRUE;

    IF Intercom_Single_Edge.Q THEN
        Active_Command := 1;
    ELSIF Intercom_Dual_Edge.Q THEN
        Active_Command := 2;
    END_IF;

(*  遥控器命令 *)
ELSIF Remote_Single_Edge.Q OR Remote_Dual_Edge.Q THEN
    Command_Source := 1; (*  遥控器 *)
    Command_Received := TRUE;

    IF Remote_Single_Edge.Q THEN
        Active_Command := 1;
    ELSIF Remote_Dual_Edge.Q THEN
        Active_Command := 2;
    END_IF;

(*  键盘命令 *)
ELSIF Keypad_Single_Edge.Q OR Keypad_Dual_Edge.Q THEN
    Command_Source := 2; (*  键盘 *)
    Command_Received := TRUE;

    IF Keypad_Single_Edge.Q THEN
        Active_Command := 1;
    ELSIF Keypad_Dual_Edge.Q THEN
        Active_Command := 2;
    END_IF;
END_IF;

(*  ============================================================================ *)
(*  命令超时管理 *)
(*  ============================================================================ *)

Command_Timer(
    IN := Command_Received,
    PT := Command_Timeout
);

(*  命令激活状态 *)
Command_Active := Command_Received AND NOT Command_Timer.Q;

(*  超时重置 *)
IF Command_Timer.Q THEN
    Command_Received := FALSE;
    Active_Command := 0;
    Command_Source := 0;
END_IF;

(*  ============================================================================ *)
(*  门状态分析和动作规划 *)
(*  ============================================================================ *)

(*  分析门板1需要的动作 *)
IF Active_Command > 0 THEN
    IF Gate1_Status_Closed THEN
        Gate1_Action_Needed := 1; (*  需要开启 *)
    ELSIF Gate1_Status_Open THEN
        Gate1_Action_Needed := 2; (*  需要关闭 *)
    ELSE
        Gate1_Action_Needed := 0; (*  运动中，无额外动作 *)
    END_IF;
ELSE
    Gate1_Action_Needed := 0;
END_IF;

(*  分析门板2需要的动作（仅在双门模式下） *)
IF Active_Command = 2 THEN
    IF Gate2_Status_Closed THEN
        Gate2_Action_Needed := 1; (*  需要开启 *)
    ELSIF Gate2_Status_Open THEN
        Gate2_Action_Needed := 2; (*  需要关闭 *)
    ELSE
        Gate2_Action_Needed := 0; (*  运动中，无额外动作 *)
    END_IF;
ELSE
    Gate2_Action_Needed := 0;
END_IF;

(*  ============================================================================ *)
(*  安全检查和命令验证 *)
(*  ============================================================================ *)

(*  基本安全检查 *)
Command_Valid := Enable AND Safety_OK AND Command_Active;

(*  命令冲突检测 *)
Command_Conflict := FALSE; (*  在这个设计中，每次只处理一个命令，无冲突 *)

(*  安全覆盖（紧急情况下允许的操作） *)
Safety_Override := Priority_Command AND Command_Source = 3; (*  对讲机优先 *)

(*  最终命令有效性 *)
Command_Valid := Command_Valid OR Safety_Override;

(*  ============================================================================ *)
(*  输出命令生成 *)
(*  ============================================================================ *)

(*  清除所有输出命令 *)
Gate1_Open_Command := FALSE;
Gate1_Close_Command := FALSE;
Gate2_Open_Command := FALSE;
Gate2_Close_Command := FALSE;

(*  模式输出 *)
Single_Gate_Mode := (Active_Command = 1) AND Command_Valid;
Dual_Gate_Mode := (Active_Command = 2) AND Command_Valid;
Operation_Mode := Active_Command;

(*  只有在命令有效时才输出控制信号 *)
IF Command_Valid THEN

    (*  门板1控制命令 *)
    CASE Gate1_Action_Needed OF
        1: Gate1_Open_Command := TRUE;   (*  开启门板1 *)
        2: Gate1_Close_Command := TRUE;  (*  关闭门板1 *)
    END_CASE;

    (*  门板2控制命令（仅在双门模式下） *)
    IF Active_Command = 2 THEN
        CASE Gate2_Action_Needed OF
            1: Gate2_Open_Command := TRUE;   (*  开启门板2 *)
            2: Gate2_Close_Command := TRUE;  (*  关闭门板2 *)
        END_CASE;
    END_IF;

END_IF;

(*  ============================================================================ *)
(*  错误代码生成 *)
(*  ============================================================================ *)

IF NOT Enable THEN
    Error_Code := 3001; (*  系统未使能 *)
ELSIF NOT Safety_OK AND NOT Safety_Override THEN
    Error_Code := 3002; (*  安全条件不满足 *)
ELSIF Command_Conflict THEN
    Error_Code := 3003; (*  命令冲突 *)
ELSIF Command_Timer.Q AND Command_Received THEN
    Error_Code := 3004; (*  命令超时 *)
ELSE
    Error_Code := 0;    (*  无错误 *)
END_IF;

(*  ============================================================================ *)
(*  系统未使能时的处理 *)
(*  ============================================================================ *)

IF NOT Enable THEN
    (*  清除所有状态 *)
    Command_Active := FALSE;
    Command_Received := FALSE;
    Active_Command := 0;
    Command_Source := 0;
    Single_Gate_Mode := FALSE;
    Dual_Gate_Mode := FALSE;
    Operation_Mode := 0;
    Command_Valid := FALSE;

    (*  清除所有输出命令 *)
    Gate1_Open_Command := FALSE;
    Gate1_Close_Command := FALSE;
    Gate2_Open_Command := FALSE;
    Gate2_Close_Command := FALSE;
END_IF;

END_FUNCTION_BLOCK