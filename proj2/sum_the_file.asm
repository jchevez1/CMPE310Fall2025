global _start

section .data
    nl db 10


section .bss
    buffer               resb 1    ;input buffer for sys_read               
    decimalbuffer        resb 16   ;decimal conversion buffer
    array                resd 1000 ;array store 1000 integers

arrayEnd:                          
    remainingintegers    resd 1    ;remaining integers to read
    readinginteger       resb 1    ;flag which is currently reading an integer                          
    accumulatingvalue    resd 1    ;current integer being built
    filedescriptor       resd 1    ;file descriptor from sys_open


section .text
_start:
    ;read a filename and open it, if open succeeds then initialize, scan integers and print the sum. And as a last thing, closes the file and exits
    mov     eax, [esp]           
    cmp     eax, 2
    jb      exit
    mov     ebx, [esp+8]         
    call    openFile
    mov     eax, [filedescriptor]
    test    eax, eax
    js      exit
    call    resetScanState
    call    readAndScanLoop
    call    printSum
    call    closeFile
    jmp     exit

openFile: 
    ;open the file using sys_open, save the file descriptor in filedescriptor and return                        
    mov     eax, 5               
    xor     ecx, ecx
    xor     edx, edx
    int     0x80
    mov     [filedescriptor], eax
    ret

resetScanState: 
    ;initialize sum, set array write pointer, mark first integer not yet read, clear accumulator and flags                       
    xor     esi, esi             
    mov     edi, array
    mov     dword [remainingintegers], -1
    mov     dword [accumulatingvalue], 0
    mov     byte  [readinginteger], 0   
    ret

readAndScanLoop:                  
.read:
    ;read 1 byte from the file into buffer, if end of file jump to finishReading
    mov     eax, 3               
    mov     ebx, [filedescriptor]
    mov     ecx, buffer
    mov     edx, 1
    int     0x80
    test    eax, eax
    jle     .finishReading

    ;load the byte from buffer into al
    mov     al, [buffer]         

    ;if byte is 0–9, start integer if needed or continue accumulating, otherwise handle nondigit
    cmp     al, '0'
    jb      .handleNonDigit
    cmp     al, '9'
    ja      .handleNonDigit
    cmp     byte [readinginteger], 0
    jne     .accumulateDigit
    mov     byte [readinginteger], 1
.accumulateDigit: 
    ;convert digit character to 0–9, set accumulator and continue reading
    movzx   edx, al              
    sub     edx, '0'
    mov     eax, [accumulatingvalue]
    mov     ecx, eax
    shl     eax, 3
    lea     eax, [eax + ecx*2]
    add     eax, edx
    mov     [accumulatingvalue], eax
    jmp     .read

.handleNonDigit:
    ;if currently in an integer, finalize it, otherwise keep reading
    cmp     byte [readinginteger], 0
    jne     .finalizeInteger      
    jmp     .read

.finalizeInteger: 
    ;finalize the integer and continue reading                        
    call    finalizeCurrentInteger
    jmp     .read

.finishReading: 
    ;if an integer is in progress, finalize it, otherwise return                              
    cmp     byte [readinginteger], 0
    je      .return
    call    finalizeCurrentInteger
.return: 
    ;return from subroutine
    ret

finalizeCurrentInteger: 
    ;load the current accumulated integer into eax       
    mov     eax, [accumulatingvalue]
     
    ;reset the accumulator to 0 and clear the reading flag
    mov     dword [accumulatingvalue], 0
    mov     byte  [readinginteger], 0

    ;if the count is not yet set, take the first integer as the count and limit it to the array capacity
    cmp     dword [remainingintegers], -1
    jne     .storeAndSum
    mov     edx, eax                         
    cmp     edx, (arrayEnd - array) / 4
    jbe     .limitApplied
    mov     edx, (arrayEnd - array) / 4
.limitApplied: 
    ;save the remaining count and return
    mov     [remainingintegers], edx
    ret

.storeAndSum: 
    ;if count is greater than 0, then store the integer in the array, advance the write pointer, add to sum and decrement the remaining count
    mov     edx, [remainingintegers]
    test    edx, edx
    jle     .return
    mov     [edi], eax
    add     edi, 4
    add     esi, eax
    dec     edx
    mov     [remainingintegers], edx
.return: 
    ;return from subroutine
    ret

printSum: 
    ;prepare to print the sum, load it into eax, set pointer to end of decimal buffer                        
    mov     eax, esi
    mov     edi, decimalbuffer
    add     edi, 16
     
    ;write 0 at the end of the buffer, set length to 1 and jump to writeDigits
    cmp     eax, 0
    jne     .convertToDecimal
    dec     edi
    mov     byte [edi], '0'
    mov     edx, 1
    jmp     .writeDigits

.convertToDecimal: 
    ;decimal conversion, clear remainder and set divisor to 10
    xor     edx, edx
    mov     ecx, 10

.decimalLoop: 
    ;divide by 10 to get next digit, write it backward, then compute length
    div     ecx
    add     dl, '0'
    dec     edi
    mov     [edi], dl
    xor     edx, edx
    test    eax, eax
    jne     .decimalLoop
    mov     edx, decimalbuffer
    add     edx, 16
    sub     edx, edi 

.writeDigits: 
    ;print the digits to stdout using sys_write, then print a newline and then return
    mov     eax, 4               
    mov     ebx, 1
    mov     ecx, edi
    int     0x80
    mov     eax, 4               
    mov     ebx, 1
    mov     ecx, nl
    mov     edx, 1
    int     0x80
    ret

closeFile: 
    ;close the file descriptor and return
    mov     eax, 6               
    mov     ebx, [filedescriptor]
    int     0x80
    ret

exit: 
    ;exit the program
    xor     ebx, ebx
    mov     eax, 1               
    int     0x80
