# Smallest 64-Bit PE File on Windows 10

Chinese Version: [Post on Zhihu](https://www.zhihu.com/question/21715980/answer/2239380126) - [Blog](https://ayaka.shn.hk/tinype/)

## Introduction

In this experiment, I crafted the smallest possible 64-bit PE file on the Windows 10 operating system. This file successfully displays a message box with a text prompt, while meeting three specific requirements:

- Symbols should be imported by name instead of ordinal
- The total length of the title and content of the message box should be 64 bytes long
- The overall file size should not exceed 300 bytes

Through nine meticulous steps, I produced a 268-byte PE file.

The experiment unfolded as follows:

- Step 1: I wrote a program using the C language and generated a standard PE file using the MSVC compiler, employing conventional methods.
- Step 2: By altering the MSVC compiler options during compilation, I reduced the size of the resulting PE file.
- Step 3: I examined the internal structure of the previously generated PE file using [PE Tools](https://petoolse.github.io/petools/) and zeroed out some of the obviously unnecessary sections. Although the file size remained the same, more zero values within the file created additional compression opportunities in subsequent steps.
- Step 4: I zeroed out the MS-DOS stub within the PE file's internal structure, a redundant part, by manually editing the content using a binary editor. This step provided further compression opportunities for later steps.
- Step 5: After a thorough analysis of the PE file's internal structure, I gained an understanding of the various sections' meanings and manually constructed an equivalent PE file using assembly language. Although the resulting file was the same as the one produced in the previous step, using assembly language enabled me to make modifications directly to the machine code, thereby more conveniently reducing the file size.
- Step 6: Based on the analysis of the PE file's internal structure, I eliminated all unnecessary sections directly from the assembly code, shrinking the file size further.
- Step 7: Although I had removed all readily removable unnecessary sections in the previous step, some unneeded fields could not be directly deleted. This is due to the PE file containing multiple file headers with these unused fields, and the file header formats being fixed. Consequently, even if a field within the file header was unused, it still had to occupy a specific position and could not be directly deleted. To address this, I tactfully overlapped multiple file headers while ensuring that each overlapped position had, at most, one useful field. This approach effectively reduced the file size without damaging the file headers.
- Step 8: The PE file also contained the machine code for five instructions. By overlapping this machine code with the file headers, as done in the previous step, I could further reduce the file size. However, it seemed that the instruction machine code was too long to fit seamlessly into the unused spaces within the file headers. To resolve this, I broke down the five instructions and added a short jump instruction after each of the first four instructions to jump to the next instruction's position. In this way, each instruction could be independently inserted into different gaps. Despite this effort, two instructions remained too long to fit. By delving deeper into the x64 instruction set and gaining a solid understanding, I discovered that using another register as a base address would result in shorter machine code without altering the semantic of the instructions. This allowed the machine code to fit into the unused gaps within the file headers, further reducing the file size.
- Step 9: I removed the trailing zeros at the end of the file since the program loader would automatically pad them with zeros upon loading.

| Step | File Size (bytes) | Entropy |
| :- | :- | :- |
| 1 | 94208 | 5.924863 |
| 2 | 896 | 3.567715 |
| 3 | 896 | 2.220567 |
| 4 | 896 | 1.608427 |
| 5 | 896 | 1.607880 |
| 6 | 448 | 2.653766 |
| 7 | 308 | 2.473451 |
| 8 | 280 | 2.620173 |
| 9 | 268 | 2.667864 |

Note that although the file size did not change during steps 3-5, the entropy decreased, indicating more zeros within the file, thereby providing more compression opportunities for subsequent steps.

## Environment

- Operating System: Microsoft Windows 10 Version 1903 (v10.0.18362.239) 64-bit
- Shell: zsh 5.7.1 (x86_64-pc-msys)
- C Compiler: Microsoft (R) C/C++ Optimizing Compiler Version 19.22.27905 for x64
- Linker: Microsoft (R) Incremental Linker Version 14.22.27905.0
- Assembler: NASM version 2.14.02 compiled on Jan 30 2019
- Debugger: x64dbg May 19 2019, 18:13:13

## Steps

**Step 1: Using conventional methods, I wrote a program in C and generated a standard PE file with the MSVC compiler.**

In Windows programming, [`MessageBoxA`](https://docs.microsoft.com/en-us/windows/desktop/api/winuser/nf-winuser-messageboxa) and [`MessageBoxW`](https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-messageboxw) are two functions available for displaying a message box. Functions ending with "A" indicate that the character encoding uses the user's current code page, while those ending with "W" indicate the use of UTF-16.

Due to the lack of uniformity in user code pages and in consideration of compatibility, I chose to use the `MessageBoxW` function in this experiment. Code page issues are quite common, and many people have encountered garbled text or crashes when programming with Python on Windows due to improper code pages. Using the `MessageBoxW` function, which is independent of the code page, helps avoid these issues.

The C code for `tiny.c` is as follows:

Next, I compiled the C code into a PE file.

```c
#include <Windows.h>

int main() {
    MessageBoxW( NULL /* hWnd */,
                 L"ABCDEFG" /* lpText, 16 bytes */,
                 L"💯 TinyPE on Windows 10" /* lpCaption, 48 bytes */,
                 MB_ICONASTERISK | MB_TOPMOST | MB_SERVICE_NOTIFICATION /* uType */ );
    return 0;
}
```

After installing Visual Studio Build Tools 2019, a Visual Studio 2019 folder will appear in the "Start" menu. Click on the "x64 Native Tools Command Prompt for VS 2019" to open the command prompt, switch to the current directory, and enter the following command:

```cmd
> cl /O1 /source-charset:utf-8 tiny.c /link /SUBSYSTEM:WINDOWS /ENTRY:mainCRTStartup user32.lib
Microsoft (R) C/C++ Optimizing Compiler Version 19.22.27905 for x64
Copyright (C) Microsoft Corporation.  All rights reserved.

tiny.c
Microsoft (R) Incremental Linker Version 14.22.27905.0
Copyright (C) Microsoft Corporation.  All rights reserved.

/out:tiny.exe
/SUBSYSTEM:WINDOWS
/ENTRY:mainCRTStartup
user32.lib
tiny.obj
```

The compilation generates a `tiny.exe` file, which runs correctly:

![](https://ayaka.shn.hk/tinype/tiny1.exe.png)

**Step 2: I reduced the size of the generated PE file by changing the MSVC compiler's compilation options.**

Referring to [Minimize the size of your program – high level](https://blogs.msdn.microsoft.com/xiangfan/2008/09/19/minimize-the-size-of-your-program-high-level/) and [Linker Options](https://docs.microsoft.com/en-us/cpp/build/reference/linker-options?view=vs-2019), it's possible to reduce the size of the compiled PE file by modifying the C code and compilation options.

The modified C code for `tiny.c` is as follows:

```c
#include <Windows.h>

void _() {
    MessageBoxW( NULL /* hWnd */,
                 L"ABCDEFG" /* lpText, 16 bytes */,
                 L"💯 TinyPE on Windows 10" /* lpCaption, 48 bytes */,
                 MB_ICONASTERISK | MB_TOPMOST | MB_SERVICE_NOTIFICATION /* uType */ );
}
```

I compiled the code using the following command-line options:

```cmd
> cl /O1 /MD /GS- /source-charset:utf-8 tiny.c /link /NOLOGO /NODEFAULTLIB /SUBSYSTEM:WINDOWS /ENTRY:_ /MERGE:.rdata=. /MERGE:.pdata=. /MERGE:.text=. /SECTION:.,ER /ALIGN:16 user32.lib
Microsoft (R) C/C++ Optimizing Compiler Version 19.22.27905 for x64
Copyright (C) Microsoft Corporation.  All rights reserved.

tiny.c
LINK : warning LNK4108: /ALIGN specified without /DRIVER; image may not run
LINK : warning LNK4254: section '.text' (60000020) merged into '.' (40000040) with different attributes
```

I compiled and generated the `tiny.exe` file, which runs correctly.

**Step 3: I used [PE Tools](https://petoolse.github.io/petools/) to examine the internal structure of the PE file produced in the previous step and set some obviously useless parts to zero. Although the file size did not decrease at this stage, more zeros within the file provided more compression opportunities for later steps.**

I opened PE Tools (v1.9.762.2018), clicked "PE Editor," and then opened `tiny.exe`.

![](https://ayaka.shn.hk/tinype/tiny2.exe.png)

I located the following three parts and set them to zero:

- Clicked on "File Header," found "Time/Date," and set it to 0
- Clicked on "View Rich," and then clicked "Clear Sign"
- Clicked on "Directories," found "Debug Directory," clicked "...," and then clicked "Clear debug info"

The modified `tiny.exe` file runs correctly.

**Step 4: In the internal structure of the PE file, the MS-DOS stub is also a useless part, so I manually set this section to zero using a binary editor. This step provided additional compression opportunities for later steps.**

I opened `tiny.exe` with a binary editor.

I located the following parts and set them to zero:

- Set `0x02-0x3b` to zero
- Set `0x40-0x7f` to zero

It is important to note that `0x00-0x01` represents `e_magic` and `0x3c-0x3f` represents `e_lfanew`. Both are useful fields, so they were not set to zero.

After the modification, the `tiny.exe` file runs correctly, with the content as follows:

```zsh
$ xxd -p tiny.exe
4d5a00000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
c00000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000504500006486010000000000000000000000
0000f00022000b020e1690010000000000000000000000030000f0010000
000000400100000010000000100000000600000000000000060000000000
000080030000f00100000000000002006081000010000000000000100000
000000000000100000000000001000000000000000000000100000000000
000000000000200300002800000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
00000000f001000010000000000000000000000000000000000000000000
0000000000002e0000000000000082010000f001000090010000f0010000
000000000000000000000000200000605803000000000000000000000000
00003dd8afdc2000540069006e0079005000450020006f006e0020005700
69006e0064006f0077007300200031003000000041004200430044004500
460047000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000041b9400024004c8d05f3feff
ff488d151cffffff33c948ff25d3feffffcccccc48030000000000000000
000066030000f00100000000000000000000000000000000000000000000
5803000000000000000000000000000094024d657373616765426f785700
5553455233322e646c6c00000000000000000000000000000000
```

I used `xxd -p -r` to convert the above text back into a binary file.

**Step 5: I thoroughly analyzed the internal structure of the PE file, understood the meaning of each part in the PE file, and then manually constructed an identical PE file using assembly language. Although there was no difference in the file generated in this step compared to the previous one, using assembly language allowed for subsequent steps to modify the assembly code instead of the binary file itself, making it more effective to reduce the file size.**

To understand the structure of the PE file, I primarily referred to the following resources:

- General information: [PE Format](https://docs.microsoft.com/en-us/windows/desktop/Debug/pe-format), [x86 Disassembly/Windows Executable Files](https://en.wikibooks.org/wiki/X86_Disassembly/Windows_Executable_Files), [Portable Executable File Format](https://blog.kowalczyk.info/articles/pefileformat.html)
- Rich header: [The Undocumented Microsoft "Rich" Header](http://bytepointer.com/articles/the_microsoft_rich_header.htm)
- Import address table: [Import table vs Import Address Table](https://reverseengineering.stackexchange.com/a/16872)

Additionally, I used [PE Tools](https://petoolse.github.io/petools/) and [PE Disassembler viewer](http://www.codedebug.com/php/Products/Products_NikPEViewer_20v.php) tools.

After understanding the structure of the PE file, I manually constructed an identical PE file using assembly language.

When coding in assembly language, it is essential not to use hardcoded values, but rather to use pseudo-instructions to calculate the corresponding values. For example, the file size value `0x0380` is replaced with `file_size equ $-$$`, and the machine instruction `0x41b940002400` is replaced with `mov r9d, 0x00240040`. This is because if hardcoded values are used, they will not change when the structure of the PE file changes in subsequent steps, resulting in a corrupted file.

Moreover, when using the NASM assembler, according to the [official documentation](https://www.nasm.us/doc/nasmdoc3.html#section-3.2.1), I used pseudo-instructions `db`, `dw`, `dd`, and `dq` to declare 1, 2, 4, and 8-byte data, respectively.

The assembly language file `stretch.asm` I wrote is as follows:

```assembly
BITS 64

%define align(n,r) (((n+(r-1))/r)*r)

; DOS Header
    dw 'MZ'                 ; e_magic
    dw 0                    ; [UNUSED] e_cblp
    dw 0                    ; [UNUSED] c_cp
    dw 0                    ; [UNUSED] e_crlc
    dw 0                    ; [UNUSED] e_cparhdr
    dw 0                    ; [UNUSED] e_minalloc
    dw 0                    ; [UNUSED] e_maxalloc
    dw 0                    ; [UNUSED] e_ss
    dw 0                    ; [UNUSED] e_sp
    dw 0                    ; [UNUSED] e_csum
    dw 0                    ; [UNUSED] e_ip
    dw 0                    ; [UNUSED] e_cs
    dw 0                    ; [UNUSED] e_lfarlc
    dw 0                    ; [UNUSED] e_ovno
    times 4 dw 0            ; [UNUSED] e_res
    dw 0                    ; [UNUSED] e_oemid
    dw 0                    ; [UNUSED] e_oeminfo
    times 10 dw 0           ; [UNUSED] e_res2
    dd pe_hdr               ; e_lfanew

; DOS Stub
    times 8 dq 0            ; [UNUSED] DOS Stub

; Rich Header
    times 8 dq 0            ; [UNUSED] Rich Header

; PE Header
pe_hdr:
    dw 'PE', 0              ; Signature

; Image File Header
    dw 0x8664               ; Machine
    dw 0x01                 ; NumberOfSections
    dd 0                    ; [UNUSED] TimeDateStamp
    dd 0                    ; PointerToSymbolTable
    dd 0                    ; NumberOfSymbols
    dw opt_hdr_size         ; SizeOfOptionalHeader
    dw 0x22                 ; Characteristics

; Optional Header, COFF Standard Fields
opt_hdr:
    dw 0x020b               ; Magic (PE32+)
    db 0x0e                 ; MajorLinkerVersion
    db 0x16                 ; MinorLinkerVersion
    dd code_size            ; SizeOfCode
    dd 0                    ; SizeOfInitializedData
    dd 0                    ; SizeOfUninitializedData
    dd entry                ; AddressOfEntryPoint
    dd iatbl                ; BaseOfCode

; Optional Header, NT Additional Fields
    dq 0x000140000000       ; ImageBase
    dd 0x10                 ; SectionAlignment
    dd 0x10                 ; FileAlignment
    dw 0x06                 ; MajorOperatingSystemVersion
    dw 0                    ; MinorOperatingSystemVersion
    dw 0                    ; MajorImageVersion
    dw 0                    ; MinorImageVersion
    dw 0x06                 ; MajorSubsystemVersion
    dw 0                    ; MinorSubsystemVersion
    dd 0                    ; Reserved1
    dd file_size            ; SizeOfImage
    dd hdr_size             ; SizeOfHeaders
    dd 0                    ; CheckSum
    dw 0x02                 ; Subsystem (Windows GUI)
    dw 0x8160               ; DllCharacteristics
    dq 0x100000             ; SizeOfStackReserve
    dq 0x1000               ; SizeOfStackCommit
    dq 0x100000             ; SizeOfHeapReserve
    dq 0x1000               ; SizeOfHeapCommit
    dd 0                    ; LoaderFlags
    dd 0x10                 ; NumberOfRvaAndSizes

; Optional Header, Data Directories
    dd 0                    ; Export, RVA
    dd 0                    ; Export, Size
    dd itbl                 ; Import, RVA
    dd itbl_size            ; Import, Size
    dd 0                    ; Resource, RVA
    dd 0                    ; Resource, Size
    dd 0                    ; Exception, RVA
    dd 0                    ; Exception, Size
    dd 0                    ; Certificate, RVA
    dd 0                    ; Certificate, Size
    dd 0                    ; Base Relocation, RVA
    dd 0                    ; Base Relocation, Size
    dd 0                    ; Debug, RVA
    dd 0                    ; Debug, Size
    dd 0                    ; Architecture, RVA
    dd 0                    ; Architecture, Size
    dd 0                    ; Global Ptr, RVA
    dd 0                    ; Global Ptr, Size
    dd 0                    ; TLS, RVA
    dd 0                    ; TLS, Size
    dd 0                    ; Load Config, RVA
    dd 0                    ; Load Config, Size
    dd 0                    ; Bound Import, RVA
    dd 0                    ; Bound Import, Size
    dd iatbl                ; IAT, RVA
    dd iatbl_size           ; IAT, Size
    dd 0                    ; Delay Import Descriptor, RVA
    dd 0                    ; Delay Import Descriptor, Size
    dd 0                    ; CLR Runtime Header, RVA
    dd 0                    ; CLR Runtime Header, Size
    dd 0                    ; Reserved, RVA
    dd 0                    ; Reserved, Size

opt_hdr_size equ $-opt_hdr

; Section Table
    section_name db '.'     ; Name
    times 8-($-section_name) db 0
    dd sect_size            ; VirtualSize
    dd iatbl                ; VirtualAddress
    dd code_size            ; SizeOfRawData
    dd iatbl                ; PointerToRawData
    dd 0                    ; PointerToRelocations
    dd 0                    ; PointerToLinenumbers
    dw 0                    ; NumberOfRelocations
    dw 0                    ; NumberOfLinenumbers
    dd 0x60000020           ; Characteristics

hdr_size equ $-$$

code:
; Import Address Directory
iatbl:
    dq symbol
    dq 0

iatbl_size equ $-iatbl

; Strings
title:
    db 0x3d,0xd8,0xaf,0xdc,0x20,0x00,0x54,0x00
    db 0x69,0x00,0x6e,0x00,0x79,0x00,0x50,0x00
    db 0x45,0x00,0x20,0x00,0x6f,0x00,0x6e,0x00
    db 0x20,0x00,0x57,0x00,0x69,0x00,0x6e,0x00
    db 0x64,0x00,0x6f,0x00,0x77,0x00,0x73,0x00
    db 0x20,0x00,0x31,0x00,0x30,0x00,0,0
content:
    db 0x41,0x00,0x42,0x00,0x43,0x00,0x44,0x00
    db 0x45,0x00,0x46,0x00,0x47,0x00,0,0

; Debug Table
    times 24 dq 0           ; [UNUSED] Debug Table

; Entry
entry:
    mov r9d, 0x00240040     ; uType
    lea r8, [rel title]     ; lpCaption
    lea rdx, [rel content]  ; lpText
    xor ecx, ecx            ; hWnd
    jmp [rel iatbl]         ; MessageBoxW

    times align($-$$,16)-($-$$) db 0xcc

; Import Directory
itbl:
    dq intbl                ; OriginalFirstThunk
    dd 0                    ; TimeDateStamp
    dd dll_name             ; ForwarderChain
    dd iatbl                ; Name
    dq 0                    ; FirstThunk

    times 3 dd 0

itbl_size equ $-itbl

; Import Name Table
intbl:
    dq symbol
    dq 0

; Symbol
symbol:
    dw 0x0294               ; [UNUSED] Function Order
    db 'MessageBoxW', 0     ; Function Name
dll_name:
    db 'USER32.dll', 0
    db 0

sect_size equ $-code

    times align($-$$,16)-($-$$) db 0

code_size equ $-code
file_size equ $-$$
```

Compile:

```zsh
$ nasm -f bin -o stretch.exe -l stretch.lst stretch.asm
```

The compiled `stretch.exe` runs normally.

At this point, I noticed that although `stretch.exe` was manually constructed following `tiny.exe` and should theoretically be identical, there were slight differences between the two:

```zsh
$ diff =(xxd step4/tiny.exe) =(xxd step5/stretch.exe)
50c50
< 00000310: 1cff ffff 33c9 48ff 25d3 feff ffcc cccc  ....3.H.%.......
---
> 00000310: 1cff ffff 31c9 ff25 d4fe ffff cccc cccc  ....1..%........
```

The `xor ecx, ecx` instruction is represented as machine code `0x33c9` in `tiny.exe` and `0x31c9` in `stretch.exe`. As explained in [XOR — Logical Exclusive OR](https://www.felixcloutier.com/x86/xor), this is due to different encoding methods of the instruction, and it doesn't affect the instruction's semantic:

```zsh
$ echo 33c9 | xxd -p -r - | ndisasm -b 64 -
00000000  33C9              xor ecx,ecx
$ echo 31c9 | xxd -p -r - | ndisasm -b 64 -
00000000  31C9              xor ecx,ecx
```

The `jmp [rel iatbl]` instruction is represented as machine code `0x48ff25d3feffff` in `tiny.exe` and `0xff25d4feffff` in `stretch.exe`. The jump addresses for these two instructions are the same:

```zsh
$ echo 48ff25d3feffff | xxd -p -r - | ndisasm -b 64 -
00000000  48FF25D3FEFFFF    jmp qword [rel 0xfffffffffffffeda]
$ echo ff25d4feffff | xxd -p -r - | ndisasm -b 64 -
00000000  FF25D4FEFFFF      jmp [rel 0xfffffffffffffeda]
```

According to an [answer on Stack Overflow](https://stackoverflow.com/a/36800114), the `48` prefix in the machine code represents REX.W, which is ignored by the processor. This prefix may be related to Windows x64 unwind data. In any case, this modification doesn't affect the instruction's effect, as seen from the execution results.

From this, I concluded that the `stretch.exe` written using assembly language in this step is equivalent to the `tiny.exe` from the previous step.

**Step 6: Based on the analysis of the internal structure of the PE file, I removed all the directly removable useless parts from the assembly code, thus reducing the file size.**

The removed parts are as follows:

- Removed DOS stub, Rich header, and debug table
- In the optional header's data directories, only kept the first 2 items out of 16, and set `NumberOfRvaAndSizes` to 2
- Removed bytes used for alignment after `itbl`

The modified `stretch.asm` is as follows:

```zsh
$ diff step5/stretch.asm step6/stretch.asm
26,31d25
< ; DOS Stub
<     times 8 dq 0            ; [UNUSED] DOS Stub
< 
< ; Rich Header
<     times 8 dq 0            ; [UNUSED] Rich Header
< 
77c71
<     dd 0x10                 ; NumberOfRvaAndSizes
---
>     dd 0x02                 ; NumberOfRvaAndSizes
84,111d77
<     dd 0                    ; Resource, RVA
<     dd 0                    ; Resource, Size
<     dd 0                    ; Exception, RVA
<     dd 0                    ; Exception, Size
<     dd 0                    ; Certificate, RVA
<     dd 0                    ; Certificate, Size
<     dd 0                    ; Base Relocation, RVA
<     dd 0                    ; Base Relocation, Size
<     dd 0                    ; Debug, RVA
<     dd 0                    ; Debug, Size
<     dd 0                    ; Architecture, RVA
<     dd 0                    ; Architecture, Size
<     dd 0                    ; Global Ptr, RVA
<     dd 0                    ; Global Ptr, Size
<     dd 0                    ; TLS, RVA
<     dd 0                    ; TLS, Size
<     dd 0                    ; Load Config, RVA
<     dd 0                    ; Load Config, Size
<     dd 0                    ; Bound Import, RVA
<     dd 0                    ; Bound Import, Size
<     dd iatbl                ; IAT, RVA
<     dd iatbl_size           ; IAT, Size
<     dd 0                    ; Delay Import Descriptor, RVA
<     dd 0                    ; Delay Import Descriptor, Size
<     dd 0                    ; CLR Runtime Header, RVA
<     dd 0                    ; CLR Runtime Header, Size
<     dd 0                    ; Reserved, RVA
<     dd 0                    ; Reserved, Size
150,152d115
< ; Debug Table
<     times 24 dq 0           ; [UNUSED] Debug Table
< 
170,171d132
< 
<     times 3 dd 0
```

Compile:

```zsh
$ nasm -f bin -o stretch.exe -l stretch.lst stretch.asm
```

The compiled `stretch.exe` runs normally.

**Step 7: In the previous step, I removed all the directly removable useless parts. However, some useless fields couldn't be directly removed. This is because the PE file contains multiple file headers with fixed formats, where these useless fields occupy specific positions. Consequently, even if a field is not used, it still occupies its respective position in the file header and cannot be directly removed. To tackle this, I employed the method of overlapping by carefully selecting suitable overlaps to combine multiple file headers while ensuring that each overlapped position corresponds to at most one useful field. In this way, I effectively reduced the file size without damaging the file headers.**

To determine whether a field is useful, I adopted the trial-and-error method. In this method, I manually set the values of the fields to 0 one by one. If the file become corrupted after a certain modification, it means that the corresponding field is useful; otherwise, it is useless.

After identifying useful and useless fields, I overlapped them to reduce the file size. For example, I set the starting position of the PE header to the `0x04` location of the DOS header, overlapping the fields of the two file headers. There could be multiple overlapping methods, but in this experiment, I chose only one.

Moreover, although both the Import table and DLLFuncEntry are useful fields, they can be overlapped since the Import table is only used before the program iis loaded, and DLLFuncEntry is only used after the program is loaded, so there is no conflict.

The overlapped `stretch.asm` is as follows:

```assembly
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
    dw 0                    ; [UNUSED] e_oemid          ; [UNUSED] SizeOfInitializedData
    dw 0                    ; [UNUSED] e_oeminfo        ; [UNUSED] SizeOfInitializedData (Cont)
    dd 0                    ; [UNUSED] e_res2           ; [UNUSED] SizeOfUninitializedData
    dd entry                ; [UNUSED] e_res2 (Cont)    ; AddressOfEntryPoint
    dd code                 ; [UNUSED] e_res2 (Cont)    ; BaseOfCode
                                                        ; Optional Header, NT Additional Fields
    dq 0x000140000000       ; [UNUSED] e_res2 (Cont)    ; ImageBase
    dd pe_hdr               ; e_lfanew                  ; [MODIFIED] SectionAlignment (0x10 -> 0x04)
    dd 0x04                                             ; [MODIFIED] FileAlignment (0x10)
    dw 0x06                                             ; [UNUSED] MajorOperatingSystemVersion
    dw 0                                                ; [UNUSED] MinorOperatingSystemVersion
    dw 0                                                ; [UNUSED] MajorImageVersion
    dw 0                                                ; [UNUSED] MinorImageVersion
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
    dd 0                    ; [UNUSED] Export, RVA
    dd 0                    ; [UNUSED] Export, Size
iatbl:                                                  ; Import Address Directory
    dd itbl                 ; Import, RVA               ; [USEDAFTERLOAD] DLLFuncEntry
    dd itbl_size            ; Import, Size              ; [USEDAFTERLOAD] DLLFuncEntry (Cont)
iatbl_size equ $-iatbl

opt_hdr_size equ $-opt_hdr

                            ; Section Table
    section_name db '.', 0  ; Name
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

; Entry
entry:
    mov r9d, 0x00240040     ; uType
    lea r8, [rel title]     ; lpCaption
    lea rdx, [rel content]  ; lpText
    xor ecx, ecx            ; hWnd
    jmp [rel iatbl]         ; MessageBoxW

itbl:                       ; Import Directory
    dq intbl                ; OriginalFirstThunk
    dd 0                    ; [UNUSED] TimeDateStamp
    dd dll_name             ; ForwarderChain
    dd iatbl                ; Name
intbl:                                                  ; Import Name Table
    dq symbol               ; [UNUSED] FirstThunk       ; Symbol
    dq 0                                                ; nullptr
itbl_size equ $-itbl

sect_size equ $-code
code_size equ $-code
file_size equ $-$$
```

Compile:

```zsh
$ nasm -f bin -o stretch.exe -l stretch.lst stretch.asm
```

The compiled `stretch.exe` runs normally.

**Step 8: The PE file also contains five instruction machine codes. If I further overlapped these machine codes with the file headers using the method from the previous step, I could reduce the file size even more. However, the instruction machine codes were too long and couldn't be inserted "seamlessly" into the gaps of the file header's useless fields. To address this, I broke down the five instructions and added a short jump instruction after each of the first four instructions, jumping to the positions of the next instruction. This allowed each instruction to be inserted independently into different gaps. Even after doing this, two instructions were still too long to fit into the gaps. After thoroughly studying and mastering the x64 instruction set, I realized that using a different register as the base for these two instructions could yield shorter machine codes while the semantic of the instructions remains the same. This allowed me to further insert the two instructions into the gaps of the file header and reduce the file size.**

In the previous step, all overlapping fields were overlapped, but the machine codes of the instructions had been left unchanged:

```zsh
$ grep -A 5 entry: stretch.lst
    94                                  entry:
    95 000000F4 41B940002400                mov r9d, 0x00240040     ; uType
    96 000000FA 4C8D05C3FFFFFF              lea r8, [rel title]     ; lpCaption
    97 00000101 488D15ACFFFFFF              lea rdx, [rel content]  ; lpText
    98 00000108 31C9                        xor ecx, ecx            ; hWnd
    99 0000010A FF2584FFFFFF                jmp [rel iatbl]         ; MessageBoxW
```

The first four instructions are used for parameter passing in function calls. According to the [x64 calling convention](https://docs.microsoft.com/en-us/cpp/build/x64-calling-convention?view=vs-2019), in Windows x64, the first four function parameters are passed using the RCX, RDX, R8, and R9 registers. Stacks are only utilized for parameter passing when there are more than four parameters. As the `hWnd` and `uType` parameters of `MessageBoxW` are 32-bit rather than 64-bit, I replaced RCX with ECX and R9 with R9D. The fifth instruction is a jump instruction. To minimize the PE file size, the handling of the return value of the `MessageBoxW` function is bypassed and the `jmp` instruction is directly used to jump to the target function.

As a whole, the machine codes of these five instructions occupy 28 bytes. However, after the overlapping process in the previous step, the largest useless field is only 8 bytes. Therefore, it was impossible to "seamlessly" insert the machine codes into the gaps of the file header's useless fields. At this point, I came up with the idea of breaking down the instructions and adding a short jump instruction after each of the first four instructions to jump to the position of the next instruction. As explained in [JMP — Jump](https://www.felixcloutier.com/x86/jmp), short jump instructions can reach a range of -128 to +127, and their machine codes only occupy 2 bytes, making this approach feasible.

| Assembly | Length of corresponding machine code |
| :- | :- |
| `mov r9d, 0x00240040` + `jmp` | 8 |
| `lea r8, [rel title]` + `jmp` | 9 |
| `lea rdx, [rel content]` + `jmp` | 9 |
| `xor ecx, ecx` + `jmp` | 4 |
| `jmp [rel iatbl]` | 6 |

However, as the table shows, the machine codes of the two `lea` instructions still occupy 9 bytes. As previously mentioned, the largest useless field is only 8 bytes, so it was still impossible to "seamlessly insert" these two instructions.

While debugging with [x64dbg](https://x64dbg.com/), I found that when the program execution reached the entry point of the user code, the RDX register value was set to the entry address:

![](https://ayaka.shn.hk/tinype/rdx.png)

At this moment, through in-depth learning and comprehensive mastery of the x64 instruction set, I realized that using the RDX register as a base in the `lea` instructions would result in shorter corresponding machine codes. Since the RDX register value was set to the entry address, it was not random and met the conditions for being used as a base.

Originally, the program used the RIP register as a base, with a corresponding machine code length of 7:

| Assembly | Machine code | Length |
| :- | :- | :- |
| `lea r8, [rip-0x4d]` | `0x4c8d05b3ffffff` | 7 |
| `lea rdx, [rip-0x44]` | `0x488d15bcffffff` | 7 |

With the RDX register as the base, the corresponding machine code length was only 4:

| Assembly | Machine code | Length |
| :- | :- | :- |
| `lea r8, [rdx-0x4d]` | `0x4c8d42b3` | 4 |
| `lea rdx, [rdx-0x44]` | `0x488d52bc` | 4 |

Thus, I modified the two `lea` instructions to use the RDX register as the base. The modified assembly instructions are as follows:

| Assembly | Machine code | Length |
| :- | :- |
| `mov r9d, 0x00240040` + `jmp` | 8 |
| `lea r8, [rdx+title-entry]` + `jmp` | 6 |
| `lea rdx, [rdx+content-entry]` + `jmp` | 6 |
| `xor ecx, ecx` + `jmp` | 4 |
| `jmp [rel iatbl]` | 6 |

Now, they could overlap with the useless fields.

The updated `stretch.asm` is as follows:

Compile:

```assembly
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
```

Compile:

```zsh
$ nasm -f bin -o stretch.exe -l stretch.lst stretch.asm
```

The compiled `stretch.exe` was successfully generated and could run normally.

**Step 9: Remove the trailing zeros from the file, as the program will automatically pad zeros at the end when loaded.**

Since the program automatically pads zeros at the end when loaded, I could safely remove the trailing zeros from the file.

I saved the modified results as `stretch.asm`:

```zsh
$ diff step8/stretch.asm step9/stretch.asm
113c113
<     dq symbol               ; [UNUSED] FirstThunk       ; Symbol
---
>     dd symbol
115d114
<     dq 0                                                ; nullptr
```

Compile:

```zsh
$ nasm -f bin -o stretch.exe -l stretch.lst stretch.asm
```

The compilation resulted in a working `stretch.exe`:

![](https://ayaka.shn.hk/tinype/tiny1.exe.png)

```zsh
$ xxd stretch.exe
00000000: 4d5a 0000 5045 0000 6486 0100 4d65 7373  MZ..PE..d...Mess
00000010: 6167 6542 6f78 5700 8000 2200 0b02 0000  ageBoxW...".....
00000020: 0201 0000 ff25 6a00 0000 0000 fc00 0000  .....%j.........
00000030: 0a00 0000 0000 0040 0100 0000 0400 0000  .......@........
00000040: 0400 0000 488d 52b8 ebda 0000 0600 0000  ....H.R.........
00000050: 0000 0000 0c01 0000 c400 0000 0000 0000  ................
00000060: 0200 6081 0000 1000 0000 0000 0010 0000  ..`.............
00000070: 0000 0000 0000 1000 0000 0000 5553 4552  ............USER
00000080: 3332 2e64 6c6c 0000 0200 0000 41b9 4000  32.dll......A.@.
00000090: 2400 ebb0 f400 0000 1800 0000 2e00 4c8d  $.............L.
000000a0: 42c8 ebe8 0201 0000 9400 0000 0201 0000  B...............
000000b0: 9400 0000 4100 4200 4300 4400 4500 4600  ....A.B.C.D.E.F.
000000c0: 4700 0000 3dd8 afdc 2000 5400 6900 6e00  G...=... .T.i.n.
000000d0: 7900 5000 4500 2000 6f00 6e00 2000 5700  y.P.E. .o.n. .W.
000000e0: 6900 6e00 6400 6f00 7700 7300 2000 3100  i.n.d.o.w.s. .1.
000000f0: 3000 0000 0801 0000 0000 0000 31c9 eb9e  0...........1...
00000100: 7c00 0000 9400 0000 0a00 0000            |...........
```

## References

In addition to the references mentioned throughout the text, the following materials were also consulted for this experiment:

1. [Tiny PE](http://www.phreedom.org/research/tinype/)
2. [Writing ultra-small Windows executables](https://keyj.emphy.de/win32-pe/)

(Experiment done in mid-2019. Chinese version published on November 23, 2021. English version published on April 13, 2023)
