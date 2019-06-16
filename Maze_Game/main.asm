TITLE Maze
INCLUDE irvine32.inc

MAXROW=28
MAXCOLUMN=82
MAPSIZE EQU MAXROW*MAXCOLUMN;미로의 최대크기

NODE STRUCT	;노드 구조체 선언  14bytes
	x DWORD ?
	y DWORD ?
	parent DWORD ?
	display BYTE ?
	dirs BYTE ?
NODE ENDS
NODESIZE=14

;키보드 관련 상수
UP=72
DOWN=80
LEFT=75
RIGHT=77
CONFIRM=13

;선택강조 색으로 변환
SELECTCOLOR MACRO
	mov ax,240
	call Settextcolor
ENDM

;일반 색으로 변환
DEFAULTCOLOR MACRO
	mov ax,15
	call Settextcolor
ENDM

POS STRUCT
	x DWORD 0
	y DWORD 1
	dir DWORD 0 ; 0:right,1:left,2:up,3:down
POS ENDS

.data

;-------시스템 관련 변수---------
cursor CONSOLE_CURSOR_INFO <1,0>
outputhandle DWORD ?
starttime DWORD ?
;-------시스템 관련 변수---------

;-------게임 관련 변수-----------
Map NODE MAPSIZE dup(<>)	;노드 배열 선언
difficulty BYTE ?			;미로 난이도
row DWORD 27				;미로 행
col DWORD 41				;미로 열

position POS <0,1,0>

;미로생성 시작 노드 변수
start DWORD ?
;미로 생성위한 x,y변수
x DWORD ?
y DWORD ?
;사용자 현재 x,y위치 변수
curx DWORD ?
cury DWORD ?
;미로 출력 범위 지정 x,y 변수
px SDWORD ?
py SDWORD ?
;미로 도착 위치 지정 x,y변수
destx DWORD 40
desty DWORD 25
;-------게임 관련 변수-----------

;-------문자열 관련 변수--------
titleStr BYTE "MAZE GAME",0

intro BYTE "---------미 로 게 임----------",0dh,0ah
	  BYTE "|                            |",0dh,0ah
	  BYTE "| 미로의 난이도를 선택하세요 |",0dh,0ah
	  BYTE "|       (ENTER로 선택)       |",0dh,0ah,0
easy  BYTE "|           초 급            |",0dh,0ah,0
mid   BYTE "|           중 급            |",0dh,0ah,0
hard  BYTE "|           고 급            |",0dh,0ah,0
endl  BYTE "------------------------------",0dh,0ah,0

TimeMsg BYTE "걸린시간",0
sec BYTE " 초",0

PlayMsg BYTE "게임을 진행하려면 아무키나 누르세요...",0dh,0ah,0
ClearMsg BYTE "축하합니다!! 탈출하셨습니다!!!",0dh,0ah,0
ReplayMsg BYTE "다시 게임을 진행하시려면 Y(y)키를 입력하세요... ",0dh,0ah,0
ThankMsg BYTE "플레이 해주셔서 감사합니다!",0dh,0ah,0
;-------문자열 관련 변수--------
.code
main PROC
	FIRST:
	call setting
	call menu
	call init
	call draw
	;미로 생성 시작 노드 지정
	mov esi, OFFSET Map
	mov eax,MAXCOLUMN
	add eax,1
	imul eax, NODESIZE
	add esi,eax
	mov (NODE PTR [esi]).parent,esi
	mov start,esi
	.REPEAT
		call make
	.UNTIL esi==start
	;미로 생성 완료까지 반복
	;도착위치 공백으로 변환
	mov eax,row
	sub eax,2
	imul eax, MAXCOLUMN
	add eax,col
	dec eax
	imul eax, NODESIZE
	mov (NODE PTR Map[eax]).display,' '

	;미로 생성 완료 후 사용자 입력 대기
	call draw
	mov edx,OFFSET PlayMsg
	call writeString
	INPUT:
	mov eax,50
	call delay
	call readKey
	jz INPUT

	;게임 시작
	call playgame

	;게임 클리어 메시지 출력
	call clrscr
	mov edx,OFFSET ClearMsg
	call WriteString
	mov edx,OFFSET ReplayMsg
	call WriteString
	REPLAY:
	call readChar
	;소문자 대문자로 변환
	and al,11011111b
	cmp al,'Y'
	je FIRST
	call clrscr
	;게임 종료
	mov edx,OFFSET ThankMsg
	call WriteString
	exit
main ENDP

setting PROC
	call clrscr
	mov dx,0	
	call gotoxy
	;타이틀 설정
	INVOKE SetConsoleTitle, ADDR titleStr
	INVOKE GetStdHandle, STD_OUTPUT_HANDLE
	mov outputhandle,eax
	;커서 없앰
	INVOKE SetConsoleCursorInfo, outputhandle,ADDR cursor
	;난수 초기화
	call Randomize
	ret
setting ENDP

playgame PROC
	call clrscr
	;시작시간 저장
	INVOKE GetTickCount
	mov starttime,eax
	DRAW:
	;사용자 위치에 따른 미로 출력
	call drawplaying
	INPUT:
	;---경과 시간 출력---
	INVOKE GetTickCount
	mov dh,2
	mov dl,8
	call gotoxy
	mov edx,OFFSET TimeMsg
	call WriteString
	mov dh,3
	mov dl,8
	call gotoxy
	sub eax,starttime
	mov ebx,1000
	mov edx,0
	DIV ebx
	call WriteDec
	mov al,'.'
	call WriteChar
	mov eax,edx
	call WriteDec
	mov edx,OFFSET sec
	call WriteString
	;---경과 시간 출력---
	;사용자 입력
	mov eax,10
	call delay
	call readKey
	jz INPUT
	call control
	mov ebx,(POS PTR position).x
	mov ecx,(POS PTR position).y
	;사용자 도착여부 판단
	.IF ebx==destx && ecx==desty
		JMP FIN
	.ENDIF
	JMP DRAW
	FIN:
	ret
playgame ENDP

drawplaying PROC USES eax ebx ecx edx
	mov edx,0
	call gotoxy
	mov ebx,(POS PTR position).x
	mov ecx,(POS PTR position).y
	;현재 사용자 위치 저장
	mov curx,ebx
	mov cury,ecx
	;출력 종료위치 저장
	mov px,ebx
	mov py,ecx
	add px,3
	add py,3
	;출력 시작위치 지정
	sub ebx,3
	sub ecx,3
	push ebx
	.REPEAT 
		mov ebx,[esp]
		.REPEAT
			;if ecx<0 || ebx<0 || ecx>=row || ebx>=col
			;미로 아닌 부분 벽으로 처리
			cmp ecx,0
				jl NOTMAP
			cmp ebx,0
				jl NOTMAP
			cmp ecx,row
				jge NOTMAP
			cmp ebx,col
				jl NEXT
			NOTMAP:
				mov al,127
				jmp PRINT
			NEXT:
			.IF ecx==cury && ebx==curx	;사용자 위치 출력
				mov al,'@'
			.ELSE
			;미로 출력
				mov esi,ecx
				imul esi,MAXCOLUMN
				add esi,ebx
				imul esi,NODESIZE
				mov al,(NODE PTR Map[esi]).display
			.ENDIF
			PRINT:
			call WriteChar
			inc ebx
		.UNTIL ebx==px
		inc ecx
		call crlf
	.UNTIL ecx==py
	pop ebx
	ret
drawplaying ENDP

control PROC USES eax ebx ecx edx esi
	;현재 위치 저장
	mov ebx,(POS PTR position).x
	mov ecx,(POS PTR position).y
	;0:right,1:left,2:up,3:down
	.IF ah==UP
		dec ecx
		mov edx,2
	.ELSEIF ah==RIGHT
		inc ebx
		mov edx,0
	.ELSEIF ah==LEFT
		dec ebx
		mov edx,1
	.ELSEIF ah==DOWN
		inc ecx
		mov edx,3
	.ENDIF
	;이동위치 미로 밖일경우 이동 안함
	.IF ecx<0 || ebx<0 || ecx>=row || ebx>=col
		ret
	.ENDIF
	mov esi,ecx
	imul esi,MAXCOLUMN
	add esi,ebx
	imul esi,NODESIZE
	mov al,(NODE PTR Map[esi]).display
	;이동위치 벽일경우 이동 안함
	.IF al!=32
		ret
	.ENDIF
	;사용자 위치 저장
	mov (POS ptr position).x,ebx
	mov (POS ptr position).y,ecx
	;방향에 따라 보이는 영역 변화주려 했으나 미구현
	mov (POS ptr position).dir,edx
	ret
control ENDP

;--------난이도 결정 메뉴 출력 함수------
printeasy PROC
	mov edx,OFFSET easy
	call writeString
	ret
printeasy ENDP

printmid PROC
	mov edx,OFFSET mid
	call writeString
	ret
printmid ENDP

printhard PROC
	mov edx,OFFSET hard
	call writeString
	ret
printhard ENDP
;--------난이도 결정 메뉴 출력 함수------

menu PROC
	mov eax,0
	push eax
	;메뉴 출력
	mov edx,OFFSET intro
	call writeString
	SELECTCOLOR
	call printeasy
	DEFAULTCOLOR
	call printmid
	call printhard
	mov edx,OFFSET endl
	call writeString
	INPUT:	;위, 아래 입력
	mov eax,50
	call delay
	call readKey
	jz INPUT
	pop ebx
	mov dl,0
	;선택된 부분 강조표시
	.IF ah==UP
		.IF bl!=0
			dec bl
			.IF bl==0
				mov dh,4
				call gotoxy
				SELECTCOLOR
				call printeasy
				DEFAULTCOLOR
				call printmid
			.ELSE
				mov dh,5
				call gotoxy
				SELECTCOLOR
				call printmid
				DEFAULTCOLOR
				call printhard
			.ENDIF
		.ENDIF
	.ELSEIF ah==DOWN
		.IF bl!=2
			inc bl
			.IF bl==1
				mov dh,4
				call gotoxy
				call printeasy
				SELECTCOLOR
				call printmid
				DEFAULTCOLOR
			.ELSE
				mov dh,5
				call gotoxy
				call printmid
				SELECTCOLOR
				call printhard
				DEFAULTCOLOR
			.ENDIF
		.ENDIF
	.ELSEIF al==CONFIRM	;엔터 입력
		jmp SELECT
	.ENDIF
	push ebx
	jmp INPUT
	SELECT:	;입력에 따른 난이도 결정
	mov difficulty,bl
	.IF difficulty==2
		mov col,81
		mov destx,80
	.ELSEIF difficulty==1
		mov col,61
		mov destx,60
	.ENDIF
	ret
menu ENDP

init PROC
	mov eax, 0
	.REPEAT
		mov ebx, 0
		.REPEAT
			mov esi,eax
			imul esi,MAXCOLUMN
			add esi,ebx
			imul esi,NODESIZE
			mov (NODE PTR Map[esi]).parent,0
			.IF ((eax&1) && (ebx&1))	;행,열 모두 홀수여야 노드로 취급
				mov (NODE PTR Map[esi]).x,ebx
				mov (NODE PTR Map[esi]).y,eax
				mov (NODE PTR Map[esi]).dirs,0Fh
				mov (NODE PTR Map[esi]).display,' '
			.ELSE
				mov (NODE PTR Map[esi]).display,127
			.ENDIF
			inc ebx
		.UNTIL ebx >= col
		inc eax
	.UNTIL eax >= row
	mov eax,MAXCOLUMN
	iMUL eax, NODESIZE
	mov (NODE PTR Map[eax]).display,'&'	;시작위치 지정
	ret
init ENDP

make PROC
	;현재 노드의 정보 저장
	mov dl,(NODE PTR [esi]).dirs
	mov ebx,(NODE PTR [esi]).x
	mov x,ebx
	mov ecx,(NODE PTR [esi]).y
	mov y,ecx
	.WHILE dl>0
		;0~100 난수 생성해 4로 나눈 나머지 이용
		mov eax,101
		call RandomRange
		and eax,3h
		mov ecx,eax
		;이미 탐색했는지 체크
		bt dx,cx
		jnc LOOPFIN
		mov bl,1
		shl bx,cl
		not bl
		and dl,bl
		;탐색한 방향 업데이트
		mov (NODE PTR [esi]).dirs,dl

		;방향에 맞는 다음 위치 지정
		.IF al==0;right
			mov eax,x
			add eax,2
			.IF eax<col
				mov ebx,eax
				mov ecx,y
			.ELSE
				jmp LOOPFIN
			.ENDIF
		.ELSEIF al==1;down
			mov eax,y
			add eax,2
			.IF eax<row
				mov ebx,x
				mov ecx,eax
			.ELSE
				jmp LOOPFIN
			.ENDIF
		.ELSEIF al==2;left
			.IF x>=2
				mov ebx,x
				sub ebx,2
				mov ecx,y
			.ELSE
				jmp LOOPFIN
			.ENDIF
		.ELSEIF al==3;up
			.IF y>=2
				mov ebx,x
				mov ecx,y
				sub ecx,2
			.ELSE
				jmp LOOPFIN
			.ENDIF
		.ENDIF

		;다음 위치 노드 확인
		mov edi,OFFSET Map
		mov eax,ecx
		imul eax,MAXCOLUMN
		add eax,ebx
		imul eax,NODESIZE
		add edi,eax
		push edx
		mov dl,(NODE PTR [edi]).display
		mov eax,(NODE PTR [edi]).parent
		;빈칸이고 공백인 노드인지 확인
		.IF dl==' ' && eax==0
			mov (NODE PTR [edi]).parent,esi
			sub ecx,y
			shr ecx,1
			add ecx,y
			sub ebx,x
			shr ebx,1
			add ebx,x
			imul ecx,MAXCOLUMN
			add ecx,ebx
			imul ecx,NODESIZE
			;사이 노드에 길 생성
			mov (NODE PTR Map[ecx]).display,' '
			pop edx
			mov (NODE PTR [esi]).dirs,dl
			;탐색할 노드 위치 변경
			mov esi,edi
			;미로 생성과정 출력
			call draw
			jmp ENDFUNC
		.ENDIF
		pop edx
		LOOPFIN:
	.ENDW
	;탐색할 방향 없을 경우 뒤로 돌아감
	mov esi,(NODE PTR [esi]).parent
	ENDFUNC:
	ret
make ENDP

draw PROC USES eax ebx ecx edx
;지도 그리는 함수
	mov dx,0	;위치 초기화
	call gotoxy
	mov eax, 0
	.REPEAT
		mov ebx, 0
		.REPEAT
			mov ecx,eax
			imul ecx,MAXCOLUMN
			add ecx,ebx
			imul ecx,NODESIZE
			push eax
			mov al,(NODE PTR Map[ecx]).display
			call WriteChar
			pop eax
			inc ebx
		.UNTIL ebx == col
		call crlf
		inc eax
	.UNTIL eax == row
	ret
draw ENDP

END main