(*
===============================================================================
DFB: DB_Safety_Check - 安全检测模块 (简化版)
===============================================================================
功能描述：
- 障碍物检测（光栅传感器）
- 过流保护检测
- 电源故障检测
- 安全状态综合判断
- 提供安全联锁信号

简化说明：
- 删除所有定时器和TIME类型变量
- 删除System_Clock输入
- 保留边沿检测（用基础BOOL实现）
- 保留核心的状态机和逻辑判断
- 即时响应安全检测，无延时过滤

作者: Claude Code Assistant
日期: 2025-09-24
版本: 2.0 (简化版)
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
    (* 安全复位边沿检测 *)
    Safety_Reset_Last   : BOOL;         (* 安全复位前一周期状态 *)
    Safety_Reset_Edge   : BOOL;         (* 安全复位边沿检测结果 *)

    (* 内部安全状态 *)
    Gate_Area_Occupied  : BOOL;         (* 门区域被占用 *)
    Overall_Safety      : BOOL;         (* 总体安全状态 *)

    (* 故障状态锁存 *)
    Overcurrent_Latched_V1 : BOOL;      (* 门板1过流锁存 *)
    Overcurrent_Latched_V2 : BOOL;      (* 门板2过流锁存 *)
    Power_Fault_Latched    : BOOL;      (* 电源故障锁存 *)
END_VAR

(* ============================================================================
   边沿检测器 - 基础变量实现R_TRIG
   ============================================================================ *)

Safety_Reset_Edge := Safety_Reset AND NOT Safety_Reset_Last;
Safety_Reset_Last := Safety_Reset;

(* ============================================================================
   障碍物检测逻辑 - 即时检测
   ============================================================================ *)

(* 通道传感器反向逻辑（光栅被遮挡时为FALSE） *)
Gate_Area_Occupied := NOT Passage_Sensor;

(* 即时障碍物检测（仅在门板运动时检测） *)
Obstacle_Detected := Gate_Area_Occupied AND (Gate1_Moving OR Gate2_Moving);

(* ============================================================================
   过流检测逻辑 - 即时检测，带锁存功能
   ============================================================================ *)

(* 门板1过流检测 - 即时响应并锁存 *)
IF Overcurrent_V1 AND Gate1_Moving THEN
    Overcurrent_Latched_V1 := TRUE;
END_IF;

(* 门板2过流检测 - 即时响应并锁存 *)
IF Overcurrent_V2 AND Gate2_Moving THEN
    Overcurrent_Latched_V2 := TRUE;
END_IF;

(* 输出过流状态 *)
Overcurrent_Gate1 := Overcurrent_Latched_V1;
Overcurrent_Gate2 := Overcurrent_Latched_V2;

(* ============================================================================
   反向控制逻辑（防夹保护） - 即时反向
   ============================================================================ *)

(* 检测到过流时立即反向 *)
Reverse_Gate1 := Overcurrent_Gate1;
Reverse_Gate2 := Overcurrent_Gate2;

(* ============================================================================
   电源故障检测 - 即时检测，带锁存功能
   ============================================================================ *)

(* 电源故障即时检测并锁存 *)
IF Power_Loss_Alarm THEN
    Power_Fault_Latched := TRUE;
END_IF;

Power_Fault := Power_Fault_Latched;

(* ============================================================================
   综合安全状态判断
   ============================================================================ *)

(* 计算总体安全状态 *)
Overall_Safety := Enable AND
                  NOT Obstacle_Detected AND
                  NOT Power_Fault AND
                  NOT Overcurrent_Gate1 AND
                  NOT Overcurrent_Gate2;

(* 安全运行许可 *)
Safe_To_Operate := Overall_Safety;

(* 紧急停止输出（任何安全条件不满足时激活） *)
Emergency_Stop := NOT Overall_Safety;

(* 安全警告（检测到潜在危险） *)
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
IF Safety_Reset_Edge THEN
    (* 复位可恢复的故障状态 *)
    IF NOT Gate_Area_Occupied THEN
        (* 障碍物清除后自动复位，无需手动复位 *)
    END_IF;

    IF NOT Overcurrent_V1 THEN
        Overcurrent_Latched_V1 := FALSE;
    END_IF;

    IF NOT Overcurrent_V2 THEN
        Overcurrent_Latched_V2 := FALSE;
    END_IF;

    (* 电源故障需要故障源清除后才能复位 *)
    IF NOT Power_Loss_Alarm THEN
        Power_Fault_Latched := FALSE;
    END_IF;
END_IF;

(* ============================================================================
   系统未使能时的处理
   ============================================================================ *)

IF NOT Enable THEN
    (* 清除锁存的故障状态 *)
    Overcurrent_Latched_V1 := FALSE;
    Overcurrent_Latched_V2 := FALSE;
    Power_Fault_Latched := FALSE;
END_IF;

END_FUNCTION_BLOCK