
#ifndef E_UART_H
#define E_UART_H

#ifdef __cplusplus
extern "C" {
#endif

/****************** Include Files ********************/
#include "xil_types.h"
#include "xstatus.h"

#define EA_TX_BYTE_FIFO_OFFSET 0x00
#define EA_TX_WORD_FIFO_OFFSET 0x04
#define EA_RX_BYTE_FIFO_OFFSET 0x08
#define EA_RX_WORD_FIFO_OFFSET 0x0C
#define EA_INT_STAT_OFFSET     0x10
#define EA_INT_MASK_OFFSET     0x14
#define EA_CTRL_OFFSET         0x18
// Offset 0x1C reserved
#define EA_BAUDRATE_CNTR_OFFSET   0x20
#define EA_OVERSAMPLE_CNTR_OFFSET 0x24
#define EA_INT_HOLDOFF_CFG_OFFSET 0x28
// Offset 0x2C reserved
// Offset 0x30 reserved
// Offset 0x34 reserved
#define EA_TX_FIFO_CNT_OFFSET     0x38
#define EA_RX_FIFO_CNT_OFFSET     0x3C

// Offset 0x10 and 0x14
#define EA_INT_STAT_RX_COALSC_TIME  0x10
#define EA_INT_STAT_RX_COALSC_BYTES 0x08
#define EA_INT_STAT_RX_NE         0x04
#define EA_INT_STAT_TX_AE         0x02
#define EA_INT_STAT_TX_EMPTY      0x01

// Offset 0x18
#define EA_CTRL_RX_EN           0x02
#define EA_CTRL_TX_EN		0x01

// Offset 0x28 - Int Coalesce
#define EA_INT_HOLDOFF_BYTES_MASK    0x7FF
#define EA_INT_HOLDOFF_BYTES_SHIFT   16
#define EA_INT_HOLDOFF_CLK_CNT_MASK  0x7FF
#define EA_INT_HOLDOFF_CLK_CNT_SHIFT 0
/**************************** Type Definitions *****************************/
/**
 *
 * Write a value to a E_UART register. A 32 bit write is performed.
 * If the component is implemented in a smaller width, only the least
 * significant data is written.
 *
 * @param   BaseAddress is the base address of the E_UARTdevice.
 * @param   RegOffset is the register offset from the base to write to.
 * @param   Data is the data written to the register.
 *
 * @return  None.
 *
 * @note
 * C-style signature:
 * 	void E_UART_mWriteReg(u32 BaseAddress, unsigned RegOffset, u32 Data)
 *
 */
#define E_UART_mWriteReg(BaseAddress, RegOffset, Data) \
  	Xil_Out32((BaseAddress) + (RegOffset), (u32)(Data))

/**
 *
 * Read a value from a E_UART register. A 32 bit read is performed.
 * If the component is implemented in a smaller width, only the least
 * significant data is read from the register. The most significant data
 * will be read as 0.
 *
 * @param   BaseAddress is the base address of the E_UART device.
 * @param   RegOffset is the register offset from the base to write to.
 *
 * @return  Data is the data from the register.
 *
 * @note
 * C-style signature:
 * 	u32 E_UART_mReadReg(u32 BaseAddress, unsigned RegOffset)
 *
 */
#define E_UART_mReadReg(BaseAddress, RegOffset) \
    Xil_In32((BaseAddress) + (RegOffset))

/************************** Function Prototypes ****************************/
/**
 *
 * Run a self-test on the driver/device. Note this may be a destructive test if
 * resets of the device are performed.
 *
 * If the hardware system is not built correctly, this function may never
 * return to the caller.
 *
 * @param   baseaddr_p is the base address of the E_UART instance to be worked on.
 *
 * @return
 *
 *    - XST_SUCCESS   if all self-test code passed
 *    - XST_FAILURE   if any self-test code failed
 *
 * @note    Caching must be turned off for this function to work.
 * @note    Self test may fail if data memory and device are not on the same bus.
 *
 */
//XStatus E_UART_Reg_SelfTest(void * baseaddr_p);

#ifdef __cplusplus
}
#endif
#endif // E_UART_H
