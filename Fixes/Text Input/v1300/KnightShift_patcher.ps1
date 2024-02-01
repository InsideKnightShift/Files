<# PeekMessageA function wrapper for ex1
The altered function discards passed wMsgFilterMin and wMsgFilterMax parameters and replaces them with WM_KEYFIRST(0x100) and WM_KEYLAST(0x109) respectively

0:  55                      push   ebp
1:  89 e5                   mov    ebp,esp
3:  57                      push   edi
4:  8b 45 18                mov    eax,DWORD PTR [ebp+0x18]
7:  50                      push   eax
8:  68 09 01 00 00          push   0x109
d:  68 00 01 00 00          push   0x100
12: 6a 00                   push   0x0
14: 8b 45 08                mov    eax,DWORD PTR [ebp+0x8]
17: 50                      push   eax
18: 8b 3d 68 b3 8d 00       mov    edi,DWORD PTR ds:0x8db368
1e: ff d7                   call   edi
20: 5f                      pop    edi
21: 5d                      pop    ebp
22: c2 14 00                ret    0x14
#>
function ApplyTextInputFixes_ex1([Parameter(Mandatory = $true)] [byte[]]$bytes)
{
	"Injecting PeekMessageA function wrapper..."
	$offset = 0x004da390
	$bytes[$offset++] = 0x55
	$bytes[$offset++] = 0x89
	$bytes[$offset++] = 0xe5
	$bytes[$offset++] = 0x57
	$bytes[$offset++] = 0x8b
	$bytes[$offset++] = 0x45
	$bytes[$offset++] = 0x18
	$bytes[$offset++] = 0x50
	$bytes[$offset++] = 0x68
	$bytes[$offset++] = 0x09
	$bytes[$offset++] = 0x01
	$bytes[$offset++] = 0x00
	$bytes[$offset++] = 0x00
	$bytes[$offset++] = 0x68
	$bytes[$offset++] = 0x00
	$bytes[$offset++] = 0x01
	$bytes[$offset++] = 0x00
	$bytes[$offset++] = 0x00
	$bytes[$offset++] = 0x6a
	$bytes[$offset++] = 0x00
	$bytes[$offset++] = 0x8b
	$bytes[$offset++] = 0x45
	$bytes[$offset++] = 0x08
	$bytes[$offset++] = 0x50
	$bytes[$offset++] = 0x8b
	$bytes[$offset++] = 0x3d
	$bytes[$offset++] = 0x68
	$bytes[$offset++] = 0xb3
	$bytes[$offset++] = 0x8d
	$bytes[$offset++] = 0x00
	$bytes[$offset++] = 0xff
	$bytes[$offset++] = 0xd7
	$bytes[$offset++] = 0x5f
	$bytes[$offset++] = 0x5d
	$bytes[$offset++] = 0xc2
	$bytes[$offset++] = 0x14
	$bytes[$offset] = 0x00
	
	"Injecting PeekMessageA function wrapper pointer..."
	$offset = 0x004da388
	$bytes[$offset++] = 0x90
	$bytes[$offset++] = 0xa3
	$bytes[$offset++] = 0x8d
	$bytes[$offset] = 0x00
	

	"Replacing PeekMessageA function addresses..."
	$offset = 0x003da0f4
	$bytes[$offset++] = 0x88
	$bytes[$offset++] = 0xa3
	$bytes[$offset++] = 0x8d
	$bytes[$offset] = 0x00
	
	$offset = 0x003da137
	$bytes[$offset++] = 0x88
	$bytes[$offset++] = 0xa3
	$bytes[$offset++] = 0x8d
	$bytes[$offset] = 0x00
	
	$offset = 0x003da1b7
	$bytes[$offset++] = 0x88
	$bytes[$offset++] = 0xa3
	$bytes[$offset++] = 0x8d
	$bytes[$offset] = 0x00
	
	$offset = 0x003da1dd
	$bytes[$offset++] = 0x88
	$bytes[$offset++] = 0xa3
	$bytes[$offset++] = 0x8d
	$bytes[$offset] = 0x00
}

<# PeekMessageA function wrapper for ex2
TThe altered function discards passed wMsgFilterMin and wMsgFilterMax parameters and replaces them with WM_KEYFIRST(0x100) and WM_KEYLAST(0x109) respectively

0:  55                      push   ebp
1:  89 e5                   mov    ebp,esp
3:  57                      push   edi
4:  8b 45 18                mov    eax,DWORD PTR [ebp+0x18]
7:  50                      push   eax
8:  68 09 01 00 00          push   0x109
d:  68 00 01 00 00          push   0x100
12: 6a 00                   push   0x0
14: 8b 45 08                mov    eax,DWORD PTR [ebp+0x8]
17: 50                      push   eax
18: 8b 3d 64 23 8e 00       mov    edi,DWORD PTR ds:0x8e2364
1e: ff d7                   call   edi
20: 5f                      pop    edi
21: 5d                      pop    ebp
22: c2 14 00                ret    0x14
#>
function ApplyTextInputFixes_ex2([Parameter(Mandatory = $true)] [byte[]]$bytes)
{
	"Injecting PeekMessageA function wrapper..."
	$offset = 0x004e1270
	$bytes[$offset++] = 0x55
	$bytes[$offset++] = 0x89
	$bytes[$offset++] = 0xe5
	$bytes[$offset++] = 0x57
	$bytes[$offset++] = 0x8b
	$bytes[$offset++] = 0x45
	$bytes[$offset++] = 0x18
	$bytes[$offset++] = 0x50
	$bytes[$offset++] = 0x68
	$bytes[$offset++] = 0x09
	$bytes[$offset++] = 0x01
	$bytes[$offset++] = 0x00
	$bytes[$offset++] = 0x00
	$bytes[$offset++] = 0x68
	$bytes[$offset++] = 0x00
	$bytes[$offset++] = 0x01
	$bytes[$offset++] = 0x00
	$bytes[$offset++] = 0x00
	$bytes[$offset++] = 0x6a
	$bytes[$offset++] = 0x00
	$bytes[$offset++] = 0x8b
	$bytes[$offset++] = 0x45
	$bytes[$offset++] = 0x08
	$bytes[$offset++] = 0x50
	$bytes[$offset++] = 0x8b
	$bytes[$offset++] = 0x3d
	$bytes[$offset++] = 0x64
	$bytes[$offset++] = 0x23
	$bytes[$offset++] = 0x8e
	$bytes[$offset++] = 0x00
	$bytes[$offset++] = 0xff
	$bytes[$offset++] = 0xd7
	$bytes[$offset++] = 0x5f
	$bytes[$offset++] = 0x5d
	$bytes[$offset++] = 0xc2
	$bytes[$offset++] = 0x14
	$bytes[$offset] = 0x00
	
	"Injecting PeekMessageA function wrapper pointer..."
	$offset = 0x004e1268
	$bytes[$offset++] = 0x70
	$bytes[$offset++] = 0x12
	$bytes[$offset++] = 0x8e
	$bytes[$offset] = 0x00
	

	"Replacing PeekMessageA function addresses..."
	$offset = 0x003dccb4
	$bytes[$offset++] = 0x68
	$bytes[$offset++] = 0x12
	$bytes[$offset++] = 0x8e
	$bytes[$offset] = 0x00
	
	$offset = 0x003dccf7
	$bytes[$offset++] = 0x68
	$bytes[$offset++] = 0x12
	$bytes[$offset++] = 0x8e
	$bytes[$offset] = 0x00
	
	$offset = 0x003dcd77
	$bytes[$offset++] = 0x68
	$bytes[$offset++] = 0x12
	$bytes[$offset++] = 0x8e
	$bytes[$offset] = 0x00
	
	$offset = 0x003dcd9d
	$bytes[$offset++] = 0x68
	$bytes[$offset++] = 0x12
	$bytes[$offset++] = 0x8e
	$bytes[$offset] = 0x00
}

"============================================"
"Validating exe files"
"============================================"
$hash = Get-FileHash KnightShift.ex1 -Algorithm MD5
if ($hash.Hash -ne '4AF0B37E623D80E8F8D4724EAC703D36')
{
	'Invalid KnightShift.ex1 version'
	Read-Host -Prompt "Press ENTER to exit"
	throw 'Invalid exe version'
}
$hash = Get-FileHash KnightShift.ex2 -Algorithm MD5
if ($hash.Hash -ne 'C44136993FF118047C261D3B3C4C7C30')
{
	'Invalid KnightShift.ex2 version'
	Read-Host -Prompt "Press ENTER to exit"
	throw 'Invalid exe version'
}
""
"============================================"
"Patching KnightShift.ex1"
"============================================"
[byte[]]$bytes = Get-Content KnightShift.ex1 -Encoding Byte -Raw
ApplyTextInputFixes_ex1  -bytes $bytes
,$bytes |Set-Content KnightShift.ex1 -Encoding Byte

""
"============================================"
"Patching KnightShift.ex2"
"============================================"
[byte[]]$bytes2 = Get-Content KnightShift.ex2 -Encoding Byte -Raw
ApplyTextInputFixes_ex2  -bytes $bytes2
,$bytes2 |Set-Content KnightShift.ex2 -Encoding Byte

"All patched!"
Read-Host -Prompt "Press ENTER to exit"