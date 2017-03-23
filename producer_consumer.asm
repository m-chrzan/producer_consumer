global init
global producer

extern malloc

extern produce
extern proberen
extern verhogen

section .bss
buffer: resb 8
buffer_size: resb 8
produce_here: resb 8
consume_here: resb 8
producer_sem: resb 8
consumer_sem: resb 8
producers_portion: resb 8
consumers_portion: resb 8

section .text

;-------------------------------------------------------------------------------
; init -- prepare for the producer and consumer processes
;  IN: RDI = size of buffer to allocate
; OUT: RAX = status code
;             0 = success
;            -1 = size requested too large (> 2^31 - 1)
;            -2 = size requested too small (= 0)
;            -3 = could not allocate requested memory
;      All other registers preserved
init:
  push rdi

  cmp rdi, 0x7fffffff ; check if size > 2^31 - 1
  ja too_big          ; if it is, return with error code -1
  cmp rdi, 0          ; check if size = 0
  je zero             ; if it is, return with error code -2

  mov [producer_sem], edi      ; the producer's semaphore starts at buffer size
  mov dword [consumer_sem], 0  ; the consumer's semaphore starts at 0
  mov dword [produce_here], 0  ; producer should start producing at the start of
                               ;   the buffer
  mov dword [consume_here], 0  ; consumer should start consuming at the start of
                               ;   the buffer
  shl rdi, 3             ; rdi *= 8, which is the size of our portions
  mov [buffer_size], rdi ; remember the buffer's size

  call malloc      ; malloc(rdi * sizeof(int64_t))
  test rax, rax    ; check if we got a NULL pointer
  jz calloc_error  ; if so, return with error code -3

  mov [buffer], rax ; store pointer to allocated memory

finish_init:
  pop rdi
  ret               ; return with success code 0

too_big:
  mov rax, -1
  jmp finish_init

zero:
  mov rax, -2
  jmp finish_init

calloc_error:
  mov rax, -3
  jmp finish_init

;-------------------------------------------------------------------------------
; producer -- procedure to be executed by the producer thread
;  CLOBBERED: RAX, RCX, RDX
;             All other registers preserved
producer:
  push rdi
producer_start:
  ; producer(&producers_portion)
  mov rdi, producers_portion
  call produce

  cmp rax, 0                         ; check if 0 was returned
  je finish_producer                 ; if so, exit the procedure

  ; P(producer_sem)
  mov edi, producer_sem
  call proberen

  ; buffer[produce_here] = producers_portion
  mov rax, [buffer]            ; get pointer to the beginning of the buffer
  add rax, [produce_here]      ; offset by produce_here
  mov rcx, [producers_portion] ; get value of producers_portion
  mov [rax], rcx               ; store value in buffer

  ; V(consumer_sem)
  mov edi, consumer_sem
  call verhogen

  ; produce_here = (produce_here + 8) % buffer_size
  mov rax, [produce_here] ; get value of produce_here
  add rax, 8              ; increase by 8
  xor rdx, rdx            ; zero rdx in preparation for 64-bit div
  div qword [buffer_size] ; divide rax (produce_here) by the buffer's size
  mov [produce_here], rdx ; set produce_here equal to the remainder

  jmp producer_start
finish_producer:
  pop rdi
  ret
