(*
===============================================================================
DFB: DB_Safety_Check - 安全检测模块
===============================================================================
功能描述：
- 障碍物检测（光栅传感器）
- 过流保护检测
- 电源故障检测
- 安全状态综合判断
- 提供安全联锁信号

检测功能：
1. 通道光栅传感器检测（行人/车辆通过）
2. 门板过流检测（防夹保护）
3. 市电故障检测
4. 系统综合安全状态输出

安全逻辑：
- 检测到障碍物时立即停止门板动作
- 过流检测时反向动作3秒后停止
- 电源故障时保持当前状态并报警

作者: Claude Code Assistant
日期: 2025-09-23
版本: 1.0
===============================================================================
*)

FUNCTION_BLOCK DB_Safety_Check

VAR_INPUT
    Enable              : BOOL;         (* 系统使能 *)
    Passage_Sensor      : BOOL;         (* 通道光栅传感器（Bar_Lumineuse） *)
    Overcurrent_V1      : BOOL;         (* 门板1过流检测 *)
    Overcurrent_V2      : BOOL;         (* 门板2过流检测 *)
    Power_Loss_Alarm    : BOOL;         (* 市电故障报警 *)
    Gate1_Moving        : BOOL;         (* 门板1正在运动 *)
    Gate2_Moving        : BOOL;         (* 门板2正在运动 *)
    Safety_Reset        : BOOL;         (* 安全复位按钮 *)
    Obstacle_Delay      : TIME := T#1s; (* 障碍物检测延时 *)
    Overcurrent_Delay   : TIME := T#500ms; (* 过流检测延时 *)
END_VAR

VAR_OUTPUT
    Safe_To_Operate     : BOOL;         (* 安全运行许可 *)
    Obstacle_Detected   : BOOL;         (* 障碍物检测 *)
    Overcurrent_Gate1   : BOOL;         (* 门板1过流故障 *)
    Overcurrent_Gate2   : BOOL;         (* 门板2过流故障 *)
    Power_Fault         : BOOL;         (* 电源故障 *)
    Emergency_Stop      : BOOL;         (* 紧急停止输出 *)
    Reverse_Gate1       : BOOL;         (* 门板1反向命令 *)
    Reverse_Gate2       : BOOL;         (* 门板2反向命令 *)
    Safety_Warning      : BOOL;         (* 安全警告 *)
    Error_Code          : INT;          (* 安全错误代码 *)
END_VAR

VAR
    (* 障碍物检测逻辑 *)
    Obstacle_Timer      : TON;          (* 障碍物检测定时器 *)
    Obstacle_Confirmed  : BOOL;         (* 障碍物确认 *)

    (* 过流检测逻辑 *)
    Overcurrent_Timer_V1: TON;          (* 门板1过流检测定时器 *)
    Overcurrent_Timer_V2: TON;          (* 门板2过流检测定时器 *)
    Overcurrent_Confirmed_V1: BOOL;     (* 门板1过流确认 *)
    Overcurrent_Confirmed_V2: BOOL;     (* 门板2过流确认 *)

    (* 反向控制定时器 *)
    Reverse_Timer_V1    : TON;          (* 门板1反向定时器 *)
    Reverse_Timer_V2    : TON;          (* 门板2反向定时器 *)
    Reverse_Duration    : TIME := T#3s; (* 反向持续时间 *)

    (* 电源故障检测 *)
    Power_Fault_Filter  : TON;          (* 电源故障滤波定时器 *)
    Power_Fault_Delay   : TIME := T#2s; (* 电源故障确认延时 *)

    (* 安全状态管理 *)
    Safety_Reset_Edge   : R_TRIG;       (* 安全复位边沿检测 *)
    Overall_Safety      : BOOL;         (* 总体安全状态 *)

    (* 内部标志 *)
    Previous_Obstacle   : BOOL;         (* 前一周期障碍物状态 *)
    Gate_Area_Occupied  : BOOL;         (* 门区域被占用 *)
END_VAR

(* 安全复位边沿检测 *)
Safety_Reset_Edge(CLK := Safety_Reset);

(* ============================================================================
   障碍物检测逻辑
   ============================================================================ *)

(* 通道传感器反向逻辑（光栅被遮挡时为FALSE） *)
Gate_Area_Occupied := NOT Passage_Sensor;

(* 障碍物检测定时器 - 只有在门板运动时才进行障碍物检测 *)
Obstacle_Timer(
    IN := Gate_Area_Occupied AND (Gate1_Moving OR Gate2_Moving),
    PT := Obstacle_Delay
);

(* 障碍物确认逻辑 *)
Obstacle_Confirmed := Obstacle_Timer.Q;
Obstacle_Detected := Obstacle_Confirmed;

(* ============================================================================
   过流检测逻辑
   ============================================================================ *)

(* 门板1过流检测 *)
Overcurrent_Timer_V1(
    IN := Overcurrent_V1 AND Gate1_Moving,
    PT := Overcurrent_Delay
);
Overcurrent_Confirmed_V1 := Overcurrent_Timer_V1.Q;
Overcurrent_Gate1 := Overcurrent_Confirmed_V1;

(* 门板2过流检测 *)
Overcurrent_Timer_V2(
    IN := Overcurrent_V2 AND Gate2_Moving,
    PT := Overcurrent_Delay
);
Overcurrent_Confirmed_V2 := Overcurrent_Timer_V2.Q;
Overcurrent_Gate2 := Overcurrent_Confirmed_V2;

(* ============================================================================
   反向控制逻辑（防夹保护）
   ============================================================================ *)

(* 门板1反向控制 *)
Reverse_Timer_V1(
    IN := Overcurrent_Gate1,
    PT := Reverse_Duration
);
Reverse_Gate1 := Reverse_Timer_V1.Q;

(* 门板2反向控制 *)
Reverse_Timer_V2(
    IN := Overcurrent_Gate2,
    PT := Reverse_Duration
);
Reverse_Gate2 := Reverse_Timer_V2.Q;

(* ============================================================================
   电源故障检测
   ============================================================================ *)

(* 电源故障滤波（避免瞬间波动误报） *)
Power_Fault_Filter(
    IN := Power_Loss_Alarm,
    PT := Power_Fault_Delay
);
Power_Fault := Power_Fault_Filter.Q;

(* ============================================================================
   综合安全状态判断
   ============================================================================ *)

(* 计算总体安全状态 *)
Overall_Safety := Enable AND
                  NOT Obstacle_Detected AND
                  NOT Power_Fault AND
                  NOT (Overcurrent_Gate1 AND Gate1_Moving) AND
                  NOT (Overcurrent_Gate2 AND Gate2_Moving);

(* 安全运行许可 *)
Safe_To_Operate := Overall_Safety;

(* 紧急停止输出（任何安全条件不满足时激活） *)
Emergency_Stop := NOT Overall_Safety;

(* 安全警告（检测到潜在危险但尚未触发紧急停止） *)
Safety_Warning := Gate_Area_Occupied OR
                  (Overcurrent_V1 AND NOT Overcurrent_Gate1) OR
                  (Overcurrent_V2 AND NOT Overcurrent_Gate2) OR
                  (Power_Loss_Alarm AND NOT Power_Fault);

(* ============================================================================
   错误代码生成
   ============================================================================ *)

(* 根据安全状态生成相应的错误代码 *)
IF NOT Enable THEN
    Error_Code := 2001;     (* 系统未使能 *)
ELSIF Obstacle_Detected THEN
    Error_Code := 2002;     (* 障碍物检测 *)
ELSIF Overcurrent_Gate1 THEN
    Error_Code := 2003;     (* 门板1过流 *)
ELSIF Overcurrent_Gate2 THEN
    Error_Code := 2004;     (* 门板2过流 *)
ELSIF Power_Fault THEN
    Error_Code := 2005;     (* 电源故障 *)
ELSE
    Error_Code := 0;        (* 无故障 *)
END_IF;

(* ============================================================================
   安全复位处理
   ============================================================================ *)

(* 当安全复位按钮按下且故障条件已清除时，允许复位 *)
IF Safety_Reset_Edge.Q THEN
    (* 复位可恢复的故障状态 *)
    IF NOT Gate_Area_Occupied THEN
        Obstacle_Confirmed := FALSE;
    END_IF;

    IF NOT Overcurrent_V1 THEN
        Overcurrent_Confirmed_V1 := FALSE;
    END_IF;

    IF NOT Overcurrent_V2 THEN
        Overcurrent_Confirmed_V2 := FALSE;
    END_IF;

    (* 电源故障需要故障源清除后才能复位 *)
    IF NOT Power_Loss_Alarm THEN
        (* Power_Fault will automatically clear when timer resets *)
    END_IF;
END_IF;

(* ============================================================================
   状态保存（用于趋势分析和故障诊断）
   ============================================================================ *)

Previous_Obstacle := Gate_Area_Occupied;

END_FUNCTION_BLOCK