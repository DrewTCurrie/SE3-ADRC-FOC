# FOC Control on Stepper Motors for Undergraduate Research Project

This repository hosts the code, documentation, and related materials for an Undergraduate Research Project conducted at Montana State University. The project focuses on advancing manufacturing processes through the application of Field Oriented Control (FOC) to measure force feedback on small CNC (Computer Numerical Control) machines.

## Conceptual Block Diagram
![Conceptual Block Diagram of the system code](https://github.com/Direxfire/FAMP/blob/main/Reference%20Materials/Diagrams/Conceptual%20Flow%20Chart.png)
## Project Overview

Manufacturing processes, particularly those involving CNC machines, require precise control over motion, force, and position to ensure high-quality output. Traditional control methods for small CNC machines often rely on open-loop systems, which may lack the accuracy and responsiveness needed for intricate machining operations. By implementing FOC, which allows for precise control over motor current and position, this project seeks to enhance the capabilities of small CNC machines by enabling the measurement of force feedback.

## Page index
1. [Project Overview](#project-overview)
2. [Objectives](#objectives)
3. [Impact](#impact)
4. [Collaborators](#collaborators)
5. [Current Work in Progress](#current-work-in-progress)
6. [Table of Contents](#table-of-contents)

## Table of Contents
1. [Caleb Notes](Caleb%20Notes/)
2. [CplusplusTests](CplusplusTests/)
3. [Drew's Daily Notes](Drew's%20Daily%20Notes/)
4. [Meeting Minutes](Meeting%20Minutes/)
   - [Advisor Meeting](Meeting%20Minutes/Advisor%20Meetings/)
   - [Group Meetings](Meeting%20Minutes/Group%20Meetings/)
5. [PocketV2 References](PocketV2%20Refernces/V2_Schematics_9-28-2023/)
6. [Reference Materials](Reference%20Materials/)
   - [Diagrams](Reference%20Materials/Diagrams/)
   - [Filter Design](Reference%20Materials/Filter%20Design/)
   - [Force Measurement](Reference%20Materials/Force%20Measurment/)
   - [State Space Controls](Reference%20Materials/StateSpace/)
   - [Stepper Motor Modeling](Reference%20Materials/StepperMotorModeling/)
7. [Simulations](Simulations/)
8. [TMC BoB Schematics](TMC%20BoB%20Schematics/)
9. [C-PID Current Control Test Repository](https://github.com/Direxfire/CPID)
10. [C-PID Current Control Prototype Analysis](https://github.com/Direxfire/StepperMotorFOC/tree/main/PrototypingAnalysis/CPID%20Current%20Control%20Test%20)
11. [SSPID Current Control Test Repository](https://github.com/Direxfire/SSPID)
12. [SSPID Current Control Prototype 1 Analysis](https://github.com/Direxfire/StepperMotorFOC/tree/main/PrototypingAnalysis/SSPID%20Current%20Control%20Test%201)
      - [MSP430FR2310 I2C Communication Issues](https://github.com/Direxfire/StepperMotorFOC/blob/main/PrototypingAnalysis/SSPID%20Current%20Control%20Test%201/Analysis%20of%20MSP430FR2310%20I2C%20Communications.md)
13. [MSP430FR2310 ADC Firmware](https://github.com/Direxfire/MSP430FR2310-ADCFirmware)      
### Objectives

- Implement FOC on stepper motors used in small CNC machines, specifically the Penta PocketNC.
- Develop algorithms to calculate torque and force applied during machining operations.
- Integrate force measurement capabilities into the CNC machine's control system.
- Validate the effectiveness of FOC-based force feedback control through experimentation and testing.

### Impact

The successful implementation of FOC-based force feedback control on small CNC machines has the potential to revolutionize manufacturing processes, especially in industries requiring high precision and accuracy. By accurately measuring and controlling the force applied during machining operations, manufacturers can achieve improved surface finish, dimensional accuracy, and overall quality of machined parts. Additionally, the integration of FOC technology can lead to increased efficiency, reduced production costs, and enhanced competitiveness in the manufacturing sector.

### Collaborators

This project is a collaborative effort involving researchers, faculty members, and students from various departments at Montana State University. The interdisciplinary nature of the project allows for the integration of expertise from fields such as mechanical engineering, electrical engineering, and computer science, facilitating comprehensive research and development efforts.


## Current Work in Progress

- Developing FOC control algorithms for stepper motors.
- Conducting experiments to validate torque and force measurement capabilities.
- Integrating force feedback control into CNC machine's control system.
