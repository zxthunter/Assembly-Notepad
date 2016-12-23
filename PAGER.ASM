	  PAGE	  60,132
	  .MODEL  small
	  .DATA
	  EXTRN	  statatr:BYTE,scrnatr:BYTE,sbuffer:WORD,pbuffer:WORD
	  EXTRN	  fsize:WORD,cell:WORD,statline:BYTE,statfind:BYTE,linenum:WORD,fpointer:WORD
	  EXTRN	  rows:WORD,vidadr:WORD,cga:BYTE

	  .CODE
	  PUBLIC  Pager,isEGA

; Procedure Pager
; Purpose   Displays status and	text lines
; Input	    Stack variable: lines to scroll (negative up, positive down)
;	    Global variables: "sbuffer", "pbuffer", "linenum"
; Output    To screen

Pager	  PROC
	  push	  bp
	  mov	  bp,sp

	  mov	  es,sbuffer		; Initialize buffer position
	  mov	  di,pbuffer

	  mov	  cx,[bp+4]		; Get count argument
	  mov	  ax,10			; Search for linefeed

	  or	  cx,cx			; Argument 0?
	  jg	  forward		; If above, forward
	  jl	  backward		; If below, backward
	  jmp	  SHORT	show		; If equal, done

backward: call	  GoBack		; Adjust backward
	  jmp	  SHORT	show		; Show screen
forward:  call	  GoForwd		; Adjust forward

; Write	line number to status line

show:	  cld				; Go forward
	  push	  di
	  push	  es
	  push	  ds			; Load DS to ES
	  pop	  es

; BinToStr (linenum,OFFSET statline[7])

	  push	  linenum		; Arg 1
	  mov	  ax,OFFSET statline[7]
	  push	  ax			; Arg 2
	  call	  BinToStr		; Convert to string

; 打印状态栏

	  mov	  cx,7			; Seven	spaces to fill
	  sub	  cx,ax			; Subtract those already done
	  mov	  al," "		; Fill with space
	  rep	  stosb
	  pop	  es

	  mov	  bl,statatr		; Load status attribute
	  mov	  BYTE PTR cell[1],bl

; CellWrt (DS,OFFSET statline,0,cell)

	  push	  ds			; Arg 1
	  mov	  ax,OFFSET statline	; Arg 2
	  push	  ax
	  sub	  ax,ax			; Arg 3
	  push	  ax
	  push	  cell			; Arg 4
	  call	  CellWrt		; Write	status line

	  pop	  di
	  mov	  bl,scrnatr		; Load screen attribute
	  mov	  BYTE PTR cell[1],bl
	  mov	  si,di			; Update position
	  mov	  cx,rows		; Lines	per screen


; 打印正文部分
show1:	  mov	  bx,rows		; Lines	of text
	  inc	  bx			; Adjust for 0
	  sub	  bx,cx			; Calculate current row
	  push	  cx			; Save line number
	  push    si

; CellWrt (sbuffer,position,line,cell)

	  push	  sbuffer		; Arg 1
	  push	  si			; Arg 2
	  push	  bx			; Arg 3
	  push	  cell			; Arg 4
	  call	  cellwrt		; Write	line
      
	  
      push	  ss			; Restore DS from SS
	  pop	  ds

      pop     si
	  pop	  cx			; Restore line number
; 测试
	  
	  mov bx,rows
	  inc bx
	  sub bx,cx
      push bx               ; 传入刚打印的行号
      push si              ; 传入刚打印的行号首地址
      push ax               ; 传入下一个字符串地址
      call FindStr
	  
	 
; 测试
		
	  

	  mov	  si,ax			; Get returned position

	  cmp	  ax,fsize		; Beyond end of	file?
	  jae	  fillout		; Yes? Fill screen with	spaces
	  loop	  show1			;    else next line


  	  

; 打印搜索栏
  	  mov	  bl,statatr		; Load status attribute
	  mov	  BYTE PTR cell[1],bl

;CellWrt (sbuffer,position,line,cell)
	  cmp rows,23
	  jne fillout
	  push	  ds			; Arg 1
	  mov	  ax,OFFSET statfind	; Arg 2
	  push	  ax
	  mov	  ax,24			; Arg 3
	  push	  ax
	  push	  cell			; Arg 4
	  call    CellWrt
	  jmp	  SHORT	pagedone	; Get out if done

; Fill the rest	with spaces

fillout:  dec	  cx			; Adjust
	  jcxz	  pagedone
	  mov	  al,80			; Columns times	remaining lines
	  mul	  cl

; CellFil (sbuffer,count,cell)

	  push	  sbuffer		; Arg 1
	  push	  ax			; Arg 2
	  push	  cell			; Arg 3
	  call	  CellFil		; Fill screen with spaces

	  push	  ss			; Restore DS from SS
	  pop	  ds

  	  

pagedone: pop	  bp
	  ret	  2
Pager	  ENDP

; Procedure CellWrt (segment,offset,line,cell)
; Purpose   Writes a line to screen buffer
; Input	    Stack variables: 1 - segment of line
;			     2 - offset
;			     3 - line number
;			     4 - attribute
; Output    Line to screen buffer, AX position

CellWrt	  PROC
	  push	  bp
	  mov	  bp,sp
	  sub	  dx,dx			; Clear	as flag	for scan
	  cmp	  cga,1			; CGA?
	  jne	  noscan
	  mov	  dx,03DAh		; Load port #

noscan:	  mov	  es,vidadr		; Load screen buffer segment
	  mov	  ds,[bp+10]		; Buffer segment
	  mov	  si,[bp+8]		; Buffer position
	  mov	  cx,80			; Cells	per row
	  mov	  ax,[bp+6]		; Starting row
	  mov	  bx,80*2		; Bytes	per row
	  mul	  bl			; Figure columns per row
	  mov	  di,ax			; Load as destination
	  mov	  bx,di			; Save start for tab calculation
	  mov	  ax,[bp+4]		; Attribute
movechar: lodsb				; Get character
	  cmp	  al,13			; CR?
	  je	  fillspc
	  cmp	  al,9			; Tab?
	  jne	  notab
	  call	  filltab		; Yes? fill with spaces
	  jcxz	  nextline		; If beyond limit done
	  jmp	  SHORT	movechar

notab:	  or	  dx,dx			; CGA?
	  je	  notab2
	  call	  Retrace		; Yes? Write during retrace
	  loop	  movechar
	  jmp	  SHORT	nextline

notab2:	  stosw				; Write
	  loop	  movechar
	  jmp	  SHORT	nextline	; Done

fillspc:  mov	  al," "		; Fill with space

	  or	  dx,dx			; CGA?
	  je	  space2
space1:	  call	  Retrace		; Yes? Write during retrace
	  loop	  space1
	  inc	  si			; Adjust
	  jmp	  SHORT	exit		; Done

space2:	  rep	  stosw			; Write
	  inc	  si			; Adjust for LF
	  jmp	  SHORT	exit		; Done

nextline: mov	  ah,10			; Search for next line feed
chklf:	  lodsb				; Load and compare
	  cmp	  al,ah
	  loopne  chklf

exit:	  mov	  ax,si			; Return position
	  pop	  bp
	  ret	  8
CellWrt	  ENDP

; Procedure CellFil (segment,count,cell)
; Purpose   Fills screen with character
; Input	    Stack variables: 1 - segment of text (offset 0)
;			     2 - number	of characters
;			     3 - attribute and character
; Output    Characters to screen buffer

CellFil	  PROC
	  push	  bp
	  mov	  bp,sp
	  sub	  dx,dx			; Clear	as flag	for scan
	  cmp	  cga,1			; CGA?
	  jne	  noscan2
	  mov	  dx,03DAh		; Load port #

noscan2:  mov	  es,vidadr		; Load screen buffer segment
	  mov	  ds,[bp+8]		; Buffer segment (position 0)
	  mov	  cx,[bp+6]		; Characters to	fill
	  mov	  ax,[bp+4]		; Attribute
	  or	  dx,dx			; CGA?
	  je	  fillem2
fillem1:  call	  Retrace		; Yes? Write during retrace
	  loop	  fillem1
	  jmp	  SHORT	filled		; Done
fillem2:  rep	  stosw			; Write

filled:	  pop	  bp
	  ret	  6
CellFil	  ENDP

; Procedure FillTab
; Purpose   Writes spaces for tab to screen
; Input	    BX points to start of line,	DI points to current position
; Output    Spaces to screen buffer

FillTab	  PROC
	  push	  bx
	  push	  cx

	  sub	  bx,di			; Get current position in line
	  neg	  bx
	  shr	  bx,1			; Divide by 2 bytes per	character

	  mov	  cx,8			; Default count	8
	  and	  bx,7			; Get modulus
	  sub	  cx,bx			; Subtract
	  mov	  bx,cx			; Save modulus

	  mov	  al," "		; Spaces
	  or	  dx,dx			; CGA?
	  je	  tabem2

tabem1:	  call	  Retrace		; Yes? Write during retrace
	  loop	  tabem1
	  jmp	  SHORT	tabbed
tabem2:	  rep	  stosw			; Write

tabbed:	  pop	  cx
	  sub	  cx,bx			; Adjust count
	  jns	  nomore		; Make negative	count 0
	  sub	  cx,cx
nomore:	  pop	  bx
	  ret
FillTab	  ENDP

; Procedure GoBack
; Purpose   Searches backward through buffer
; Input	    CX has number of lines; ES:DI has buffer position
; Output    Updates "linenum" and "pbuffer"

GoBack	  PROC
	  std				; Go backward
	  neg	  cx			; Make count positive
	  mov	  dx,cx			; Save a copy
	  inc	  cx			; One extra to go up one
	  or	  di,di			; Start	of file?
	  je	  exback		; If so, ignore
findb:	  push	  cx			;   else save count
	  mov	  cx,0FFh		; Load maximum character count
	  cmp	  cx,di			; Near start of	buffer?
	  jl	  notnear		; No? Continue
	  mov	  cx,di			;   else search	only to	start
notnear:  repne	  scasb			; Find last previous LF
	  jcxz	  atstart		; If not found,	must be	at start
	  pop	  cx
	  loop	  findb
	  cmp	  linenum,0FFFFh	; End of file flag?
	  jne	  notend		; No? Continue
	  add	  di,2			; Adjust for cr/lf
	  mov	  pbuffer,di		; Save position
	  call	  EndCount		; Count	back to	get line number
	  ret

notend:	  sub	  linenum,dx		; Calculate line number
	  jg	  positive
	  mov	  linenum,1		; Set to 1 if negative
positive: add	  di,2			; Adjust for cr/lf
	  mov	  pbuffer,di		; Save position
	  ret

atstart:  pop	  cx
	  sub	  di,di			; Load start of	file
	  mov	  linenum,1		; Line 1
	  mov	  pbuffer,di		; Save position
exback:	  ret
GoBack	  ENDP

; Procedure GoForwd
; Purpose   Searches forward through a buffer
; Input	    CX has number of lines; ES:DI has buffer position
; Output    Updates "linenum" and "pbuffer"

GoForwd	  PROC
	  cld				; Go forward
	  mov	  dx,cx			; Copy count
findf:	  push	  cx			; Save count
	  mov	  cx,0FFh		; Load maximum character count
	  repne	  scasb			; Find next LF
	  jcxz	  atend			; If not found,	must be	at end
	  cmp	  di,fsize		; Beyond end?
	  jae	  atend
	  pop	  cx
	  loop	  findf
	  add	  linenum,dx		; Calulate line	number
	  mov	  pbuffer,di		; Save position
	  ret

atend:	  pop	  cx
	  mov	  di,pbuffer		; Restore position
	  ret
GoForwd	  ENDP

; Procedure EndCount
; Purpose   Counts backward to count lines in file
; Input	    ES:DI has buffer position
; Output    Modifies "linenum"

EndCount  PROC
	  push	  di

	  mov	  al,13			; Search for CR
	  mov	  linenum,0		; Initialize

findstrt: inc	  linenum		; Adjust count
	  mov	  cx,0FFh		; Load maximum character count
	  cmp	  cx,di			; Near start of	buffer?
	  jl	  notnear2		; No? Continue
	  mov	  cx,di			;   else search	only to	start
notnear2: repne	  scasb			; Find last previous cr
	  jcxz	  found			; If not found,	must be	at start
	  jmp	  SHORT	findstrt

found:	  pop	  di
	  ret
EndCount  ENDP

; Procedure isEGA
; Purpose   Determines if an EGA is active
; Input	    None
; Output    0 if no; lines per screen if yes

isEGA	  PROC
	  push	  bp
	  push	  es
	  mov	  ah,12h		; Call EGA status function
	  mov	  bl,10h
	  sub	  cx,cx			; Clear	status bits
	  int	  10h
	  sub	  ax,ax			; Segment 0 and	assume no EGA
	  jcxz	  noega			; If status still clear, no EGA

	  mov	  es,ax			; ES=0
	  test	  BYTE PTR es:[487h],1000b ; Test active bit
	  jnz	  noega			; If set, not active
	  mov	  ax,1130h		; Get EGA information
	  int	  10h
	  mov	  al,dl			; Return lines per screen
	  cbw

noega:	  pop	  es
	  pop	  bp
	  ret
isEGA	  ENDP

; Procedure BinToStr (number,address)
; Purpose   Converts integer to	string
; Input	    Stack arguments: 1 - Number	to convert; 2 -	Near address for write
; Output    AX has characters written

BinToStr  PROC
	  push	  bp
	  mov	  bp,sp
	  mov	  ax,[bp+6]		; Arg 1
	  mov	  di,[bp+4]		; Arg 2

	  sub	  cx,cx			; Clear	counter
	  mov	  bx,10			; Divide by 10

; Convert and save on stack backwards

getdigit: sub	  dx,dx			; Clear	top
	  div	  bx			; Divide to get	last digit as remainder
	  add	  dl,"0"		; Convert to ASCII
	  push	  dx			; Save on stack
	  or	  ax,ax			; Quotient 0?
	  loopnz  getdigit		; No? Get another

; Take off the stack and store forward

	  neg	  cx			; Negate and save count
	  mov	  dx,cx
putdigit: pop	  ax			; Get character
	  stosb				; Store	it
	  loop	  putdigit
	  mov	  ax,dx			; Return digit count

	  pop	  bp
	  ret	  4
BinToStr  ENDP

; Procedure Retrace
; Purpose   Writes cell	during horizontal retrace (CGA)
; Input	    ES:DI has screen buffer position, AX has cell
; Output    Character to screen	buffer

Retrace	  PROC
	  push	  bx
	  mov	  bx,ax			; Save character
lscan2:	  in	  al,dx			; Look in the port
	  shr	  al,1			;   until it goes low
	  jc	  lscan2
	  cli
hscan2:	  in	  al,dx			; Look in the port
	  shr	  al,1			;   until it goes high
	  jnc	  hscan2
	  mov	  ax,bx			; Restore and write it
	  stosw
	  sti
	  pop	  bx
	  ret
Retrace	  ENDP



; 找某一行中是否有要查找的字符串，并进行高亮显示
; 参数一：查找字符串的行数，参数二：在文件中的源串地址 , 参数三：在文本中找的末尾地址

FindStr proc
	    push	  bp
	    mov	  	bp,sp
	    push  si
	    push  di
	    push  ax
	    push  cx
	    push  es
	    push  bx

	    mov    di,[bp+6]
	    mov    [bp+10],di       ;初始化源字符串首地址

fstr2:  mov     es,sbuffer
		mov     di,[bp+6]       ; 源串地址
	    mov     si,OFFSET statfind
	    add 	si,9                  ; 目标串地址
	    mov     cx,fpointer           ; 目标串长度
	    cmp     cx,0
	    je      exitf
	    cld
	    repz cmpsb
	    jnz  fstr1  			; 字符串相等，准备更新高亮  
        
        mov ax,[bp+10]     
        push ax
        mov ax,[bp+6]
        push ax   
        call CalTab
        mov bx,ax

	    mov ax,[bp+8]          ;打印的行数
	    push ax
	    mov ax,[bp+6]
	    sub ax,[bp+10]
	    add ax,bx
	    push ax
	    mov ax,fpointer
	    push ax
	    call HighLight
	    jmp exitf
	    
        
			
fstr1:     
		
		mov ax,[bp+6]                     ; 源字符串向后移1
 		inc ax
 		mov [bp+6],ax

 		mov ax,[bp+4]
 		cmp di,ax                   ; 检查到回车则退出
 		jb fstr2
 		 
exitf:  pop bx
		pop es
		pop cx
		pop ax
		pop di
		pop si
		pop bp
		ret 6
FindStr endp


; 计算es段下某两个字节单元间tab的数量
; 参数1：起始偏移，参数2：终止偏移
; 返回：ax中tab个数
CalTab proc
	push	  bp
	mov	  	bp,sp
	push    di
	push    bx
	mov    ax,0
	mov    di,[bp+6]
ct2:mov   bl, es:[di]
	cmp   bl,9
	jne   ct1
	inc   ax
ct1:inc di
    cmp  di,[bp+4]
    jb   ct2
    mov  bl,7
    mul  bl
ct3:pop bx
    pop di
	pop bp
	ret  4  
CalTab endp

; 高亮显示某行，某位，多个字节
; 参数1：所在行数，参数2：所在第一个字节，参数3：输出的个数

HighLight proc
    push bp
    mov	  bp,sp
    push ax
    push bx
    push cx
    push es
    push di
	
	mov	  es,vidadr
	
	mov	  ax,[bp+8]		; 所在行号
	mov	  bx,80*2			; 每行字节数
	mul	  bl				; 计算行起始地址	
	mov	  di,ax				
	add   di,[bp+6]
	add   di,[bp+6]	        ; 计算欲高亮显示处起始地址
    mov   cx,[bp+4]         ; 字符数
    cmp   cx,0
    je    hl2
hl1:mov     bx,es:[di]
	mov     bh,statatr
	mov     es:[di],bx	    ; 取出字节，改变状态，回填
	add     di,2
	dec cx
	cmp cx,0
	jne  hl1
	
hl2:pop di
	pop es
	pop cx
	pop bx
	pop ax
	pop bp
	ret 6
HighLight endp

	  END
