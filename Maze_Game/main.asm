TITLE Maze
INCLUDE irvine32.inc

MAXROW=28
MAXCOLUMN=82
MAPSIZE EQU MAXROW*MAXCOLUMN;�̷��� �ִ�ũ��

NODE STRUCT	;��� ����ü ����  14bytes
	x DWORD ?
	y DWORD ?
	parent DWORD ?
	display BYTE ?
	dirs BYTE ?
NODE ENDS
NODESIZE=14

;Ű���� ���� ���
UP=72
DOWN=80
LEFT=75
RIGHT=77
CONFIRM=13

;���ð��� ������ ��ȯ
SELECTCOLOR MACRO
	mov ax,240
	call Settextcolor
ENDM

;�Ϲ� ������ ��ȯ
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

;-------�ý��� ���� ����---------
cursor CONSOLE_CURSOR_INFO <1,0>
outputhandle DWORD ?
starttime DWORD ?
;-------�ý��� ���� ����---------

;-------���� ���� ����-----------
Map NODE MAPSIZE dup(<>)	;��� �迭 ����
difficulty BYTE ?			;�̷� ���̵�
row DWORD 27				;�̷� ��
col DWORD 41				;�̷� ��

position POS <0,1,0>

;�̷λ��� ���� ��� ����
start DWORD ?
;�̷� �������� x,y����
x DWORD ?
y DWORD ?
;����� ���� x,y��ġ ����
curx DWORD ?
cury DWORD ?
;�̷� ��� ���� ���� x,y ����
px SDWORD ?
py SDWORD ?
;�̷� ���� ��ġ ���� x,y����
destx DWORD 40
desty DWORD 25
;-------���� ���� ����-----------

;-------���ڿ� ���� ����--------
titleStr BYTE "MAZE GAME",0

intro BYTE "---------�� �� �� ��----------",0dh,0ah
	  BYTE "|                            |",0dh,0ah
	  BYTE "| �̷��� ���̵��� �����ϼ��� |",0dh,0ah
	  BYTE "|       (ENTER�� ����)       |",0dh,0ah,0
easy  BYTE "|           �� ��            |",0dh,0ah,0
mid   BYTE "|           �� ��            |",0dh,0ah,0
hard  BYTE "|           �� ��            |",0dh,0ah,0
endl  BYTE "------------------------------",0dh,0ah,0

TimeMsg BYTE "�ɸ��ð�",0
sec BYTE " ��",0

PlayMsg BYTE "������ �����Ϸ��� �ƹ�Ű�� ��������...",0dh,0ah,0
ClearMsg BYTE "�����մϴ�!! Ż���ϼ̽��ϴ�!!!",0dh,0ah,0
ReplayMsg BYTE "�ٽ� ������ �����Ͻ÷��� Y(y)Ű�� �Է��ϼ���... ",0dh,0ah,0
ThankMsg BYTE "�÷��� ���ּż� �����մϴ�!",0dh,0ah,0
;-------���ڿ� ���� ����--------
.code
main PROC
	FIRST:
	call setting
	call menu
	call init
	call draw
	;�̷� ���� ���� ��� ����
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
	;�̷� ���� �Ϸ���� �ݺ�
	;������ġ �������� ��ȯ
	mov eax,row
	sub eax,2
	imul eax, MAXCOLUMN
	add eax,col
	dec eax
	imul eax, NODESIZE
	mov (NODE PTR Map[eax]).display,' '

	;�̷� ���� �Ϸ� �� ����� �Է� ���
	call draw
	mov edx,OFFSET PlayMsg
	call writeString
	INPUT:
	mov eax,50
	call delay
	call readKey
	jz INPUT

	;���� ����
	call playgame

	;���� Ŭ���� �޽��� ���
	call clrscr
	mov edx,OFFSET ClearMsg
	call WriteString
	mov edx,OFFSET ReplayMsg
	call WriteString
	REPLAY:
	call readChar
	;�ҹ��� �빮�ڷ� ��ȯ
	and al,11011111b
	cmp al,'Y'
	je FIRST
	call clrscr
	;���� ����
	mov edx,OFFSET ThankMsg
	call WriteString
	exit
main ENDP

setting PROC
	call clrscr
	mov dx,0	
	call gotoxy
	;Ÿ��Ʋ ����
	INVOKE SetConsoleTitle, ADDR titleStr
	INVOKE GetStdHandle, STD_OUTPUT_HANDLE
	mov outputhandle,eax
	;Ŀ�� ����
	INVOKE SetConsoleCursorInfo, outputhandle,ADDR cursor
	;���� �ʱ�ȭ
	call Randomize
	ret
setting ENDP

playgame PROC
	call clrscr
	;���۽ð� ����
	INVOKE GetTickCount
	mov starttime,eax
	DRAW:
	;����� ��ġ�� ���� �̷� ���
	call drawplaying
	INPUT:
	;---��� �ð� ���---
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
	;---��� �ð� ���---
	;����� �Է�
	mov eax,10
	call delay
	call readKey
	jz INPUT
	call control
	mov ebx,(POS PTR position).x
	mov ecx,(POS PTR position).y
	;����� �������� �Ǵ�
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
	;���� ����� ��ġ ����
	mov curx,ebx
	mov cury,ecx
	;��� ������ġ ����
	mov px,ebx
	mov py,ecx
	add px,3
	add py,3
	;��� ������ġ ����
	sub ebx,3
	sub ecx,3
	push ebx
	.REPEAT 
		mov ebx,[esp]
		.REPEAT
			;if ecx<0 || ebx<0 || ecx>=row || ebx>=col
			;�̷� �ƴ� �κ� ������ ó��
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
			.IF ecx==cury && ebx==curx	;����� ��ġ ���
				mov al,'@'
			.ELSE
			;�̷� ���
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
	;���� ��ġ ����
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
	;�̵���ġ �̷� ���ϰ�� �̵� ����
	.IF ecx<0 || ebx<0 || ecx>=row || ebx>=col
		ret
	.ENDIF
	mov esi,ecx
	imul esi,MAXCOLUMN
	add esi,ebx
	imul esi,NODESIZE
	mov al,(NODE PTR Map[esi]).display
	;�̵���ġ ���ϰ�� �̵� ����
	.IF al!=32
		ret
	.ENDIF
	;����� ��ġ ����
	mov (POS ptr position).x,ebx
	mov (POS ptr position).y,ecx
	;���⿡ ���� ���̴� ���� ��ȭ�ַ� ������ �̱���
	mov (POS ptr position).dir,edx
	ret
control ENDP

;--------���̵� ���� �޴� ��� �Լ�------
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
;--------���̵� ���� �޴� ��� �Լ�------

menu PROC
	mov eax,0
	push eax
	;�޴� ���
	mov edx,OFFSET intro
	call writeString
	SELECTCOLOR
	call printeasy
	DEFAULTCOLOR
	call printmid
	call printhard
	mov edx,OFFSET endl
	call writeString
	INPUT:	;��, �Ʒ� �Է�
	mov eax,50
	call delay
	call readKey
	jz INPUT
	pop ebx
	mov dl,0
	;���õ� �κ� ����ǥ��
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
	.ELSEIF al==CONFIRM	;���� �Է�
		jmp SELECT
	.ENDIF
	push ebx
	jmp INPUT
	SELECT:	;�Է¿� ���� ���̵� ����
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
			.IF ((eax&1) && (ebx&1))	;��,�� ��� Ȧ������ ���� ���
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
	mov (NODE PTR Map[eax]).display,'&'	;������ġ ����
	ret
init ENDP

make PROC
	;���� ����� ���� ����
	mov dl,(NODE PTR [esi]).dirs
	mov ebx,(NODE PTR [esi]).x
	mov x,ebx
	mov ecx,(NODE PTR [esi]).y
	mov y,ecx
	.WHILE dl>0
		;0~100 ���� ������ 4�� ���� ������ �̿�
		mov eax,101
		call RandomRange
		and eax,3h
		mov ecx,eax
		;�̹� Ž���ߴ��� üũ
		bt dx,cx
		jnc LOOPFIN
		mov bl,1
		shl bx,cl
		not bl
		and dl,bl
		;Ž���� ���� ������Ʈ
		mov (NODE PTR [esi]).dirs,dl

		;���⿡ �´� ���� ��ġ ����
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

		;���� ��ġ ��� Ȯ��
		mov edi,OFFSET Map
		mov eax,ecx
		imul eax,MAXCOLUMN
		add eax,ebx
		imul eax,NODESIZE
		add edi,eax
		push edx
		mov dl,(NODE PTR [edi]).display
		mov eax,(NODE PTR [edi]).parent
		;��ĭ�̰� ������ ������� Ȯ��
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
			;���� ��忡 �� ����
			mov (NODE PTR Map[ecx]).display,' '
			pop edx
			mov (NODE PTR [esi]).dirs,dl
			;Ž���� ��� ��ġ ����
			mov esi,edi
			;�̷� �������� ���
			call draw
			jmp ENDFUNC
		.ENDIF
		pop edx
		LOOPFIN:
	.ENDW
	;Ž���� ���� ���� ��� �ڷ� ���ư�
	mov esi,(NODE PTR [esi]).parent
	ENDFUNC:
	ret
make ENDP

draw PROC USES eax ebx ecx edx
;���� �׸��� �Լ�
	mov dx,0	;��ġ �ʱ�ȭ
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