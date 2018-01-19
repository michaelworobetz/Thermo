$MODLP51
org 0000H
   ljmp MainProgram

CLK  EQU 22118400
BAUD equ 115200
BRG_VAL equ (0x100-(CLK/(16*BAUD)))

CSEG

CE_ADC EQU P2.0
MY_MOSI EQU P2.1
MY_MISO EQU P2.2
MY_SCLK EQU P2.3

DSEG at 30H
x: ds 4
y: ds 4
bcd: ds 5
result: ds 4
print: ds 4
BCD_counter: ds 4

BSEG
mf: dbit 1


cseg
; These 'equ' must match the wiring between the microcontroller and the LCD!
LCD_RS equ P1.1
LCD_RW equ P1.2
LCD_E  equ P1.3
LCD_D4 equ P3.2
LCD_D5 equ P3.3
LCD_D6 equ P3.4
LCD_D7 equ P3.5
$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$include(math32.inc)
$LIST
Initial_Message: db  '   TEMP: xx C   ', 0
INIT_SPI:
 setb MY_MISO ; Make MISO an input pin
 clr MY_SCLK ; For mode (0,0) SCLK is zero
 ret

DO_SPI_G:
 push acc
 mov R1, #0 ; Received byte stored in R1
 mov R2, #8 ; Loop counter (8-bits)
DO_SPI_G_LOOP:
 mov a, R0 ; Byte to write is in R0
 rlc a ; Carry flag has bit to write
 mov R0, a
 mov MY_MOSI, c
 setb MY_SCLK ; Transmit
 mov c, MY_MISO ; Read received bit
 mov a, R1 ; Save received bit in R1
 rlc a
 mov R1, a
 clr MY_SCLK
 djnz R2, DO_SPI_G_LOOP
 pop acc
 ret
 
 
Do_Something_With_Result:
	mov x, Result
	mov x+1, Result+1
	mov x+2, #0
	mov x+3, #0
	load_y(412)
	lcall mul32
	load_y(1023)
	lcall div32
	load_y(273)
	lcall sub32
	mov a, x
	da a
	mov print, a
	lcall print2lcd

	load_y(6)
	mov a, x
	da a
	lcall sub32
	lcall hex2bcd
	mov a, bcd+0
	swap a
	anl a, #0x0f
	orl a, #0x30
	lcall putchar

	mov a, bcd+0
	anl a, #0x0f
	orl a, #0x30
	lcall putchar
	
	
	mov a, #'\r'
	lcall putchar
	mov a, #'\n'
	lcall putchar
	ret
	
print2lcd:
	mov BCD_counter, print
	Set_Cursor(1, 10)
	Display_BCD(BCD_counter)
	ret


delay:
	 mov R2, #200
L12: mov R1, #100
L11: mov R0, #100
L10: djnz R0, L10
	 djnz R1, L11
	 djnz R2, L12
	 ret
; Configure the serial port and baud rate

InitSerialPort:
    ; Since the reset button bounces, we need to wait a bit before
    ; sending messages, otherwise we risk displaying gibberish!
    mov R1, #222
    mov R0, #166
    djnz R0, $   ; 3 cycles->3*45.21123ns*166=22.51519us
    djnz R1, $-4 ; 22.51519us*222=4.998ms
    ; Now we can proceed with the configuration
	orl	PCON,#0x80
	mov	SCON,#0x52
	mov	BDRCON,#0x00
	mov	BRL,#BRG_VAL
	mov	BDRCON,#0x1E ; BDRCON=BRR|TBCK|RBCK|SPD;
    ret

; Send a character using the serial port
putchar:
    jnb TI, putchar
    clr TI
    mov SBUF, a
    ret

; Send a constant-zero-terminated string using the serial port
SendString:
    clr A
    movc A, @A+DPTR
    jz SendStringDone
    lcall putchar
    inc DPTR
    sjmp SendString
SendStringDone:
    ret
    

MainProgram:
     MOV SP, #7FH ; Set the stack pointer to the begining of idata
    lcall LCD_4BIT
    Set_Cursor(1, 1)
    Send_Constant_String(#Initial_Message)    
    LCALL InitSerialPort
   	lcall INIT_SPI
  
Forever:
	clr CE_ADC
	mov R0, #00000001B ; Start bit:1
	lcall DO_SPI_G
	mov R0, #10000000B ; Single ended, read channel 0
	lcall DO_SPI_G
	mov a, R1 ; R1 contains bits 8 and 9
	anl a, #00000011B ; We need only the two least significant bits
	mov Result+1, a ; Save result high.
	mov R0, #55H ; It doesn't matter what we transmit...
	lcall DO_SPI_G
	mov Result, R1 ; R1 contains bits 0 to 7. Save result low.
	setb CE_ADC
	lcall Delay
	lcall Do_Something_With_Result
	sjmp Forever
    
END