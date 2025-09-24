(*
===============================================================================
DFB: DB_United_Control_Logic - 统一门控制逻辑模块
===============================================================================
功能描述：
- 集成单门和双门的完整控制逻辑
- 处理遥控/键盘命令（cmd_v1_tele_digi, cmd_v12_tele_digi）
- 处理对讲命令（cmd_v1_interphone, cmd_v12_interphone）
- 管理两个门板的状态和电机控制
- 包含完整的安全保护功能

控制逻辑：
单门模式（V1）：
- 门关状态 + 单门命令 → 门1开启
- 门开状态 + 单门命令 → 门1关闭
- 门运动状态 + 单门命令 → 门1停止并关闭

双门模式（V12）：
- 两门全关 + 双门命令 → 两门开启
- 两门全开 + 双门命令 → 两门关闭
- 混合/运动状态 + 双门命令 → 两门关闭

对讲模式：
- cmd_v1_interphone：作用等同于cmd_v1_tele_digi
- cmd_v12_interphone：作用等同于cmd_v12_tele_digi

输入参数：
- Enable: 系统使能信号
- Emergency_Stop: 紧急停止（常闭触点，TRUE=正常）
- cmd_v1_tele_digi: 单门遥控/键盘命令
- cmd_v12_tele_digi: 双门遥控/键盘命令
- cmd_v1_interphone: 单门对讲命令
- cmd_v12_interphone: 双门对讲命令
- Sensor_Open_V1: 门1全开位置传感器
- Sensor_Close_V1: 门1全关位置传感器
- Sensor_Open_V2: 门2全开位置传感器
- Sensor_Close_V2: 门2全关位置传感器
- Overcurrent_V1: 门1过流检测
- Overcurrent_V2: 门2过流检测
- Bar_Lumineuse: 通道传感器（障碍物检测）

输出参数：
- Motor_Open_V1: 门1开启电机输出
- Motor_Close_V1: 门1关闭电机输出
- Motor_Open_V2: 门2开启电机输出
- Motor_Close_V2: 门2关闭电机输出
- Warning_Light: 警告灯输出
- Area_Light: 区域照明输出
- Status_V1: 门1状态（0=关闭，1=开启中，2=开启，3=关闭中）
- Status_V2: 门2状态
- Error: 系统故障指示
- Error_Code: 故障代码

作者: Claude Code Assistant
日期: 2025-09-24
版本: 1.0
===============================================================================
*)

FUNCTION_BLOCK DB_United_Control_Logic

VAR_INPUT
    Enable              : BOOL;     (* 系统使能信号 *)
    Emergency_Stop      : BOOL;     (* 紧急停止（常闭触点，TRUE=正常） *)

    (* 命令输入信号 *)
    cmd_v1_tele_digi    : BOOL;     (* 单门遥控/键盘命令 *)
    cmd_v12_tele_digi   : BOOL;     (* 双门遥控/键盘命令 *)
    cmd_v1_interphone   : BOOL;     (* 单门对讲命令 *)
    cmd_v12_interphone  : BOOL;     (* 双门对讲命令 *)

    (* 位置传感器 *)
    Sensor_Open_V1      : BOOL;     (* 门1全开位置传感器 *)
    Sensor_Close_V1     : BOOL;     (* 门1全关位置传感器 *)
    Sensor_Open_V2      : BOOL;     (* 门2全开位置传感器 *)
    Sensor_Close_V2     : BOOL;     (* 门2全关位置传感器 *)

    (* 安全传感器 *)
    Overcurrent_V1      : BOOL;     (* 门1过流检测 *)
    Overcurrent_V2      : BOOL;     (* 门2过流检测 *)
    Bar_Lumineuse       : BOOL;     (* 通道传感器（障碍物检测） *)
END_VAR

VAR_OUTPUT
    (* 电机控制输出 *)
    Motor_Open_V1       : BOOL;     (* 门1开启电机输出 *)
    Motor_Close_V1      : BOOL;     (* 门1关闭电机输出 *)
    Motor_Open_V2       : BOOL;     (* 门2开启电机输出 *)
    Motor_Close_V2      : BOOL;     (* 门2关闭电机输出 *)

    (* 辅助设备输出 *)
    Warning_Light       : BOOL;     (* 警告灯输出 *)
    Area_Light          : BOOL;     (* 区域照明输出 *)

    (* 状态输出 *)
    Status_V1           : INT;      (* 门1状态：0=关闭，1=开启中，2=开启，3=关闭中 *)
    Status_V2           : INT;      (* 门2状态 *)

    (* 故障输出 *)
    Error               : BOOL;     (* 系统故障指示 *)
    Error_Code          : INT;      (* 故障代码 *)
END_VAR

VAR
    (* 门1状态变量 *)
    Gate1_State         : INT := 0; (* 门1状态：0=关闭，1=开启中，2=开启，3=关闭中 *)
    Gate2_State         : INT := 0; (* 门2状态 *)

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

    (* 安全和故障变量 *)
    Safety_Error        : BOOL;
    Obstacle_Detected   : BOOL;
    Force_Stop          : BOOL;

    (* 照明控制 *)
    Light_Timer         : TON;      (* 照明定时器 *)
    Light_ON_Time       : TIME := T#30S;  (* 照明持续时间30秒 *)
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
(* 安全检测 *)
(* ============================================================================ *)

(* 障碍物检测（通道传感器信号反逻辑，TRUE=有障碍物） *)
Obstacle_Detected := Bar_Lumineuse;

(* 安全故障检测 *)
Safety_Error := NOT Emergency_Stop OR Overcurrent_V1 OR Overcurrent_V2;

(* 强制停止条件 *)
Force_Stop := Safety_Error OR Obstacle_Detected;

(* 系统故障状态 *)
Error := Safety_Error OR NOT Enable;

(* 故障代码 *)
IF NOT Emergency_Stop THEN
    Error_Code := 1001;  (* 紧急停止激活 *)
ELSIF Overcurrent_V1 OR Overcurrent_V2 THEN
    Error_Code := 1002;  (* 过流保护 *)
ELSIF NOT Enable THEN
    Error_Code := 1003;  (* 系统未使能 *)
ELSE
    Error_Code := 0;     (* 无故障 *)
END_IF;

(* ============================================================================ *)
(* 门状态判断 *)
(* ============================================================================ *)

(* 门1状态判断 *)
Gate1_Is_Closed := (Gate1_State = 0);
Gate1_Is_Open := (Gate1_State = 2);
Gate1_Is_Moving := (Gate1_State = 1) OR (Gate1_State = 3);

(* 门2状态判断 *)
Gate2_Is_Closed := (Gate2_State = 0);
Gate2_Is_Open := (Gate2_State = 2);
Gate2_Is_Moving := (Gate2_State = 1) OR (Gate2_State = 3);

(* 双门组合状态 *)
Both_Gates_Closed := Gate1_Is_Closed AND Gate2_Is_Closed;
Both_Gates_Open := Gate1_Is_Open AND Gate2_Is_Open;
Any_Gate_Moving := Gate1_Is_Moving OR Gate2_Is_Moving;

(* ============================================================================ *)
(* 门1控制状态机 *)
(* ============================================================================ *)

CASE Gate1_State OF

    0: (* 门1关闭状态 *)
        Motor_Open_V1 := FALSE;
        Motor_Close_V1 := FALSE;

        (* 状态转换条件 *)
        IF Enable AND NOT Error THEN
            IF cmd_v1_edge THEN
                (* 单门命令：关闭→开启 *)
                Gate1_State := 1;
            ELSIF cmd_v12_edge AND Both_Gates_Closed THEN
                (* 双门命令：两门都关闭→门1开启 *)
                Gate1_State := 1;
            END_IF;
        END_IF;

    1: (* 门1开启中状态 *)
        Motor_Close_V1 := FALSE;

        (* 电机控制 *)
        IF NOT Force_Stop THEN
            Motor_Open_V1 := TRUE;
        ELSE
            Motor_Open_V1 := FALSE;
        END_IF;

        (* 状态转换条件 *)
        IF Sensor_Open_V1 THEN
            (* 到达全开位置 *)
            Gate1_State := 2;
            Motor_Open_V1 := FALSE;
        ELSIF Force_Stop OR cmd_v1_edge OR (cmd_v12_edge AND NOT Both_Gates_Closed) THEN
            (* 遇到障碍物、命令或双门关闭命令 *)
            Gate1_State := 3;
            Motor_Open_V1 := FALSE;
        END_IF;

    2: (* 门1开启状态 *)
        Motor_Open_V1 := FALSE;
        Motor_Close_V1 := FALSE;

        (* 状态转换条件 *)
        IF Enable AND NOT Error THEN
            IF cmd_v1_edge THEN
                (* 单门命令：开启→关闭 *)
                Gate1_State := 3;
            ELSIF cmd_v12_edge THEN
                (* 双门命令→关闭 *)
                Gate1_State := 3;
            END_IF;
        END_IF;

    3: (* 门1关闭中状态 *)
        Motor_Open_V1 := FALSE;

        (* 电机控制 *)
        IF NOT Force_Stop THEN
            Motor_Close_V1 := TRUE;
        ELSE
            Motor_Close_V1 := FALSE;
        END_IF;

        (* 状态转换条件 *)
        IF Sensor_Close_V1 THEN
            (* 到达全关位置 *)
            Gate1_State := 0;
            Motor_Close_V1 := FALSE;
        ELSIF Force_Stop OR cmd_v1_edge THEN
            (* 遇到障碍物或开门命令 *)
            Gate1_State := 1;
            Motor_Close_V1 := FALSE;
        END_IF;

    ELSE (* 未知状态，重置 *)
        Gate1_State := 0;

END_CASE;

(* ============================================================================ *)
(* 门2控制状态机 *)
(* ============================================================================ *)

CASE Gate2_State OF

    0: (* 门2关闭状态 *)
        Motor_Open_V2 := FALSE;
        Motor_Close_V2 := FALSE;

        (* 状态转换条件 - 只响应双门命令 *)
        IF Enable AND NOT Error AND cmd_v12_edge AND Both_Gates_Closed THEN
            Gate2_State := 1;
        END_IF;

    1: (* 门2开启中状态 *)
        Motor_Close_V2 := FALSE;

        (* 电机控制 *)
        IF NOT Force_Stop THEN
            Motor_Open_V2 := TRUE;
        ELSE
            Motor_Open_V2 := FALSE;
        END_IF;

        (* 状态转换条件 *)
        IF Sensor_Open_V2 THEN
            (* 到达全开位置 *)
            Gate2_State := 2;
            Motor_Open_V2 := FALSE;
        ELSIF Force_Stop OR cmd_v12_edge THEN
            (* 遇到障碍物或双门命令 *)
            Gate2_State := 3;
            Motor_Open_V2 := FALSE;
        END_IF;

    2: (* 门2开启状态 *)
        Motor_Open_V2 := FALSE;
        Motor_Close_V2 := FALSE;

        (* 状态转换条件 - 只响应双门命令 *)
        IF Enable AND NOT Error AND cmd_v12_edge THEN
            Gate2_State := 3;
        END_IF;

    3: (* 门2关闭中状态 *)
        Motor_Open_V2 := FALSE;

        (* 电机控制 *)
        IF NOT Force_Stop THEN
            Motor_Close_V2 := TRUE;
        ELSE
            Motor_Close_V2 := FALSE;
        END_IF;

        (* 状态转换条件 *)
        IF Sensor_Close_V2 THEN
            (* 到达全关位置 *)
            Gate2_State := 0;
            Motor_Close_V2 := FALSE;
        ELSIF Force_Stop THEN
            (* 遇到障碍物 *)
            Gate2_State := 1;
            Motor_Close_V2 := FALSE;
        END_IF;

    ELSE (* 未知状态，重置 *)
        Gate2_State := 0;

END_CASE;

(* ============================================================================ *)
(* 辅助设备控制 *)
(* ============================================================================ *)

(* 警告灯控制：任一门运动时点亮 *)
Warning_Light := Gate1_Is_Moving OR Gate2_Is_Moving;

(* 区域照明控制：有命令时点亮30秒 *)
Light_Timer(IN := cmd_v1_edge OR cmd_v12_edge, PT := Light_ON_Time);
Area_Light := Light_Timer.Q;

(* ============================================================================ *)
(* 状态输出更新 *)
(* ============================================================================ *)

Status_V1 := Gate1_State;
Status_V2 := Gate2_State;

(* ============================================================================ *)
(* 系统未使能时的安全处理 *)
(* ============================================================================ *)

IF NOT Enable THEN
    Motor_Open_V1 := FALSE;
    Motor_Close_V1 := FALSE;
    Motor_Open_V2 := FALSE;
    Motor_Close_V2 := FALSE;
    Warning_Light := FALSE;
END_IF;

END_FUNCTION_BLOCK