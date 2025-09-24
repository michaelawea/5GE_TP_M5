(*  *)
===============================================================================
DFB: DB_Keypad_Validation - 密码验证模块
===============================================================================
功能描述：
- 数字键盘密码输入验证
- 支持两个密码：1504（单门），2502（双门）
- 密码输入超时管理
- 错误次数限制和锁定保护
- 密码正确后的有效时间管理

密码逻辑：
- 密码1504：单门控制权限
- 密码2502：双门控制权限
- 输入超时：10秒无输入自动清除
- 错误锁定：连续3次错误后锁定5分钟
- 有效时间：密码正确后30秒内有效

键盘接口说明：
- 需要通过FBD连接数字键盘硬件
- 建议使用矩阵键盘扫描方式
- 按键编码：0-9数字键，*清除键，#确认键

作者: Claude Code Assistant
日期: 2025-09-23
版本: 1.0
===============================================================================
*)

FUNCTION_BLOCK DB_Keypad_Validation

VAR_INPUT
    Enable              : BOOL;                 (*  系统使能 *)
    Key_0               : BOOL;                 (*  数字键0 *)
    Key_1               : BOOL;                 (*  数字键1 *)
    Key_2               : BOOL;                 (*  数字键2 *)
    Key_3               : BOOL;                 (*  数字键3 *)
    Key_4               : BOOL;                 (*  数字键4 *)
    Key_5               : BOOL;                 (*  数字键5 *)
    Key_6               : BOOL;                 (*  数字键6 *)
    Key_7               : BOOL;                 (*  数字键7 *)
    Key_8               : BOOL;                 (*  数字键8 *)
    Key_9               : BOOL;                 (*  数字键9 *)
    Key_Clear           : BOOL;                 (* 清除键 (*) *)
    Key_Enter           : BOOL;                 (*  确认键 (#) *)
    Reset_Lock          : BOOL;                 (*  管理员解锁复位 *)
    Password_Single     : INT := 1504;          (*  单门密码 *)
    Password_Dual       : INT := 2502;          (*  双门密码 *)
    Input_Timeout       : TIME := T#10s;        (*  输入超时时间 *)
    Valid_Duration      : TIME := T#30s;        (*  密码有效持续时间 *)
    Lock_Duration       : TIME := T#5m;         (*  锁定持续时间 *)
    Max_Attempts        : INT := 3;             (*  最大尝试次数 *)
    System_Clock        : TIME;                 (*  系统时钟输入 *)
END_VAR

VAR_OUTPUT
    Single_Gate_Access  : BOOL;                 (*  单门访问权限 *)
    Dual_Gate_Access    : BOOL;                 (*  双门访问权限 *)
    Input_Active        : BOOL;                 (*  正在输入状态 *)
    System_Locked       : BOOL;                 (*  系统锁定状态 *)
    Error_Display       : BOOL;                 (*  错误显示 *)
    Input_Display       : STRING[4];           (*  输入显示（****） *)
    Status_Display      : STRING[20];          (*  状态显示信息 *)
    Attempts_Remaining  : INT;                  (*  剩余尝试次数 *)
    Lock_Time_Remaining : TIME;                 (*  锁定剩余时间 *)
END_VAR

VAR
    (*  密码输入缓冲区 *)
    Input_Buffer        : ARRAY[1..4] OF INT;  (*  输入缓冲区 *)
    Input_Index         : INT := 0;            (*  输入位置索引 *)
    Input_Password      : INT;                 (*  输入的完整密码 *)

    (* 按键边沿检测 - 替换R_TRIG *)
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

    (* 定时器 - 替换TON *)
    Input_Timer_Start         : TIME;          (* 输入超时定时器开始时间 *)
    Input_Timer_Active        : BOOL;          (* 输入超时定时器激活标志 *)
    Valid_Timer_Start         : TIME;          (* 有效时间定时器开始时间 *)
    Valid_Timer_Active        : BOOL;          (* 有效时间定时器激活标志 *)
    Lock_Timer_Start          : TIME;          (* 锁定时间定时器开始时间 *)
    Lock_Timer_Active         : BOOL;          (* 锁定时间定时器激活标志 *)
    Error_Display_Timer_Start : TIME;          (* 错误显示定时器开始时间 *)
    Error_Display_Timer_Active: BOOL;          (* 错误显示定时器激活标志 *)

    (*  状态管理 *)
    Failed_Attempts     : INT := 0;            (*  失败尝试次数 *)
    Password_Valid      : BOOL;                (*  密码验证有效 *)
    Access_Type         : INT;                 (*  访问类型：1=单门，2=双门 *)
    Last_Valid_Type     : INT;                 (*  最后有效的访问类型 *)

    (*  内部标志 *)
    Key_Pressed         : BOOL;                (*  按键按下标志 *)
    Pressed_Key         : INT;                 (*  按下的键值 *)
    Reset_Edge          : BOOL;                (*  复位边沿检测 - 替换R_TRIG *)
    Reset_Lock_Last     : BOOL;                (*  复位锁定前一周期状态 *)

    (*  显示相关 *)
    i                   : INT;                 (*  循环计数器 *)
END_VAR

(*  ============================================================================ *)
(*  初始化和边沿检测 - 基础变量实现R_TRIG *)
(*  ============================================================================ *)

Reset_Edge := Reset_Lock AND NOT Reset_Lock_Last;
Reset_Lock_Last := Reset_Lock;

(* 按键边沿检测 - 基础变量实现R_TRIG *)
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

(*  ============================================================================ *)
(*  系统锁定管理 - 基础变量实现TON定时器功能 *)
(*  ============================================================================ *)

(* 锁定定时器 *)
IF System_Locked AND NOT Reset_Edge THEN
    IF NOT Lock_Timer_Active THEN
        Lock_Timer_Start := System_Clock;
        Lock_Timer_Active := TRUE;
    END_IF;

    (* 检查锁定时间是否到期 *)
    IF (System_Clock - Lock_Timer_Start) >= Lock_Duration THEN
        System_Locked := FALSE;
        Failed_Attempts := 0;
        Lock_Timer_Active := FALSE;
    END_IF;
ELSE
    Lock_Timer_Active := FALSE;
END_IF;

(* 锁定状态更新 *)
IF Failed_Attempts >= Max_Attempts THEN
    System_Locked := TRUE;
END_IF;

(* 锁定解除条件 *)
IF Reset_Edge THEN
    System_Locked := FALSE;
    Failed_Attempts := 0;
    Lock_Timer_Active := FALSE;
END_IF;

(* 计算锁定剩余时间 *)
IF System_Locked AND Lock_Timer_Active THEN
    Lock_Time_Remaining := Lock_Duration - (System_Clock - Lock_Timer_Start);
ELSE
    Lock_Time_Remaining := T#0s;
END_IF;

(* 计算剩余尝试次数 *)
Attempts_Remaining := Max_Attempts - Failed_Attempts;

(*  ============================================================================ *)
(*  按键处理逻辑 *)
(*  ============================================================================ *)

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

(*  ============================================================================ *)
(*  密码输入处理 *)
(*  ============================================================================ *)

(* 只有在系统使能且未锁定时才能输入 *)
IF Enable AND NOT System_Locked THEN

    (* 清除键处理 *)
    IF Key_Edge_Clear THEN
        Input_Index := 0;
        FOR i := 1 TO 4 DO
            Input_Buffer[i] := 0;
        END_FOR;
        Input_Active := FALSE;
        Input_Timer_Active := FALSE;
    END_IF;

    (* 数字键输入处理 *)
    IF Key_Pressed AND Pressed_Key >= 0 AND Pressed_Key <= 9 THEN
        Input_Active := TRUE;

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
            Last_Valid_Type := 1;
            Password_Valid := TRUE;
            Failed_Attempts := 0;
        ELSIF Input_Password = Password_Dual THEN
            (* 双门密码正确 *)
            Access_Type := 2;
            Last_Valid_Type := 2;
            Password_Valid := TRUE;
            Failed_Attempts := 0;
        ELSE
            (* 密码错误 *)
            Password_Valid := FALSE;
            Failed_Attempts := Failed_Attempts + 1;
            Error_Display := TRUE;
            Error_Display_Timer_Start := System_Clock;
            Error_Display_Timer_Active := TRUE;
        END_IF;

        (* 清除输入缓冲区 *)
        Input_Index := 0;
        FOR i := 1 TO 4 DO
            Input_Buffer[i] := 0;
        END_FOR;
        Input_Active := FALSE;
        Input_Timer_Active := FALSE;
    END_IF;

END_IF;

(*  ============================================================================ *)
(*  超时处理 - 基础变量实现TON定时器功能 *)
(*  ============================================================================ *)

(* 输入超时定时器 *)
IF Input_Active THEN
    IF NOT Input_Timer_Active THEN
        Input_Timer_Start := System_Clock;
        Input_Timer_Active := TRUE;
    END_IF;

    (* 检查是否超时 *)
    IF (System_Clock - Input_Timer_Start) >= Input_Timeout THEN
        Input_Index := 0;
        FOR i := 1 TO 4 DO
            Input_Buffer[i] := 0;
        END_FOR;
        Input_Active := FALSE;
        Input_Timer_Active := FALSE;
    END_IF;
ELSE
    Input_Timer_Active := FALSE;
END_IF;

(*  ============================================================================ *)
(*  访问权限管理 - 基础变量实现TON定时器功能 *)
(*  ============================================================================ *)

(* 有效时间定时器 *)
IF Password_Valid THEN
    IF NOT Valid_Timer_Active THEN
        Valid_Timer_Start := System_Clock;
        Valid_Timer_Active := TRUE;
    END_IF;

    (* 检查是否超时 *)
    IF (System_Clock - Valid_Timer_Start) >= Valid_Duration THEN
        Password_Valid := FALSE;
        Access_Type := 0;
        Valid_Timer_Active := FALSE;
    END_IF;
ELSE
    Valid_Timer_Active := FALSE;
END_IF;

(* 权限输出 *)
IF Password_Valid THEN
    CASE Last_Valid_Type OF
        1: (* 单门权限 *)
            Single_Gate_Access := TRUE;
            Dual_Gate_Access := FALSE;
        2: (* 双门权限 *)
            Single_Gate_Access := FALSE;
            Dual_Gate_Access := TRUE;
    END_CASE;
ELSE
    Single_Gate_Access := FALSE;
    Dual_Gate_Access := FALSE;
END_IF;

(*  ============================================================================ *)
(*  显示处理 - 基础变量实现TON定时器功能 *)
(*  ============================================================================ *)

(* 错误显示定时器（3秒） *)
IF Error_Display AND Error_Display_Timer_Active THEN
    IF (System_Clock - Error_Display_Timer_Start) >= T#3s THEN
        Error_Display := FALSE;
        Error_Display_Timer_Active := FALSE;
    END_IF;
END_IF;

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

(*  ============================================================================ *)
(*  系统未使能时的处理 *)
(*  ============================================================================ *)

IF NOT Enable THEN
    (* 清除所有状态 *)
    Input_Index := 0;
    Input_Active := FALSE;
    Password_Valid := FALSE;
    Single_Gate_Access := FALSE;
    Dual_Gate_Access := FALSE;
    Error_Display := FALSE;
    Input_Timer_Active := FALSE;
    Valid_Timer_Active := FALSE;
    Error_Display_Timer_Active := FALSE;

    (* 清除输入缓冲区 *)
    FOR i := 1 TO 4 DO
        Input_Buffer[i] := 0;
    END_FOR;
END_IF;

END_FUNCTION_BLOCK