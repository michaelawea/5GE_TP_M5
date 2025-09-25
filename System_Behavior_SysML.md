# 双扇门控制系统 - SysML行为规范

## 1. 系统行为需求 (Behavioral Requirements)

### BR1: 命令处理行为
- **BR1.1**: 单门命令 (cmd_v1) → 仅控制门1
- **BR1.2**: 双门命令 (cmd_v12) → 同时控制门1和门2
- **BR1.3**: 遥控/键盘命令与对讲命令逻辑OR合并
- **BR1.4**: 命令优先级: 双门控制激活时屏蔽单门命令

### BR2: 门状态定义
- **BR2.1**: State=0 → CLOSED (关闭)
- **BR2.2**: State=1 → OPENING (开启中)
- **BR2.3**: State=2 → OPEN (开启)
- **BR2.4**: State=3 → CLOSING (关闭中)

## 2. 单门控制行为场景 (Single Gate Control)

### SC1: 单门命令响应
**触发条件**: `cmd_v1_combined = TRUE`
**前置条件**: `Enable = TRUE AND NOT Dual_Active`

| 当前状态 | 行为 | 输出 |
|---------|------|------|
| Gate1_CLOSED | 开始开门 | Open_Command_V1 = TRUE |
| Gate1_OPEN | 开始关门 | Close_Command_V1 = TRUE |
| Gate1_OPENING | 停止并关门 | Close_Command_V1 = TRUE |
| Gate1_CLOSING | 继续关门 | Close_Command_V1 = TRUE |

## 3. 双门控制行为场景 (Dual Gate Control)

### SC2: 双门开启序列
**触发条件**: `cmd_v12_combined = TRUE AND Both_Gates_Closed`
**执行序列**:
1. T=0: Open_Command_V1 = TRUE (门1先开)
2. T=0~1000: Dual_Open_Counter++ (延时计数)
3. T=1000: Open_Command_V2 = TRUE (门2后开)
4. 持续输出直到 cmd_v12_combined = FALSE

### SC3: 双门关闭序列
**触发条件**: `cmd_v12_combined = TRUE AND Both_Gates_Open`
**执行序列**:
1. T=0: Close_Command_V2 = TRUE (门2先关)
2. T=0~1000: Dual_Close_Counter++ (延时计数)
3. T=1000: Close_Command_V1 = TRUE (门1后关)
4. 持续输出直到 cmd_v12_combined = FALSE

## 4. Gate Control状态机行为

### SC4: 门状态转换
```
CLOSED(0) --[Open_Cmd & Enable & !Error & !Bar_Lumineuse]--> OPENING(1)
OPENING(1) --[Sensor_Open]--> OPEN(2)
OPENING(1) --[Overcurrent | Close_Cmd]--> CLOSING(3)
OPENING(1) --[Bar_Lumineuse]--> OPENING(1) [Motor停止,保持位置]
OPEN(2) --[Close_Cmd | Open_Cmd]--> CLOSING(3)
CLOSING(3) --[Sensor_Close]--> CLOSED(0)
CLOSING(3) --[Overcurrent | Open_Cmd]--> OPENING(1)
CLOSING(3) --[Bar_Lumineuse]--> CLOSING(3) [Motor停止,保持位置]
```

### SC5: 安全响应行为

#### SC5.1: 移动区域检测 (Bar_Lumineuse)
**功能**: 检测门扇移动区域内是否有人/物体
**触发条件**: `Bar_Lumineuse = TRUE` (检测到有人进入移动区域)

| 当前状态 | 响应行为 | 输出 |
|---------|---------|------|
| OPENING | 立即停止开门 | Motor_Open=FALSE, 保持当前位置 |
| CLOSING | 立即停止关门 | Motor_Close=FALSE, 保持当前位置 |
| CLOSED/OPEN | 禁止启动新动作 | 屏蔽所有命令 |

#### SC5.2: 过流保护 (Overcurrent)
**功能**: 检测门扇是否受阻（夹到物体/强行阻挡）
**触发条件**: `Overcurrent = TRUE` (电机过流)

| 当前状态 | 响应行为 | 输出 |
|---------|---------|------|
| OPENING | 立即停止 | Motor_Open=FALSE, Error=TRUE |
| CLOSING | 立即停止 | Motor_Close=FALSE, Error=TRUE |

#### SC5.3: 紧急停止
**触发条件**: `Emergency_Stop = FALSE` (常闭触点断开)
**响应**: 立即停止所有电机，Error=TRUE

## 5. 辅助设备控制行为

### SC6: 警告灯控制
- **条件**: Any_Gate_Moving (Gate1_State ∈ {1,3} OR Gate2_State ∈ {1,3})
- **输出**: Warning_Light = TRUE

### SC7: 区域照明控制
- **条件**: cmd_v1_combined OR cmd_v12_combined
- **输出**: Area_Light = TRUE

## 6. 异常处理场景

### SC8: 系统未使能
**条件**: `Enable = FALSE`
**行为**:
- 所有输出命令 = FALSE
- 保持当前门位置状态
- Warning_Light = FALSE

### SC9: 错误状态处理
**错误代码**:
- 1001: 安全故障 (Emergency_Stop OR Overcurrent)
- 1003: 系统未使能

## 7. 缺失功能场景 ⚠️

### SC10: 移动区域人员检测 [未实现]
**需求**: Bar_Lumineuse = TRUE → 检测到人员进入移动区域，立即停止所有门运动
**建议实现**:
```
IF Bar_Lumineuse THEN
    (* 停止所有电机但不触发错误 *)
    Motor_Open := FALSE
    Motor_Close := FALSE
    (* 保持当前位置，等待区域清空 *)
    Movement_Blocked := TRUE
END_IF
```

### SC11: 市电缺失报警 [未实现]
**需求**: Alarm_Abs_Secteur = TRUE → 系统报警+切换应急模式
**建议实现**:
```
IF Alarm_Abs_Secteur THEN
    System_Alarm := TRUE
    Emergency_Mode := TRUE
END_IF
```

### SC12: 自动关门 [未实现]
**需求**: 门开启后延时自动关闭
**建议实现**:
```
IF Gate_Open AND Auto_Close_Timer > Timeout THEN
    Trigger_Close_Command
END_IF
```

### SC13: 照明延时关闭 [未实现]
**需求**: 命令结束后延时关闭照明
**建议实现**:
```
IF NOT Any_Command AND Light_Timer < Delay THEN
    Area_Light := TRUE
ELSE
    Area_Light := FALSE
END_IF
```

## 8. 系统约束 (Constraints)

### CR1: 时序约束
- 双门延时: 1000 PLC周期
- 命令响应: < 1个扫描周期
- 安全响应: 立即 (同周期)

### CR2: 互锁约束
- 单门与双门命令互斥
- 开门与关门命令互斥
- 双门控制激活时屏蔽单门

### CR3: 优先级层次
1. 紧急停止 (最高)
2. 移动区域人员检测 (Bar_Lumineuse)
3. 过流保护 (防夹/受阻)
4. 用户命令 (最低)

## 9. 测试场景 (Test Cases)

### TC1: 正常操作
- 单门开关循环
- 双门开关循环
- 命令切换测试

### TC2: 安全功能
- 紧急停止响应
- 移动区域人员检测 [待实现]
- 过流保护（门扇受阻）触发

### TC3: 边界条件
- 运动中反向命令
- 同时多命令
- 系统未使能命令

### TC4: 异常恢复
- 故障后复位
- 电源恢复
- 手动操作切换

---
**版本**: 2.0
**日期**: 2025-09-25
**状态**: 部分功能待实现