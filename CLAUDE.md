# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a dual-swing gate control system project for Schneider Electric M340 PLC, programmed using Unity Pro. The system controls two gate panels for a private residence with pedestrian (single panel) and vehicle (dual panel) access modes.

## Development Environment

- **PLC**: Schneider Electric M340 (BMX P34 20102 V2.10)
- **Software**: Unity Pro
- **Languages**: Structured Text (ST) and Function Block Diagram (FBD)
- **Components**: DFB (Derived Function Blocks) and FFB (Factory Function Blocks)
- **Network**: Ethernet NOE 100.2 (IP: 134.214.184.171)

## Key I/O Configuration

### Outputs
- `%Q0.3.0`: Gate Panel 1 Open Command (开启_V1)
- `%Q0.3.1`: Gate Panel 1 Close Command (关闭_V1)
- `%Q0.3.2`: Gate Panel 2 Open Command (开启_V2)
- `%Q0.3.3`: Gate Panel 2 Close Command (关闭_V2)
- `%Q0.3.4`: Warning Light (信号灯)
- `%Q0.3.5`: Area Lighting (照明)

### Inputs
- `%I0.2.0`: Passage Sensor (Bar_Lumineuse)
- `%I0.2.1`: Panel 2 Fully Open Sensor (Capt_Ouv_V2)
- `%I0.2.2`: Panel 1 Fully Open Sensor (Capt_Ouv_V1)
- `%I0.2.3`: Panel 1 Fully Closed Sensor (Capt_Ferm_V1)
- `%I0.2.4`: Panel 2 Fully Closed Sensor (Capt_Ferm_V2)
- `%I0.2.5`: Panel 2 Overcurrent Sensor (Capt_Surintens_V2)
- `%I0.2.6`: Panel 1 Overcurrent Sensor (Capt_Surintens_V1)
- `%I0.2.7`: Intercom Panel 1 Command (Cmd_V1_Interphone)
- `%I0.2.8`: Intercom Dual Panel Command (Cmd_V12_Interphone)
- `%I0.2.9`: Remote/Keypad Panel 1 Command (Cmd_V1_Tele_Digi)
- `%I0.2.10`: Remote/Keypad Dual Panel Command (Cmd_V12_Tele_Digi)
- `%I0.2.11`: Mains Power Loss Alarm (Alarm_Abs_Secteur)

## Control Access Methods

1. **Remote Control**: Two buttons for single/dual panel control
2. **Keypad**: Code 1504 (single panel), Code 2502 (dual panel)
3. **Intercom**: Visitor doorbell with resident control buttons

## Safety Requirements

- Obstacle detection in movement zone (immediate stop)
- Overcurrent detection for anti-pinch protection (stop and reverse)
- Warning light activation during movement
- Mains power loss detection and alarm

## Development Approach

When implementing ST code for this project:
1. Focus on modular DFB design for reusable gate control logic
2. Implement safety checks as highest priority
3. Handle state transitions (closed → opening → open → closing → closed)
4. Manage command conflicts (e.g., close command during opening)
5. Use appropriate timers for gate operation sequences

## Code Generation Notes

- Generate Structured Text (ST) code compatible with Unity Pro IEC 61131-3 standard
- Use BOOL type for digital I/O signals
- Implement state machines using CASE statements
- Include proper safety interlocks and emergency stop logic
- Follow Unity Pro DFB structure with clear input/output definitions