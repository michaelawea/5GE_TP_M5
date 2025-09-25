(*
===============================================================================
DFB: DFB_Warning_Flash - 警告灯闪烁控制模块
===============================================================================
功能描述：
- 当接收到持续的闪烁命令时，产生周期性的闪烁输出
- 支持可配置的闪烁频率和占空比
- 安全异常时（过流、通道有人）用于警告灯闪烁

输入参数：
- Enable: 系统使能信号
- Flash_Command: 闪烁命令（来自United_Control_Logic的Warning_Light）
- Flash_Period: 闪烁周期（PLC扫描周期数，默认500=约500ms）
- Duty_Cycle: 占空比（百分比，默认50%）

输出参数：
- Warning_Light_Out: 警告灯物理输出（连接到%Q0.3.4）

工作原理：
- Flash_Command=FALSE: 警告灯关闭
- Flash_Command=TRUE: 警告灯按设定频率闪烁

作者: Claude Code Assistant
日期: 2025-09-25
版本: 1.0
===============================================================================
*)

FUNCTION_BLOCK DFB_Warning_Flash

VAR_INPUT
    Enable          : BOOL := TRUE;     (* 系统使能信号 *)
    Flash_Command   : BOOL;             (* 闪烁命令信号 *)
    Flash_Period    : INT := 500;       (* 闪烁周期（PLC周期数） *)
    Duty_Cycle      : INT := 50;        (* 占空比（百分比） *)
END_VAR

VAR_OUTPUT
    Warning_Light_Out : BOOL;           (* 警告灯物理输出 *)
END_VAR

VAR
    Flash_Counter   : INT := 0;         (* 闪烁计数器 *)
    On_Time         : INT;              (* 点亮时间 *)
    Flash_State     : BOOL := FALSE;    (* 当前闪烁状态 *)
END_VAR

(* ============================================================================ *)
(* 闪烁逻辑实现 *)
(* ============================================================================ *)

(* 计算点亮时间（基于占空比） *)
On_Time := (Flash_Period * Duty_Cycle) / 100;

(* 系统使能且有闪烁命令时才工作 *)
IF Enable AND Flash_Command THEN

    (* 闪烁计数器递增 *)
    Flash_Counter := Flash_Counter + 1;

    (* 根据计数器位置决定闪烁状态 *)
    IF Flash_Counter <= On_Time THEN
        Flash_State := TRUE;        (* 点亮阶段 *)
    ELSE
        Flash_State := FALSE;       (* 熄灭阶段 *)
    END_IF;

    (* 周期结束，重置计数器 *)
    IF Flash_Counter >= Flash_Period THEN
        Flash_Counter := 0;
    END_IF;

    (* 输出闪烁状态 *)
    Warning_Light_Out := Flash_State;

ELSE
    (* 没有闪烁命令或系统未使能，关闭警告灯 *)
    Warning_Light_Out := FALSE;
    Flash_Counter := 0;
    Flash_State := FALSE;
END_IF;

END_FUNCTION_BLOCK