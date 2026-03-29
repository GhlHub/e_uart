#ifndef E_UART_OBJ_H
#define E_UART_OBJ_H


#ifdef __cplusplus
extern "C" {
#endif


typedef struct {
#ifndef SDT
	u16 DeviceId;		/**< Unique ID  of device */
#else
	char *Name;
#endif
	UINTPTR RegBaseAddr;	/**< Register base address */
#ifdef SDT
	u16 IntrId;             /** Bits[11:0] Interrupt-id Bits[15:12]
				 * trigger type and level flags */
	UINTPTR IntrParent;     /** Bit[0] Interrupt parent type Bit[64/32:1]
				 * Parent base address */
#endif
} EUart_Config, *PEUart_Config;

typedef void (*EUart_Handler)(void *CallBackRef, unsigned int ByteCount);


extern EUart_Config EUart_Config_Table[];

typedef struct {
	UINTPTR BaseAddress;
	u32     IsReady;

	u32		intMaskShadow;
	EUart_Handler rxHandler;
	void *rxCallbackRef;
	EUart_Handler txHandler;
	void *txCallbackRef;


} EUart, *PEUart;

PEUart_Config EUart_LookupConfig(u16 DeviceId);
int EUart_CfgInitialize(PEUart uPtr, UINTPTR EffectiveAddr, u32 BusSpeedHz, u32 BaudRate);
void EUart_Enable(PEUart pUart);
u32 EUart_RdDebugStat(PEUart pUart);
void EUart_EnableTxInterrupt(PEUart uPtr, u32 flags);
void EUart_DisableTxInterrupt(PEUart uPtr, u32 flags);
void EUart_EnableRxInterrupt(PEUart uPtr);
void EUart_DisableRxInterrupt(PEUart uPtr);
void EUart_EnableInterrupt(PEUart uPtr);
void EUart_SendByte(PEUart uPtr, u8 data);
void EUart_SendWord(PEUart uPtr, u32 word);
u32 EUart_SendFifoOccupancy(PEUart uPtr);
u8  EUart_RecvByte(PEUart uPtr);
u32 EUart_RecvWord(PEUart pUart);
u32 EUart_RecvFifoOccupancy(PEUart pUart);
void EUart_Isr(PEUart pUart);
void EUart_SetRxHandler(PEUart pUart, EUart_Handler FuncPtr, void *CallBackRef);
void EUart_SetTxHandler(PEUart pUart, EUart_Handler FuncPtr, void *CallBackRef);



#ifdef __cplusplus
}
#endif
#endif
