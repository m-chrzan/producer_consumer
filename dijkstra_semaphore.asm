global proberen
global verhogen

section .text

;-------------------------------------------------------------------------------
; proberen -- attempt to grab the semaphore
;        IN: RDI = pointer to 32-bit integer, the semaphore's value
; CLOBBERED: RAX
;            All other registers preserved
spin_lock:
  lock inc dword [rdi]
proberen:
  mov eax, [rdi]
  test eax, eax        ; check if semaphore > 0
  jle proberen         ; if not, spinlock
  mov eax, -1
  lock xadd [rdi], eax ; try decreasing the semaphore
  test eax, eax        ; check if the semaphore was > 0
  jle spin_lock        ; if not, spinlock, adding back the 1
  ret

;-------------------------------------------------------------------------------
; verhogen -- release the semaphore
;  IN: edi = pointer to 32-bit integer, the semaphore's value
;      All registers preserved
verhogen:
  lock inc dword [rdi]
  ret
