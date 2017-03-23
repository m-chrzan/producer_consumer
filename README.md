# Producer and Consumer

An x86\_64 assembly solution to the classic producer and consumer problem.

## Semaphore

`dijkstra_semaphore.asm` provides an implementation of a spin-locking semaphore
with Dijsktra's original semantics. This means that processes waiting on the
semaphore wait busily, and that starvation-freedom is not guaranteed.

## Producer and Consumer

`producer_consumer.asm` exports three functions:

* `int init(size_t size)`: initializes a cyclic buffer holding up to `size`
  portions for the producer and consumer to use. `size` needs to be greater than
  0 and less than 2^31.

* `void producer()`: procedure to be executed by the producer process.

* `void consumer()`: procedure to be executed by the consumer process.

The following functions need to be provided at link time:

* `int produce(int64_t *portion)`: function called by the producer to produce a
  portion. Should return 1 if there are more portions to be produced, and 0 if
  production is finished.

* `int consume(int64_t portion)`: function called by the consumer that has
  gotten a portion from the buffer. Should return 1 if the consumer is to keep
  consuming, and 0 if consumption is finished.

* `void *malloc(size_t size)`: function that allocates memory for `size` bytes
  and returns a pointer to that memory.
