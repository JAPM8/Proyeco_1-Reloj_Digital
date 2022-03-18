/*	
    Archivo:		main.S
    Dispositivo:	PIC16F887
    Autor:		Javier Alejandro Pérez Marín 20183
    Compilador:		pic-as (v2.30), MPLABX V6.00

    Programa:		Reloj digital con 3 modos: reloj, fecha y temporizador
    Hardware:		Led indicadores de modo en PORTA, botones de congiguración
			del reloj en PORTB, 7 segmentos multiplexados en PORTC,
			selector de displays en PORTD, led de alarma en PORTE
			y buzzer en PORTE.

    Creado:			12/03/22
    Última modificación:	18/03/22	
*/

PROCESSOR 16F887
// config statements should precede project file includes.
#include <xc.inc>
 
; CONFIG1
CONFIG  FOSC = INTRC_NOCLKOUT ; Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
CONFIG  PWRTE = OFF           ; Power-up Timer Enable bit (PWRT enabled)
CONFIG  MCLRE = OFF           ; RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)

CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
CONFIG  LVP = OFF             ; Low Voltage Programming Enable bit (RB3/PGM pin has PGM function, low voltage programming enabled)

; CONFIG2
CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)
    
;-------------------------------------------------------------------------------
;                      VALORES ABSOLUTOS ASIGNADOS
;-------------------------------------------------------------------------------
LED_HORA    EQU 0	      ; Utilizado para encender RA0
LED_FECHA   EQU 1	      ; Utilizado para encender RA1
LED_TEMP    EQU 2	      ; Utilizado para encender RA2
LED_ACTIVE  EQU 3	      ; Utilizado para encender RA3
LED_PUNTOS  EQU 4	      ; Utilizado para encender RA4
LED_DISP1   EQU 6	      ; Utilizado para encender RA6
LED_DISP2   EQU 7	      ; Utilizado para encender RA7

LED_FIN_T   EQU 0             ; Utilizado para encender RE0
BUZZER	    EQU 1	      ; Utilizado para encender RE1

BT_UP       EQU 0	      ; Utilizado para leer RB0
BT_DOWN     EQU 1	      ; Utilizado para leer RB1
BT_EDITAR   EQU 2	      ; Utilizado para leer RB2
BT_INICIAR  EQU 3	      ; Utilizado para leer RB3
BT_MODO	    EQU 4	      ; Utilizado para leer RB4
	  
SEL_UNIDAD  EQU 3	      ; Utilizado para encender RD3
SEL_DECENA  EQU 2	      ; Utilizado para encender RD2
SEL_CENTENA EQU 1	      ; Utilizado para encender RD1
SEL_MILES   EQU 0	      ; Utilizado para encender RD0
   
;-------------------------------------------------------------------------------
;                                  MACROS
;-------------------------------------------------------------------------------
RESET_TMR0 MACRO
    BANKSEL TMR0	       ; Cambiamos al banco 1
    MOVLW   236                ; Se mueve N al registro W, N=256-((5 ms)(4 MHz)/4*256) -> N= 236 aprox
    MOVWF   TMR0	       ; Se le da delay a TMR0
    BCF	    T0IF	       ; Limpiamos la bandera de interrupción
    
    ENDM

RESET_TMR1 MACRO TMR1_H, TMR1_L	
    BANKSEL TMR1H
    MOVLW   TMR1_H	       ; Literal a guardar en TMR1H a W
    MOVWF   TMR1H	       ; Guardamos literal en TMR1H
    MOVLW   TMR1_L	       ; Literal a guardar en TMR1L a W
    MOVWF   TMR1L	       ; Guardamos literal en TMR1L
    BCF	    TMR1IF	       ; Limpiamos bandera de interrupción de TMR1
    
    ENDM

SEL_DISPLAY MACRO DISP1, DISP2, DISP3, DISP4
    MOVF    DISP1, W
    CALL    TABLA		
    MOVWF   DISPLAY	       ; Configuración para 7 segmentos de unidades
    
    MOVF    DISP2, W
    CALL    TABLA
    MOVWF   DISPLAY+1	       ; Configuración para 7 segmentos de decenas
    
    MOVF    DISP3, W
    CALL    TABLA
    MOVWF   DISPLAY+2	       ; Configuración para 7 segmentos de centenas
    
    MOVF    DISP4, W
    CALL    TABLA
    MOVWF   DISPLAY+3	       ; Configuración para 7 segmentos de miles
 
    ENDM
    
;-------------------------------------------------------------------------------
;                           VARIABLES UTILIZADAS
;-------------------------------------------------------------------------------
PSECT udata_shr		      ; Common memory
   W_TEMP:		DS 1	      ; 1 Byte
   STATUS_TEMP:		DS 1	      ; 1 Byte

PSECT udata_bank0
    MODO:		DS 1	      ; 1 Byte
    ST_SET:		DS 1	      ; 1 Byte
    ST_INICIAR:		DS 1	      ; 1 Byte
    
    CONT_TMR_1:		DS 1	      ; 1 Byte
    UNIDADES:		DS 1	      ; 1 Byte
    DECENAS:		DS 1	      ; 1 Byte
    CENTENAS:		DS 1	      ; 1 Byte
    MILES:		DS 1	      ; 1 Byte
    
    CONT_TIMER:		DS 1	      ; 1 Byte
    CONT_FIN_ALARMA:	DS 1	      ; 1 Byte
    BANDERA_TIMER:	DS 1	      ; 1 Byte
    SEGUNDOS_TIMER:	DS 1	      ; 1 Byte (31)
    MINUTOS_TIMER:	DS 1	      ; 1 Byte
    UNIDADES_TEMP:	DS 1	      ; 1 Byte
    DECENAS_TEMP:	DS 1	      ; 1 Byte
    CENTENAS_TEMP:	DS 1	      ; 1 Byte
    MILES_TEMP:		DS 1	      ; 1 Byte
    
    MEDIO_SEC:		DS 1	      ; 1 Byte
    SEGUNDOS:		DS 1	      ; 1 Byte
    DIV:	        DS 1	      ; 1 Byte
    DIV2:	        DS 1	      ; 1 Byte
    
    MESES:		DS 1	      ; 1 Byte
    DIAS:		DS 1	      ; 1 Byte
    A_DIAS:		DS 1	      ; 1 Byte
    A_MESES:		DS 1	      ; 1 Byte
    MAX_DIAS:		DS 1	      ; 1 Byte
    UNIDADES_F:		DS 1	      ; 1 Byte
    DECENAS_F:		DS 1	      ; 1 Byte
    CENTENAS_F:		DS 1	      ; 1 Byte
    MILES_F:		DS 1	      ; 1 Byte
        
    BANDERA:		DS 1	      ; 1 Byte 
    DISPLAY:		DS 4	      ; 4 Byte's
    


; CONFIG Vector RESET
    
PSECT resVect, class=CODE, abs, delta=2
ORG 00h                       ; posición 0000h para el reset
    
; ---------------vector reset--------------
resetVec:
    PAGESEL main
    GOTO    main
;-------------------------------------------------------------------------------
;			   VECTOR INTERRUPCIÓN
;-------------------------------------------------------------------------------

ORG 04h			      ; Posición 0004h para las interrupciones
PUSH:			      ; Se guarda el w 
    MOVWF  W_TEMP	      ; Movemos el registro W a la variable W_TEMP
    SWAPF  STATUS, W	      ; Se hace un swap para no modificar el STATUS
    MOVWF  STATUS_TEMP	      ; Se pasa el registro STATUS a la variable STATUS_TEMP
    
ISR:			      ; Rutina de interrupción   
    BANKSEL PORTA
    BTFSC   RBIF	      ; Se verifica la bandera de cambio de estado de PORTB
    CALL    INT_IOCB	      ; Pasamos a subrutina INT_IOCB
    
    BTFSC   T0IF	      ; Verficamos bandera de interrupción del TMR0
    CALL    CONT_TMR0	      ; Pasamos a subrutina de interrupción del TMR0
    
    BTFSC   TMR1IF	      ; Verificamos bandera de interrupción del TMR1
    CALL    CONT_TMR1	      ; Pasamos a subrutina de interrupción del TMR1
    
    BTFSC   TMR2IF	      ; Verificamos bandera de interrupción del TMR2
    CALL    CONT_TMR2	      ; Pasamos a subrutina de interrupción del TMR2
                
POP:			      ; Se regresan los registros w y STATUS
    SWAPF   STATUS_TEMP, W   
    MOVWF   STATUS	     
    SWAPF   W_TEMP, F	     
    SWAPF   W_TEMP, W	     
    
    RETFIE		      ; Se regresa de la interrupción   
    
;*******************************************************************************
;                          Sub-rutinas de interrupción
;******************************************************************************* 
INT_IOCB:       
    BTFSS   PORTB, BT_EDITAR  ; Anti-rebote botón BT_EDITAR
    CALL    INC_SET	      ; De estar presionado se pasa a incrementar estado de set
    
    BTFSS   PORTB, BT_MODO    ; Anti-rebote botón BT_MODO
    CALL    INC_MODO	      ; De estar presionado se pasa a incrementar estado de modo
    
    MOVF    MODO, W	      ; Modo a W
    BCF	    ZERO
    XORLW   2		      ; Se verifica si se está en modo timer
    BTFSC   ZERO
    CALL    MODO_INICIAR      ; Solo en modo timer interesa modificar estado iniciar
    
    MOVF    ST_INICIAR, W     ; Cuando está activa la alarma, en cualquier instante se puede desactivar
    BCF	    ZERO
    XORLW   3		      ; Se garantiza que ya está funcionando la alarma
    BTFSC   ZERO
    CALL    MODO_INICIAR      ; Solo en modo alarma timer interesa modificar estado en cualquier otro modo
    
    BCF	    RBIF	      ; Limpieza bandera de interrupción
    
    RETURN

MODO_INICIAR:
    BTFSS   PORTB, BT_INICIAR ; Anti-rebote botón BT_INICIAR
    CALL    INC_INICIAR	      ; De estar presionado se pasa a incrementar estado de iniciar
    
    RETURN
    
INC_INICIAR:
    INCF    ST_INICIAR 	      ; Se cambia de estado de iniciar ACTIVAR->DESACTIVAR
    MOVF    ST_INICIAR, W
    SUBLW   5		      ; Se limita a máximo estado 101b
    BTFSC   ZERO	    
    CLRF    ST_INICIAR	      ; Reinicio de estado
    
    RETURN

INC_SET:
    INCF    ST_SET	      ; Se cambia de estado de set MOSTRAR->MINUTOS->HORAS (021)
    MOVF    ST_SET, W
    SUBLW   3		      ; Se limita a máximo estado 11b
    BTFSC   ZERO
    CLRF    ST_SET	      ; Reinicio de estado
    
    RETURN
    
INC_MODO:
    INCF    MODO	       ; Se cambia de estado de modo HORA->FECHA->TEMPORIZADOR->ALARMA
    MOVF    MODO, W
    SUBLW   3		       ; Se limita a máximo estado 10b
    BTFSC   ZERO
    CLRF    MODO
    
    RETURN
;*******************************************************************************    
CONT_TMR0:
    RESET_TMR0		      ; Reinicio de timer
    
    CALL    COLOCAR_VALORES   ; Subrutina para colocación de selectores
    
    RETURN
    
COLOCAR_VALORES:
    BCF	PORTD, SEL_UNIDAD   ; Apagamos selector de unidades
    BCF	PORTD, SEL_DECENA   ; Apagamos selector de decenas
    BCF	PORTD, SEL_CENTENA  ; Apagamos selector de centenas
    BCF	PORTD, SEL_MILES    ; Apagamos selector de miles

    ; Lógica de condicionales para verificar que display encender

    BTFSC   BANDERA, 3	    ; Verificamos bandera 3
    GOTO    DISPLAY_3
    BTFSC   BANDERA, 2	    ; Verificamos bandera 2
    GOTO    DISPLAY_2
    BTFSC   BANDERA, 1	    ; Verificamos bandera 1
    GOTO    DISPLAY_1
    BTFSC   BANDERA, 0	    ; Verificamos bandera 0
    GOTO    DISPLAY_0

DISPLAY_0:			
    MOVF    DISPLAY, W	    ; Colocamos el valor de variable DISPLAY en W
    MOVWF   PORTC	    ; Colocamos el valor de W en Puerto C

    ; Activamos el primer display
    BSF	PORTD, SEL_UNIDAD

    BCF	BANDERA, 0	    ; Se modifica bandera para entrar a display_1
    BSF	BANDERA, 1	

RETURN

DISPLAY_1:
    MOVF    DISPLAY+1, W   ; Colocamos el valor de variable DISPLAY en W
    MOVWF   PORTC	   ; Colocamos el valor de W en Puerto C

    ; Activamos el segundo display
    BSF	PORTD, SEL_DECENA      
    BCF	BANDERA, 1         ; Se modifica bandera para entrar a display_2
    BSF	BANDERA, 2     

RETURN

DISPLAY_2:			
    MOVF    DISPLAY+2, W   ; Colocamos el valor de variable DISPLAY en W
    MOVWF   PORTC	   ; Colocamos el valor de W en Puerto C

    ; Activamos el tercer display
    BSF	PORTD, SEL_CENTENA  

    BCF	BANDERA, 2         ; Se modifica bandera para entrar a display_3    
    BSF	BANDERA, 3

RETURN

DISPLAY_3:
    MOVF    DISPLAY+3, W   ; Colocamos el valor de variable DISPLAY en W
    MOVWF   PORTC	   ; Colocamos el valor de W en Puerto C

    ; Activamos el cuarto display
    BSF	PORTD, SEL_MILES  

    BCF	BANDERA, 3	    
    BSF     BANDERA, 0	

RETURN
;*******************************************************************************
CONT_TMR1:
    RESET_TMR1 0x0B, 0xDC     ; TMR1 a 500 ms
    
    CALL    LED_INTERMITENCIA ; Sin importar operación anterior, nos interesa que cada 500 ms parpadeen los leds entre display    
    
    INCF    CONT_TMR_1	      ; Contador de interrupciones de TMR1
    MOVF    CONT_TMR_1, W	
    SUBLW   120		      ; 120 interrupciones de 500 ms equivalen a 1 min
    BTFSC   ZERO	      ; Revisión de bandera
    CALL    INC_MINUTOS	      ; De resultar 0 la resta pasamos a la subrutina de incremento de minutos
    
    RETURN
    
LED_INTERMITENCIA:
    INCF    MEDIO_SEC	      ; Contador de medios segundos
    BSF	    PORTA, LED_PUNTOS ; Se encienden 2 puntos del reloj
    MOVF    MEDIO_SEC, W
    SUBLW   2		      
    BTFSC   ZERO
    GOTO    NEG_INTERMITENCIA ; Luego de 2 repeticiones apagamos 2 puntos
    
    RETURN
 
NEG_INTERMITENCIA:
    CLRF    MEDIO_SEC
    BCF	    PORTA, LED_PUNTOS ; Se apagan 2 puntos del reloj
    
    RETURN 
    
INC_MINUTOS:
    CLRF    CONT_TMR_1
    INCF    UNIDADES	      ; Se incrementa unidades de minuto
    MOVF    UNIDADES, W	      
    SUBLW   10
    BTFSC   ZERO	      ; Se revisa si ya nos encontramos en 10 unidades
    CLRF    UNIDADES
    BTFSC   ZERO
    INCF    DECENAS	      ; Se incrementa decenas de minuto 
    
    MOVF    DECENAS, W
    SUBLW   6
    BTFSC   ZERO	      ; Se revisa si ya nos encontramos en 6 decenas
    CLRF    DECENAS
    BTFSC   ZERO	      
    CALL    INC_HORAS	      ; Pasamos a incrementar horas
    
    RETURN
    
INC_HORAS:
    INCF    CENTENAS	      ; Se incrementa centenas (unidades de hora)
    MOVF    CENTENAS, W
    SUBLW   10
    BTFSC   ZERO
    CLRF    CENTENAS	      ; Se revisa si ya nos encontramos en 10 centenas
    BTFSC   ZERO
    INCF    MILES	      ; Se incrementa miles (decenas de hora)
    
    MOVF    MILES, W
    SUBLW   2
    BTFSC   ZERO	      ; Se verifica si nos encontramos cerca de las 24 horas
    CALL    MEDIA_NOCHE
    
    RETURN
    
MEDIA_NOCHE:
    MOVF    CENTENAS, W
    SUBLW   4
    BTFSC   ZERO	      ; Verificamos si ya son las 24 hrs.
    CALL    REINICIO_RELOJ
    
    RETURN
    
REINICIO_RELOJ:		      ; Limpieza de reloj
    CLRF    UNIDADES
    CLRF    DECENAS
    CLRF    CENTENAS
    CLRF    MILES    
    
    INCF    UNIDADES_F	      ; Se incrementan unidades de días
    INCF    DIAS	      ; Se incrementa contador de días
    MOVF    UNIDADES_F, W
    SUBLW   10		      ;Se verifica si ya se tienen 10 unidades de día para incrementar decenas de dias
    BTFSC   ZERO
    INCF    DECENAS_F
    BTFSC   ZERO
    CLRF    UNIDADES_F
    
    MOVF    MESES, W	   
    CALL    TABLA_MESES	      ; El número de mes pasa a la tabla de máximos 
    MOVWF   MAX_DIAS	      ; Se obtiene día máximo posible por el mes en que se está
    
    MOVF    DIAS, W	      
    SUBWF   MAX_DIAS, W	    
    BTFSC   ZERO	      ; Si días igual máx días se incrementa el mes
    CALL    INC_MES
    
    MOVF    MESES, W	      
    SUBLW   13
    BTFSC   ZERO	      ; Se verifica si ya pasamos del mes 12
    GOTO    $+2
 
    RETURN
    
    MOVLW   1		      ; Se configuran variables de meses para mostrar mes 1
    MOVWF   MESES
    CLRF    CENTENAS_F
    CLRF    MILES_F
    BSF	    CENTENAS_F, 0
    
    RETURN
     
INC_MES:
    INCF    MESES
    
    INCF    CENTENAS_F	      ; Se incrementan centenas (unidades de mes)
    MOVF    CENTENAS_F, W
    SUBLW   10		      ;Se verifica si ya se tienen 10 unidades de mes para incrementar decenas de mes
    BTFSC   ZERO
    INCF    MILES_F	    
    BTFSC   ZERO
    CLRF    CENTENAS_F
    
    CLRF    UNIDADES_F	      ; Se configura día 1 de nuevo
    BSF	    UNIDADES_F, 0
    MOVLW   1
    MOVWF   DIAS
    CLRF    DECENAS_F
    
    RETURN   
;*******************************************************************************       
CONT_TMR2:
    BCF	    TMR2IF
    INCF    CONT_TIMER	       ; Contador de repeticiones del TMR2
    
    MOVF    CONT_TIMER, W      ; Contador a W
    SUBLW   20		       ; 20 repeticiones equivalen a 1 segundo
    BTFSS   ZERO	       ; Si existe Zero pasamos a decrementar segundos
    RETURN
    BTFSC   BANDERA_TIMER, 0   ; Bandera que indica tiempo finalizado y pasa a min de espera alarma
    GOTO    MINUTO_ALARMA
    
    CLRF    CONT_TIMER
    
    DECF    SEGUNDOS_TIMER     ; Se decrementa segundos configurados
    MOVF    SEGUNDOS_TIMER, W
    SUBLW   -1		       ; Se verifica si ya pasamos de 0 seg
    BTFSC   ZERO
    MOVLW   59		       ; Underflow
    BTFSC   ZERO
    MOVWF   SEGUNDOS_TIMER     ; Underflow segundos (0 a 59)
    BTFSC   ZERO
    CALL    DEC_MIN_TIMER      ; Se pasa a undeflow segundos y resta min
    CALL    DISPLAY_INT_T      ; Se pasa a seteo de variables display
    
    SALTO_ALARMA:
    RETURN

DISPLAY_INT_T:
    BANKSEL PORTA
    CLRF    DIV
    CLRF    UNIDADES_TEMP      ; Se limpian variables de display de segundos
    CLRF    DECENAS_TEMP
    
    MOVF    SEGUNDOS_TIMER, W 
    MOVWF   DIV
  
    MOVLW   10	               ; Restamos 10 para obtener cantidad de decenas
    SUBWF   DIV, F	     
    INCF    DECENAS_TEMP       ; +1 decena de segundo
    BTFSC   STATUS, 0          ; Se verifica si ocurrió BORROW (resultado aún mayor que 10)
    GOTO    $-4	               ; De ser así se continua restando
    DECF    DECENAS_TEMP       ; Se elimina la última añadición pues ya nos pasamos
    MOVLW   10	               ; Se regresa el valor a sus unidades antes de la resta 
    ADDWF   DIV, F
    
    MOVLW   1	               ; Restamos 1 para obtener cantidad de unidades
    SUBWF   DIV, F	            
    INCF    UNIDADES_TEMP      ; +1 unidad de segundo
    BTFSC   STATUS, 0          ; Se verifica si ocurrió BORROW (resultado aún mayor que 1)
    GOTO    $-4	               ; De ser así se continua restando
    DECF    UNIDADES_TEMP
    MOVLW   1	               ; Se elimina la última añadición pues ya nos pasamos
    ADDWF   DIV, F             ; Se regresa el valor a 0 en este caso
    
    MOVF    UNIDADES_TEMP, W   ; Se suma en w variables de display para verificar si ya minutos=segundos=0
    ADDWF   DECENAS_TEMP, W
    ADDWF   CENTENAS_TEMP, W
    ADDWF   MILES_TEMP, W
    BTFSC   ZERO
    CALL    FIN_T	       ; Se pasa a subrutina de alarma del timer
    
    RETURN    
    
DEC_MIN_TIMER:
    BANKSEL PORTA
            
    DECF    MINUTOS_TIMER	; Minutos - 1
    CALL    DISPLAY_INT_M	; Se pasa a obtener variables de display
        
    RETURN

DISPLAY_INT_M:
    CLRF    DIV2
    CLRF    CENTENAS_TEMP    ; Se limpian variables de display de minutos
    CLRF    MILES_TEMP
    
    MOVF    MINUTOS_TIMER, W 
    MOVWF   DIV2
  
    MOVLW   10	       ; Restamos 10 para obtener cantidad de decenas
    SUBWF   DIV2, F	     
    INCF    MILES_TEMP ; +1 decena de minuto
    BTFSC   STATUS, 0  ; Se verifica si ocurrió BORROW (resultado aún mayor que 10)
    GOTO    $-4	       ; De ser así se continua restando
    DECF    MILES_TEMP ; Se elimina la última añadición pues ya nos pasamos
    MOVLW   10	       ; Se regresa el valor a sus unidades antes de la resta 
    ADDWF   DIV2, F
    
    MOVLW   1	       ; Restamos 1 para obtener cantidad de unidades
    SUBWF   DIV2, F	            
    INCF    CENTENAS_TEMP; +1 unidad de minuto
    BTFSC   STATUS, 0  ; Se verifica si ocurrió BORROW (resultado aún mayor que 1)
    GOTO    $-4	       ; De ser así se continua restando
    DECF    CENTENAS_TEMP
    MOVLW   1	       ; Se elimina la última añadición pues ya nos pasamos
    ADDWF   DIV2, F  ; Se regresa el valor a 0 en este caso
    
    RETURN    
    
FIN_T:  
    BANKSEL PORTA
    CLRF    UNIDADES_TEMP   ;Limpieza display
    CLRF    DECENAS_TEMP
    CLRF    CENTENAS_TEMP
    CLRF    MILES_TEMP
    
    BSF	    BANDERA_TIMER, 0	; Bandera indica 00:00
    BSF	    PORTE, LED_FIN_T	; Se enciende alarma
    BSF	    PORTE, BUZZER	; Se enciende buzzer
    BCF	    PORTA, LED_ACTIVE	; Se apaga led de timer activo
    
    MOVLW   3
    MOVWF   ST_INICIAR	        ; Se pasa a estado 3 de iniciar
    
    RETURN
    
MINUTO_ALARMA:
    CLRF    CONT_TIMER		; Limpieza contador de segundos
    INCF    CONT_FIN_ALARMA	; Contador de minuto para desactivación de alarma
    MOVF    CONT_FIN_ALARMA, W
    SUBLW   60    		; Luego de 1 minuto
    BTFSC   ZERO
    GOTO    APAGAR_TIMER	; Se pasa a apagar timer
    SALTO_ALARMA2:
    
    GOTO    SALTO_ALARMA
    
APAGAR_TIMER:
   MOVLW    4
   MOVWF    ST_INICIAR		; Se pasa a estado 4 timer (reinicio)
   
    GOTO    SALTO_ALARMA2
;******************************************************************************* 
    
; CONFIG uCS
PSECT code, delta=2, abs
ORG 200h                      ; Posición para tablas Y código

 ;------------------------------------------------------------------------------
 ;				  TABLAS
 ;------------------------------------------------------------------------------
 
 TABLA:
    CLRF    PCLATH	     ; Limpiamos registro PCLATH
    BSF	    PCLATH, 1	     ; Posicionamos el PC en dirección 02xxh
    ANDLW   0x0F	     ; No saltar más del tamaño de la tabla
    ADDWF   PCL		     ; Apuntamos el PC a PCLATH + PCL + W
    retlw 00111111B ;0
    retlw 00000110B ;1
    retlw 01011011B ;2
    retlw 01001111B ;3
    retlw 01100110B ;4
    retlw 01101101B ;5
    retlw 01111101B ;6
    retlw 00000111B ;7
    retlw 01111111B ;8
    retlw 01101111B ;9
    retlw 01110111B ;10 (A)
    retlw 01111100B ;11 (b)
    retlw 00111001B ;12 (C)
    retlw 01011110B ;13 (d)
    retlw 01111001B ;14 (E)
    retlw 01110001B ;15 (F)

TABLA_MESES:
    CLRF    PCLATH	     ; Limpiamos registro PCLATH
    BSF	    PCLATH, 1	     ; Posicionamos el PC en dirección 02xxh
    ANDLW   0x0F	     ; No saltar más del tamaño de la tabla
    ADDWF   PCL		     ; Apuntamos el PC a PCLATH + PCL + W
    
    ;Se devuelve el límite de días dependiendo del mes
    RETLW	0  ;MES INICIAL 0 por si en algún punto se tuviera mes 0 aunque no debería
    RETLW	32 ;ENERO (1)
    RETLW	29 ;FEBRERO (2)
    RETLW	32 ;MARZO (3)
    RETLW	31 ;ABRIL (4)
    RETLW	32 ;MAYO (5)
    RETLW	31 ;JUNIO (6)
    RETLW	32 ;JULIO (7)
    RETLW	32 ;AGOSTO (8)
    RETLW	31 ;SEPTIEMBRE (9)
    RETLW	32 ;OCTUBRE (10)
    RETLW	31 ;NOVIEMBRE (11)
    RETLW	32 ;DICIEMBRE (12)

;-------------------------------------------------------------------------------
;       CONFIGURACIONES, LIMPIEZA DE VARIABLES Y ASIGNACIÓN DE VALORES    
;-------------------------------------------------------------------------------    
    
main:
; Configuración Inputs y Outputs
    CALL    CONFIG_PINES
; Configuración deL Oscilador (4 MHz)
    CALL    CONFIG_RELOJ
; Configuración Timer0
    CALL    CONFIG_TIMER0
; Configuración Timer1
    CALL    CONFIG_TIMER1
; Configuración Timer2
    CALL    CONFIG_TIMER2
; Configuración de interrupciones
    CALL    ENABLE_INTS
; Configuración de lectura de cambios en puerto B
    CALL    CONFIG_IOCRB
    
    BANKSEL PORTA
    
; Limpieza y asignación de valores iniciales a variables
    
    CLRF    MODO
    CLRF    ST_SET
    CLRF    ST_INICIAR
    CLRF    CONT_TMR_1
    CLRF    UNIDADES
    CLRF    DECENAS
    CLRF    CENTENAS
    CLRF    MILES
    CLRF    MEDIO_SEC
    CLRF    DISPLAY
      
    CLRF    DIAS
    BSF	    DIAS, 0	      ; Día inicial 1
    CLRF    MESES
    BSF	    MESES, 0	      ; Mes inicial 1
    CLRF    MAX_DIAS
    BSF	    MAX_DIAS, 5	      ; Al encender pic máx días es 32 
    
    CLRF    UNIDADES_F
    BSF	    UNIDADES_F, 0     ; No hay día cero a menos que se acabe el mundo jajaja (se inicia en día 1)
    CLRF    DECENAS_F
    CLRF    CENTENAS_F
    BSF	    CENTENAS_F, 0     ; No hay mes cero (se inicia en mes 1)
    CLRF    MILES_F
   
    CLRF    A_MESES	      ; Variables de día y mes anterior 31/12
    CLRF    A_DIAS
    MOVLW   32
    MOVWF   A_DIAS
    
    CLRF    BANDERA_TIMER	
    CLRF    SEGUNDOS_TIMER	
    CLRF    MINUTOS_TIMER	
    CLRF    UNIDADES_TEMP	
    CLRF    DECENAS_TEMP	
    CLRF    CENTENAS_TEMP	
    CLRF    MILES_TEMP	
    CLRF    CONT_FIN_ALARMA
    CLRF    CONT_TIMER
    CLRF    SEGUNDOS_TIMER
    CLRF    MINUTOS_TIMER

;-------------------------------------------------------------------------------
;                       LOOP PRINCIPAL FSM
;-------------------------------------------------------------------------------
    
LOOP_FSM:
    BANKSEL IOCB
    BTFSS   IOCB, BT_MODO     ; Se habilitan botones pues se deshabilitan como progra defensiva
    BSF	    IOCB, BT_MODO
    BTFSS   IOCB, BT_EDITAR
    BSF	    IOCB, BT_EDITAR   ; Se habilita edición
    BTFSS   IOCB, BT_INICIAR
    BSF	    IOCB, BT_INICIAR  ; Se habilita activación timer
    
    BANKSEL PORTA
    MOVF    MODO, W	      ; Movemos el valor de estado en el que se encuentra
    BCF	    ZERO
    XORLW   0	              ; Lógica de XOR: val iguales activa ZERO flag
    BTFSC   ZERO
    GOTO    HORA	      ; Se pasa a modo hora donde se mostrará o editará
    
    MOVF    MODO, W	      ; Movemos el valor de estado en el que se encuentra
    BCF	    ZERO
    XORLW   1		
    BTFSC   ZERO
    GOTO    FECHA	      ; Se pasa a modo fecha donde se mostrará o editará
    
    MOVF    MODO, W           ; Movemos el valor de estado en el que se encuentra
    BCF	    ZERO
    XORLW   2		
    BTFSC   ZERO	      
    GOTO    TIMER	      ; Se pasa a modo timer donde se mostrará, configurará y activará
        
    GOTO LOOP_FSM

;-------------------------------------------------------------------------------
;                       MODO HORA Y SUBRUTINAS DE ESTE
;-------------------------------------------------------------------------------

HORA:
    BANKSEL T1CON
    BTFSS   TMR1ON	      ; Se verifica que se encuentre encendido el TMR1
    BSF	    TMR1ON
    
    BANKSEL PORTA
    BSF	    PORTA, LED_HORA   ; Se enciende Led indicador de modo
    BCF	    PORTA, LED_FECHA
    BCF	    PORTA, LED_TEMP
    BCF	    PORTA, LED_DISP1
    BCF	    PORTA, LED_DISP2
    
    CLRF    DISPLAY
    SEL_DISPLAY UNIDADES, DECENAS, CENTENAS, MILES	; Macro para configuración de displays (HORA:MINUTOS)
    
    MOVF    ST_SET, W         ; Se revisa el estado de set
    BCF	    ZERO
    XORLW   1		
    BTFSC   ZERO
    GOTO    EDIT_MIN	      ; Se pasa a modo edición de minutos
    
    MOVF    ST_SET, W	      ; Se revisa el estado de set
    BCF	    ZERO
    XORLW   2		
    BTFSC   ZERO	      
    GOTO    EDIT_HRS	      ; Se pasa a modo edición de horas
    
    MOVF    ST_INICIAR, W     ; Se revisa el estado de iniciar
    BCF	    ZERO
    XORLW   4		
    BTFSC   ZERO	      
    GOTO    CLEAR_TIMER       ; Se pasa a detener del timer
    
    GOTO LOOP_FSM
    
EDIT_MIN:
    BANKSEL IOCB
    BCF	    IOCB, BT_MODO     ; Se deshabilita cambio de modo
    
    BANKSEL T1CON
    BCF	    TMR1ON	      ; Se pausa TMR1
    
    BSF	    PORTA, LED_DISP1  ; Se enciende led de edición para primer display
    BCF	    PORTA, LED_DISP2
    
    BTFSS   PORTB, BT_UP      ; Se verifica si se encuentra presionado botón de display up
    GOTO    ANTIREB_MIN	      ; Se pasa a anti-rebote de incremento de minutos
    BTFSS   PORTB, BT_DOWN    ; Se verifica si se encuentra presionado botón de display down
    GOTO    ANTIREB_MIN2      ; Se pasa a anti-rebote de decremento de minutos
    
    CLRF    DISPLAY
    SEL_DISPLAY UNIDADES, DECENAS, CENTENAS, MILES	; Macro para configuración de displays (HORA:MINUTOS)
    
    MOVF    ST_SET, W	      ; Se revisa el estado de set
    BCF	    ZERO
    XORLW   2		
    BTFSC   ZERO	      
    GOTO    EDIT_HRS	      ; Se pasa a modo edición de horas    
    
    GOTO    EDIT_MIN
    
ANTIREB_MIN:
    BTFSS   PORTB, BT_UP      ; Se verifica si se encuentra presionado botón de display up
    GOTO    $-1
    CALL    INC_MIN	      ; Se incrementa min
    
    GOTO    EDIT_MIN
    
ANTIREB_MIN2:
    BTFSS   PORTB, BT_DOWN    ; Se verifica si se encuentra presionado botón de display up
    GOTO    $-1
    
    DECF    UNIDADES	      ; Se decrementa unidades de minuto
    CALL    DEC_MIN	      ; Se pasa a revisar underflow
    
    GOTO    EDIT_MIN
    
INC_MIN:
    INCF    UNIDADES	      ; Se incrementa unidades de minuto
    MOVF    UNIDADES, W	      
    SUBLW   10
    BTFSC   ZERO	      ; Se revisa si ya nos encontramos en 10 unidades
    CLRF    UNIDADES
    BTFSC   ZERO
    INCF    DECENAS	      ; Se incrementa decenas de minuto 
    
    MOVF    DECENAS, W
    SUBLW   6
    BTFSC   ZERO	      ; Se revisa si ya nos encontramos en 6 decenas
    CLRF    DECENAS
        
    RETURN 
    
EDIT_HRS:
    BANKSEL IOCB
    BCF	    IOCB, BT_MODO     ; Se deshabilita cambio de modo
    
    BANKSEL T1CON
    BCF	    TMR1ON	      ; Se pausa TMR1
    
    BCF	    PORTA, LED_DISP1  ; Se enciende led de edición para primer display
    BSF	    PORTA, LED_DISP2
    
    BTFSS   PORTB, BT_UP      ; Se verifica si se encuentra presionado botón de display up
    GOTO    ANTIREB_HRS       ; Se pasa a anti-rebote de incremento de horas
    BTFSS   PORTB, BT_DOWN    ; Se verifica si se encuentra presionado botón de display down
    GOTO    ANTIREB_HRS2      ; Se pasa a anti-rebote de decremento de horas
    
    CLRF    DISPLAY
    SEL_DISPLAY UNIDADES, DECENAS, CENTENAS, MILES	; Macro para configuración de displays (HORA:MINUTOS)
    
    MOVF    ST_SET, W	
    BTFSC   ZERO	      
    GOTO    HORA	      ; Se pasa a modo mostrar hora
    
    GOTO    EDIT_HRS

DEC_MIN:
    BCF	    ZERO
    MOVLW   -1		      ; Se mueve literal de -1 a W
    SUBWF   UNIDADES, W	      ; Se verifica si la operación de decremento resulto en -1 (UNIDADES-(-1)=0)
    BTFSS   ZERO	      ; De activarse la bandera saltamos setear unidades a 9 y dec de Decenas
    RETURN
    DECF    DECENAS	      ; DECENAS - 1
    MOVLW   9
    MOVWF   UNIDADES	      ; Underflow Unidades 0->9
    
    BCF	    ZERO
    MOVLW   -1		      ; Se mueve literal de -1 a W
    SUBWF   DECENAS, W	      ; Se verifica si la operación de decremento resulto en -1 (DECENAS-(-1)=0)
    BTFSS   ZERO	      ; De activarse la bandera saltamos setear decenas a 5
    RETURN
    MOVLW   5
    MOVWF   DECENAS
    
    RETURN
    
ANTIREB_HRS:
    BTFSS   PORTB, BT_UP      ; Se verifica si se encuentra presionado botón de display up
    GOTO    $-1
    CALL    INC_HRS	      ; Se incrementa min
    
    GOTO    EDIT_HRS

ANTIREB_HRS2:
    BTFSS   PORTB, BT_DOWN    ; Se verifica si se encuentra presionado botón de display down
    GOTO    $-1
    DECF    CENTENAS	      ; Se decrementa unidades de hora
    CALL    DEC_HRS	      ; Se decrementa min
    
    GOTO    EDIT_HRS

DEC_HRS:
    BCF	    ZERO
    MOVLW   -1		      ; Se mueve literal de -1 a W
    SUBWF   CENTENAS, W	      ; Se verifica si la operación de decremento resulto en -1 (CENTENAS-(-1)=0)
    BTFSS   ZERO	      ; De activarse la bandera saltamos setear CENTENAS a 9 y dec de MILES
    RETURN
    DECF    MILES	      ; MILES - 1
    MOVLW   9
    MOVWF   CENTENAS	      ; Underflow CENTENAS 0->9
    
    BCF	    ZERO
    MOVLW   -1		      ; Se mueve literal de -1 a W
    SUBWF   MILES, W	      ; Se verifica si la operación de decremento resulto en -1 (MILES-(-1)=0)
    
    BTFSS   ZERO	      ; De activarse la bandera saltamos setear MILES a 2 y CENTENAS A 3
    RETURN
    MOVLW   2
    MOVWF   MILES
    MOVLW   3
    MOVWF   CENTENAS
    
    RETURN
    
INC_HRS:
    INCF    CENTENAS	      ; Se incrementa centenas (unidades de hora)
    MOVF    CENTENAS, W
    SUBLW   10
    BTFSC   ZERO
    CLRF    CENTENAS	      ; Se revisa si ya nos encontramos en 10 centenas
    BTFSC   ZERO
    INCF    MILES	      ; Se incrementa miles (decenas de hora)
    
    MOVF    MILES, W	      ; Se verifica overflow de horas (reinicio a las 24 hrs)
    SUBLW   2
    BTFSC   ZERO
    GOTO    $+2
    RETURN
    
    MOVF    CENTENAS, W	      ; Se verifica si unidades de hora igual a 4
    SUBLW   4
    BTFSC   ZERO	      ; De serlo se pasa a 00 horas
    CLRF    CENTENAS
    BTFSC   ZERO
    CLRF    MILES
        
    RETURN

;-------------------------------------------------------------------------------
;	           MODO FECHA Y SUBRUTINAS DE ESTE
;-------------------------------------------------------------------------------
    
FECHA:
    BANKSEL T1CON
    BTFSS   TMR1ON	      ; Se verifica que se encuentre encendido el TMR1
    BSF	    TMR1ON
    
    BANKSEL PORTA
    BCF	    PORTA, LED_HORA   ; Se enciende Led indicador de modo
    BSF	    PORTA, LED_FECHA
    BCF	    PORTA, LED_TEMP
    BCF	    PORTA, LED_DISP1
    BCF	    PORTA, LED_DISP2
    
    CLRF    DISPLAY
    SEL_DISPLAY CENTENAS_F, MILES_F, UNIDADES_F, DECENAS_F ; Macro para configuración de displays (día/mes)
    
    MOVF    ST_SET, W	      ; Se revisa el estado de set
    BCF	    ZERO
    XORLW   1		
    BTFSC   ZERO
    GOTO    EDIT_MES	      ; Se pasa a modo edición de minutos
    
    MOVF    ST_SET, W	      ; Se revisa el estado de set
    BCF	    ZERO
    XORLW   2		
    BTFSC   ZERO	      
    GOTO    EDIT_DIAS	      ; Se pasa a modo edición de horas
    
    MOVF    ST_INICIAR, W     ; Se revisa el estado de iniciar
    BCF	    ZERO
    XORLW   4		
    BTFSC   ZERO	      
    GOTO    CLEAR_TIMER      ; Se pasa a detener del timer
    
    GOTO LOOP_FSM

EDIT_MES:
    BANKSEL IOCB
    BCF	    IOCB, BT_MODO     ; Se deshabilita cambio de modo
    
    BANKSEL T1CON
    BCF	    TMR1ON	      ; Se pausa TMR1
    
    BSF	    PORTA, LED_DISP1  ; Se enciende led de edición para primer display
    BCF	    PORTA, LED_DISP2
        
    BTFSS   PORTB, BT_UP      ; Se verifica si se encuentra presionado botón de display up
    GOTO    ANTIREB_MES	      ; Se pasa a anti-rebote de incremento de mes
    BTFSS   PORTB, BT_DOWN    ; Se verifica si se encuentra presionado botón de display down
    GOTO    ANTIREB_MES2      ; Se pasa a anti-rebote de decremento de minutos
    
    CLRF    DISPLAY
    SEL_DISPLAY CENTENAS_F, MILES_F, UNIDADES_F, DECENAS_F ; Macro para configuración de displays (día/mes)
        
    MOVF    ST_SET, W	      ; Se verifica estado de set
    BCF	    ZERO
    XORLW   2		
    BTFSC   ZERO	      
    GOTO    EDIT_DIAS	      ; Se pasa a modo edición de días    
    
    GOTO    EDIT_MES

ANTIREB_MES2:
    BTFSS   PORTB, BT_DOWN    ; Se verifica si se encuentra presionado botón de display down
    GOTO    $-1
    CALL    DEC_MESES	      ; Se decrementa MESES
    
    GOTO EDIT_MES
    
ANTIREB_MES:
    BTFSS   PORTB, BT_UP      ; Se verifica si se encuentra presionado botón de display up
    GOTO    $-1
    CALL    INC_MESES	      ; Se incrementa MESES
    
    GOTO EDIT_MES
    
DEC_MESES:
    CLRF    UNIDADES_F	      ; Cada vez que se cambie de mes se reinician días
    CLRF    DECENAS_F
    MOVLW   1
    MOVWF   DIAS	      ; Dias=1
    BSF	    UNIDADES_F, 0     ; Unidad días= 1
    
    DECF    MESES	      ; Se decrementa valor de meses
    BTFSS   ZERO	      ; Se verifica si se llega a mes 0
    GOTO    $+3
    MOVLW   12
    MOVWF   MESES
    
    CALL    MESES_DISPLAY     ; Se pasa a dividir meses en centenas y miles
    
    RETURN
    
MESES_DISPLAY:
    CLRF    MILES_F           ; Se limpian variables de display de meses
    CLRF    CENTENAS_F
    
    MOVF    MESES, W 
    MOVWF   A_MESES
  
    MOVLW   10	              ; Restamos 10 para obtener cantidad de decenas
    SUBWF   A_MESES, F	     
    INCF    MILES_F	      ; +1 decena de meses
    BTFSC   STATUS, 0         ; Se verifica si ocurrió BORROW (resultado aún mayor que 10)
    GOTO    $-4	              ; De ser así se continua restando
    DECF    MILES_F           ; Se elimina la última añadición pues ya nos pasamos
    MOVLW   10	              ; Se regresa el valor a sus unidades antes de la resta 
    ADDWF   A_MESES, F
    
    MOVLW   1	              ; Restamos 1 para obtener cantidad de unidades
    SUBWF   A_MESES, F	            
    INCF    CENTENAS_F        ; +1 unidad de meses
    BTFSC   STATUS, 0         ; Se verifica si ocurrió BORROW (resultado aún mayor que 1)
    GOTO    $-4	              ; De ser así se continua restando
    DECF    CENTENAS_F
    MOVLW   1	              ; Se elimina la última añadición pues ya nos pasamos
    ADDWF   A_MESES, F        ; Se regresa el valor a 0 en este caso

    RETURN
    
INC_MESES:
    CLRF    UNIDADES_F	      ; Cada vez que se cambie de mes se reinician días
    CLRF    DECENAS_F
    MOVLW   1
    MOVWF   DIAS	      ; Dias=1
    BSF	    UNIDADES_F, 0     ; Unidad días= 1
    
    INCF    CENTENAS_F	      ; Se incrementa unidades de mes
    INCF    MESES	      ; Se incrementan meses
    MOVF    CENTENAS_F, W	      
    SUBLW   10
    BTFSC   ZERO	      ; Se revisa si ya nos encontramos en 10 unidades de mes
    CLRF    CENTENAS_F
    BTFSC   ZERO
    INCF    MILES_F	      ; Se incrementa decenas de minuto 
    
    MOVF    MESES, W
    SUBLW   13
    BTFSS   ZERO	      ; Se revisa si ya nos encontramos en mes 13   
    RETURN
    
    MOVLW   1
    MOVWF   MESES
    CLRF    CENTENAS_F
    CLRF    MILES_F
    BSF	    CENTENAS_F, 0
    
    RETURN
    
EDIT_DIAS:
    BANKSEL IOCB
    BCF	    IOCB, BT_MODO     ; Se deshabilita cambio de modo
    
    BANKSEL T1CON
    BCF	    TMR1ON	      ; Se pausa TMR1
    
    BCF	    PORTA, LED_DISP1  ; Se enciende led de edición para primer display
    BSF	    PORTA, LED_DISP2
    
    MOVF    MESES, W	   
    CALL    TABLA_MESES	      ; El número de mes pasa a la tabla de máximos 
    MOVWF   MAX_DIAS	      ; Se obtiene día máximo posible por el mes en que se está
    
    BTFSS   PORTB, BT_UP      ; Se verifica si se encuentra presionado botón de display up
    GOTO    ANTIREB_DIAS      ; Se pasa a anti-rebote de incremento de días
    BTFSS   PORTB, BT_DOWN    ; Se verifica si se encuentra presionado botón de display down
    GOTO    ANTIREB_DIAS2     ; Se pasa a anti-rebote de decremento de días
    
    CLRF    DISPLAY
    SEL_DISPLAY CENTENAS_F, MILES_F, UNIDADES_F, DECENAS_F ; Macro para configuración de displays (día/mes)
    
    MOVF    ST_SET, W         ; Se verifica estado de set	
    BTFSC   ZERO	      
    GOTO    FECHA	      ; Se pasa a modo mostrar fecha    
    
    GOTO EDIT_DIAS
    
ANTIREB_DIAS:
    BTFSS   PORTB, BT_UP      ; Se verifica si se encuentra presionado botón de display up
    GOTO    $-1
    CALL    INC_DIAS	      ; Subrutina incrementa días
    
    GOTO EDIT_MES
 
ANTIREB_DIAS2:
    BTFSS   PORTB, BT_DOWN    ; Se verifica si se encuentra presionado botón de display down
    GOTO    $-1
    CALL    DEC_DIAS	      ; Subtutina decrementa días
    
    GOTO EDIT_MES
    
INC_DIAS:
    INCF    DIAS	      ; Se incrementa variable días
    
    MOVF    DIAS, W	      
    SUBWF   MAX_DIAS, W	    
    BTFSC   ZERO	      ; Si días igual máx días se reinicia en 1
    CLRF    DIAS
    BTFSC   ZERO
    INCF    DIAS
    
    CALL    DIAS_DISPLAY      ; Subrutina de separación de unidades, decenas, centenas, miles
    
    RETURN
    
DEC_DIAS:
    DECF    DIAS	      ; Se decrementa variable días
    
    MOVF    DIAS, W	      	    
    BTFSC   ZERO	      ; Si días igual 0
    CALL    UNDER_DIAS	      ; Se pasa a underflow días
        
    CALL    DIAS_DISPLAY      ; Subrutina de separación de unidades, decenas, centenas, miles
    
    RETURN
    
UNDER_DIAS:
    MOVF    MAX_DIAS, W	      ; Movemos máx de días a W
    MOVWF   DIAS	      ; Seteamos días en el máximo (underflow)
    DECF    DIAS	      ; Se decrementa en uno pues max_dias es una unidad mayor
    
    RETURN
    
DIAS_DISPLAY:
    CLRF    UNIDADES_F        ; Se limpian variables de display de días
    CLRF    DECENAS_F
    
    MOVF    DIAS, W 
    MOVWF   A_DIAS
  
    MOVLW   10	              ; Restamos 10 para obtener cantidad de decenas
    SUBWF   A_DIAS, F	     
    INCF    DECENAS_F         ; +1 decena de días
    BTFSC   STATUS, 0         ; Se verifica si ocurrió BORROW (resultado aún mayor que 10)
    GOTO    $-4	              ; De ser así se continua restando
    DECF    DECENAS_F         ; Se elimina la última añadición pues ya nos pasamos
    MOVLW   10	              ; Se regresa el valor a sus unidades antes de la resta 
    ADDWF   A_DIAS, F
    
    MOVLW   1	              ; Restamos 1 para obtener cantidad de unidades
    SUBWF   A_DIAS, F	            
    INCF    UNIDADES_F        ; +1 unidad de días
    BTFSC   STATUS, 0         ; Se verifica si ocurrió BORROW (resultado aún mayor que 1)
    GOTO    $-4	              ; De ser así se continua restando
    DECF    UNIDADES_F
    MOVLW   1	              ; Se elimina la última añadición pues ya nos pasamos
    ADDWF   A_DIAS, F         ; Se regresa el valor a 0 en este caso
    
    RETURN
    
;-------------------------------------------------------------------------------
;	             MODO TIMER Y SUSBRUTINAS DE ESTE		    
;-------------------------------------------------------------------------------
    
TIMER:
    BANKSEL T1CON
    BTFSS   TMR1ON	      ; Se verifica que se encuentre encendido el TMR1
    BSF	    TMR1ON
    
    BCF	    PORTA, LED_HORA   ; Se enciende Led indicador de modo
    BCF	    PORTA, LED_FECHA
    BSF	    PORTA, LED_TEMP
    BCF	    PORTA, LED_DISP1
    BCF	    PORTA, LED_DISP2
        
    CLRF    DISPLAY
    SEL_DISPLAY UNIDADES_TEMP, DECENAS_TEMP, CENTENAS_TEMP, MILES_TEMP	; Macro para configuración de displays (MINUTOS:SEGUNDOS)
    
    MOVF    ST_SET, W         ; Se revisa el estado de set
    BCF	    ZERO
    XORLW   1		
    BTFSC   ZERO
    GOTO    EDIT_SEG_T	      ; Se pasa a modo edición de segundos del timer
    
    MOVF    ST_SET, W	      ; Se revisa el estado de set
    BCF	    ZERO
    XORLW   2		
    BTFSC   ZERO	      
    GOTO    EDIT_MIN_T	      ; Se pasa a modo edición de minutos del timer
    
    BANKSEL IOCB
    BSF	    IOCB, BT_MODO     ; Se habilita cambio de modo
    
    BANKSEL PORTA
    MOVF    ST_INICIAR, W     ; Se revisa el estado de iniciar
    BCF	    ZERO
    XORLW   1		
    BTFSC   ZERO
    GOTO    INIT_TIMER	      ; Se pasa a iniciar timer
    
    MOVF    ST_INICIAR, W     ; Se revisa el estado de iniciar
    BCF	    ZERO
    XORLW   2		
    BTFSC   ZERO	      
    GOTO    STOP_TIMER	      ; Se pasa a detener del timer
    
    MOVF    ST_INICIAR, W     ; Se revisa el estado de iniciar
    BCF	    ZERO
    XORLW   3		
    BTFSC   ZERO	      
    GOTO    ALARMA_TIMER      ; Se pasa a detener del timer
    
    MOVF    ST_INICIAR, W     ; Se revisa el estado de iniciar
    BCF	    ZERO
    XORLW   4		
    BTFSC   ZERO	      
    GOTO    CLEAR_TIMER       ; Se pasa a limpiar timer
    
    
    GOTO LOOP_FSM

INIT_TIMER:
        
    MOVF    UNIDADES_TEMP, W  ; Se verifica que se tenga como mínimo un segundo
    ADDWF   DECENAS_TEMP, W
    ADDWF   CENTENAS_TEMP, W
    ADDWF   MILES_TEMP, W
    BTFSC   ZERO
    CLRF    ST_INICIAR	      ; No se activa timer
    BTFSC   ZERO
    GOTO    TIMER             ; Se regresa a modo mostrar
    
    BANKSEL IOCB
    BCF	    IOCB, BT_EDITAR   ; Se deshabilita edición
    
    BANKSEL PORTA
    BTFSS   TMR2ON
    BSF	    TMR2ON
    
    BSF	    PORTA, LED_ACTIVE ; Se enciende led indicativo que está activo temp
    
    CLRF    BANDERA_TIMER     ; Limpieza de bandera de interrupción tmr2
    
    CLRF    DISPLAY
    SEL_DISPLAY UNIDADES_TEMP, DECENAS_TEMP, CENTENAS_TEMP, MILES_TEMP	; Macro para configuración de displays (MINUTOS:SEGUNDOS)
    
    MOVF    MODO, W	      ; Movemos el valor de estado en el que se encuentra
    BCF	    ZERO
    XORLW   0	              ; Lógica de XOR: val iguales activa ZERO flag
    BTFSC   ZERO
    GOTO    HORA	      ; Se pasa a modo hora donde se mostrará o editará
    
    MOVF    ST_INICIAR, W     ; Se revisa el estado de iniciar
    BCF	    ZERO
    XORLW   2		
    BTFSC   ZERO	      
    GOTO    STOP_TIMER	      ; Se pasa a detener del timer
    
    MOVF    ST_INICIAR, W     ; Se revisa el estado de iniciar
    BCF	    ZERO
    XORLW   3		
    BTFSC   ZERO	      
    GOTO    ALARMA_TIMER      ; Se pasa a detener del timer*/
    
    GOTO INIT_TIMER
 
STOP_TIMER: 
    BANKSEL PORTA
    BCF	    TMR2ON
    
    CLRF    ST_INICIAR	      ; Se pasa a estado 0 de iniciar (mostrar)
    
    BCF	    PORTA, LED_ACTIVE ; Se apaga led indicativo que está activo temp
    
    MOVF    ST_INICIAR, W     ; Se revisa el estado de iniciar		
    BTFSC   ZERO
    GOTO    TIMER	      ; Se pasa a mostrar valor detenido TIMER
    
    GOTO STOP_TIMER
    
ALARMA_TIMER:
    BANKSEL PORTA
    
    CLRF    DISPLAY
    SEL_DISPLAY UNIDADES_TEMP, DECENAS_TEMP, CENTENAS_TEMP, MILES_TEMP	; Macro para configuración de displays (MINUTOS:SEGUNDOS)
        
    MOVF    ST_INICIAR, W     ; Se revisa el estado de iniciar
    BCF	    ZERO
    XORLW   4		
    BTFSC   ZERO	      
    GOTO    CLEAR_TIMER      ; Se pasa a detener del timer
        
    MOVF    MODO, W	      ; Movemos el valor de estado en el que se encuentra
    BCF	    ZERO
    XORLW   0	              
    BTFSC   ZERO
    GOTO    HORA	      ; Se pasa a modo hora donde se mostrará o editará
    
    GOTO ALARMA_TIMER
    
CLEAR_TIMER:
    BANKSEL PORTA
    BCF	    TMR2ON	      ; Se apaga TMR2
    
    BCF	    PORTE, LED_FIN_T  ; Se apaga alarma
    BCF	    PORTE, BUZZER     ; Se apaga buzzer
    
    CLRF    BANDERA_TIMER     ; Limpieza bandera
    CLRF    CONT_TIMER	      ; Limpieza contadores
    CLRF    SEGUNDOS_TIMER
    CLRF    MINUTOS_TIMER
    CLRF    CONT_FIN_ALARMA
    
    CLRF    UNIDADES_TEMP
    CLRF    DECENAS_TEMP
    CLRF    CENTENAS_TEMP
    CLRF    MILES_TEMP
    
    CLRF    ST_INICIAR	      ; Se regresa a estado 0 de mostrar
        
    MOVF    ST_INICIAR, W     ; Se revisa el estado de iniciar		
    BTFSC   ZERO
    GOTO    TIMER	      ; Se pasa a mostrar valor detenido TIMER
    
    GOTO CLEAR_TIMER
    
EDIT_SEG_T:
    BANKSEL IOCB
    BCF	    IOCB, BT_MODO     ; Se deshabilita cambio de modo
    BCF	    IOCB, BT_INICIAR  ; Se deshabilita activación timer
    
    BANKSEL T2CON
    BCF	    TMR2ON	      ; Se pausa TMR2
    CLRF    TMR2	      ; Se limpia cuenta de TMR2
        
    BSF	    PORTA, LED_DISP1  ; Se enciende led de edición para primer display
    BCF	    PORTA, LED_DISP2
    
    BTFSS   PORTB, BT_UP      ; Se verifica si se encuentra presionado botón de display up
    GOTO    ANTIREB_SEG	      ; Se pasa a anti-rebote de incremento de segundos
    BTFSS   PORTB, BT_DOWN    ; Se verifica si se encuentra presionado botón de display down
    GOTO    ANTIREB_SEG2      ; Se pasa a anti-rebote de decremento de segundos
    
    CLRF    DISPLAY
    SEL_DISPLAY UNIDADES_TEMP, DECENAS_TEMP, CENTENAS_TEMP, MILES_TEMP	; Macro para configuración de displays (MINUTOS:SEGUNDOS)
    
    MOVF    ST_SET, W	      ; Se revisa el estado de set
    BCF	    ZERO
    XORLW   2		
    BTFSC   ZERO	      
    GOTO    EDIT_MIN_T	      ; Se pasa a modo edición de minutos timer    
    
    GOTO    EDIT_SEG_T
    
ANTIREB_SEG:
    BTFSS   PORTB, BT_UP      ; Se verifica si se encuentra presionado botón de display up
    GOTO    $-1
    
    INCF    SEGUNDOS_TIMER    ; Se incrementa segundos del timer
    CALL    INC_SEG	      ; Se pasa a revisar overflow
    
    GOTO    EDIT_SEG_T
    
ANTIREB_SEG2:
    BTFSS   PORTB, BT_DOWN    ; Se verifica si se encuentra presionado botón de display down
    GOTO    $-1
    
    DECF    SEGUNDOS_TIMER    ; Se decrementa segundos del timer
    CALL    DEC_SEG	      ; Se pasa a revisar underflow
    
    GOTO    EDIT_SEG_T

INC_SEG:
        
    MOVF    SEGUNDOS_TIMER, W ; Segundos del timer a W
    SUBLW   60	              ; Se verifica si se tienen 60 segundos
    BTFSC   ZERO	    
    CLRF    SEGUNDOS_TIMER    ; En 60 segundos se pasa a 0 segundos
    
    CALL    DISPLAY_TIMER     ; Subrutina para obtención de display
    
    RETURN
    
DEC_SEG:
    MOVF    SEGUNDOS_TIMER, W ; Segundos del timer a W
    SUBLW   -1		      ; -1- SEGUNDOS
    BTFSC   ZERO	      ; Se verifica si se tienen -1 segundos    
    MOVLW   59
    BTFSC   ZERO
    MOVWF   SEGUNDOS_TIMER    ; De -1 segundos se pasa a 59 segundos 
    
    CALL    DISPLAY_TIMER     ; Subrutina para obtención de display
    
    RETURN
    
DISPLAY_TIMER:
    
    CLRF    UNIDADES_TEMP    ; Se limpian variables de display de segundos
    CLRF    DECENAS_TEMP
    
    MOVF    SEGUNDOS_TIMER, W 
    MOVWF   DIV
  
    MOVLW   10	       ; Restamos 10 para obtener cantidad de decenas
    SUBWF   DIV, F	     
    INCF    DECENAS_TEMP ; +1 decena de segundo
    BTFSC   STATUS, 0  ; Se verifica si ocurrió BORROW (resultado aún mayor que 10)
    GOTO    $-4	       ; De ser así se continua restando
    DECF    DECENAS_TEMP ; Se elimina la última añadición pues ya nos pasamos
    MOVLW   10	       ; Se regresa el valor a sus unidades antes de la resta 
    ADDWF   DIV, F
    
    MOVLW   1	       ; Restamos 1 para obtener cantidad de unidades
    SUBWF   DIV, F	            
    INCF    UNIDADES_TEMP; +1 unidad de segundo
    BTFSC   STATUS, 0  ; Se verifica si ocurrió BORROW (resultado aún mayor que 1)
    GOTO    $-4	       ; De ser así se continua restando
    DECF    UNIDADES_TEMP
    MOVLW   1	       ; Se elimina la última añadición pues ya nos pasamos
    ADDWF   DIV, F     ; Se regresa el valor a 0 en este caso
    
    RETURN
    
EDIT_MIN_T:
    BANKSEL IOCB
    BCF	    IOCB, BT_MODO     ; Se deshabilita cambio de modo
    BCF	    IOCB, BT_INICIAR  ; Se deshabilita activación timer
    
    BANKSEL T2CON
    BCF	    TMR2ON	      ; Se pausa TMR2
    CLRF    TMR2	      ; Se limpia cuenta de TMR2
        
    BCF	    PORTA, LED_DISP1  ; Se enciende led de edición para primer display
    BSF	    PORTA, LED_DISP2
    
    BTFSS   PORTB, BT_UP      ; Se verifica si se encuentra presionado botón de display up
    GOTO    ANTIREB_MIN_T     ; Se pasa a anti-rebote de incremento de minutos
    BTFSS   PORTB, BT_DOWN    ; Se verifica si se encuentra presionado botón de display down
    GOTO    ANTIREB_MIN2_T    ; Se pasa a anti-rebote de decremento de minutos
    
    CLRF    DISPLAY
    SEL_DISPLAY UNIDADES_TEMP, DECENAS_TEMP, CENTENAS_TEMP, MILES_TEMP	; Macro para configuración de displays (MINUTOS:SEGUNDOS)
    
    MOVF    ST_SET, W	
    BTFSC   ZERO	      
    GOTO    TIMER	      ; Se pasa a modo mostrar timer configurado
    
    GOTO    EDIT_MIN_T
    
ANTIREB_MIN_T:
    BTFSS   PORTB, BT_UP      ; Se verifica si se encuentra presionado botón de display up
    GOTO    $-1
    INCF    MINUTOS_TIMER     ; Se incrementa minutos de timer
    CALL    INC_MINT	      ; Se pasa a verificar overflow
    
    GOTO    EDIT_MIN_T

ANTIREB_MIN2_T:
    BTFSS   PORTB, BT_DOWN    ; Se verifica si se encuentra presionado botón de display down
    GOTO    $-1
    DECF    MINUTOS_TIMER     ; Se decrementa minutos de timer
    CALL    DEC_MINT	      ; Se pasa a verificar underflow
    
    GOTO    EDIT_MIN_T

INC_MINT:
    MOVF    MINUTOS_TIMER, W  ; Minutos del timer a W
    SUBLW   100	              ; Se verifica si se tienen 100 minutos
    BTFSC   ZERO	    
    CLRF    MINUTOS_TIMER     ; En 100 minutos se pasa a 0 minutos
    
    CALL    DISPLAY_TIMER_M   ; Subrutina para obtención de display
    
    RETURN
        
DEC_MINT:
    MOVF    MINUTOS_TIMER, W  ; Minutos del timer a W
    SUBLW   -1		      ; -1-Minutos
    BTFSC   ZERO	      ; Se verifica si se tienen -1 minutos    
    MOVLW   99
    BTFSC   ZERO
    MOVWF   MINUTOS_TIMER     ; De -1 minutos se pasa a 99 minutos
    
    CALL    DISPLAY_TIMER_M   ; Subrutina para obtención de display
    
    RETURN
    
DISPLAY_TIMER_M:
    
    CLRF    CENTENAS_TEMP    ; Se limpian variables de display de minutos
    CLRF    MILES_TEMP
    
    MOVF    MINUTOS_TIMER, W 
    MOVWF   DIV2
  
    MOVLW   10	             ; Restamos 10 para obtener cantidad de decenas
    SUBWF   DIV2, F	     
    INCF    MILES_TEMP       ; +1 decena de minuto
    BTFSC   STATUS, 0        ; Se verifica si ocurrió BORROW (resultado aún mayor que 10)
    GOTO    $-4	             ; De ser así se continua restando
    DECF    MILES_TEMP       ; Se elimina la última añadición pues ya nos pasamos
    MOVLW   10	             ; Se regresa el valor a sus unidades antes de la resta 
    ADDWF   DIV2, F
    
    MOVLW   1	             ; Restamos 1 para obtener cantidad de unidades
    SUBWF   DIV2, F	            
    INCF    CENTENAS_TEMP    ; +1 unidad de minuto
    BTFSC   STATUS, 0        ; Se verifica si ocurrió BORROW (resultado aún mayor que 1)
    GOTO    $-4	             ; De ser así se continua restando
    DECF    CENTENAS_TEMP
    MOVLW   1	             ; Se elimina la última añadición pues ya nos pasamos
    ADDWF   DIV2, F          ; Se regresa el valor a 0 en este caso
    
    RETURN
    
;-------------------------------------------------------------------------------
;                      Subrutinas de configuración del PIC
;-------------------------------------------------------------------------------

CONFIG_PINES:
    BANKSEL ANSEL	      ; Cambiamos de banco
    CLRF    ANSEL	      ; Ra como I/O digital
    CLRF    ANSELH	      ; Rb como I/O digital
    
    BANKSEL TRISA
    CLRF    TRISA	      ; PORTA -> Output
    BCF	    TRISE, 0	      ; RE0 output
    BCF	    TRISE, 1	      ; RE1 output
    
    BANKSEL TRISB	      ; Cambiamos de banco
    BSF	    TRISB, BT_UP      ; RB0-RB4 como inputs
    BSF	    TRISB, BT_DOWN
    BSF	    TRISB, BT_EDITAR
    BSF	    TRISB, BT_INICIAR
    BSF	    TRISB, BT_MODO
    
    BANKSEL OPTION_REG	      ; Cambiamos de banco
    BCF	    OPTION_REG,	7     ; PORTB pull-up habilitadas (RBPU)
    
    CLRF    WPUB	      
    BANKSEL WPUB
    BSF	    WPUB,  BT_UP      ; Se habilita registro de Pull-up para RB0-RB4
    BSF	    WPUB,  BT_DOWN
    BSF	    WPUB,  BT_EDITAR
    BSF	    WPUB,  BT_INICIAR
    BSF	    WPUB,  BT_MODO
      
    BANKSEL TRISC
    CLRF    TRISC	      ; PORTC -> output
    
    BANKSEL TRISD
    BCF	    TRISD, SEL_UNIDAD ; RD0-RD3 como output
    BCF	    TRISD, SEL_DECENA
    BCF	    TRISD, SEL_CENTENA
    BCF	    TRISD, SEL_MILES
        
    BANKSEL PORTA             ; Cambiamos de banco
    CLRF    PORTA	      ; Limpieza de puertos para que inicien en 0
    CLRF    PORTB
    CLRF    PORTC
    CLRF    PORTD
    CLRF    PORTE
    
    RETURN

CONFIG_RELOJ:
    BANKSEL OSCCON	      ; Cambiamos de banco
    BSF	    OSCCON, 0	      ; Seteamos para utilizar reloj interno (SCS=1)
    
    ;Se modifican los bits 4 al 6 de OSCCON al valor de 110b para frecuencia de 4 MHz (IRCF=110b)
    BSF	    OSCCON, 6
    BCF	    OSCCON, 5
    BSF	    OSCCON, 4
    
    RETURN

CONFIG_TIMER0:
    BANKSEL OPTION_REG	      ; Cambiamos de banco
    BCF	    T0CS	      ; Seteamos TMR0 como temporizador(T0CS)
    BCF	    PSA		      ; Se asigna el prescaler a TMR0(PSA)
   ; Se setea el prescaler a 256 BSF <2:0>
    BSF	    PS2		      ; PS2
    BSF	    PS1		      ; PS1
    BSF	    PS0		      ; PS0
    
    RESET_TMR0		      ; Macro de reinicio
    
    RETURN

CONFIG_TIMER1:
    BANKSEL INTCON	      ; Cambiamos de banco
    BCF	    TMR1CS	      ; Cambiamos a reloj interno
    BCF	    T1OSCEN	      ; LP - OFF
    
    BSF	    T1CKPS1	      ; Prescaler 1:8
    BSF	    T1CKPS0
    
    BCF	    TMR1GE	      ; TMR1 contador
    BSF	    TMR1ON	      ; Encendemos TMR1
    
    RESET_TMR1 0x0B, 0xDC     ; TMR1 a 500 ms
    
    RETURN

CONFIG_TIMER2:
    BANKSEL PR2		      ; Cambiamos de banco
    MOVLW   240		      ; Valor para interrupciones cada 50 ms
    MOVWF   PR2		      ; Cargamos litaral a PR2    
    
    
    BANKSEL T2CON	      ; Cambiamos de banco
    CLRF    TMR2	      ; TMR2 inicia en 0
    BSF	    T2CKPS1	      ; Prescaler 1:16
    BSF	    T2CKPS0
    BCF	    TMR2IF	      ; Flag de interrupción TMR2
    
    BSF	    TOUTPS3	      ;Postscaler 1:13
    BSF	    TOUTPS2
    BCF	    TOUTPS1
    BCF	    TOUTPS0
    
    BCF	    TMR2ON	      ; TMR2 OFF
    
    RETURN

ENABLE_INTS:
    BANKSEL PIE1
    BSF	    TMR1IE	      ; Se habilita interrupción del TMR1
    BSF	    TMR2IE	      ; Se habilita interrupción del TMR2
    
    BANKSEL INTCON
    BSF	    GIE		      ; Se habilitan todas las interrupciones
    BSF	    PEIE	      ; Se habilitan interrupciones de perifericos
    BSF	    T0IE	      ; Se habilita interrupción del TMR0
    
    BSF	    RBIE	      ; Se habilita la interrupción de cambio de estado de PORTB	          
    BCF	    RBIF	      ; Flag de cambio de estado de PORTB
    
    BCF	    T0IF	      ; Flag de interrupción TMR0
    BCF	    TMR1IF	      ; Flag de interrupción TMR1
    BCF	    TMR2IF	      ; Flag de interrupción TMR2
    
    RETURN
  
CONFIG_IOCRB:
    BANKSEL TRISA	      ; Cambio de banco
    BSF	    IOCB, BT_MODO     ; Se habilita interrupción de cambio de estado para RB4
    BSF	    IOCB, BT_INICIAR  ; Se habilita interrupción de cambio de estado para RB3
    BSF	    IOCB, BT_EDITAR   ; Se habilita interrupción de cambio de estado para RB2  
    
    BANKSEL PORTA	      ; Cambio de banco
    MOVF    PORTB, W	      ; Al leer termina la condición de mismatch
    BCF	    RBIF	      ; Se limpia la flag de cambio de estado de PORTB
    
    RETURN

/*
		         (^?^)(^?^)(^?^)(^?^)(^?^)(^?^)(^?^)
			     FIN, MUCHAS GRACIAS
                         (^?^)(^?^)(^?^)(^?^)(^?^)(^?^)(^?^)
*/
    
END