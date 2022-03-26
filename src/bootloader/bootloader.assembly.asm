mov eax, 76546
mov eax, cs
start _Int:
;===============
int Time
;===============
stop _Int

start _Script:
mov rdx,
mov rdi,
syscall

message db 'Welcome to Epiost',10

mov cs, 90h
mov eax, cs
stop _Script
mov eax, Time
