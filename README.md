# Minimal 64-Bit PE File on Windows 10

Chinese Version: [Post on Zhihu](https://www.zhihu.com/question/21715980/answer/2239380126) - [Blog](https://ayaka.shn.hk/tinype/)

**Note**: The English version is not completed yet, please refer to the Chinese version.

## Introduction

This experiment aims to produce a minimal 64-bit [Portable Executable](https://en.wikipedia.org/wiki/Portable_Executable) (PE) file on the Windows 10 operating system that can pop up a message box with a text prompt and meet the three requirements of the experiment:

- Symbols should be imported by name (instead of ordinal)
- Total length of message box title and content should be 64 bytes
- File size should less than 300 bytes

After nine steps, a PE file of 268 bytes was produced.

The steps of the experiment were as follows:

- Step 1: Using the ordinary method, write a program in C and use the MSVC compiler to generate a normal PE file.
- Step 2: Reduce the size of the generated PE file by changing the command line options of the MSVC compiler.
- Step 3: Examine the PE file generated in the previous step using [PE Tools](https://petoolse.github.io/petools/). Set the apparently unused parts to zero. At this point the file size has not been reduced, but there are more zeros in the file, which leaves more room for compression in subsequent steps.
- Step 4: In the PE file, the MS-DOS stub is also an unused part, so use a binary editor to zero out this part manually. This step also leaves more room for compression in subsequent steps.
- Step 5: Analyse the structure of the PE file in detail, master the function of each part. Then manually create an identical PE file using assembly. Although the file generated in this step is no different from the previous one, using assembly makes it easier to reduce the file size by making changes to the assembly code in subsequent steps instead of modifying the binary file itself.
- Step 6: Based on the analysis of the structure of the PE file, remove all of the unused parts from the assembly code, thus reducing the file size.
- Step 7: Although all of the unused parts were removed in the previous step, there are still some unused fields that cannot be removed directly. This is because PE files contain multiple headers and the unused fields are parts of these file headers. Since the formats of the headers are fixed, even if a field in the header is unused, it still has to occupy the space in the header and therefore cannot be deleted directly. To address this issue, the approach of overlapping can be adopted, in which multiple file headers are overlapped together by carefully selecting the starting position of the file headers and ensuring that after overlapping, each overlapping position can only correspond to at most one used field. This allows the file size to be reduced effectively without breaking the file headers.
- Step 8: The PE file also contains machine code of five instructions. If the machine code of these five instructions is also overlapped with the file header as in the previous step, the file size can be further reduced. However, the machine code of the instructions is too long to fit into the gaps of the unused fields in the file headers. To solve this problem, a possible solution is to split the five instructions apart and add a short jump instruction to each of the first four instructions to jump to the next instruction, so that each instruction can be inserted into a different gap. However, even with this approach there are still two instructions that are too long to be inserted into the gap. At this moment, with my in-depth study and full mastery of the x64 instruction set, it occurs to me that the machine code of these two instructions can be shortened without changing the semantics when these two instructions use the value of another register as their base address. In this way, the machine code is also inserted into the gaps of the unused fields, thus further reducing the file size.
- Step 9: Remove the zeros at the end of the file, as the file is automatically filled with zeros when the program is being loaded.

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

In steps 3-5, although the file size is not reduced, the entropy of the file decreases, which indicates that there are more zeros inside the file, and hence more room for compression in subsequent steps.

## Environment

* Operating System: Microsoft Windows 10 Version 1903 (v10.0.18362.239) 64-bit
* Shell: zsh 5.7.1 (x86_64-pc-msys)
* C Compiler: Microsoft (R) C/C++ Optimizing Compiler Version 19.22.27905 for x64
* Linker: Microsoft (R) Incremental Linker Version 14.22.27905.0
* Assembler: NASM version 2.14.02 compiled on Jan 30 2019
* Debugger: x64dbg May 19 2019, 18:13:13

## Steps

### Step 1

> Call Windows API to display a message box in C. Generate PE file with MSVC compiler

The usage Windows API function `MessageBoxW` referenced [MessageBoxW function](https://docs.microsoft.com/en-us/windows/desktop/api/winuser/nf-winuser-messageboxw).

In Windows programming, function name ending with A means that the character encoding is current code page of the user, while W means that the character encoding is UTF-16. Since the code page of users are not unified currently, for the sake of compatibility, the `MessageBoxW` function that end with W is used.

Save the following code as `tiny.c`:

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

After installing Visual Studio Build Tools 2019, there would be Visual Studio 2019 folder in Start Menu. Open command prompt by clicking x64 Native Tools Command Prompt for VS 2019. Change to current directory. Type the following command:

```cmd
$ cl /O1 /source-charset:utf-8 tiny.c /link /SUBSYSTEM:WINDOWS /ENTRY:mainCRTStartup user32.lib
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

The compilation yields `tiny.exe`, which runs normally.

![Run `tiny1.exe`](images/tiny1.exe.png)

**File size 94208 bytes. Entropy 5.924863**

### Step 2

> Change the command line options of MSVC compiler to reduce the size of the generated file

This step mainly referenced [Minimize the size of your program – high level](https://blogs.msdn.microsoft.com/xiangfan/2008/09/19/minimize-the-size-of-your-program-high-level/) and [Linker Options](https://docs.microsoft.com/en-us/cpp/build/reference/linker-options?view=vs-2019).

Save the following code as `tiny.c`:

```c
#include <Windows.h>

void _() {
    MessageBoxW( NULL /* hWnd */,
                 L"ABCDEFG" /* lpText, 16 bytes */,
                 L"💯 TinyPE on Windows 10" /* lpCaption, 48 bytes */,
                 MB_ICONASTERISK | MB_TOPMOST | MB_SERVICE_NOTIFICATION /* uType */ );
}
```

Compile by the following command line option:

```cmd
$ cl /O1 /MD /GS- /source-charset:utf-8 tiny.c /link /NOLOGO /NODEFAULTLIB /SUBSYSTEM:WINDOWS /ENTRY:_ /MERGE:.rdata=. /MERGE:.pdata=. /MERGE:.text=. /SECTION:.,ER /ALIGN:16 user32.lib
Microsoft (R) C/C++ Optimizing Compiler Version 19.22.27905 for x64
Copyright (C) Microsoft Corporation.  All rights reserved.

tiny.c
LINK : warning LNK4108: /ALIGN specified without /DRIVER; image may not run
LINK : warning LNK4254: section '.text' (60000020) merged into '.' (40000040) with different attributes
```

The compilation yields `tiny.exe`, which runs normally.

**File size 896 bytes. Entropy 3.567715**

### Step 3

> Roughly analyse the generated PE file by [PE Tools](https://petoolse.github.io/petools/). Clean the unused `TimeDateStamp` field, Rich header and debug directory

Open PE Tools (v1.9.762.2018). Click "PE Editor", then open `tiny.exe`.

![Open `tiny2.exe` by PE Tools](images/tiny2.exe.png)

* Click "File Header". Find "Time/Date" and set to 0
* Click "View Rich", then click "Clear Sign"
* Click "Directories". Find "Debug Directory". Click "...", then click "Clear debug info"

The modified `tiny.exe`runs normally.

**File size 896 bytes. Entropy 2.220567**

### Step 4

> Clean the unused MS-DOS stub by hex editor

Open  `tiny.exe` by hex editor.

* Set 0x02-0x3b to zero (0x00-0x01 is `e_magic`, 0x3c-0x3f is `e_lfanew`)
* Set 0x40-0x7f to zero

The modified `tiny.exe`runs normally. The content should be:

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

`xxd -p -r` can be used to convert the above text file back to binary file.

**File size 896 bytes. Entropy 1.608427**

### Step 5

> Analyse the fields of PE file in detail. Reconstruct the file manually by assembly. Substitute hard-coded values by pseudo instructions (e.g. substitute the size of file by `$-$$`)

The structure of PE files referenced the following contents:

* Overview: [PE Format](https://docs.microsoft.com/en-us/windows/desktop/Debug/pe-format), [x86 Disassembly/Windows Executable Files](https://en.wikibooks.org/wiki/X86_Disassembly/Windows_Executable_Files), [Portable Executable File Format](https://blog.kowalczyk.info/articles/pefileformat.html)
* Rich header: [The Undocumented Microsoft "Rich" Header](http://bytepointer.com/articles/the_microsoft_rich_header.htm)
* Import address table: [Import table vs Import Address Table](https://reverseengineering.stackexchange.com/a/16872)

When understanding the structure of PE files, the tools mainly used are [PE Tools](https://petoolse.github.io/petools/) and [PE Disassembler viewer](http://www.codedebug.com/php/Products/Products_NikPEViewer_20v.php).

According to the [official documentation](https://www.nasm.us/doc/nasmdoc3.html#section-3.2.1) of NASM assembler, the pseudo instructions `db`, `dw`, `dd` are used to `dq` declare data of 1, 2, 4 and 8 bytes respectively.

Substitute hard-coded values by pseudo instructions. For example, the file size, 0x0380, is substituted by `file_size equ $-$$`. The instruction 0x41b940002400 is substituted by `mov r9d, 0x00240040`.

`stretch.asm` is written as the following:

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

The compilation yields `stretch.exe`, which runs normally.

Although `stretch.exe` is written manually according to `tiny.exe`, there are some differences:

```zsh
$ diff =(xxd step4/tiny.exe) =(xxd step5/stretch.exe)
50c50
< 00000310: 1cff ffff 33c9 48ff 25d3 feff ffcc cccc  ....3.H.%.......
---
> 00000310: 1cff ffff 31c9 ff25 d4fe ffff cccc cccc  ....1..%........
```

`xor ecx, ecx` is represented by machine code 0x33c9 in `tiny.exe`, but represented by 0x31c9 in `stretch.exe`. According to [XOR — Logical Exclusive OR](https://www.felixcloutier.com/x86/xor), the difference is caused by the different ways of instruction encoding. The effect of the instruction is not affected.

```zsh
$ echo 33c9 | xxd -p -r - | ndisasm -b 64 -
00000000  33C9              xor ecx,ecx
$ echo 31c9 | xxd -p -r - | ndisasm -b 64 -
00000000  31C9              xor ecx,ecx
```

`jmp [rel iatbl]` is represented by machine code 0x48ff25d3feffff in `tiny.exe`, but represented by 0xff25d4feffff in `stretch.exe`. The jump addresses of the two instructions are not different:

```zsh
$ echo 48ff25d3feffff | xxd -p -r - | ndisasm -b 64 -
00000000  48FF25D3FEFFFF    jmp qword [rel 0xfffffffffffffeda]
$ echo ff25d4feffff | xxd -p -r - | ndisasm -b 64 -
00000000  FF25D4FEFFFF      jmp [rel 0xfffffffffffffeda]
```

According to [an answer](https://stackoverflow.com/a/36800114) on Stack Overflow, the 48 prefix in machine code stands for REX.W, which would be ignored by the processor. This prefix may be related to unwind data on Windows x64. In addition, the change do not affect the behaviour of the program.

**File size 896 bytes. Entropy 1.607880**

### Step 6

> Remove unused DOS stub, Rich header and debug table. For the 16 entries in data directories of optional header, only keep the first 2 entries, and set `NumberOfRvaAndSizes` to 2. Remove the padding bytes after `itbl`

Save the modification as `stretch.asm`:

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

The compilation yields `stretch.exe`, which runs normally.

**File size 448 bytes. Entropy 2.653766**

### Step 7

---

## References

Besides the references declared above, this experiment also referenced the following contents:

1. [Tiny PE](http://www.phreedom.org/research/tinype/)
1. [Writing ultra-small Windows executables](https://keyj.emphy.de/win32-pe/)
