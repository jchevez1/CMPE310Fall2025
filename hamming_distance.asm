global _start

SECTION .data
    ;asks the user for two strings and output the hamming distance
    firststring db "Please enter first string: "     
    fststringlen equ $ -firststring            

    secondstring db "Please enter second string: "    
    sndstringlen equ $ -secondstring             

    hammingdstc db "The Hamming distance is: "
    hammingdstclen equ $ -hammingdstc

    nl db 10

SECTION .bss
    string1    resb 256   
    string2    resb 256
    numstrings resb 32            ;decimal conversion

SECTION .text
_start:
    ;prompt for first string and read it into string1
    mov     eax, 4                ;system call number (sys_write)
    mov     ebx, 1                ;file descriptor (stdout)
    mov     ecx, firststring      ;input to write
    mov     edx, fststringlen     ;string length
    int     0x80                  ;call kernel

    ;read line 1, it has to be less or equal than 256
    mov     eax, 3                ;sys_read
    mov     ebx, 0                ;stdin
    mov     ecx, string1          ;string address 
    mov     edx, 256              ;max bytes to read
    int     0x80                  ;read kernel
    test    eax, eax              ;check if bytes to read are less than 0 
    jle     .exit                 ;if bytes to read are less than 0 then exit the program
    mov     esi, string1          ;pointer for string1
    mov     ebp, eax              ;firsInputLength
    

    ;remove the ending newline of the first input so it doesn’t affect the hamming distance
    mov     edx, ebp              
    dec     edx                   
    cmp     byte [esi+edx], 10    
    jne     .firstInputKeptLength
    dec     ebp
.firstInputKeptLength:
    ;make sure the first input isn’t longer than 255 characters
    cmp     ebp, 255
    jbe     .firstInputFinalLength
    mov     ebp, 255
.firstInputFinalLength:


    ;prompt for second string and read it into string2
    mov     eax, 4                 ;system call number (sys_write)
    mov     ebx, 1                 ;file descriptor (stdout)
    mov     ecx, secondstring      ;input to write
    mov     edx, sndstringlen      ;string length
    int     0x80                   ;call kernel

    ;read line 2, it has to be less or equal than 256
    mov     eax, 3                 ;sys_read
    mov     ebx, 0                 ;stdin
    mov     ecx, string2           ;string address
    mov     edx, 256               ;max bytes to read
    int     0x80                   ;read kernel
    test    eax, eax               ;check if bytes to read are less than 0
    jle     .exit                  ;if bytes to read are less than 0 then exit the program
    mov     edi, string2           ;pointer for string2
    mov     ebx, eax               ;secondInputLength


    ;remove the ending newline of the second input so it doesn’t affect the hamming distance
    mov     edx, ebx
    dec     edx
    cmp     byte [edi+edx], 10
    jne     .secondInputKeptLength
    dec     ebx
.secondInputKeptLength:
    ;make sure the second input isn’t longer than 255 characters
    cmp     ebx, 255
    jbe     .secondInputFinalLength
    mov     ebx, 255
.secondInputFinalLength:

    
    ;compute n = min(firsInputLength, secondInputLength) into ecx
    mov     ecx, ebp
    cmp     ebp, ebx
    jbe     .startComparing
    mov     ecx, ebx
.startComparing:


    ;reset the running hamming distance sum to zero
    xor     ebp, ebp             

.loop:
    ;if there are no more bytes to compare then jump to printing the output
    test    ecx, ecx
    jz      .print
    
    ;take one byte from each string and xor them to see which bits differ
    mov     al, [esi]
    xor     al, [edi]
    movzx   eax, al               
    xor     edx, edx

.countBits:
    ;count 1-bits by shifting right and adding 1 whenever a bit shifts into the carry flag
    test    eax, eax              
    jz      .addCountToTotal
    shr     eax, 1                
    adc     edx, 0                
    jmp     .countBits

.addCountToTotal:
    ;add this byte’s bit differences to the total count
    add     ebp, edx              
    
    ;move to next byte pair and continue until ecx is 0
    inc     esi
    inc     edi
    dec     ecx
    jmp     .loop


.print:
    ;print the text "The Hamming distance is:"
    mov     eax, 4
    mov     ebx, 1
    mov     ecx, hammingdstc
    mov     edx, hammingdstclen
    int     0x80

    ;print the final total and check if it’s 0, if not then convert it to decimal
    mov     eax, ebp
    test    eax, eax
    jnz     .convertToDecimal

    ;0 case
    mov     byte [numstrings+31], '0'
    mov     ecx, numstrings+31
    mov     edx, 1
    jmp     .writeDigits

.convertToDecimal:
    ;convert eax to decimal ASCII, and also writing digits backward into numstrings 
    mov     edi, numstrings+31        
    mov     ebx, 10

.decimalLoop:
    ;turn the number into decimal digits
    xor     edx, edx
    div     ebx                   
    add     dl, '0'
    mov     byte [edi], dl
    dec     edi
    test    eax, eax
    jnz     .decimalLoop

    ;set ecx to the first digit and edx to how many digits to print
    lea     ecx, [edi+1]          
    mov     edx, numstrings+31
    sub     edx, ecx
    inc     edx

.writeDigits:
    ;write the digits from numstrings to stdout
    mov     eax, 4
    mov     ebx, 1
    int     0x80

    ;write one newline character
    mov     eax, 4
    mov     ebx, 1
    mov     ecx, nl
    mov     edx, 1
    int     0x80


.exit:
    ;exit the program
    mov     eax, 1                
    xor     ebx, ebx
    int     0x80
