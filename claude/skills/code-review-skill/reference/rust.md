# Rust Code Review Guide

> A Rust code review guide. The compiler can catch memory safety issues, but reviewers need to focus on things the compiler cannot detect — business logic, API design, performance, cancellation safety, and maintainability.

## Table of Contents

- [Ownership and Borrowing](#ownership-and-borrowing)
- [Unsafe Code Review](#unsafe-code-review-most-critical)
- [Async Code](#async-code)
- [Cancellation Safety](#cancellation-safety)
- [spawn vs await](#spawn-vs-await)
- [Error Handling](#error-handling)
- [Performance](#performance)
- [Trait Design](#trait-design)
- [Review Checklist](#rust-review-checklist)

---

## Ownership and Borrowing

### Avoid Unnecessary clone()

```rust
// ❌ clone() is "Rust's duct tape" — used to work around the borrow checker
fn bad_process(data: &Data) -> Result<()> {
    let owned = data.clone();  // Why is this clone needed?
    expensive_operation(owned)
}

// ✅ Ask during review: is this clone necessary? Can borrowing be used instead?
fn good_process(data: &Data) -> Result<()> {
    expensive_operation(data)  // Pass a reference
}

// ✅ If a clone is truly needed, add a comment explaining why
fn justified_clone(data: &Data) -> Result<()> {
    // Clone needed: data will be moved to spawned task
    let owned = data.clone();
    tokio::spawn(async move {
        process(owned).await
    });
    Ok(())
}
```

### Using Arc<Mutex<T>>

```rust
// ❌ Arc<Mutex<T>> can hide unnecessary shared state
struct BadService {
    cache: Arc<Mutex<HashMap<String, Data>>>,  // Is sharing truly needed?
}

// ✅ Consider whether sharing is needed, or whether the design can avoid it
struct GoodService {
    cache: HashMap<String, Data>,  // Single owner
}

// ✅ If concurrent access is truly needed, consider a better data structure
use dashmap::DashMap;

struct ConcurrentService {
    cache: DashMap<String, Data>,  // More fine-grained locking
}
```

### Cow (Copy-on-Write) Pattern

```rust
use std::borrow::Cow;

// ❌ Always allocates a new string
fn bad_process_name(name: &str) -> String {
    if name.is_empty() {
        "Unknown".to_string()  // Allocation
    } else {
        name.to_string()  // Unnecessary allocation
    }
}

// ✅ Use Cow to avoid unnecessary allocations
fn good_process_name(name: &str) -> Cow<'_, str> {
    if name.is_empty() {
        Cow::Borrowed("Unknown")  // Static string, no allocation
    } else {
        Cow::Borrowed(name)  // Borrow the original data
    }
}

// ✅ Only allocate when modification is needed
fn normalize_name(name: &str) -> Cow<'_, str> {
    if name.chars().any(|c| c.is_uppercase()) {
        Cow::Owned(name.to_lowercase())  // Modification needed, allocate
    } else {
        Cow::Borrowed(name)  // No modification needed, borrow
    }
}
```

---

## Unsafe Code Review (Most Critical!)

### Basic Requirements

```rust
// ❌ unsafe without safety documentation — this is a red flag
unsafe fn bad_transmute<T, U>(t: T) -> U {
    std::mem::transmute(t)
}

// ✅ Every unsafe must explain: why is it safe? what invariants must hold?
/// Transmutes `T` to `U`.
///
/// # Safety
///
/// - `T` and `U` must have the same size and alignment
/// - `T` must be a valid bit pattern for `U`
/// - The caller ensures no references to `t` exist after this call
unsafe fn documented_transmute<T, U>(t: T) -> U {
    // SAFETY: Caller guarantees size/alignment match and bit validity
    std::mem::transmute(t)
}
```

### Unsafe Block Comments

```rust
// ❌ unsafe block with no explanation
fn bad_get_unchecked(slice: &[u8], index: usize) -> u8 {
    unsafe { *slice.get_unchecked(index) }
}

// ✅ Every unsafe block must have a SAFETY comment
fn good_get_unchecked(slice: &[u8], index: usize) -> u8 {
    debug_assert!(index < slice.len(), "index out of bounds");
    // SAFETY: We verified index < slice.len() via debug_assert.
    // In release builds, callers must ensure valid index.
    unsafe { *slice.get_unchecked(index) }
}

// ✅ Wrap unsafe to provide a safe API
pub fn checked_get(slice: &[u8], index: usize) -> Option<u8> {
    if index < slice.len() {
        // SAFETY: bounds check performed above
        Some(unsafe { *slice.get_unchecked(index) })
    } else {
        None
    }
}
```

### Common unsafe Patterns

```rust
// ✅ FFI boundary
extern "C" {
    fn external_function(ptr: *const u8, len: usize) -> i32;
}

pub fn safe_wrapper(data: &[u8]) -> Result<i32, Error> {
    // SAFETY: data.as_ptr() is valid for data.len() bytes,
    // and external_function only reads from the buffer.
    let result = unsafe {
        external_function(data.as_ptr(), data.len())
    };
    if result < 0 {
        Err(Error::from_code(result))
    } else {
        Ok(result)
    }
}

// ✅ unsafe on a performance-critical path
pub fn fast_copy(src: &[u8], dst: &mut [u8]) {
    assert_eq!(src.len(), dst.len(), "slices must be equal length");
    // SAFETY: src and dst are valid slices of equal length,
    // and dst is mutable so no aliasing.
    unsafe {
        std::ptr::copy_nonoverlapping(
            src.as_ptr(),
            dst.as_mut_ptr(),
            src.len()
        );
    }
}
```

---

## Async Code

### Avoid Blocking Operations

```rust
// ❌ Blocking inside an async context — starves other tasks
async fn bad_async() {
    let data = std::fs::read_to_string("file.txt").unwrap();  // Blocking!
    std::thread::sleep(Duration::from_secs(1));  // Blocking!
}

// ✅ Use async APIs
async fn good_async() -> Result<String> {
    let data = tokio::fs::read_to_string("file.txt").await?;
    tokio::time::sleep(Duration::from_secs(1)).await;
    Ok(data)
}

// ✅ If a blocking operation is unavoidable, use spawn_blocking
async fn with_blocking() -> Result<Data> {
    let result = tokio::task::spawn_blocking(|| {
        // Blocking operations are safe here
        expensive_cpu_computation()
    }).await?;
    Ok(result)
}
```

### Mutex and .await

```rust
// ❌ Holding a std::sync::Mutex across .await — can cause deadlocks
async fn bad_lock(mutex: &std::sync::Mutex<Data>) {
    let guard = mutex.lock().unwrap();
    async_operation().await;  // Holding lock while waiting!
    process(&guard);
}

// ✅ Option 1: minimize lock scope
async fn good_lock_scoped(mutex: &std::sync::Mutex<Data>) {
    let data = {
        let guard = mutex.lock().unwrap();
        guard.clone()  // Release the lock immediately
    };
    async_operation().await;
    process(&data);
}

// ✅ Option 2: use tokio::sync::Mutex (safe to hold across .await)
async fn good_lock_tokio(mutex: &tokio::sync::Mutex<Data>) {
    let guard = mutex.lock().await;
    async_operation().await;  // OK: tokio Mutex is designed to be held across .await
    process(&guard);
}

// 💡 Selection guide:
// - std::sync::Mutex: low contention, short critical section, not held across .await
// - tokio::sync::Mutex: needs to be held across .await, high-contention scenarios
```

### Async Trait Methods

```rust
// ❌ Pitfalls of async trait methods (older versions)
#[async_trait]
trait BadRepository {
    async fn find(&self, id: i64) -> Option<Entity>;  // Implicit Box
}

// ✅ Rust 1.75+: native async trait methods
trait Repository {
    async fn find(&self, id: i64) -> Option<Entity>;

    // Return a concrete Future type to avoid allocation
    fn find_many(&self, ids: &[i64]) -> impl Future<Output = Vec<Entity>> + Send;
}

// ✅ For scenarios requiring dyn
trait DynRepository: Send + Sync {
    fn find(&self, id: i64) -> Pin<Box<dyn Future<Output = Option<Entity>> + Send + '_>>;
}
```

---

## Cancellation Safety

### What Is Cancellation Safety

```rust
// When a Future is dropped at an .await point, what state is it in?
// Cancellation-safe Future: can be safely cancelled at any await point
// Cancellation-unsafe Future: cancellation may cause data loss or inconsistent state

// ❌ Example of cancellation-unsafe code
async fn cancel_unsafe(conn: &mut Connection) -> Result<()> {
    let data = receive_data().await;  // If cancelled here...
    conn.send_ack().await;  // ...the acknowledgment will never be sent, data may be lost
    Ok(())
}

// ✅ Cancellation-safe version
async fn cancel_safe(conn: &mut Connection) -> Result<()> {
    // Use transactions or atomic operations to ensure consistency
    let transaction = conn.begin_transaction().await?;
    let data = receive_data().await;
    transaction.commit_with_ack(data).await?;  // Atomic operation
    Ok(())
}
```

### Cancellation Safety in select!

```rust
use tokio::select;

// ❌ Using a cancellation-unsafe Future in select!
async fn bad_select(stream: &mut TcpStream) {
    let mut buffer = vec![0u8; 1024];
    loop {
        select! {
            // If timeout completes first, read is cancelled
            // Partially read data may be lost!
            result = stream.read(&mut buffer) => {
                handle_data(&buffer[..result?]);
            }
            _ = tokio::time::sleep(Duration::from_secs(5)) => {
                println!("Timeout");
            }
        }
    }
}

// ✅ Use cancellation-safe APIs
async fn good_select(stream: &mut TcpStream) {
    let mut buffer = vec![0u8; 1024];
    loop {
        select! {
            // tokio::io::AsyncReadExt::read is cancellation-safe
            // On cancellation, unread data remains in the stream
            result = stream.read(&mut buffer) => {
                match result {
                    Ok(0) => break,  // EOF
                    Ok(n) => handle_data(&buffer[..n]),
                    Err(e) => return Err(e),
                }
            }
            _ = tokio::time::sleep(Duration::from_secs(5)) => {
                println!("Timeout, retrying...");
            }
        }
    }
}

// ✅ Use tokio::pin! to ensure a Future can be safely reused
async fn pinned_select() {
    let sleep = tokio::time::sleep(Duration::from_secs(10));
    tokio::pin!(sleep);

    loop {
        select! {
            _ = &mut sleep => {
                println!("Timer elapsed");
                break;
            }
            data = receive_data() => {
                process(data).await;
                // sleep continues counting down, it is not reset
            }
        }
    }
}
```

### Documenting Cancellation Safety

```rust
/// Reads a complete message from the stream.
///
/// # Cancel Safety
///
/// This method is **not** cancel safe. If cancelled while reading,
/// partial data may be lost and the stream state becomes undefined.
/// Use `read_message_cancel_safe` if cancellation is expected.
async fn read_message(stream: &mut TcpStream) -> Result<Message> {
    let len = stream.read_u32().await?;
    let mut buffer = vec![0u8; len as usize];
    stream.read_exact(&mut buffer).await?;
    Ok(Message::from_bytes(&buffer))
}

/// Reads a message with cancel safety.
///
/// # Cancel Safety
///
/// This method is cancel safe. If cancelled, any partial data
/// is preserved in the internal buffer for the next call.
async fn read_message_cancel_safe(reader: &mut BufferedReader) -> Result<Message> {
    reader.read_message_buffered().await
}
```

---

## spawn vs await

### When to Use spawn

```rust
// ❌ Unnecessary spawn — adds overhead and loses structured concurrency
async fn bad_unnecessary_spawn() {
    let handle = tokio::spawn(async {
        simple_operation().await
    });
    handle.await.unwrap();  // Why not just await directly?
}

// ✅ Directly await simple operations
async fn good_direct_await() {
    simple_operation().await;
}

// ✅ spawn for truly parallel execution
async fn good_parallel_spawn() {
    let task1 = tokio::spawn(fetch_from_service_a());
    let task2 = tokio::spawn(fetch_from_service_b());

    // Both requests run in parallel
    let (result1, result2) = tokio::try_join!(task1, task2)?;
}

// ✅ spawn for background tasks (fire-and-forget)
async fn good_background_spawn() {
    // Start a background task without waiting for it to finish
    tokio::spawn(async {
        cleanup_old_sessions().await;
        log_metrics().await;
    });

    // Continue with other work
    handle_request().await;
}
```

### The 'static Requirement for spawn

```rust
// ❌ The Future passed to spawn must be 'static
async fn bad_spawn_borrow(data: &Data) {
    tokio::spawn(async {
        process(data).await;  // Error: `data` is not 'static
    });
}

// ✅ Option 1: clone the data
async fn good_spawn_clone(data: &Data) {
    let owned = data.clone();
    tokio::spawn(async move {
        process(&owned).await;
    });
}

// ✅ Option 2: share via Arc
async fn good_spawn_arc(data: Arc<Data>) {
    let data = Arc::clone(&data);
    tokio::spawn(async move {
        process(&data).await;
    });
}

// ✅ Option 3: use scoped tasks (tokio-scoped or async-scoped)
async fn good_scoped_spawn(data: &Data) {
    // Assumes the async-scoped crate is used
    async_scoped::scope(|s| async {
        s.spawn(async {
            process(data).await;  // Can borrow
        });
    }).await;
}
```

### JoinHandle Error Handling

```rust
// ❌ Ignoring errors from spawn
async fn bad_ignore_spawn_error() {
    let handle = tokio::spawn(async {
        risky_operation().await
    });
    let _ = handle.await;  // Ignores panics and errors
}

// ✅ Properly handle JoinHandle results
async fn good_handle_spawn_error() -> Result<()> {
    let handle = tokio::spawn(async {
        risky_operation().await
    });

    match handle.await {
        Ok(Ok(result)) => {
            // Task completed successfully
            process_result(result);
            Ok(())
        }
        Ok(Err(e)) => {
            // Error inside the task
            Err(e.into())
        }
        Err(join_err) => {
            // Task panicked or was cancelled
            if join_err.is_panic() {
                error!("Task panicked: {:?}", join_err);
            }
            Err(anyhow!("Task failed: {}", join_err))
        }
    }
}
```

### Structured Concurrency vs spawn

```rust
// ✅ Prefer join! (structured concurrency)
async fn structured_concurrency() -> Result<(A, B, C)> {
    // All tasks are within the same scope
    // If any one fails, the others are cancelled
    tokio::try_join!(
        fetch_a(),
        fetch_b(),
        fetch_c()
    )
}

// ✅ When using spawn, consider task lifetimes
struct TaskManager {
    handles: Vec<JoinHandle<()>>,
}

impl TaskManager {
    async fn shutdown(self) {
        // Graceful shutdown: wait for all tasks to complete
        for handle in self.handles {
            if let Err(e) = handle.await {
                error!("Task failed during shutdown: {}", e);
            }
        }
    }

    async fn abort_all(self) {
        // Forced shutdown: cancel all tasks
        for handle in self.handles {
            handle.abort();
        }
    }
}
```

---

## Error Handling

### Library vs Application Error Types

```rust
// ❌ Using anyhow in library code — callers cannot match on the error
pub fn parse_config(s: &str) -> anyhow::Result<Config> { ... }

// ✅ Libraries use thiserror; applications use anyhow
#[derive(Debug, thiserror::Error)]
pub enum ConfigError {
    #[error("invalid syntax at line {line}: {message}")]
    Syntax { line: usize, message: String },
    #[error("missing required field: {0}")]
    MissingField(String),
    #[error(transparent)]
    Io(#[from] std::io::Error),
}

pub fn parse_config(s: &str) -> Result<Config, ConfigError> { ... }
```

### Preserving Error Context

```rust
// ❌ Swallowing error context
fn bad_error() -> Result<()> {
    operation().map_err(|_| anyhow!("failed"))?;  // Original error is lost
    Ok(())
}

// ✅ Use context to preserve the error chain
fn good_error() -> Result<()> {
    operation().context("failed to perform operation")?;
    Ok(())
}

// ✅ Use with_context for lazy evaluation
fn good_error_lazy() -> Result<()> {
    operation()
        .with_context(|| format!("failed to process file: {}", filename))?;
    Ok(())
}
```

### Error Type Design

```rust
// ✅ Use #[source] to preserve the error chain
#[derive(Debug, thiserror::Error)]
pub enum ServiceError {
    #[error("database error")]
    Database(#[source] sqlx::Error),

    #[error("network error: {message}")]
    Network {
        message: String,
        #[source]
        source: reqwest::Error,
    },

    #[error("validation failed: {0}")]
    Validation(String),
}

// ✅ Implement From for common conversions
impl From<sqlx::Error> for ServiceError {
    fn from(err: sqlx::Error) -> Self {
        ServiceError::Database(err)
    }
}
```

---

## Performance

### Avoid Unnecessary collect()

```rust
// ❌ Unnecessary collect — intermediate allocation
fn bad_sum(items: &[i32]) -> i32 {
    items.iter()
        .filter(|x| **x > 0)
        .collect::<Vec<_>>()  // Unnecessary!
        .iter()
        .sum()
}

// ✅ Lazy iteration
fn good_sum(items: &[i32]) -> i32 {
    items.iter().filter(|x| **x > 0).copied().sum()
}
```

### String Concatenation

```rust
// ❌ String concatenation re-allocates on every iteration in a loop
fn bad_concat(items: &[&str]) -> String {
    let mut s = String::new();
    for item in items {
        s = s + item;  // Re-allocates every time!
    }
    s
}

// ✅ Pre-allocate or use join
fn good_concat(items: &[&str]) -> String {
    items.join("")
}

// ✅ Pre-allocate with with_capacity
fn good_concat_capacity(items: &[&str]) -> String {
    let total_len: usize = items.iter().map(|s| s.len()).sum();
    let mut result = String::with_capacity(total_len);
    for item in items {
        result.push_str(item);
    }
    result
}

// ✅ Use the write! macro
use std::fmt::Write;

fn good_concat_write(items: &[&str]) -> String {
    let mut result = String::new();
    for item in items {
        write!(result, "{}", item).unwrap();
    }
    result
}
```

### Avoid Unnecessary Allocations

```rust
// ❌ Unnecessary Vec allocation
fn bad_check_any(items: &[Item]) -> bool {
    let filtered: Vec<_> = items.iter()
        .filter(|i| i.is_valid())
        .collect();
    !filtered.is_empty()
}

// ✅ Use iterator methods
fn good_check_any(items: &[Item]) -> bool {
    items.iter().any(|i| i.is_valid())
}

// ❌ String::from for a static string
fn bad_static() -> String {
    String::from("error message")  // Runtime allocation
}

// ✅ Return &'static str
fn good_static() -> &'static str {
    "error message"  // No allocation
}
```

---

## Trait Design

### Avoid Over-abstraction

```rust
// ❌ Over-abstraction — this isn't Java, not everything needs an Interface
trait Processor { fn process(&self); }
trait Handler { fn handle(&self); }
trait Manager { fn manage(&self); }  // Too many traits

// ✅ Only create traits when polymorphism is needed
// Concrete types are usually simpler and faster
struct DataProcessor {
    config: Config,
}

impl DataProcessor {
    fn process(&self, data: &Data) -> Result<Output> {
        // Direct implementation
    }
}
```

### Trait Objects vs Generics

```rust
// ❌ Unnecessary trait objects (dynamic dispatch)
fn bad_process(handler: &dyn Handler) {
    handler.handle();  // vtable call
}

// ✅ Use generics (static dispatch, can be inlined)
fn good_process<H: Handler>(handler: &H) {
    handler.handle();  // May be inlined
}

// ✅ Trait objects are appropriate for heterogeneous collections
fn store_handlers(handlers: Vec<Box<dyn Handler>>) {
    // Need to store different types of handlers
}

// ✅ Use impl Trait return types
fn create_handler() -> impl Handler {
    ConcreteHandler::new()
}
```

---

## Rust Review Checklist

### Issues the Compiler Cannot Catch

**Business Logic Correctness**
- [ ] Boundary conditions are handled correctly
- [ ] State machine transitions are complete
- [ ] Race conditions in concurrent scenarios

**API Design**
- [ ] Public API is hard to misuse
- [ ] Type signatures clearly express intent
- [ ] Error type granularity is appropriate

### Ownership and Borrowing

- [ ] clone() is intentional and the reason is documented
- [ ] Does Arc<Mutex<T>> truly need shared state?
- [ ] RefCell usage is justified
- [ ] Lifetimes are not overly complex
- [ ] Consider using Cow to avoid unnecessary allocations

### Unsafe Code (Most Important)

- [ ] Every unsafe block has a SAFETY comment
- [ ] unsafe fn has a # Safety documentation section
- [ ] Explains why it is safe, not just what it does
- [ ] Lists the invariants that must be maintained
- [ ] unsafe scope is as small as possible
- [ ] Considered whether a safe alternative exists

### Async/Concurrency

- [ ] No blocking operations inside async (std::fs, thread::sleep)
- [ ] No std::sync locks held across .await
- [ ] Tasks passed to spawn satisfy 'static
- [ ] Lock acquisition order is consistent
- [ ] Channel buffer sizes are reasonable

### Cancellation Safety

- [ ] Futures used in select! are cancellation-safe
- [ ] Cancellation safety of async functions is documented
- [ ] Cancellation does not cause data loss or inconsistent state
- [ ] tokio::pin! used correctly for Futures that need to be reused

### spawn vs await

- [ ] spawn only used for scenarios that truly need parallelism
- [ ] Simple operations are directly awaited, not spawned
- [ ] JoinHandle results are correctly handled
- [ ] Task lifetimes and shutdown strategies are considered
- [ ] Prefer join!/try_join! for structured concurrency

### Error Handling

- [ ] Libraries: thiserror for structured errors
- [ ] Applications: anyhow + context
- [ ] No unwrap/expect in production code
- [ ] Error messages are helpful for debugging
- [ ] must_use return values are handled
- [ ] #[source] used to preserve the error chain

### Performance

- [ ] Avoid unnecessary collect()
- [ ] Pass large data by reference
- [ ] Strings use with_capacity or write!
- [ ] impl Trait vs Box<dyn Trait> choice is appropriate
- [ ] Avoid allocations on hot paths
- [ ] Consider using Cow to reduce cloning

### Code Quality

- [ ] cargo clippy zero warnings
- [ ] cargo fmt formatted
- [ ] Documentation comments are complete
- [ ] Tests cover boundary conditions
- [ ] Public APIs have documentation examples
