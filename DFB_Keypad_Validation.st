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

    (*  按键边沿检测 *)
    Key_Edge_0          : R_TRIG;
    Key_Edge_1          : R_TRIG;
    Key_Edge_2          : R_TRIG;
    Key_Edge_3          : R_TRIG;
    Key_Edge_4          : R_TRIG;
    Key_Edge_5          : R_TRIG;
    Key_Edge_6          : R_TRIG;
    Key_Edge_7          : R_TRIG;
    Key_Edge_8          : R_TRIG;
    Key_Edge_9          : R_TRIG;
    Key_Edge_Clear      : R_TRIG;
    Key_Edge_Enter      : R_TRIG;

    (*  定时器 *)
    Input_Timer         : TON;                 (*  输入超时定时器 *)
    Valid_Timer         : TON;                 (*  有效时间定时器 *)
    Lock_Timer          : TON;                 (*  锁定时间定时器 *)
    Error_Display_Timer : TON;                 (*  错误显示定时器 *)

    (*  状态管理 *)
    Failed_Attempts     : INT := 0;            (*  失败尝试次数 *)
    Password_Valid      : BOOL;                (*  密码验证有效 *)
    Access_Type         : INT;                 (*  访问类型：1=单门，2=双门 *)
    Last_Valid_Type     : INT;                 (*  最后有效的访问类型 *)

    (*  内部标志 *)
    Key_Pressed         : BOOL;                (*  按键按下标志 *)
    Pressed_Key         : INT;                 (*  按下的键值 *)
    Reset_Edge          : R_TRIG;              (*  复位边沿检测 *)

    (*  显示相关 *)
    i                   : INT;                 (*  循环计数器 *)
END_VAR

(*  ============================================================================ *)
(*  初始化和边沿检测 *)
(*  ============================================================================ *)

Reset_Edge(CLK := Reset_Lock);

(*  按键边沿检测 *)
Key_Edge_0(CLK := Key_0);
Key_Edge_1(CLK := Key_1);
Key_Edge_2(CLK := Key_2);
Key_Edge_3(CLK := Key_3);
Key_Edge_4(CLK := Key_4);
Key_Edge_5(CLK := Key_5);
Key_Edge_6(CLK := Key_6);
Key_Edge_7(CLK := Key_7);
Key_Edge_8(CLK := Key_8);
Key_Edge_9(CLK := Key_9);
Key_Edge_Clear(CLK := Key_Clear);
Key_Edge_Enter(CLK := Key_Enter);

(*  ============================================================================ *)
(*  系统锁定管理 *)
(*  ============================================================================ *)

(*  锁定定时器 *)
Lock_Timer(
    IN := System_Locked AND NOT Reset_Edge.Q,
    PT := Lock_Duration
);

(*  锁定状态更新 *)
IF Failed_Attempts >= Max_Attempts THEN
    System_Locked := TRUE;
END_IF;

(*  锁定解除条件 *)
IF Lock_Timer.Q OR Reset_Edge.Q THEN
    System_Locked := FALSE;
    Failed_Attempts := 0;
END_IF;

(*  计算锁定剩余时间 *)
IF System_Locked THEN
    Lock_Time_Remaining := Lock_Duration - Lock_Timer.ET;
ELSE
    Lock_Time_Remaining := T#0s;
END_IF;

(*  计算剩余尝试次数 *)
Attempts_Remaining := Max_Attempts - Failed_Attempts;

(*  ============================================================================ *)
(*  按键处理逻辑 *)
(*  ============================================================================ *)

Key_Pressed := FALSE;
Pressed_Key := -1;

(*  检测按下的数字键 *)
IF Key_Edge_0.Q THEN Key_Pressed := TRUE; Pressed_Key := 0; END_IF;
IF Key_Edge_1.Q THEN Key_Pressed := TRUE; Pressed_Key := 1; END_IF;
IF Key_Edge_2.Q THEN Key_Pressed := TRUE; Pressed_Key := 2; END_IF;
IF Key_Edge_3.Q THEN Key_Pressed := TRUE; Pressed_Key := 3; END_IF;
IF Key_Edge_4.Q THEN Key_Pressed := TRUE; Pressed_Key := 4; END_IF;
IF Key_Edge_5.Q THEN Key_Pressed := TRUE; Pressed_Key := 5; END_IF;
IF Key_Edge_6.Q THEN Key_Pressed := TRUE; Pressed_Key := 6; END_IF;
IF Key_Edge_7.Q THEN Key_Pressed := TRUE; Pressed_Key := 7; END_IF;
IF Key_Edge_8.Q THEN Key_Pressed := TRUE; Pressed_Key := 8; END_IF;
IF Key_Edge_9.Q THEN Key_Pressed := TRUE; Pressed_Key := 9; END_IF;

(*  ============================================================================ *)
(*  密码输入处理 *)
(*  ============================================================================ *)

(*  只有在系统使能且未锁定时才能输入 *)
IF Enable AND NOT System_Locked THEN

    (*  清除键处理 *)
    IF Key_Edge_Clear.Q THEN
        Input_Index := 0;
        FOR i := 1 TO 4 DO
            Input_Buffer[i] := 0;
        END_FOR;
        Input_Active := FALSE;
    END_IF;

    (*  数字键输入处理 *)
    IF Key_Pressed AND Pressed_Key >= 0 AND Pressed_Key <= 9 THEN
        Input_Active := TRUE;

        IF Input_Index < 4 THEN
            Input_Index := Input_Index + 1;
            Input_Buffer[Input_Index] := Pressed_Key;
        END_IF;
    END_IF;

    (*  确认键处理 *)
    IF Key_Edge_Enter.Q AND Input_Index = 4 THEN
        (*  计算输入的密码 *)
        Input_Password := Input_Buffer[1] * 1000 +
                         Input_Buffer[2] * 100 +
                         Input_Buffer[3] * 10 +
                         Input_Buffer[4];

        (*  密码验证 *)
        IF Input_Password = Password_Single THEN
            (*  单门密码正确 *)
            Access_Type := 1;
            Last_Valid_Type := 1;
            Password_Valid := TRUE;
            Failed_Attempts := 0;
        ELSIF Input_Password = Password_Dual THEN
            (*  双门密码正确 *)
            Access_Type := 2;
            Last_Valid_Type := 2;
            Password_Valid := TRUE;
            Failed_Attempts := 0;
        ELSE
            (*  密码错误 *)
            Password_Valid := FALSE;
            Failed_Attempts := Failed_Attempts + 1;
            Error_Display := TRUE;
        END_IF;

        (*  清除输入缓冲区 *)
        Input_Index := 0;
        FOR i := 1 TO 4 DO
            Input_Buffer[i] := 0;
        END_FOR;
        Input_Active := FALSE;
    END_IF;

END_IF;

(*  ============================================================================ *)
(*  超时处理 *)
(*  ============================================================================ *)

(*  输入超时定时器 *)
Input_Timer(
    IN := Input_Active,
    PT := Input_Timeout
);

(*  输入超时清除 *)
IF Input_Timer.Q THEN
    Input_Index := 0;
    FOR i := 1 TO 4 DO
        Input_Buffer[i] := 0;
    END_FOR;
    Input_Active := FALSE;
END_IF;

(*  ============================================================================ *)
(*  访问权限管理 *)
(*  ============================================================================ *)

(*  有效时间定时器 *)
Valid_Timer(
    IN := Password_Valid,
    PT := Valid_Duration
);

(*  权限输出 *)
IF Password_Valid AND NOT Valid_Timer.Q THEN
    CASE Last_Valid_Type OF
        1: (*  单门权限 *)
            Single_Gate_Access := TRUE;
            Dual_Gate_Access := FALSE;
        2: (*  双门权限 *)
            Single_Gate_Access := FALSE;
            Dual_Gate_Access := TRUE;
    END_CASE;
ELSE
    Single_Gate_Access := FALSE;
    Dual_Gate_Access := FALSE;

    (*  有效时间到期，清除验证状态 *)
    IF Valid_Timer.Q THEN
        Password_Valid := FALSE;
        Access_Type := 0;
    END_IF;
END_IF;

(*  ============================================================================ *)
(*  显示处理 *)
(*  ============================================================================ *)

(*  错误显示定时器（3秒） *)
Error_Display_Timer(
    IN := Error_Display,
    PT := T#3s
);

IF Error_Display_Timer.Q THEN
    Error_Display := FALSE;
END_IF;

(*  生成输入显示（星号掩码） *)
Input_Display := '';
FOR i := 1 TO Input_Index DO
    Input_Display := CONCAT(Input_Display, '*');
END_FOR;

(*  状态显示信息 *)
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
    (*  清除所有状态 *)
    Input_Index := 0;
    Input_Active := FALSE;
    Password_Valid := FALSE;
    Single_Gate_Access := FALSE;
    Dual_Gate_Access := FALSE;
    Error_Display := FALSE;

    (*  清除输入缓冲区 *)
    FOR i := 1 TO 4 DO
        Input_Buffer[i] := 0;
    END_FOR;
END_IF;

END_FUNCTION_BLOCK