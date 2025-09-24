(*
===============================================================================
DFB: DB_Keypad_Validation - 密码验证模块 (简化版)
===============================================================================
功能描述：
- 数字键盘密码输入验证
- 支持两个密码：1504（单门），2502（双门）
- 错误次数限制和锁定保护
- 即时密码验证

简化说明：
- 删除所有定时器和TIME类型变量
- 删除System_Clock输入
- 删除输入超时和有效时间管理
- 保留边沿检测（用基础BOOL实现）
- 保留核心密码验证逻辑
- 简化锁定机制（无时间限制）

密码逻辑：
- 密码1504：单门控制权限
- 密码2502：双门控制权限
- 错误锁定：连续3次错误后锁定，需管理员解锁

作者: Claude Code Assistant
日期: 2025-09-24
版本: 2.0 (简化版)
===============================================================================
*)

FUNCTION_BLOCK DB_Keypad_Validation

VAR_INPUT
    Enable              : BOOL;                 (* 系统使能 *)
    Key_0               : BOOL;                 (* 数字键0 *)
    Key_1               : BOOL;                 (* 数字键1 *)
    Key_2               : BOOL;                 (* 数字键2 *)
    Key_3               : BOOL;                 (* 数字键3 *)
    Key_4               : BOOL;                 (* 数字键4 *)
    Key_5               : BOOL;                 (* 数字键5 *)
    Key_6               : BOOL;                 (* 数字键6 *)
    Key_7               : BOOL;                 (* 数字键7 *)
    Key_8               : BOOL;                 (* 数字键8 *)
    Key_9               : BOOL;                 (* 数字键9 *)
    Key_Clear           : BOOL;                 (* 清除键 (*) *)
    Key_Enter           : BOOL;                 (* 确认键 (#) *)
    Reset_Lock          : BOOL;                 (* 管理员解锁复位 *)
    Password_Single     : INT := 1504;          (* 单门密码 *)
    Password_Dual       : INT := 2502;          (* 双门密码 *)
    Max_Attempts        : INT := 3;             (* 最大尝试次数 *)
END_VAR

VAR_OUTPUT
    Single_Gate_Access  : BOOL;                 (* 单门访问权限 *)
    Dual_Gate_Access    : BOOL;                 (* 双门访问权限 *)
    Input_Active        : BOOL;                 (* 正在输入状态 *)
    System_Locked       : BOOL;                 (* 系统锁定状态 *)
    Error_Display       : BOOL;                 (* 错误显示 *)
    Input_Display       : STRING[4];           (* 输入显示（****） *)
    Status_Display      : STRING[20];          (* 状态显示信息 *)
    Attempts_Remaining  : INT;                  (* 剩余尝试次数 *)
END_VAR

VAR
    (* 密码输入缓冲区 *)
    Input_Buffer        : ARRAY[1..4] OF INT;  (* 输入缓冲区 *)
    Input_Index         : INT := 0;            (* 输入位置索引 *)
    Input_Password      : INT;                 (* 输入的完整密码 *)

    (* 按键边沿检测 *)
    Key_0_Last          : BOOL;
    Key_1_Last          : BOOL;
    Key_2_Last          : BOOL;
    Key_3_Last          : BOOL;
    Key_4_Last          : BOOL;
    Key_5_Last          : BOOL;
    Key_6_Last          : BOOL;
    Key_7_Last          : BOOL;
    Key_8_Last          : BOOL;
    Key_9_Last          : BOOL;
    Key_Clear_Last      : BOOL;
    Key_Enter_Last      : BOOL;
    Key_Edge_0          : BOOL;
    Key_Edge_1          : BOOL;
    Key_Edge_2          : BOOL;
    Key_Edge_3          : BOOL;
    Key_Edge_4          : BOOL;
    Key_Edge_5          : BOOL;
    Key_Edge_6          : BOOL;
    Key_Edge_7          : BOOL;
    Key_Edge_8          : BOOL;
    Key_Edge_9          : BOOL;
    Key_Edge_Clear      : BOOL;
    Key_Edge_Enter      : BOOL;

    (* 状态管理 *)
    Failed_Attempts     : INT := 0;            (* 失败尝试次数 *)
    Password_Valid      : BOOL;                (* 密码验证有效 *)
    Access_Type         : INT;                 (* 访问类型：1=单门，2=双门 *)

    (* 内部标志 *)
    Key_Pressed         : BOOL;                (* 按键按下标志 *)
    Pressed_Key         : INT;                 (* 按下的键值 *)
    Reset_Edge          : BOOL;                (* 复位边沿检测 *)
    Reset_Lock_Last     : BOOL;                (* 复位锁定前一周期状态 *)

    (* 显示相关 *)
    i                   : INT;                 (* 循环计数器 *)
    Error_Pulse         : BOOL;                (* 错误显示脉冲 *)
END_VAR

(* ============================================================================
   边沿检测器 - 基础变量实现R_TRIG
   ============================================================================ *)

Reset_Edge := Reset_Lock AND NOT Reset_Lock_Last;
Reset_Lock_Last := Reset_Lock;

(* 按键边沿检测 *)
Key_Edge_0 := Key_0 AND NOT Key_0_Last;
Key_0_Last := Key_0;

Key_Edge_1 := Key_1 AND NOT Key_1_Last;
Key_1_Last := Key_1;

Key_Edge_2 := Key_2 AND NOT Key_2_Last;
Key_2_Last := Key_2;

Key_Edge_3 := Key_3 AND NOT Key_3_Last;
Key_3_Last := Key_3;

Key_Edge_4 := Key_4 AND NOT Key_4_Last;
Key_4_Last := Key_4;

Key_Edge_5 := Key_5 AND NOT Key_5_Last;
Key_5_Last := Key_5;

Key_Edge_6 := Key_6 AND NOT Key_6_Last;
Key_6_Last := Key_6;

Key_Edge_7 := Key_7 AND NOT Key_7_Last;
Key_7_Last := Key_7;

Key_Edge_8 := Key_8 AND NOT Key_8_Last;
Key_8_Last := Key_8;

Key_Edge_9 := Key_9 AND NOT Key_9_Last;
Key_9_Last := Key_9;

Key_Edge_Clear := Key_Clear AND NOT Key_Clear_Last;
Key_Clear_Last := Key_Clear;

Key_Edge_Enter := Key_Enter AND NOT Key_Enter_Last;
Key_Enter_Last := Key_Enter;

(* ============================================================================
   系统锁定管理 - 简化版
   ============================================================================ *)

(* 锁定状态更新 *)
IF Failed_Attempts >= Max_Attempts THEN
    System_Locked := TRUE;
END_IF;

(* 锁定解除条件 *)
IF Reset_Edge THEN
    System_Locked := FALSE;
    Failed_Attempts := 0;
END_IF;

(* 计算剩余尝试次数 *)
Attempts_Remaining := Max_Attempts - Failed_Attempts;

(* ============================================================================
   按键处理逻辑
   ============================================================================ *)

Key_Pressed := FALSE;
Pressed_Key := -1;

(* 检测按下的数字键 *)
IF Key_Edge_0 THEN Key_Pressed := TRUE; Pressed_Key := 0; END_IF;
IF Key_Edge_1 THEN Key_Pressed := TRUE; Pressed_Key := 1; END_IF;
IF Key_Edge_2 THEN Key_Pressed := TRUE; Pressed_Key := 2; END_IF;
IF Key_Edge_3 THEN Key_Pressed := TRUE; Pressed_Key := 3; END_IF;
IF Key_Edge_4 THEN Key_Pressed := TRUE; Pressed_Key := 4; END_IF;
IF Key_Edge_5 THEN Key_Pressed := TRUE; Pressed_Key := 5; END_IF;
IF Key_Edge_6 THEN Key_Pressed := TRUE; Pressed_Key := 6; END_IF;
IF Key_Edge_7 THEN Key_Pressed := TRUE; Pressed_Key := 7; END_IF;
IF Key_Edge_8 THEN Key_Pressed := TRUE; Pressed_Key := 8; END_IF;
IF Key_Edge_9 THEN Key_Pressed := TRUE; Pressed_Key := 9; END_IF;

(* ============================================================================
   密码输入处理
   ============================================================================ *)

(* 只有在系统使能且未锁定时才能输入 *)
IF Enable AND NOT System_Locked THEN

    (* 清除键处理 *)
    IF Key_Edge_Clear THEN
        Input_Index := 0;
        FOR i := 1 TO 4 DO
            Input_Buffer[i] := 0;
        END_FOR;
        Input_Active := FALSE;
        Password_Valid := FALSE;
        Single_Gate_Access := FALSE;
        Dual_Gate_Access := FALSE;
        Error_Display := FALSE;
    END_IF;

    (* 数字键输入处理 *)
    IF Key_Pressed AND Pressed_Key >= 0 AND Pressed_Key <= 9 THEN
        Input_Active := TRUE;
        Error_Display := FALSE;

        IF Input_Index < 4 THEN
            Input_Index := Input_Index + 1;
            Input_Buffer[Input_Index] := Pressed_Key;
        END_IF;
    END_IF;

    (* 确认键处理 *)
    IF Key_Edge_Enter AND Input_Index = 4 THEN
        (* 计算输入的密码 *)
        Input_Password := Input_Buffer[1] * 1000 +
                         Input_Buffer[2] * 100 +
                         Input_Buffer[3] * 10 +
                         Input_Buffer[4];

        (* 密码验证 *)
        IF Input_Password = Password_Single THEN
            (* 单门密码正确 *)
            Access_Type := 1;
            Password_Valid := TRUE;
            Single_Gate_Access := TRUE;
            Dual_Gate_Access := FALSE;
            Failed_Attempts := 0;
            Error_Display := FALSE;
        ELSIF Input_Password = Password_Dual THEN
            (* 双门密码正确 *)
            Access_Type := 2;
            Password_Valid := TRUE;
            Single_Gate_Access := FALSE;
            Dual_Gate_Access := TRUE;
            Failed_Attempts := 0;
            Error_Display := FALSE;
        ELSE
            (* 密码错误 *)
            Password_Valid := FALSE;
            Single_Gate_Access := FALSE;
            Dual_Gate_Access := FALSE;
            Failed_Attempts := Failed_Attempts + 1;
            Error_Display := TRUE;
        END_IF;

        (* 清除输入缓冲区 *)
        Input_Index := 0;
        FOR i := 1 TO 4 DO
            Input_Buffer[i] := 0;
        END_FOR;
        Input_Active := FALSE;
    END_IF;

END_IF;

(* ============================================================================
   访问权限管理 - 简化版（权限立即生效，用户手动清除）
   ============================================================================ *)

(* 权限在密码正确后保持有效，直到用户清除或系统禁用 *)
IF NOT Enable OR Key_Edge_Clear THEN
    Single_Gate_Access := FALSE;
    Dual_Gate_Access := FALSE;
    Password_Valid := FALSE;
    Access_Type := 0;
END_IF;

(* ============================================================================
   显示处理
   ============================================================================ *)

(* 生成输入显示（星号掩码） *)
Input_Display := '';
FOR i := 1 TO Input_Index DO
    Input_Display := CONCAT(Input_Display, '*');
END_FOR;

(* 状态显示信息 *)
IF NOT Enable THEN
    Status_Display := 'SYSTEM DISABLED';
ELSIF System_Locked THEN
    Status_Display := 'SYSTEM LOCKED';
ELSIF Error_Display THEN
    Status_Display := 'INVALID PASSWORD';
ELSIF Input_Active THEN
    Status_Display := 'ENTER PASSWORD';
ELSIF Single_Gate_Access THEN
    Status_Display := 'SINGLE GATE ACCESS';
ELSIF Dual_Gate_Access THEN
    Status_Display := 'DUAL GATE ACCESS';
ELSE
    Status_Display := 'READY';
END_IF;

(* ============================================================================
   系统未使能时的处理
   ============================================================================ *)

IF NOT Enable THEN
    (* 清除所有状态 *)
    Input_Index := 0;
    Input_Active := FALSE;
    Password_Valid := FALSE;
    Single_Gate_Access := FALSE;
    Dual_Gate_Access := FALSE;
    Error_Display := FALSE;

    (* 清除输入缓冲区 *)
    FOR i := 1 TO 4 DO
        Input_Buffer[i] := 0;
    END_FOR;
END_IF;

END_FUNCTION_BLOCK