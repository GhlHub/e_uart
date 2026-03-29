//#include  <xparameters.h>

#include <e_uart.h>
#include <e_uart_obj.h>

static void StubHandler(void *CallBackRef, unsigned int ByteCount);

// So rx/tx handlers look like this
// static void StubHandler(void *CallBackRef, unsigned int ByteCount)

void  Xil_Out32(UINTPTR ptr, u32 data) {
	*(u32 *)(ptr) = data;
}

u32  Xil_In32(UINTPTR ptr){
	u32 x;
	x = *(u32 *)(ptr);
	return x;
}


int EUart_CfgInitialize(PEUart uPtr, UINTPTR EffectiveAddr, u32 BusSpeedHz, u32 BaudRate)
{
	u32 oversample_clock_ticks;
	u32 baudrate_clock_ticks;
	u32 clk_holdoff;
	u32 byte_holdoff;
	u32 x32;

	/*
	 * Assert validates the input arguments
	 */
	Xil_AssertNonvoid(uPtr != NULL);

	/*
	 * Set some default values, including setting the callback
	 * handlers to stubs.
	 */
	uPtr->BaseAddress = EffectiveAddr;

	uPtr->rxCallbackRef = StubHandler;
	uPtr->txCallbackRef = StubHandler;
	uPtr->intMaskShadow = 0;
	uPtr->rxHandler     = NULL;
	uPtr->txHandler		= NULL;

	// Disable tx / rx
	E_UART_mWriteReg(uPtr->BaseAddress, EA_CTRL_OFFSET, 0);

	oversample_clock_ticks = (u32) (((float)BusSpeedHz / ((float)BaudRate * 5.0)) + 0.5);
	baudrate_clock_ticks   = (u32) (((float)BusSpeedHz / (float)BaudRate) + 0.5);

	E_UART_mWriteReg(uPtr->BaseAddress, EA_BAUDRATE_CNTR_OFFSET,   baudrate_clock_ticks-1);
	E_UART_mWriteReg(uPtr->BaseAddress, EA_OVERSAMPLE_CNTR_OFFSET, oversample_clock_ticks-1);
	E_UART_mWriteReg(uPtr->BaseAddress, EA_INT_MASK_OFFSET, 0);

	// Program coalescing registers
	// rx interrupt coalescing
	// Depending on the application, these can be optimized to further minimize interrupts without
	// sacrificing responsiveness
	clk_holdoff = 5;
	byte_holdoff = 5;
	x32 = ((clk_holdoff   & EA_INT_HOLDOFF_CLK_CNT_MASK) << EA_INT_HOLDOFF_CLK_CNT_SHIFT) |
		  (((byte_holdoff & EA_INT_HOLDOFF_BYTES_MASK)   << 16));
	E_UART_mWriteReg(uPtr->BaseAddress, EA_INT_HOLDOFF_CFG_OFFSET, x32);
	return XST_SUCCESS;
}

void EUart_Enable(PEUart pUart) {
	E_UART_mWriteReg(pUart->BaseAddress, EA_CTRL_OFFSET, EA_CTRL_TX_EN | EA_CTRL_RX_EN);
}

u32 EUart_RdDebugStat(PEUart pUart) {
	u32 x;
	x = E_UART_mReadReg(pUart->BaseAddress, EA_CTRL_OFFSET);
	return x;
}

void EUart_EnableTxInterrupt(PEUart uPtr, u32 flags) {
	// flags could be 0 or EA_INT_STAT_TX_AE
	uPtr->intMaskShadow |= (flags | EA_INT_STAT_TX_EMPTY);
	E_UART_mWriteReg(uPtr->BaseAddress, EA_INT_MASK_OFFSET, uPtr->intMaskShadow);
}

void EUart_DisableTxInterrupt(PEUart uPtr, u32 flags) {
	// flags could be 0 or EA_INT_STAT_TX_AE
	uPtr->intMaskShadow &= ~(0xffffffff & (flags | EA_INT_STAT_TX_EMPTY));
	E_UART_mWriteReg(uPtr->BaseAddress, EA_INT_MASK_OFFSET, uPtr->intMaskShadow);
}

void EUart_EnableRxInterrupt(PEUart uPtr) {
	uPtr->intMaskShadow |= (EA_INT_STAT_RX_COALSC_TIME | EA_INT_STAT_RX_COALSC_BYTES);
		// For now we don't use the not empty interrupt and rely on interrupt coalescing
	E_UART_mWriteReg(uPtr->BaseAddress, EA_INT_MASK_OFFSET, uPtr->intMaskShadow);
}

void EUart_DisableRxInterrupt(PEUart uPtr) {
	uPtr->intMaskShadow &= ~(EA_INT_STAT_RX_COALSC_TIME | EA_INT_STAT_RX_COALSC_BYTES);
		// For now we don't use the not empty interrupt and rely on interrupt coalescing
	E_UART_mWriteReg(uPtr->BaseAddress, EA_INT_MASK_OFFSET, uPtr->intMaskShadow);
}

void EUart_EnableInterrupt(PEUart uPtr) {
	E_UART_mWriteReg(uPtr->BaseAddress, EA_INT_MASK_OFFSET, uPtr->intMaskShadow);
}

void EUart_SendByte(PEUart uPtr, u8 data) {
	E_UART_mWriteReg(uPtr->BaseAddress, EA_TX_BYTE_FIFO_OFFSET, data);
}

void EUart_SendWord(PEUart uPtr, u32 word) {
	E_UART_mWriteReg(uPtr->BaseAddress, EA_TX_WORD_FIFO_OFFSET, word);
}

u32 EUart_SendFifoOccupancy(PEUart uPtr) {
	u32 occupancy;
	occupancy = E_UART_mReadReg(uPtr->BaseAddress, EA_TX_FIFO_CNT_OFFSET);
	if(occupancy > 1024)
		occupancy = 1024;
	return occupancy;
}

u8 EUart_RecvByte(PEUart uPtr) {
	u32 rx;
	rx = E_UART_mReadReg(uPtr->BaseAddress, EA_RX_BYTE_FIFO_OFFSET);
	return rx;
}

u32 EUart_RecvWord(PEUart pUart) {
	u32 rx;
	rx = E_UART_mReadReg(pUart->BaseAddress, EA_RX_WORD_FIFO_OFFSET);
	return rx;
}

u32 EUart_RecvFifoOccupancy(PEUart pUart) {
	u32 occupancy;
	occupancy = E_UART_mReadReg(pUart->BaseAddress, EA_RX_FIFO_CNT_OFFSET);
	return occupancy;
}

void EUart_Isr(PEUart pUart) {
	u32 intStatus;
	u32 rx_bytes_avail;
	u32 tx_bytes_avail;

	E_UART_mWriteReg(pUart->BaseAddress, EA_INT_MASK_OFFSET, 0);
	intStatus = E_UART_mReadReg(pUart->BaseAddress, EA_INT_STAT_OFFSET);
	// Check for rx interrupts first
	// Here we look at the NotEmpty flag since we are already here, might as well try to process it.
	if(intStatus & (EA_INT_STAT_RX_COALSC_TIME |
			        EA_INT_STAT_RX_COALSC_BYTES |
					EA_INT_STAT_RX_NE)) {
		// process rx ints
		// We call the rx callback routine
		//EUart_DisableRxInterrupt(pUart);
		if(pUart->rxHandler) {
			rx_bytes_avail = EUart_RecvFifoOccupancy(pUart);
			pUart->rxHandler(pUart->rxCallbackRef, rx_bytes_avail);
		}
		//EUart_EnableRxInterrupt(pUart);
	}
	if(intStatus & (EA_INT_STAT_TX_AE |
			        EA_INT_STAT_TX_EMPTY)) {
		// process tx ints
		// We call the tx callback routine
		//EUart_DisableTxInterrupt(pUart, EA_INT_STAT_TX_AE);
		if(pUart->txHandler) {
			tx_bytes_avail = EUart_SendFifoOccupancy(pUart);
			pUart->txHandler(pUart->txCallbackRef, tx_bytes_avail);
		}
	}
	E_UART_mWriteReg(pUart->BaseAddress, EA_INT_MASK_OFFSET, pUart->intMaskShadow);
	// EUart_EnableInterrupt(uPtr)
	// We let the application decide when to turn this back on
}

void EUart_SetRxHandler(PEUart pUart, EUart_Handler FuncPtr, void *CallBackRef) {
	pUart->rxHandler     = FuncPtr;
	pUart->rxCallbackRef = CallBackRef;
}

void EUart_SetTxHandler(PEUart pUart, EUart_Handler FuncPtr, void *CallBackRef) {
	pUart->txHandler     = FuncPtr;
	pUart->txCallbackRef = CallBackRef;
}



static void StubHandler(void *CallBackRef, unsigned int ByteCount) {
	Xil_AssertVoidAlways();
}

