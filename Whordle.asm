; * Carles Vilella, 2017 (ENTI-UB)

; *************************************************************************
; Our data section. Here we declare our strings for our console message
; *************************************************************************

SGROUP 		GROUP 	CODE_SEG, DATA_SEG
			ASSUME 	CS:SGROUP, DS:SGROUP, SS:SGROUP

    TRUE  EQU 1
    FALSE EQU 0

; EXTENDED ASCII CODES
    ASCII_SPECIAL_KEY EQU 00
    ASCII_LEFT        EQU 04Bh
    ASCII_RIGHT       EQU 04Dh
    ASCII_UP          EQU 048h
    ASCII_DOWN        EQU 050h
    ASCII_QUIT        EQU 01Bh ; 'Escape'

; ASCII / ATTR CODES TO DRAW THE FIELD
    ASCII_FIELD    EQU 020h
    ATTR_FIELD     EQU 070h

    ASCII_NUMBER_ZERO EQU 030h

; CURSOR
    CURSOR_SIZE_HIDE EQU 02607h  ; BIT 5 OF CH = 1 MEANS HIDE CURSOR
    CURSOR_SIZE_SHOW EQU 00607h

; ASCII
    ASCII_YES_UPPERCASE      EQU 059h
    ASCII_YES_LOWERCASE      EQU 079h
	ASCII_ENTER              EQU 13
	ASCII_BACKSPACE          EQU 008h

; COMPARE_CHARS
    ASCII_Z_LOWER_CHAR      EQU 7Ah
    ASCII_A_LOWER_CHAR      EQU 61h
    ASCII_Z_UPPER_CHAR      EQU 5Ah
    ASCII_A_UPPER_CHAR      EQU 41h


    ASCII_LOWER_TO_UPPER    EQU 20h

; COLOR SCREEN DIMENSIONS IN NUMBER OF CHARACTERS
    SCREEN_MAX_ROWS EQU 17
    SCREEN_MAX_COLS EQU 20

; FIELD DIMENSIONS
    FIELD_R1 EQU 1
    FIELD_R2 EQU SCREEN_MAX_ROWS-2
    FIELD_C1 EQU 1
    FIELD_C2 EQU SCREEN_MAX_COLS-2
	
; GAME CONSTANTS
    WORD_COUNT EQU 6h
	LETTER_COUNT EQU 5h

; *************************************************************************
; Our executable assembly code starts here in the .code section
; *************************************************************************
CODE_SEG	SEGMENT PUBLIC
			ORG 100h

MAIN 	PROC 	NEAR

  MAIN_GO:

      CALL REGISTER_TIMER_INTERRUPT

      CALL INIT_GAME
      CALL INIT_SCREEN
      CALL DRAW_FIELD

      MOV DH, 3
      MOV DL, 5
      
      CALL MOVE_CURSOR
	  
	  ; BL = letter counter
	  MOV BL, LETTER_COUNT
	  ; BH = Word counter
	  MOV BH, WORD_COUNT
	  
	  LEA SI, [CURR_WORD]
      
  MAIN_LOOP:
      CMP [END_GAME], TRUE
      JZ END_PROG

	  ; Game end
	  CMP BH, 0
	  JE END_PROG

      ; Check if a key is available to read
      MOV AH, 0Bh
      INT 21h
      CMP AL, 0
      JZ MAIN_LOOP

      ; A key is available -> read
      CHECK_LOOP:
      CALL READ_CHAR   
      CALL LOWER_TO_UPPER

	  ; Quit
      CMP AL, ASCII_QUIT
      JZ END_PROG
	  
	  ; Check backspace
	  CMP AL, ASCII_BACKSPACE
	  JNE END_IF_BACKSPACE
	  CMP BL, LETTER_COUNT
	  JE END_IF_BACKSPACE
	  
	  DEC SI
	  
	  ADD BL, 1
	  SUB DL, 2
	  CALL MOVE_CURSOR
	  MOV AL, 20h
	  CALL PRINT_CHAR
	  CALL MOVE_CURSOR
	  JMP END_KEY
	  
  END_IF_BACKSPACE:
	  
	  ; Check if final letter
	  CMP BL, 0
	  JNE END_IF_FINAL_LETTER	
	  CMP AL, ASCII_ENTER
	  JNE END_KEY
	  
	  ;; validate word
	  CALL CHECK_WORD
	  
	  ;;DEBUG
	  PUSH AX
	  PUSH BX
	  PUSH CX
	  PUSH DX
	  MOV AL, [CORRECT_LETTER_FLAG]
	  ADD AL, 30h
	  ;CALL PRINT_CHAR
  
	  MOV AL, [CORRECT_POSITION_FLAG]
	  ADD AL, 30h
	  ;CALL PRINT_CHAR
	  POP DX
	  POP CX
	  POP BX
	  POP AX

	  MOV [PRESS_ENTER], 1

	  CALL FILL_TILE
	  
	  MOV [PRESS_ENTER], 0
	  
	  LEA SI, [CURR_WORD]
	  MOV BL, LETTER_COUNT
	  SUB BH, 1
	  ADD DH, 2
      MOV DL, 5
      CALL MOVE_CURSOR
	  JMP END_KEY
	  
  END_IF_FINAL_LETTER:
  
	  ; Input letter
      CMP AL, ASCII_Z_UPPER_CHAR
      JA CHECK_LOOP
      CMP AL, ASCII_A_UPPER_CHAR
      JB CHECK_LOOP

	  MOV [SI], AL
	  INC SI

	  ADD DL, 2
	  SUB BL, 1
      CALL PRINT_CHAR
      
      ; Is it a special key?
      CMP AL, ASCII_SPECIAL_KEY
      JNZ MAIN_LOOP
      
      CALL READ_CHAR

      ; The game is on!
      MOV [START_GAME], TRUE
      
      JMP MAIN_LOOP
      
  END_KEY:
      JMP MAIN_LOOP

  END_PROG:
      CALL RESTORE_TIMER_INTERRUPT
      CALL SHOW_CURSOR
      CALL PRINT_SCORE_STRING
      CALL PRINT_SCORE
      CALL PRINT_PLAY_AGAIN_STRING
      
      CALL READ_CHAR

      CMP AL, ASCII_YES_UPPERCASE
      JZ MAIN_GO
      CMP AL, ASCII_YES_LOWERCASE
      JZ MAIN_GO

	INT 20h		

MAIN	ENDP	

; ****************************************
; Reads char from keyboard
; If char is not available, blocks until a key is pressed
; The char is not output to screen
; Entry: 
;
; Returns:
;   AL: ASCII CODE
;   AH: ATTRIBUTE
; Modifies:
;   
; Uses: 
;   
; Calls:
;   
; ****************************************
PUBLIC  CHECK_WORD
CHECK_WORD PROC NEAR

	PUSH SI ; game word pointer
	PUSH AX ; current word pointer
	PUSH BX ; current word flags
    PUSH CX ; temp storage
	PUSH DX ; loop counters
	
	XOR SI, SI
	XOR AX, AX
	XOR BX, BX
	XOR CX, CX
	XOR DX, DX
	
	MOV DH, LETTER_COUNT
	LEA AX, [CURR_WORD]
	
	; Loop: For every letter in the current word,
	; check if it's in the game word, and if their positions match
	
  WORD_LOOP_1:
  
	MOV DL, LETTER_COUNT
	LEA SI, [GAME_WORD]
  
  WORD_LOOP_2:
    
	MOV CH, [SI]
	
	PUSH SI
	MOV SI, AX
	MOV CL, [SI]
	POP SI
	
	; Do letters match
	CMP CL, CH
	JNE END_LOOP_2
	; Do positions match
	CMP DL, DH
	JE CORRECT_POSITION

  CORRECT_LETTER:
  
    OR BH, 1
	JMP END_LOOP_2
  
  CORRECT_POSITION:
  
    OR BL, 1
	AND BH, 0FEh
	JMP END_LOOP_1
		
  END_LOOP_2:
	
	INC SI
	SUB DL, 1
	CMP DL, 0
	JNE WORD_LOOP_2
	
  END_LOOP_1:
	
	INC AX
	SUB DH, 1
	CMP DH, 0
	JE END_LOOP
  
    SHL BH, 1
	SHL BL, 1
	JMP WORD_LOOP_1
	
  END_LOOP:	
	
	; Save flags
	LEA SI, [CORRECT_LETTER_FLAG]
	MOV [SI], BH
	LEA SI, [CORRECT_POSITION_FLAG]
	MOV [SI], BL
	
	POP DX
	POP CX
    POP BX
	POP AX
	POP SI

    RET
      
CHECK_WORD ENDP

; ****************************************
; Reset internal variables
; Entry: 
;   
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   INC_ROW memory variable
;   INC_COL memory variable
;   DIV_SPEED memory variable
;   NUM_TILES memory variable
;   START_GAME memory variable
;   END_GAME memory variable
; Calls:
;   -
; ****************************************
                  PUBLIC  INIT_GAME
INIT_GAME         PROC    NEAR

    MOV [DIV_SPEED], 10
    
    MOV [START_GAME], FALSE
    MOV [END_GAME], FALSE

    RET
INIT_GAME	ENDP	

; ****************************************
; Reset internal variables
; Entry: 
;   
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   INC_ROW memory variable
;   INC_COL memory variable
;   DIV_SPEED memory variable
;   NUM_TILES memory variable
;   START_GAME memory variable
;   END_GAME memory variable
; Calls:
;   -
; ****************************************
                  PUBLIC  FILL_TILE
FILL_TILE         PROC    NEAR

	PUSH DX
	PUSH AX
	PUSH CX
	PUSH BX
	PUSH SI
	
	LEA SI, [CURR_WORD]
	
	INC SI
	INC SI
	INC SI
	INC SI
	
	MOV CL, 0 ;contador
	MOV BH, 0 ;max loops	
	
		
RESTORE_CORRECT_LETTER_FLAG:

	MOV AL, [CORRECT_LETTER_FLAG]
	
SHIFT_RIGHT_LOOP_FOR_CORRECT_LETTER:
	
	CMP CL, BH
	JE CHECK_TILE_FOR_CORRECT_LETTER
	SHR AL, 1
	INC CL
	JMP SHIFT_RIGHT_LOOP_FOR_CORRECT_LETTER

CHECK_TILE_FOR_CORRECT_LETTER:

	CALL GET_CURSOR_PROP
	SUB DL, 2
	CALL MOVE_CURSOR
	
	MOV CL, 0
	AND AL, 01h
	CMP AL, 1
	JNE RESTORE_CORRECT_POSITION_FLAG	
		
	;draw
	MOV AL, [SI]
	MOV BL, 0E0h
	CALL PRINT_CHAR_ATTR
	DEC SI
	;draw		
		
	INC BH
	CMP BH, 5
	JNE RESTORE_CORRECT_LETTER_FLAG
	JMP END_FILL_TILE





RESTORE_CORRECT_POSITION_FLAG:

	MOV BL, 0
	MOV AL, [CORRECT_POSITION_FLAG]
	
SHIFT_RIGHT_LOOP_FOR_CORRECT_POSITION:

	CMP BL, BH
	JE CHECK_TILE_FOR_CORRECT_POSITION
	SHR AL, 1
	INC BL
	JMP SHIFT_RIGHT_LOOP_FOR_CORRECT_POSITION
	
CHECK_TILE_FOR_CORRECT_POSITION:

	AND AL, 01h
	CMP AL, 1
	JNE FILL_WITH_GREY
	
	;DRAW	
	MOV AL, [SI]
	MOV BL, 20h
	CALL PRINT_CHAR_ATTR
	DEC SI
	;DRAW
	
	INC BH
	CMP BH, 5
	JB RESTORE_CORRECT_LETTER_FLAG
	JMP END_FILL_TILE
	
	
	
	
	
	
	
FILL_WITH_GREY:

	;DRAW
	MOV AL, [SI]
	MOV BL, 70h
	CALL PRINT_CHAR_ATTR
	DEC SI
	;DRAW

	INC BH
	CMP BH, 5
	JB RESTORE_CORRECT_LETTER_FLAG
	
END_FILL_TILE:

	POP SI
	POP BX
	POP CX
	POP AX
	POP DX

    RET
FILL_TILE	ENDP	

; ****************************************
; Reads char from keyboard
; If char is not available, blocks until a key is pressed
; The char is not output to screen
; Entry: 
;
; Returns:
;   AL: ASCII CODE
;   AH: ATTRIBUTE
; Modifies:
;   
; Uses: 
;   
; Calls:
;   
; ****************************************
PUBLIC  READ_CHAR
READ_CHAR PROC NEAR

    MOV AH, 8
    INT 21h

    RET
      
READ_CHAR ENDP


; ****************************************
; Read character and attribute at cursor position, page 0
; Entry: 
;
; Returns:
;   AL: ASCII CODE
;   AH: ATTRIBUTE
; Modifies:
;   
; Uses: 
;   
; Calls:
;   int 10h, service AH=8
; ****************************************
PUBLIC READ_SCREEN_CHAR                 
READ_SCREEN_CHAR PROC NEAR

    PUSH BX

    MOV AH, 8
    XOR BH, BH
    INT 10h

    POP BX
    RET
      
READ_SCREEN_CHAR  ENDP

; ****************************************
; Draws the rectangular field of the game
; Entry: 
; 
; Returns:
;   
; Modifies:
;   
; Uses: 
;   Coordinates of the rectangle: 
;    left - top: (FIELD_R1, FIELD_C1) 
;    right - bottom: (FIELD_R2, FIELD_C2)
;   Character: ASCII_FIELD
;   Attribute: ATTR_FIELD
; Calls:
;   PRINT_CHAR_ATTR
; ****************************************
PUBLIC DRAW_FIELD
DRAW_FIELD PROC NEAR

    PUSH AX
    PUSH BX
    PUSH DX

    MOV AL, ASCII_FIELD
    MOV BL, ATTR_FIELD

    MOV DL, FIELD_C2
  UP_DOWN_SCREEN_LIMIT:
    MOV DH, FIELD_R1
    CALL MOVE_CURSOR
    CALL PRINT_CHAR_ATTR

    MOV DH, FIELD_R2
    CALL MOVE_CURSOR
    CALL PRINT_CHAR_ATTR

    DEC DL
    CMP DL, FIELD_C1
    JNS UP_DOWN_SCREEN_LIMIT

    MOV DH, FIELD_R2
  LEFT_RIGHT_SCREEN_LIMIT:
    MOV DL, FIELD_C1
    CALL MOVE_CURSOR
    CALL PRINT_CHAR_ATTR

    MOV DL, FIELD_C2
    CALL MOVE_CURSOR
    CALL PRINT_CHAR_ATTR

    DEC DH
    CMP DH, FIELD_R1
    JNS LEFT_RIGHT_SCREEN_LIMIT
                 
    POP DX
    POP BX
    POP AX
    RET

DRAW_FIELD       ENDP

; ****************************************
; Prints character and attribute in the 
; current cursor position, page 0 
; Keeps the cursor position
; Entry: 
;   AL: ASCII to print
;   BL: ATTRIBUTE to print
; Returns:
;   
; Modifies:
;   
; Uses: 
;
; Calls:
;   int 10h, service AH=9
; Nota:
;   Compatibility problem when debugging
; ****************************************
PUBLIC PRINT_CHAR_ATTR
PRINT_CHAR_ATTR PROC NEAR

    PUSH AX
    PUSH BX
    PUSH CX

    MOV AH, 9
    MOV BH, 0
    MOV CX, 1
    INT 10h

    POP CX
    POP BX
    POP AX
    RET

PRINT_CHAR_ATTR        ENDP     

; ****************************************
; Prints character and attribute in the 
; current cursor position, page 0 
; Cursor moves one position right
; Entry: 
;    AL: ASCII code to print
; Returns:
;   
; Modifies:
;   
; Uses: 
;
; Calls:
;   int 21h, service AH=2
; ****************************************
PUBLIC PRINT_CHAR
PRINT_CHAR PROC NEAR

    PUSH AX
    PUSH DX

    MOV AH, 2
    MOV DL, AL
    INT 21h
    MOV DL, 20h
    INT 21h

    POP DX
    POP AX

    RET

PRINT_CHAR        ENDP     

; ****************************************
; CONVERT LOWER CHAR TO UPPER CHAR
; Entry: 
;    AL: ASCII code to print
; Returns:
;   AL
; Modifies:
;   
; Uses: 
;
; Calls:
; ****************************************
PUBLIC LOWER_TO_UPPER
LOWER_TO_UPPER PROC NEAR

    CMP AL, ASCII_Z_LOWER_CHAR
    JA END_IF_LOWER_TO_UPPER
    CMP AL, ASCII_A_LOWER_CHAR
    JB END_IF_LOWER_TO_UPPER

    SUB AL, ASCII_LOWER_TO_UPPER


END_IF_LOWER_TO_UPPER:
    RET

LOWER_TO_UPPER        ENDP     

; ****************************************
; CHECK IF IS VALID CHAR
; Entry: 
;    AL: ASCII code to print
; Returns:
;   CL
; Modifies:
;   
; Uses: 
;
; Calls:
; ****************************************

PUBLIC CHECK_UPPER_CHAR
CHECK_UPPER_CHAR PROC NEAR

      MOV  CL, 1

      CMP AL, ASCII_Z_UPPER_CHAR
      JA REPEAT_CHAR
      CMP AL, ASCII_A_UPPER_CHAR
      JB REPEAT_CHAR

      JMP END_IF_CHECK_UPPER_CHAR

REPEAT_CHAR:
    MOV CL, 0


END_IF_CHECK_UPPER_CHAR:

      RET

CHECK_UPPER_CHAR ENDP



; ****************************************
; Set screen to mode 3 (80x25, color) and 
; clears the screen
; Entry: 
;   -
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   Screen size: SCREEN_MAX_ROWS, SCREEN_MAX_COLS
; Calls:
;   int 10h, service AH=0
;   int 10h, service AH=6
; ****************************************
PUBLIC INIT_SCREEN
INIT_SCREEN	PROC NEAR

      PUSH AX
      PUSH BX
      PUSH CX
      PUSH DX

      ; Set screen mode
      MOV AL,3
      MOV AH,0
      INT 10h

      ; Clear screen
      XOR AL, AL
      XOR CX, CX
      MOV DH, SCREEN_MAX_ROWS
      MOV DL, SCREEN_MAX_COLS
      MOV BH, 7
      MOV AH, 6
      INT 10h
      
      POP DX      
      POP CX      
      POP BX      
      POP AX      
	RET

INIT_SCREEN		ENDP

; ****************************************
; Hides the cursor 
; Entry: 
;   -
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   -
; Calls:
;   int 10h, service AH=1
; ****************************************
PUBLIC  HIDE_CURSOR
HIDE_CURSOR PROC NEAR

      PUSH AX
      PUSH CX
      
      MOV AH, 1
      MOV CX, CURSOR_SIZE_HIDE
      INT 10h

      POP CX
      POP AX
      RET

HIDE_CURSOR       ENDP

; ****************************************
; Shows the cursor (standard size)
; Entry: 
;   -
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   -
; Calls:
;   int 10h, service AH=1
; ****************************************
PUBLIC SHOW_CURSOR
SHOW_CURSOR PROC NEAR

    PUSH AX
    PUSH CX
      
    MOV AH, 1
    MOV CX, CURSOR_SIZE_SHOW
    INT 10h

    POP CX
    POP AX
    RET

SHOW_CURSOR       ENDP

; ****************************************
; Get cursor properties: coordinates and size (page 0)
; Entry: 
;   -
; Returns:
;   (DH, DL): coordinates -> (row, col)
;   (CH, CL): cursor size
; Modifies:
;   -
; Uses: 
;   -
; Calls:
;   int 10h, service AH=3
; ****************************************
PUBLIC GET_CURSOR_PROP
GET_CURSOR_PROP PROC NEAR

      PUSH AX
      PUSH BX

      MOV AH, 3
      XOR BX, BX
      INT 10h

      POP BX
      POP AX
      RET
      
GET_CURSOR_PROP       ENDP

; ****************************************
; Set cursor properties: coordinates and size (page 0)
; Entry: 
;   (DH, DL): coordinates -> (row, col)
;   (CH, CL): cursor size
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   -
; Calls:
;   int 10h, service AH=2
; ****************************************
PUBLIC SET_CURSOR_PROP
SET_CURSOR_PROP PROC NEAR

      PUSH AX
      PUSH BX

      MOV AH, 2
      XOR BX, BX
      INT 10h

      POP BX
      POP AX
      RET
      
SET_CURSOR_PROP       ENDP

; ****************************************
; Move cursor to coordinate
; Cursor size if kept
; Entry: 
;   (DH, DL): coordinates -> (row, col)
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   -
; Calls:
;   GET_CURSOR_PROP
;   SET_CURSOR_PROP
; ****************************************
PUBLIC MOVE_CURSOR
MOVE_CURSOR PROC NEAR

      PUSH DX
      CALL GET_CURSOR_PROP  ; Get cursor size
      POP DX
      CALL SET_CURSOR_PROP
      RET

MOVE_CURSOR       ENDP

; ****************************************
; Moves cursor one position to the right
; If the column limit is reached, the cursor does not move
; Cursor size if kept
; Entry: 
;   -
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   SCREEN_MAX_COLS
; Calls:
;   GET_CURSOR_PROP
;   SET_CURSOR_PROP
; ****************************************
PUBLIC  MOVE_CURSOR_RIGHT
MOVE_CURSOR_RIGHT PROC NEAR

    PUSH CX
    PUSH DX

    CALL GET_CURSOR_PROP
    ADD DL, 1
    CMP DL, SCREEN_MAX_COLS
    JZ MOVE_CURSOR_RIGHT_END
    
    CALL SET_CURSOR_PROP

  MOVE_CURSOR_RIGHT_END:
    POP DX
    POP CX
    RET

MOVE_CURSOR_RIGHT       ENDP

; ****************************************
; Print string to screen
; The string end character is '$'
; Entry: 
;   DX: pointer to string
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   SCREEN_MAX_COLS
; Calls:
;   INT 21h, service AH=9
; ****************************************
PUBLIC PRINT_STRING
PRINT_STRING PROC NEAR

    PUSH DX
      
    MOV AH,9
    INT 21h

    POP DX
    RET

PRINT_STRING       ENDP

; ****************************************
; Print the score string, starting in the cursor
; (FIELD_C1, FIELD_R2) coordinate
; Entry: 
;   DX: pointer to string
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   SCORE_STR
;   FIELD_C1
;   FIELD_R2
; Calls:
;   GET_CURSOR_PROP
;   SET_CURSOR_PROP
;   PRINT_STRING
; ****************************************
PUBLIC PRINT_SCORE_STRING
PRINT_SCORE_STRING PROC NEAR

    PUSH CX
    PUSH DX

    CALL GET_CURSOR_PROP  ; Get cursor size
    MOV DH, FIELD_R2+1
    MOV DL, FIELD_C1
    CALL SET_CURSOR_PROP

    LEA DX, SCORE_STR
    CALL PRINT_STRING

    POP DX
    POP CX
    RET

PRINT_SCORE_STRING       ENDP

; ****************************************
; Print the score string, starting in the
; current cursor coordinate
; Entry: 
;   -
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   PLAY_AGAIN_STR
;   FIELD_C1
;   FIELD_R2
; Calls:
;   PRINT_STRING
; ****************************************
PUBLIC PRINT_PLAY_AGAIN_STRING
PRINT_PLAY_AGAIN_STRING PROC NEAR

    PUSH DX

    LEA DX, PLAY_AGAIN_STR
    CALL PRINT_STRING

    POP DX
    RET

PRINT_PLAY_AGAIN_STRING       ENDP

; ****************************************
; Prints the score of the player in decimal, on the screen, 
; starting in the cursor position
; NUM_TILES range: [0, 9999]
; Entry: 
;   -
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   NUM_TILES memory variable
; Calls:
;   PRINT_CHAR
; ****************************************
PUBLIC PRINT_SCORE
PRINT_SCORE PROC NEAR

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    ; 1000'
    XOR DX, DX
    MOV BX, 1000
    DIV BX            ; DS:AX / BX -> AX: quotient, DX: remainder
    ADD AL, ASCII_NUMBER_ZERO
    CALL PRINT_CHAR

    ; 100'
    MOV AX, DX        ; Remainder
    XOR DX, DX
    MOV BX, 100
    DIV BX            ; DS:AX / BX -> AX: quotient, DX: remainder
    ADD AL, ASCII_NUMBER_ZERO
    CALL PRINT_CHAR

    ; 10'
    MOV AX, DX          ; Remainder
    XOR DX, DX
    MOV BX, 10
    DIV BX            ; DS:AX / BX -> AX: quotient, DX: remainder
    ADD AL, ASCII_NUMBER_ZERO
    CALL PRINT_CHAR

    ; 1'
    MOV AX, DX
    ADD AL, ASCII_NUMBER_ZERO
    CALL PRINT_CHAR

    POP DX
    POP CX
    POP BX
    POP AX
    RET   
         
PRINT_SCORE        ENDP

; ****************************************
; Game timer interrupt service routine
; Called 18.2 times per second by the operating system
; Calls previous ISR
; Manages the movement of the snake: 
;   position, direction, speed, length, display, collisions
; Entry: 
;   -
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   OLD_INTERRUPT_BASE memory variable
;   START_GAME memory variable
;   END_GAME memory variable
;   INT_COUNT memory variable
;   DIV_SPEED memory variable
;   INC_COL memory variable
;   INC_ROW memory variable
;   ATTR_SNAKE constant
;   NUM_TILES memory variable
;   NUM_TILES_INC_SPEED
; Calls:
;   MOVE_CURSOR
;   READ_SCREEN_CHAR
;   PRINT_SNAKE
; ****************************************
PUBLIC NEW_TIMER_INTERRUPT
NEW_TIMER_INTERRUPT PROC NEAR

    ; Call previous interrupt
    PUSHF
    CALL DWORD PTR [OLD_INTERRUPT_BASE]

    PUSH AX

    ; Do nothing if game is stopped
    CMP [PRESS_ENTER], TRUE
    JNZ END_ISR
	
    ; Check if it is time to increase the speed of the snake
    CMP [DIV_SPEED], 1
    JZ END_ISR
    MOV AX, [TIME_SPEED]
    DIV [REVEAL_SPEED]
    CMP AH, 0                 ; REMAINDER
    JNZ END_ISR
    DEC [DIV_SPEED]

    JMP END_ISR
      
END_SNAKES:
      MOV [END_GAME], TRUE
      
END_ISR:

      POP AX
      IRET

NEW_TIMER_INTERRUPT ENDP
                 
; ****************************************
; Replaces current timer ISR with the game timer ISR
; Entry: 
;   -
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   OLD_INTERRUPT_BASE memory variable
;   NEW_TIMER_INTERRUPT memory variable
; Calls:
;   int 21h, service AH=35 (system interrupt 08)
; ****************************************
PUBLIC REGISTER_TIMER_INTERRUPT
REGISTER_TIMER_INTERRUPT PROC NEAR

        PUSH AX
        PUSH BX
        PUSH DS
        PUSH ES 

        CLI                                 ;Disable Ints
        
        ;Get current 01CH ISR segment:offset
        MOV  AX, 3508h                      ;Select MS-DOS service 35h, interrupt 08h
        INT  21h                            ;Get the existing ISR entry for 08h
        MOV  WORD PTR OLD_INTERRUPT_BASE+02h, ES  ;Store Segment 
        MOV  WORD PTR OLD_INTERRUPT_BASE, BX  ;Store Offset

        ;Set new 01Ch ISR segment:offset
        MOV  AX, 2508h                      ;MS-DOS serivce 25h, IVT entry 01Ch
        MOV  DX, offset NEW_TIMER_INTERRUPT ;Set the offset where the new IVT entry should point to
        INT  21h                            ;Define the new vector

        STI                                 ;Re-enable interrupts

        POP  ES                             ;Restore interrupts
        POP  DS
        POP  BX
        POP  AX
        RET      

REGISTER_TIMER_INTERRUPT ENDP

; ****************************************
; Restore timer ISR
; Entry: 
;   -
; Returns:
;   -
; Modifies:
;   -
; Uses: 
;   OLD_INTERRUPT_BASE memory variable
; Calls:
;   int 21h, service AH=25 (system interrupt 08)
; ****************************************
PUBLIC RESTORE_TIMER_INTERRUPT
RESTORE_TIMER_INTERRUPT PROC NEAR

      PUSH AX                             
      PUSH DS
      PUSH DX 

      CLI                                 ;Disable Ints
        
      ;Restore 08h ISR
      MOV  AX, 2508h                      ;MS-DOS service 25h, ISR 08h
      MOV  DX, WORD PTR OLD_INTERRUPT_BASE
      MOV  DS, WORD PTR OLD_INTERRUPT_BASE+02h
      INT  21h                            ;Define the new vector

      STI                                 ;Re-enable interrupts

      POP  DX                             
      POP  DS
      POP  AX
      RET    
      
RESTORE_TIMER_INTERRUPT ENDP

CODE_SEG 	ENDS

DATA_SEG	SEGMENT	PUBLIC
			
    OLD_INTERRUPT_BASE    DW  0, 0  ; Stores the current (system) timer ISR address

    ; (INC_ROW. INC_COL) may be (-1, 0, 1), and determine the direction of movement of the snake
    INC_ROW DB 0    
    INC_COL DB 0
	
	PRESS_ENTER DW 0

    TIME_SPEED DW 0              ; SNAKE LENGTH
    REVEAL_SPEED DB 20   ; THE SPEED IS INCREASED EVERY 'NUM_TILES_INC_SPEED'
    
    DIV_SPEED DB 10             ; THE SNAKE SPEED IS THE (INTERRUPT FREQUENCY) / DIV_SPEED
    INT_COUNT DB 0              ; 'INT_COUNT' IS INCREASED EVERY INTERRUPT CALL, AND RESET WHEN IT ACHIEVES 'DIV_SPEED'

    START_GAME DB 0             ; 'MAIN' sets START_GAME to '1' when a key is pressed
    END_GAME DB 0               ; 'NEW_TIMER_INTERRUPT' sets END_GAME to '1' when a condition to end the game happens

    SCORE_STR           DB "Your score is $"
    PLAY_AGAIN_STR      DB ". Do you want to play again? (Y/N)$"
	
	GAME_WORD              DB "COCKA"
    CURR_WORD              DB 5 DUP(0)
	
	CORRECT_LETTER_FLAG    DB 0
	CORRECT_POSITION_FLAG  DB 0
    
DATA_SEG	ENDS

		END MAIN
