BITS 64

                            ; DOS Header
    dw 'MZ'                 ; e_magic
    dw 0                    ; [UNUSED] e_cblp
pe_hdr:                                                 ; PE Header
    dw 'PE'                 ; [UNUSED] c_cp             ; Signature
    dw 0                    ; [UNUSED] e_crlc           ; Signature (Cont)
                                                        ; Image File Header
    dw 0x8664               ; [UNUSED] e_cparhdr        ; Machine
code:
symbol:                                                                                     ; Symbol
    dw 0x01                 ; [UNUSED] e_minalloc       ; NumberOfSections                  ; [UNUSED] Function Order
    db 'MessageBoxW', 0                                                                     ; Function Name
    times 14-($-symbol) db 0; [UNUSED] e_maxalloc       ; [UNUSED] TimeDateStamp
                            ; [UNUSED] e_ss             ; [UNUSED] TimeDateStamp (Cont)
                            ; [UNUSED] e_sp             ; [UNUSED] PointerToSymbolTable
                            ; [UNUSED] e_csum           ; [UNUSED] PointerToSymbolTable (Cont)
                            ; [UNUSED] e_ip             ; [UNUSED] NumberOfSymbols
                            ; [UNUSED] e_cs             ; [UNUSED] NumberOfSymbols (Cont)
    dw opt_hdr_size         ; [UNUSED] e_lfarlc         ; SizeOfOptionalHeader
    dw 0x22                 ; [UNUSED] e_ovno           ; Characteristics
opt_hdr:                                                ; Optional Header, COFF Standard Fields
    dw 0x020b               ; [UNUSED] e_res            ; Magic (PE32+)
    db 0                    ; [UNUSED] e_res (Cont)     ; [UNUSED] MajorLinkerVersion
    db 0                    ; [UNUSED] e_res (Cont)     ; [UNUSED] MinorLinkerVersion
    dd code_size            ; [UNUSED] e_res (Cont)     ; SizeOfCode
code_4:                                                                                     ; Code Fragment 4
    jmp [rel iatbl]                                                                         ; MessageBoxW
    times 8-($-code_4) db 0 ; [UNUSED] e_oemid          ; [UNUSED] SizeOfInitializedData
                            ; [UNUSED] e_oeminfo        ; [UNUSED] SizeOfInitializedData (Cont)
                            ; [UNUSED] e_res2           ; [UNUSED] SizeOfUninitializedData
    dd entry                ; [UNUSED] e_res2 (Cont)    ; AddressOfEntryPoint
    dd code                 ; [UNUSED] e_res2 (Cont)    ; BaseOfCode
                                                        ; Optional Header, NT Additional Fields
    dq 0x000140000000       ; [UNUSED] e_res2 (Cont)    ; ImageBase
    dd pe_hdr               ; e_lfanew                  ; [MODIFIED] SectionAlignment (0x10 -> 0x04)
    dd 0x04                                             ; [MODIFIED] FileAlignment (0x10)
code_3:                                                                                     ; Code Fragment 3
    lea rdx, [rdx+content-entry]                                                            ; lpText
    jmp code_4
    times 8-($-code_3) db 0                             ; [UNUSED] MajorOperatingSystemVersion
                                                        ; [UNUSED] MinorOperatingSystemVersion
                                                        ; [UNUSED] MajorImageVersion
                                                        ; [UNUSED] MinorImageVersion
    dw 0x06                                             ; MajorSubsystemVersion
    dw 0                                                ; MinorSubsystemVersion
    dd 0                                                ; [UNUSED] Reserved1
    dd file_size                                        ; SizeOfImage
    dd hdr_size                                         ; SizeOfHeaders
    dd 0                                                ; [UNUSED] CheckSum
    dw 0x02                                             ; Subsystem (Windows GUI)
    dw 0x8160                                           ; DllCharacteristics
    dq 0x100000                                         ; SizeOfStackReserve
    dq 0x1000                                           ; SizeOfStackCommit
    dq 0x100000                                         ; SizeOfHeapReserve
dll_name:                                                                                   ; DLLName
    db 'USER32.dll', 0                                                                      ; DLLName
    times 12-($-dll_name) db 0                          ; [UNUSED] SizeOfHeapCommit
                                                        ; [UNUSED] LoaderFlags
    dd 0x02                                             ; [MODIFIED] NumberOfRvaAndSizes (0x10)

                            ; Optional Header, Data Directories
code_2:                                                 ; Code Fragment 2
    mov r9d, 0x00240040                                 ; uType
    jmp code_3
    times 8-($-code_2) db 0 ; [UNUSED] Export, RVA
                            ; [UNUSED] Export, Size
iatbl:                                                  ; Import Address Directory
    dd itbl                 ; Import, RVA               ; [USEDAFTERLOAD] DLLFuncEntry
    dd itbl_size            ; Import, Size              ; [USEDAFTERLOAD] DLLFuncEntry (Cont)
iatbl_size equ $-iatbl

opt_hdr_size equ $-opt_hdr

                            ; Section Table
    section_name db '.', 0  ; Name
code_1:                                                 ; Code Fragment 1
    lea r8, [rdx+title-entry]                           ; lpCaption
    jmp code_2
    times 8-($-section_name) db 0
    dd sect_size            ; VirtualSize
    dd iatbl                ; VirtualAddress
    dd code_size            ; SizeOfRawData
    dd iatbl                ; PointerToRawData
content:                                                ; Strings
    db 0x41,0x00,0x42,0x00,0x43,0x00,0x44,0x00
    db 0x45,0x00,0x46,0x00,0x47,0x00,0,0
                            ; [UNUSED] PointerToRelocations
                            ; [UNUSED] PointerToLinenumbers
                            ; [UNUSED] NumberOfRelocations
                            ; [UNUSED] NumberOfLinenumbers
                            ; [UNUSED] Characteristics
hdr_size equ $-$$

title:
    db 0x3d,0xd8,0xaf,0xdc,0x20,0x00,0x54,0x00
    db 0x69,0x00,0x6e,0x00,0x79,0x00,0x50,0x00
    db 0x45,0x00,0x20,0x00,0x6f,0x00,0x6e,0x00
    db 0x20,0x00,0x57,0x00,0x69,0x00,0x6e,0x00
    db 0x64,0x00,0x6f,0x00,0x77,0x00,0x73,0x00
    db 0x20,0x00,0x31,0x00,0x30,0x00,0,0

itbl:                       ; Import Directory
    dq intbl                ; OriginalFirstThunk
entry:                                                  ; Code Fragment 0
    xor ecx, ecx                                        ; hWnd
    jmp code_1
    times 4-($-entry) db 0  ; [UNUSED] TimeDateStamp
    dd dll_name             ; ForwarderChain
    dd iatbl                ; Name
intbl:                                                  ; Import Name Table
    dq symbol               ; [UNUSED] FirstThunk       ; Symbol
itbl_size equ $-itbl
    dq 0                                                ; nullptr

sect_size equ $-code
code_size equ $-code
file_size equ $-$$
