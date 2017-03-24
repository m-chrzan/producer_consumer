global init
global producer
global consumer

extern malloc

extern produce
extern consume
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
  test rdi, rdi       ; check if size = 0
  je zero             ; if it is, return with error code -2

  mov [producer_sem], edi     ; the producer's semaphore starts at buffer size
  mov dword [consumer_sem], 0 ; the consumer's semaphore starts at 0
  mov qword [produce_here], 0 ; producer should start producing at the start of
                              ;   the buffer
  mov qword [consume_here], 0 ; consumer should start consuming at the start of
                              ;   the buffer
  shl rdi, 3             ; rdi *= 8, which is the size of our portions
  mov [buffer_size], rdi ; remember the buffer's size

  call malloc     ; malloc(size * sizeof(int64_t))
  test rax, rax   ; check if we got a NULL pointer
  jz malloc_error ; if so, return with error code -3

  mov [buffer], rax ; store pointer to allocated memory

  xor rax, rax ; set return code to 0
finish_init:
  pop rdi
  ret

too_big:
  mov rax, -1
  jmp finish_init

zero:
  mov rax, -2
  jmp finish_init

malloc_error:
  mov rax, -3
  jmp finish_init

;-------------------------------------------------------------------------------
; producer -- procedure to be executed by the producer thread
; CLOBBERED: RAX, RCX, RDX
;            All other registers preserved
producer:
  push rdi
producer_start:
  ; produce(&producers_portion)
  mov rdi, producers_portion
  call produce

  cmp rax, 0         ; check if 0 was returned
  je finish_producer ; if so, exit the procedure

  ; P(producer_sem)
  mov rdi, producer_sem
  call proberen

  ; buffer[produce_here] = producers_portion
  mov rax, [buffer]            ; get pointer to the beginning of the buffer
  add rax, [produce_here]      ; offset by produce_here
  mov rcx, [producers_portion] ; get value of producers_portion
  mov [rax], rcx               ; store value in buffer

  ; V(consumer_sem)
  mov rdi, consumer_sem
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

;-------------------------------------------------------------------------------
; consumer -- procedure to be executed by the consumer thread
; CLOBBERED: RAX, RCX, RDX
;            All other registers preserved
consumer:
  push rdi
consumer_start:
  ; P(consumer_sem)
  mov rdi, consumer_sem
  call proberen

  ; consumers_portion = buffer[consume_here]
  mov rax, [buffer]            ; get pointer to the beginning of the buffer
  add rax, [consume_here]      ; offset by consume_here
  mov rcx, [rax]               ; get value of consumers_portion
  mov [consumers_portion], rcx ; save it in a named variable

  ; V(producer_sem)
  mov rdi, producer_sem
  call verhogen

  ; consume(consumers_portion)
  mov rdi, [consumers_portion]
  call consume

  test rax, rax      ; check if 0 was returned
  je finish_consumer ; if so, finish procedure

  ; consume_here = (consume_here + 8) % buffer_size
  mov rax, [consume_here] ; get value of consume_here
  add rax, 8              ; increase by 8
  xor rdx, rdx            ; zero rdx in preparation for 64-bit div
  div qword [buffer_size] ; divide rax (consume_here + 8) by the buffer's size
  mov [consume_here], rdx ; set consume_here equal to the remainder

  jmp consumer_start
finish_consumer:
  pop rdi
  ret
