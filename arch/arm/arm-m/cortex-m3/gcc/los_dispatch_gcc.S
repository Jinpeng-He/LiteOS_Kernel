/** ----------------------------------------------------------------------------
 * Copyright (c) <2016-2018>, <Huawei Technologies Co., Ltd>
 * All rights reserved.
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 * 1. Redistributions of source code must retain the above copyright notice, this list of
 * conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice, this list
 * of conditions and the following disclaimer in the documentation and/or other materials
 * provided with the distribution.
 * 3. Neither the name of the copyright holder nor the names of its contributors may be used
 * to endorse or promote products derived from this software without specific prior written
 * permission.
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *---------------------------------------------------------------------------*/
/** ----------------------------------------------------------------------------
 * Notice of Export Control Law
 * ===============================================
 * Huawei LiteOS may be subject to applicable export control laws and regulations, which might
 * include those applicable to Huawei LiteOS of U.S. and the country in which you are located.
 * Import, export and usage of Huawei LiteOS in any manner by you shall be in compliance with such
 * applicable export control laws and regulations.
 *---------------------------------------------------------------------------*/

/****************************************************************************************
*                                  EXPORT FUNCTIONS
****************************************************************************************/

    .global  LOS_IntLock
    .global  LOS_IntUnLock
    .global  LOS_IntRestore
    .global  LOS_StartToRun
    .global  osTaskSchedule
    .global  PendSV_Handler

/****************************************************************************************
*                                  EXTERN PARAMETERS
****************************************************************************************/

    .extern  g_stLosTask
    .extern  g_pfnTskSwitchHook
    .extern  g_bTaskScheduled

/****************************************************************************************
*                                  EQU
****************************************************************************************/

.equ    OS_NVIC_INT_CTRL,              0xE000ED04  /* Interrupt Control and State Register. */
.equ    OS_NVIC_PENDSVSET,             0x10000000  /* Value to trigger PendSV exception. */

.equ    OS_NVIC_SYSPRI2,               0xE000ED20  /* System Handler Priority Register 2. */
.equ    OS_NVIC_PENDSV_SYSTICK_PRI,    0xFFFF0000  /* SysTick + PendSV priority level (lowest). */

.equ    OS_TASK_STATUS_RUNNING,        0x0010      /* Task Status Flag (RUNNING). */

/****************************************************************************************
*                                  CODE GENERATION DIRECTIVES
****************************************************************************************/

    .section .text
    .thumb
    .syntax unified
    .arch armv7-m

/****************************************************************************************
* Function:
*        VOID LOS_StartToRun(VOID);
* Description:
*        Start the first task, which is the highest priority task in the priority queue.
*        Other tasks are started by task scheduling.
****************************************************************************************/
    .type LOS_StartToRun, %function
LOS_StartToRun:
    //关闭中断
    CPSID   I

    /**
     * Set PendSV and SysTick prority to the lowest.
     * read ---> modify ---> write-back.
     *寄存器控制，设置PendSV和systick的优先级
     */
    LDR     R0, =OS_NVIC_SYSPRI2
    LDR     R1, =OS_NVIC_PENDSV_SYSTICK_PRI
    LDR     R2, [R0]
    ORR     R1, R1, R2
    STR     R1, [R0]

    /**
     * Set g_bTaskScheduled = 1.
     *使能调度，全局调度的总开关，如果该变量的值不为1，那么所有的调度功能不会生效
     */
    LDR     R0, =g_bTaskScheduled
    MOV     R1, #1
    STR     R1, [R0]

    /**
     * Set g_stLosTask.pstRunTask = g_stLosTask.pstNewTask.
     * |<---pstRunTask--->|<---pstNewTask--->|
     * |<----4 byte------>|<----4 byte------>|
     */
    LDR     R0, =g_stLosTask
    LDR     R1, [R0, #4]
    STR     R1, [R0]

    /**
     * Set g_stLosTask.pstRunTask->usTaskStatus |= OS_TASK_STATUS_RUNNING.
     */
    //R1 = g_stLosTask.pstRunTask
    LDR     R1, [R0]
    // R2 = g_stLosTask.pstRunTask->usTaskStatus
    LDRH    R2, [R1, #4]
    // R3 = OS_TASK_STATUS_RUNNING
    MOV     R3, #OS_TASK_STATUS_RUNNING
    // R2 = R2|R3
    ORR     R2, R2, R3
    //g_stLosTask.pstRunTask->usTaskStatus = *(R1+4) = R2 ,这里4就是usTaskStatus在LOS_TASK_CB中的偏移，R1为pStackPointer
    STRH    R2, [R1, #4]

    /**
     * Restore the default stack frame(R0-R3,R12,LR,PC,xPSR) of g_stLosTask.pstRunTask to R0-R7.
     * Return by setting the CONTROL register.
     *
     * The initial stack of the current running task is as follows:
     *
     *                 POP: Restore the context of the current running task ===>|
     *                                                             High addr--->|
     *                                                   Bottom of the stack--->|
     * ----------+-----------------------+--------------------------------------+
     *           |   R4-R11,   PRIMASK   |   R0-R3,   R12,   LR,   PC,   xPSR   |
     * ----------+-----------------------+--------------------------------------+
     *           |<---Top of the stack, restored from g_stLosTask.pstRunTask->pStackPointer
     *           |<---      skip     --->|<---        copy to R0-R7         --->|
     *                                                            R12 to PSP--->|
     *                                    Stack pointer after LOS_StartToRun--->|
     */
     // R12 = *R1 = *pStackPointer,为当前的栈顶指针,任务上下文出栈
    LDR     R12, [R1]
    ADD     R12, R12, #36          /* skip R4-R11, PRIMASK. */
    LDMFD   R12!, {R0-R7}       //从R12处作为栈出栈到R0-R7

    /**
     * Set the stack pointer of g_stLosTask.pstRunTask to PSP.
     PSP = R12
     */
    MSR     PSP, R12

    /**
     * Set the CONTROL register, after schedule start, privilege level and stack = PSP.
     * 栈指针从MSP切换到PSP
     */
    MOV     R12, #2
    MSR     CONTROL, R12

    /**
     * Enable interrupt. (The default PRIMASK value is 0, so enable directly)
     */
    // LR = R5 = osTaskExit 任务执行完毕退出时候执行的函数
    MOV     LR, R5
    CPSIE   I

    /**
     * Jump directly to the default PC of g_stLosTask.pstRunTask, the field information
     * of the main function will be destroyed and will never be returned.
     * PC = R6 跳转到新的任务执行
     */
    BX      R6

/****************************************************************************************
* Function:
*        UINTPTR LOS_IntLock(VOID);
* Description:
*        Disable all interrupts except Reset,NMI and HardFault.
*        The value of currnet interruption state will be returned to the caller to save.
*
* Function:
*        VOID LOS_IntRestore(UINTPTR uvIntSave);
* Description:
*        Restore the locked interruption of LOS_IntLock.
*        The caller must pass in the value of interruption state previously saved.
****************************************************************************************/
    .type LOS_IntLock, %function
LOS_IntLock:
    MRS     R0, PRIMASK
    CPSID   I
    BX      LR

    .type LOS_IntUnLock, %function
LOS_IntUnLock:
    MRS     R0, PRIMASK
    CPSIE   I
    BX      LR

    .type LOS_IntRestore, %function
LOS_IntRestore:
    MSR     PRIMASK, R0
    BX      LR

/****************************************************************************************
* Function:
*        VOID osTaskSchedule(VOID);
* Description:
*        Start the task swtich process by software trigger PendSV interrupt.
****************************************************************************************/
    .type osTaskSchedule, %function
osTaskSchedule:
    //软件触发PendSV中断
    LDR     R0, =OS_NVIC_INT_CTRL
    LDR     R1, =OS_NVIC_PENDSVSET
    STR     R1, [R0]
    BX      LR

/****************************************************************************************
* Function:
*        VOID PendSV_Handler(VOID);
* Description:
*        PendSV interrupt handler, switch the context of the task.
*        First: Save the context of the current running task(g_stLosTask.pstRunTask)
*               to its own stack.
*        Second: Restore the context of the next running task(g_stLosTask.pstNewTask)
*                from its own stack.
****************************************************************************************/
    .type PendSV_Handler, %function
PendSV_Handler:
    /**
     * R12: Save the interruption state of the current running task.
     * Disable all interrupts except Reset,NMI and HardFault
     */
    // R12 = PRIMASK 保存当前任务的中断状态，用于恢复
    MRS     R12, PRIMASK
    //关闭中断
    CPSID   I

    /**
     * Call task switch hook.
     */
    LDR     R2, =g_pfnTskSwitchHook
    LDR     R2, [R2]
    CBZ     R2, TaskSwitch
    PUSH    {R12, LR}
    BLX     R2
    POP     {R12, LR}

TaskSwitch:
    /**
     * R0 = now stack pointer of the current running task.
     */
    // R0 = PSP
    MRS     R0, PSP

    /**
     * Save the stack frame(R4-R11) of the current running task.
     * R12 save the PRIMASK value of the current running task.
     * NOTE: Before entering the exception handler function, these registers
     *       (xPSR,PC,LR,R12,R3-R0) have been automatically
     *       saved by the CPU in the stack of the current running task.
     *
     * The stack of the current running task is as follows:
     *
     *           |<=== PUSH: Save the context of the current running task
     *           |                                                      High addr--->|
     * ----------+-----------------------+--------------------------------------+-----
     *           |   R4-R11,   PRIMASK   |   R0-R3,   R12,   LR,   PC,   xPSR   |
     * ----------+-----------------------+--------------------------------------+-----
     *                               Stack pointer before entering exception--->|
     *                                   |<---        cpu auto saved        --->|
     *                                   |<---PSP to R0
     *           |<---Top of the stack, save to g_stLosTask.pstRunTask->pStackPointer
     */
    //R4-R12依次进栈，保存任务上下文，开始切换,当前以R0作为栈地址指针
    STMFD   R0!, {R4-R12}          /* save the core registers and PRIMASK. */

    /**
     * R5,R8.
     */
    LDR     R5, =g_stLosTask
    MOV     R8, #OS_TASK_STATUS_RUNNING

    /**
     * Save the stack pointer of the current running task to TCB.
     * (g_stLosTask.pstRunTask->pStackPointer = R0)
     */
    // R6 = g_stLosTask.pstRunTask->pStackPointer
    LDR     R6, [R5]
    //g_stLosTask.pstRunTask->pStackPointer = R0，保存栈指针
    STR     R0, [R6]

    /**
     * Clear the RUNNING state of the current running task.
     * (g_stLosTask.pstRunTask->usTaskStatus &= ~OS_TASK_STATUS_RUNNING)
     */
    // R7 = g_stLosTask.pstRunTask->usTaskStatus，R6指向pstRunTask，所以这里加4获取状态
    LDRH    R7, [R6, #4]
    // R7 &= ~R8
    BIC     R7, R7, R8
    //写回 g_stLosTask.pstRunTask->usTaskStatus = *(R6+4) = R7
    STRH    R7, [R6, #4]

    /**
     * Switch the current running task to the next running task.
     * (g_stLosTask.pstRunTask = g_stLosTask.pstNewTask)
     */
    // R5指向g_stLosTask也就是pstRunTask，里面跳过4个字节就是pstNewTask
    // R0 = pstNewTask
    LDR     R0, [R5, #4]
    //pstRunTask=*R5 = R0 = pstNewTask
    STR     R0, [R5]

    /**
     * Set the RUNNING state of the next running task.
     * (g_stLosTask.pstNewTask->usTaskStatus |= OS_TASK_STATUS_RUNNING)
     */
    LDRH    R7, [R0, #4]
    ORR     R7, R7, R8
    STRH    R7, [R0, #4]

    /**
     * Restore the stack pointer of the next running task from TCB.
     * (R1 = g_stLosTask.pstNewTask->pStackPointer)
     */
    LDR     R1, [R0]

    /**
     * Restore the stack frame(R4-R11) of the next running task.
     * R12 restore the PRIMASK value of the next running task.
     * NOTE: After exiting the exception handler function, these registers
     *       (PC,xPSR,R0-R3,R12,LR) will be automatically
     *       restored by the CPU from the stack of the next running task.
     *
     * 1. The stack of the next running task is as follows:
     *
     *                    POP: Restore the context of the next running task ===>|
     *                                                                  High addr--->|
     * ----------+-----------------------+--------------------------------------+-----
     *           |   R4-R11,   PRIMASK   |   R0-R3,   R12,   LR,   PC,   xPSR   |
     * ----------+-----------------------+--------------------------------------+-----
     *           |<---Top of the stack, restored from g_stLosTask.pstNewTask->pStackPointer
     *                      R1 to PSP--->|
     *                                   |<---      cpu auto restoring      --->|
     *                                 Stack pointer after exiting exception--->|
     *
     * 2. If the next running task is run for the first time, the stack is as follows:
     *
     *                    POP: Restore the context of the next running task ===>|
     *                                                             High addr--->|
     *                                                   Bottom of the stack--->|
     * ----------+-----------------------+--------------------------------------+
     *           |   R4-R11,   PRIMASK   |   R0-R3,   R12,   LR,   PC,   xPSR   |
     * ----------+-----------------------+--------------------------------------+
     *           |<---Top of the stack, restored from g_stLosTask.pstNewTask->pStackPointer
     *                      R1 to PSP--->|
     *                                   |<---      cpu auto restoring      --->|
     *                                 Stack pointer after exiting exception--->|
     */
    // 以R1作为栈指针出栈
    LDMFD   R1!, {R4-R12}          /* restore the core registers and PRIMASK. */

    /**
     * Set the stack pointer of the next running task to PSP.
     */
    // 栈指针重新赋值切换到新的任务的栈PSP = R1
    MSR     PSP, R1

    /**
     * Restore the interruption state of the next running task.
     *PRIMASK = R12将新的任务的状态恢复，跳转
     */
    MSR     PRIMASK, R12
    BX      LR

