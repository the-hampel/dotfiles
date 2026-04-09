# Common Bugs Checklist

Language-specific bugs and issues to watch for during code review.

## Universal Issues

### Logic Errors
- [ ] Off-by-one errors in loops and array access
- [ ] Incorrect boolean logic (De Morgan's law violations)
- [ ] Missing null/undefined checks
- [ ] Race conditions in concurrent code
- [ ] Incorrect comparison operators (== vs ===, = vs ==)
- [ ] Integer overflow/underflow
- [ ] Floating point comparison issues

### Resource Management
- [ ] Memory leaks (unclosed connections, listeners)
- [ ] File handles not closed
- [ ] Database connections not released
- [ ] Event listeners not removed
- [ ] Timers/intervals not cleared

### Error Handling
- [ ] Swallowed exceptions (empty catch blocks)
- [ ] Generic exception handling hiding specific errors
- [ ] Missing error propagation
- [ ] Incorrect error types thrown
- [ ] Missing finally/cleanup blocks

## TypeScript/JavaScript

### Type Issues
```typescript
// ❌ Using any defeats type safety
function process(data: any) { return data.value; }

// ✅ Use proper types
interface Data { value: string; }
function process(data: Data) { return data.value; }
```

### Async/Await Pitfalls
```typescript
// ❌ Missing await
async function fetch() {
  const data = fetchData();  // Missing await!
  return data.json();
}

// ❌ Unhandled promise rejection
async function risky() {
  const result = await fetchData();  // No try-catch
  return result;
}

// ✅ Proper error handling
async function safe() {
  try {
    const result = await fetchData();
    return result;
  } catch (error) {
    console.error('Fetch failed:', error);
    throw error;
  }
}
```

### React Specific

#### Hooks Rules Violations
```tsx
// ❌ Conditionally calling Hooks — violates Rules of Hooks
function BadComponent({ show }) {
  if (show) {
    const [value, setValue] = useState(0);  // Error!
  }
  return <div>...</div>;
}

// ✅ Hooks must be called unconditionally at the top level
function GoodComponent({ show }) {
  const [value, setValue] = useState(0);
  if (!show) return null;
  return <div>{value}</div>;
}

// ❌ Calling Hooks inside a loop
function BadLoop({ items }) {
  items.forEach(item => {
    const [selected, setSelected] = useState(false);  // Error!
  });
}

// ✅ Lift state up or use a different data structure
function GoodLoop({ items }) {
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  return items.map(item => (
    <Item key={item.id} selected={selectedIds.has(item.id)} />
  ));
}
```

#### Common useEffect Mistakes
```tsx
// ❌ Incomplete dependency array — stale closure
function StaleClosureExample({ userId, onSuccess }) {
  const [data, setData] = useState(null);
  useEffect(() => {
    fetchData(userId).then(result => {
      setData(result);
      onSuccess(result);  // onSuccess may be stale!
    });
  }, [userId]);  // missing onSuccess dependency
}

// ✅ Complete dependency array
useEffect(() => {
  fetchData(userId).then(result => {
    setData(result);
    onSuccess(result);
  });
}, [userId, onSuccess]);

// ❌ Infinite loop — updating a dependency inside the effect
function InfiniteLoop() {
  const [count, setCount] = useState(0);
  useEffect(() => {
    setCount(count + 1);  // triggers re-render, which triggers the effect again
  }, [count]);  // infinite loop!
}

// ❌ Missing cleanup function — memory leak
function MemoryLeak({ userId }) {
  const [user, setUser] = useState(null);
  useEffect(() => {
    fetchUser(userId).then(setUser);  // setUser still called after component unmounts
  }, [userId]);
}

// ✅ Correct cleanup
function NoLeak({ userId }) {
  const [user, setUser] = useState(null);
  useEffect(() => {
    let cancelled = false;
    fetchUser(userId).then(data => {
      if (!cancelled) setUser(data);
    });
    return () => { cancelled = true; };
  }, [userId]);
}

// ❌ useEffect used for derived state (anti-pattern)
function BadDerived({ items }) {
  const [total, setTotal] = useState(0);
  useEffect(() => {
    setTotal(items.reduce((a, b) => a + b.price, 0));
  }, [items]);  // unnecessary effect + extra render
}

// ✅ Calculate directly or use useMemo
function GoodDerived({ items }) {
  const total = useMemo(
    () => items.reduce((a, b) => a + b.price, 0),
    [items]
  );
}

// ❌ useEffect used for event responses
function BadEvent() {
  const [query, setQuery] = useState('');
  useEffect(() => {
    if (query) logSearch(query);  // should be in the event handler
  }, [query]);
}

// ✅ Side effects belong in event handlers
function GoodEvent() {
  const handleSearch = (q: string) => {
    setQuery(q);
    logSearch(q);
  };
}
```

#### useMemo / useCallback Misuse
```tsx
// ❌ Over-optimization — constants don't need memo
function OverOptimized() {
  const config = useMemo(() => ({ api: '/v1' }), []);  // pointless
  const noop = useCallback(() => {}, []);  // pointless
}

// ❌ useMemo with empty deps (can hide bugs)
function EmptyDeps({ user }) {
  const greeting = useMemo(() => `Hello ${user.name}`, []);
  // greeting won't update when user changes!
}

// ❌ useCallback with a dependency that always changes
function UselessCallback({ data }) {
  const process = useCallback(() => {
    return data.map(transform);
  }, [data]);  // if data is a new reference every time, this is completely useless
}

// ❌ useMemo/useCallback without pairing with React.memo
function Parent() {
  const data = useMemo(() => compute(), []);
  const handler = useCallback(() => {}, []);
  return <Child data={data} onClick={handler} />;
  // Child doesn't use React.memo — these optimizations are pointless
}

// ✅ Correct optimization combination
const MemoChild = React.memo(function Child({ data, onClick }) {
  return <button onClick={onClick}>{data}</button>;
});

function Parent() {
  const data = useMemo(() => expensiveCompute(), [dep]);
  const handler = useCallback(() => {}, []);
  return <MemoChild data={data} onClick={handler} />;
}
```

#### Component Design Issues
```tsx
// ❌ Defining a component inside another component
function Parent() {
  // A new Child function is created on every render, causing a full remount
  const Child = () => <div>child</div>;
  return <Child />;
}

// ✅ Define components outside
const Child = () => <div>child</div>;
function Parent() {
  return <Child />;
}

// ❌ Props are always new references — defeats memo
function BadProps() {
  return (
    <MemoComponent
      style={{ color: 'red' }}      // new object on every render
      onClick={() => handle()}       // new function on every render
      items={data.filter(x => x)}    // new array on every render
    />
  );
}

// ❌ Mutating props directly
function MutateProps({ user }) {
  user.name = 'Changed';  // never do this!
  return <div>{user.name}</div>;
}
```

#### Server Component Mistakes (React 19+)
```tsx
// ❌ Using client-side APIs in a Server Component
// app/page.tsx (Server Component by default)
export default function Page() {
  const [count, setCount] = useState(0);  // Error!
  useEffect(() => {}, []);  // Error!
  return <button onClick={() => {}}>Click</button>;  // Error!
}

// ✅ Move interactive logic to a Client Component
// app/counter.tsx
'use client';
export function Counter() {
  const [count, setCount] = useState(0);
  return <button onClick={() => setCount(c => c + 1)}>{count}</button>;
}

// app/page.tsx
import { Counter } from './counter';
export default async function Page() {
  const data = await fetchData();  // Server Components can await directly
  return <Counter initialCount={data.count} />;
}

// ❌ Marking a parent component 'use client' turns the entire subtree into client components
// layout.tsx
'use client';  // bad idea! all child components become client components
export default function Layout({ children }) { ... }
```

#### Common Testing Mistakes
```tsx
// ❌ Querying via container
const { container } = render(<Component />);
const button = container.querySelector('button');  // not recommended

// ✅ Use screen with semantic queries
render(<Component />);
const button = screen.getByRole('button', { name: /submit/i });

// ❌ Using fireEvent
fireEvent.click(button);

// ✅ Using userEvent
await userEvent.click(button);

// ❌ Testing implementation details
expect(component.state.isOpen).toBe(true);

// ✅ Testing behavior
expect(screen.getByRole('dialog')).toBeVisible();

// ❌ Awaiting a synchronous query
await screen.getByText('Hello');  // getBy is synchronous

// ✅ Use findBy for async
await screen.findByText('Hello');  // findBy waits
```

### React Common Mistakes Checklist
- [ ] Hooks not called at the top level (inside conditions/loops)
- [ ] Incomplete useEffect dependency array
- [ ] useEffect missing cleanup function
- [ ] useEffect used for derived state calculation
- [ ] useMemo/useCallback overused
- [ ] useMemo/useCallback not paired with React.memo
- [ ] Child components defined inside parent components
- [ ] Props are new object/function references (when passed to memo components)
- [ ] Props mutated directly
- [ ] Lists missing key or using index as key
- [ ] Server Component using client-side APIs
- [ ] 'use client' placed on a parent component, turning the entire tree into client components
- [ ] Tests querying via container instead of screen
- [ ] Tests verifying implementation details instead of behavior

### React 19 Actions & Forms Mistakes

```tsx
// === useActionState Mistakes ===

// ❌ Calling setState directly inside an Action instead of returning state
const [state, action] = useActionState(async (prev, formData) => {
  setSomeState(newValue);  // wrong! should return new state
}, initialState);

// ✅ Return new state
const [state, action] = useActionState(async (prev, formData) => {
  const result = await submitForm(formData);
  return { ...prev, data: result };  // return new state
}, initialState);

// ❌ Forgetting to handle isPending
const [state, action] = useActionState(submitAction, null);
return <button>Submit</button>;  // user can click multiple times

// ✅ Use isPending to disable the button
const [state, action, isPending] = useActionState(submitAction, null);
return <button disabled={isPending}>Submit</button>;

// === useFormStatus Mistakes ===

// ❌ Calling useFormStatus at the same level as the form
function Form() {
  const { pending } = useFormStatus();  // always undefined!
  return <form><button disabled={pending}>Submit</button></form>;
}

// ✅ Call it inside a child component
function SubmitButton() {
  const { pending } = useFormStatus();
  return <button disabled={pending}>Submit</button>;
}
function Form() {
  return <form><SubmitButton /></form>;
}

// === useOptimistic Mistakes ===

// ❌ Using it for critical business operations
function PaymentButton() {
  const [optimisticPaid, setPaid] = useOptimistic(false);
  const handlePay = async () => {
    setPaid(true);  // dangerous: shows "paid" but the operation may fail
    await processPayment();
  };
}

// ❌ No handling of UI state after rollback
const [optimisticLikes, addLike] = useOptimistic(likes);
// UI rolls back on failure, but user may be confused why the like disappeared

// ✅ Provide failure feedback
const handleLike = async () => {
  addLike(1);
  try {
    await likePost();
  } catch {
    toast.error('Failed to like, please try again');  // notify the user
  }
};
```

### React 19 Forms Checklist
- [ ] useActionState returns new state instead of calling setState
- [ ] useActionState correctly uses isPending to disable submission
- [ ] useFormStatus called inside a child component of the form
- [ ] useOptimistic not used for critical operations (payment, deletion, etc.)
- [ ] useOptimistic provides user feedback on failure
- [ ] Server Actions correctly marked with 'use server'

### Suspense & Streaming Mistakes

```tsx
// === Suspense Boundary Mistakes ===

// ❌ One Suspense for the entire page — slow content blocks fast content
function BadPage() {
  return (
    <Suspense fallback={<FullPageLoader />}>
      <FastHeader />      {/* fast */}
      <SlowMainContent /> {/* slow — blocks the entire page */}
      <FastFooter />      {/* fast */}
    </Suspense>
  );
}

// ✅ Independent boundaries, each non-blocking
function GoodPage() {
  return (
    <>
      <FastHeader />
      <Suspense fallback={<ContentSkeleton />}>
        <SlowMainContent />
      </Suspense>
      <FastFooter />
    </>
  );
}

// ❌ No Error Boundary
function NoErrorHandling() {
  return (
    <Suspense fallback={<Loading />}>
      <DataFetcher />  {/* uncaught error causes a blank screen */}
    </Suspense>
  );
}

// ✅ Error Boundary + Suspense
function WithErrorHandling() {
  return (
    <ErrorBoundary fallback={<ErrorFallback />}>
      <Suspense fallback={<Loading />}>
        <DataFetcher />
      </Suspense>
    </ErrorBoundary>
  );
}

// === use() Hook Mistakes ===

// ❌ Creating a Promise inside the component (new Promise on every render)
function BadUse() {
  const data = use(fetchData());  // creates a new Promise on every render!
  return <div>{data}</div>;
}

// ✅ Create it in the parent component and pass via props
function Parent() {
  const dataPromise = useMemo(() => fetchData(), []);
  return <Child dataPromise={dataPromise} />;
}
function Child({ dataPromise }) {
  const data = use(dataPromise);
  return <div>{data}</div>;
}

// === Next.js Streaming Mistakes ===

// ❌ Awaiting slow data in layout.tsx — blocks all child pages
// app/layout.tsx
export default async function Layout({ children }) {
  const config = await fetchSlowConfig();  // blocks the entire application!
  return <ConfigProvider value={config}>{children}</ConfigProvider>;
}

// ✅ Move slow data to the page level or use Suspense
// app/layout.tsx
export default function Layout({ children }) {
  return (
    <Suspense fallback={<ConfigSkeleton />}>
      <ConfigProvider>{children}</ConfigProvider>
    </Suspense>
  );
}
```

### Suspense Checklist
- [ ] Slow content has its own independent Suspense boundary
- [ ] Each Suspense has a corresponding Error Boundary
- [ ] fallback is a meaningful skeleton screen (not just a simple spinner)
- [ ] Promises used with use() are not created during render
- [ ] Slow data is not awaited in layout
- [ ] Nesting depth does not exceed 3 levels

### TanStack Query Mistakes

```tsx
// === Query Configuration Mistakes ===

// ❌ queryKey does not include query parameters
function BadQuery({ userId, filters }) {
  const { data } = useQuery({
    queryKey: ['users'],  // missing userId and filters!
    queryFn: () => fetchUsers(userId, filters),
  });
  // data won't update when userId or filters change
}

// ✅ queryKey includes all parameters that affect the data
function GoodQuery({ userId, filters }) {
  const { data } = useQuery({
    queryKey: ['users', userId, filters],
    queryFn: () => fetchUsers(userId, filters),
  });
}

// ❌ staleTime: 0 causes excessive refetching
const { data } = useQuery({
  queryKey: ['data'],
  queryFn: fetchData,
  // default staleTime: 0 — refetches on every component mount/window focus
});

// ✅ Set a reasonable staleTime
const { data } = useQuery({
  queryKey: ['data'],
  queryFn: fetchData,
  staleTime: 5 * 60 * 1000,  // won't auto-refetch within 5 minutes
});

// === useSuspenseQuery Mistakes ===

// ❌ useSuspenseQuery + enabled (not supported)
const { data } = useSuspenseQuery({
  queryKey: ['user', userId],
  queryFn: () => fetchUser(userId),
  enabled: !!userId,  // wrong! useSuspenseQuery does not support enabled
});

// ✅ Implement with conditional rendering
function UserQuery({ userId }) {
  const { data } = useSuspenseQuery({
    queryKey: ['user', userId],
    queryFn: () => fetchUser(userId),
  });
  return <UserProfile user={data} />;
}

function Parent({ userId }) {
  if (!userId) return <SelectUser />;
  return (
    <Suspense fallback={<UserSkeleton />}>
      <UserQuery userId={userId} />
    </Suspense>
  );
}

// === Mutation Mistakes ===

// ❌ Not invalidating queries after a successful mutation
const mutation = useMutation({
  mutationFn: updateUser,
  // forgot to invalidate — UI shows stale data
});

// ✅ Invalidate related queries on success
const mutation = useMutation({
  mutationFn: updateUser,
  onSuccess: () => {
    queryClient.invalidateQueries({ queryKey: ['users'] });
  },
});

// ❌ Optimistic update without handling rollback
const mutation = useMutation({
  mutationFn: updateTodo,
  onMutate: async (newTodo) => {
    queryClient.setQueryData(['todos'], (old) => [...old, newTodo]);
    // old data not saved — cannot roll back on failure!
  },
});

// ✅ Complete optimistic update
const mutation = useMutation({
  mutationFn: updateTodo,
  onMutate: async (newTodo) => {
    await queryClient.cancelQueries({ queryKey: ['todos'] });
    const previous = queryClient.getQueryData(['todos']);
    queryClient.setQueryData(['todos'], (old) => [...old, newTodo]);
    return { previous };
  },
  onError: (err, newTodo, context) => {
    queryClient.setQueryData(['todos'], context.previous);
  },
  onSettled: () => {
    queryClient.invalidateQueries({ queryKey: ['todos'] });
  },
});

// === v5 Migration Mistakes ===

// ❌ Using deprecated API
const { data, isLoading } = useQuery(['key'], fetchFn);  // v4 syntax

// ✅ v5 single object argument
const { data, isPending } = useQuery({
  queryKey: ['key'],
  queryFn: fetchFn,
});

// ❌ Confusing isPending and isLoading
if (isLoading) return <Spinner />;
// in v5: isLoading = isPending && isFetching

// ✅ Choose based on intent
if (isPending) return <Spinner />;  // no cached data
// or
if (isFetching) return <Refreshing />;  // background refresh in progress
```

### TanStack Query Checklist
- [ ] queryKey includes all parameters that affect the data
- [ ] A reasonable staleTime is set (not the default 0)
- [ ] useSuspenseQuery does not use enabled
- [ ] Related queries are invalidated after a successful mutation
- [ ] Optimistic updates have complete rollback logic
- [ ] v5 uses the single object argument syntax
- [ ] Understands isPending vs isLoading vs isFetching

### TypeScript/JavaScript Common Mistakes
- [ ] `==` instead of `===`
- [ ] Modifying array/object during iteration
- [ ] `this` context lost in callbacks
- [ ] Missing `key` prop in lists
- [ ] Closure capturing loop variable
- [ ] parseInt without radix parameter

## Vue 3

### Reactivity Loss
```vue
<!-- ❌ Destructuring reactive loses reactivity -->
<script setup>
const state = reactive({ count: 0 })
const { count } = state  // count is not reactive!
</script>

<!-- ✅ Use toRefs -->
<script setup>
const state = reactive({ count: 0 })
const { count } = toRefs(state)  // count.value is reactive
</script>
```

### Passing Props Reactivity
```vue
<!-- ❌ Passing a props value to a composable loses reactivity -->
<script setup>
const props = defineProps<{ id: string }>()
const { data } = useFetch(props.id)  // won't refetch when id changes!
</script>

<!-- ✅ Use toRef or a getter -->
<script setup>
const props = defineProps<{ id: string }>()
const { data } = useFetch(() => props.id)  // getter preserves reactivity
// or
const { data } = useFetch(toRef(props, 'id'))
</script>
```

### Watch Cleanup
```vue
<!-- ❌ Async watch without cleanup, causing race conditions -->
<script setup>
watch(id, async (newId) => {
  const data = await fetchData(newId)
  result.value = data  // old request may overwrite the newer result!
})
</script>

<!-- ✅ Use onCleanup to cancel stale requests -->
<script setup>
watch(id, async (newId, _, onCleanup) => {
  const controller = new AbortController()
  onCleanup(() => controller.abort())

  const data = await fetchData(newId, controller.signal)
  result.value = data
})
</script>
```

### Computed Side Effects
```vue
<!-- ❌ Modifying other state inside computed -->
<script setup>
const total = computed(() => {
  sideEffect.value++  // side effect! executes on every access
  return items.value.reduce((a, b) => a + b, 0)
})
</script>

<!-- ✅ computed should only do pure calculation -->
<script setup>
const total = computed(() => {
  return items.value.reduce((a, b) => a + b, 0)
})
// Put side effects in watch
watch(total, () => { sideEffect.value++ })
</script>
```

### Common Template Mistakes
```vue
<!-- ❌ Using v-if and v-for on the same element (v-if has higher priority) -->
<template>
  <div v-for="item in items" v-if="item.visible" :key="item.id">
    {{ item.name }}
  </div>
</template>

<!-- ✅ Use computed or wrap with template -->
<template>
  <template v-for="item in items" :key="item.id">
    <div v-if="item.visible">{{ item.name }}</div>
  </template>
</template>
```

### Common Mistakes
- [ ] Destructuring a reactive object loses reactivity
- [ ] Props passed to composables without maintaining reactivity
- [ ] Async watch callback has no cleanup function
- [ ] Side effects inside computed
- [ ] Using index as key in v-for (when the list can be reordered)
- [ ] v-if and v-for on the same element
- [ ] defineProps without TypeScript type declarations
- [ ] Object default values in withDefaults not using factory functions
- [ ] Mutating props directly (instead of emitting)
- [ ] watchEffect dependencies unclear, causing excessive triggering

## Python

### Mutable Default Arguments
```python
# ❌ Bug: List shared across all calls
def add_item(item, items=[]):
    items.append(item)
    return items

# ✅ Correct
def add_item(item, items=None):
    if items is None:
        items = []
    items.append(item)
    return items
```

### Exception Handling
```python
# ❌ Catching everything, including KeyboardInterrupt
try:
    risky_operation()
except:
    pass

# ✅ Catch specific exceptions
try:
    risky_operation()
except ValueError as e:
    logger.error(f"Invalid value: {e}")
    raise
```

### Class Attributes
```python
# ❌ Shared mutable class attribute
class User:
    permissions = []  # Shared across all instances!

# ✅ Initialize in __init__
class User:
    def __init__(self):
        self.permissions = []
```

### Common Mistakes
- [ ] Using `is` instead of `==` for value comparison
- [ ] Forgetting `self` parameter in methods
- [ ] Modifying list while iterating
- [ ] String concatenation in loops (use join)
- [ ] Not closing files (use `with` statement)

## Rust

### Ownership and Borrowing

```rust
// ❌ Use after move
let s = String::from("hello");
let s2 = s;
println!("{}", s);  // Error: s was moved

// ✅ Clone if needed (but consider if clone is necessary)
let s = String::from("hello");
let s2 = s.clone();
println!("{}", s);  // OK

// ❌ Using clone() to bypass the borrow checker (anti-pattern)
fn process(data: &Data) {
    let owned = data.clone();  // unnecessary clone
    do_something(owned);
}

// ✅ Use borrowing correctly
fn process(data: &Data) {
    do_something(data);  // pass a reference
}

// ❌ Storing borrows in a struct (usually a bad idea)
struct Parser<'a> {
    input: &'a str,  // complicates lifetimes
    position: usize,
}

// ✅ Use owned data
struct Parser {
    input: String,  // owns the data, simplifies lifetimes
    position: usize,
}

// ❌ Modifying a collection while iterating
let mut vec = vec![1, 2, 3];
for item in &vec {
    vec.push(*item);  // Error: cannot borrow as mutable
}

// ✅ Collect into a new collection
let vec = vec![1, 2, 3];
let new_vec: Vec<_> = vec.iter().map(|x| x * 2).collect();
```

### Unsafe Code Review

```rust
// ❌ unsafe block without a safety comment
unsafe {
    ptr::write(dest, value);
}

// ✅ Must have a SAFETY comment explaining the invariants
// SAFETY: the dest pointer is obtained from Vec::as_mut_ptr(), which guarantees:
// 1. The pointer is valid and aligned
// 2. The target memory is not borrowed by any other reference
// 3. The write will not exceed the allocated capacity
unsafe {
    ptr::write(dest, value);
}

// ❌ unsafe fn without a # Safety doc comment
pub unsafe fn from_raw_parts(ptr: *mut T, len: usize) -> Self { ... }

// ✅ Must document the safety contract
/// Creates a new instance from raw parts.
///
/// # Safety
///
/// - `ptr` must have been allocated via `GlobalAlloc`
/// - `len` must be less than or equal to the allocated capacity
/// - The caller must ensure no other references to the memory exist
pub unsafe fn from_raw_parts(ptr: *mut T, len: usize) -> Self { ... }

// ❌ Cross-module unsafe invariants
mod a {
    pub fn set_flag() { FLAG = true; }  // safe code affects unsafe behavior
}
mod b {
    pub unsafe fn do_thing() {
        if FLAG { /* assumes FLAG means something */ }
    }
}

// ✅ Encapsulate unsafe boundaries within a single module
mod safe_wrapper {
    // all unsafe logic lives within this module
    // expose a safe API to the outside
}
```

### Async/Concurrency

```rust
// ❌ Blocking inside an async context
async fn bad_fetch(url: &str) -> Result<String> {
    let resp = reqwest::blocking::get(url)?;  // blocks the entire runtime!
    Ok(resp.text()?)
}

// ✅ Use the async version
async fn good_fetch(url: &str) -> Result<String> {
    let resp = reqwest::get(url).await?;
    Ok(resp.text().await?)
}

// ❌ Holding a Mutex across an .await
async fn bad_lock(mutex: &Mutex<Data>) {
    let guard = mutex.lock().unwrap();
    some_async_op().await;  // lock held across an await point!
    drop(guard);
}

// ✅ Shorten the lock-hold duration
async fn good_lock(mutex: &Mutex<Data>) {
    let data = {
        let guard = mutex.lock().unwrap();
        guard.clone()  // release the lock immediately after getting the data
    };
    some_async_op().await;
    // work with data
}

// ❌ Using std::sync::Mutex inside an async function
async fn bad_async_mutex(mutex: &std::sync::Mutex<Data>) {
    let _guard = mutex.lock().unwrap();  // potential deadlock
    tokio::time::sleep(Duration::from_secs(1)).await;
}

// ✅ Use tokio::sync::Mutex (if holding across .await is necessary)
async fn good_async_mutex(mutex: &tokio::sync::Mutex<Data>) {
    let _guard = mutex.lock().await;
    tokio::time::sleep(Duration::from_secs(1)).await;
}

// ❌ Forgetting that Futures are lazy
fn bad_spawn() {
    let future = async_operation();  // not executed!
    // future is dropped, nothing happens
}

// ✅ Must await or spawn
async fn good_spawn() {
    async_operation().await;  // executes
    // or
    tokio::spawn(async_operation());  // executes in the background
}

// ❌ Spawned task missing 'static bound
async fn bad_spawn_lifetime(data: &str) {
    tokio::spawn(async {
        println!("{}", data);  // Error: data is not 'static
    });
}

// ✅ Use move or Arc
async fn good_spawn_lifetime(data: String) {
    tokio::spawn(async move {
        println!("{}", data);  // OK: owns the data
    });
}
```

### Error Handling

```rust
// ❌ Using unwrap/expect in production code
fn bad_parse(input: &str) -> i32 {
    input.parse().unwrap()  // panic!
}

// ✅ Propagate errors correctly
fn good_parse(input: &str) -> Result<i32, ParseIntError> {
    input.parse()
}

// ❌ Swallowing error information
fn bad_error_handling() -> Result<()> {
    match operation() {
        Ok(v) => Ok(v),
        Err(_) => Err(anyhow!("operation failed"))  // original error is lost
    }
}

// ✅ Add context using context()
fn good_error_handling() -> Result<()> {
    operation().context("failed to perform operation")?;
    Ok(())
}

// ❌ Library code using anyhow (should use thiserror)
// lib.rs
pub fn parse_config(path: &str) -> anyhow::Result<Config> {
    // callers cannot distinguish between error types
}

// ✅ Library code uses thiserror to define error types
#[derive(Debug, thiserror::Error)]
pub enum ConfigError {
    #[error("failed to read config file: {0}")]
    Io(#[from] std::io::Error),
    #[error("invalid config format: {0}")]
    Parse(#[from] serde_json::Error),
}

pub fn parse_config(path: &str) -> Result<Config, ConfigError> {
    // callers can match on different error variants
}

// ❌ Ignoring a must_use return value
fn bad_ignore_result() {
    some_fallible_operation();  // warning: unused Result
}

// ✅ Handle explicitly or mark as intentionally ignored
fn good_handle_result() {
    let _ = some_fallible_operation();  // explicitly ignored
    // or
    some_fallible_operation().ok();  // convert to Option
}
```

### Performance Pitfalls

```rust
// ❌ Unnecessary collect
fn bad_process(items: &[i32]) -> i32 {
    items.iter()
        .filter(|x| **x > 0)
        .collect::<Vec<_>>()  // unnecessary allocation
        .iter()
        .sum()
}

// ✅ Lazy iteration
fn good_process(items: &[i32]) -> i32 {
    items.iter()
        .filter(|x| **x > 0)
        .sum()
}

// ❌ Repeated allocation inside a loop
fn bad_loop() -> String {
    let mut result = String::new();
    for i in 0..1000 {
        result = result + &i.to_string();  // reallocates on every iteration!
    }
    result
}

// ✅ Pre-allocate or use push_str
fn good_loop() -> String {
    let mut result = String::with_capacity(4000);  // pre-allocate
    for i in 0..1000 {
        write!(result, "{}", i).unwrap();  // append in place
    }
    result
}

// ❌ Excessive use of clone
fn bad_clone(data: &HashMap<String, Vec<u8>>) -> Vec<u8> {
    data.get("key").cloned().unwrap_or_default()
}

// ✅ Return a reference or use Cow
fn good_ref(data: &HashMap<String, Vec<u8>>) -> &[u8] {
    data.get("key").map(|v| v.as_slice()).unwrap_or(&[])
}

// ❌ Passing a large struct by value
fn bad_pass(data: LargeStruct) { ... }  // copies the entire struct

// ✅ Pass by reference
fn good_pass(data: &LargeStruct) { ... }

// ❌ Box<dyn Trait> for small, known types
fn bad_trait_object() -> Box<dyn Iterator<Item = i32>> {
    Box::new(vec![1, 2, 3].into_iter())
}

// ✅ Use impl Trait
fn good_impl_trait() -> impl Iterator<Item = i32> {
    vec![1, 2, 3].into_iter()
}

// ❌ retain can be slower than filter+collect (in some cases)
vec.retain(|x| x.is_valid());  // O(n) but with a high constant factor

// ✅ If in-place modification isn't needed, consider filter
let vec: Vec<_> = vec.into_iter().filter(|x| x.is_valid()).collect();
```

### Lifetimes and References

```rust
// ❌ Returning a reference to a local variable
fn bad_return_ref() -> &str {
    let s = String::from("hello");
    &s  // Error: s will be dropped
}

// ✅ Return owned data or a static reference
fn good_return_owned() -> String {
    String::from("hello")
}

// ❌ Overly generalized lifetimes
fn bad_lifetime<'a, 'b>(x: &'a str, y: &'b str) -> &'a str {
    x  // 'b is never used
}

// ✅ Simplified lifetimes
fn good_lifetime(x: &str, _y: &str) -> &str {
    x  // compiler infers this automatically
}

// ❌ Struct holding multiple related references with independent lifetimes
struct Bad<'a, 'b> {
    name: &'a str,
    data: &'b [u8],  // these should usually share the same lifetime
}

// ✅ Related data using the same lifetime
struct Good<'a> {
    name: &'a str,
    data: &'a [u8],
}
```

### Rust Review Checklist

**Ownership and Borrowing**
- [ ] clone() is intentional, not used to bypass the borrow checker
- [ ] Avoid storing borrows in structs (unless necessary)
- [ ] Rc/Arc usage is reasonable and doesn't hide unnecessary shared state
- [ ] No unnecessary RefCell (runtime checks vs. compile-time)

**Unsafe Code**
- [ ] Every unsafe block has a SAFETY comment
- [ ] unsafe fn has a # Safety doc comment
- [ ] Safety invariants are clearly documented
- [ ] unsafe boundaries are as small as possible

**Async/Concurrency**
- [ ] No blocking inside async contexts
- [ ] No std::sync locks held across .await
- [ ] Spawned tasks satisfy the 'static bound
- [ ] Futures are correctly awaited or spawned
- [ ] Lock ordering is consistent (to avoid deadlocks)

**Error Handling**
- [ ] Library code uses thiserror; application code uses anyhow
- [ ] Errors carry sufficient context
- [ ] No unwrap/expect in production code
- [ ] must_use return values are handled correctly

**Performance**
- [ ] Unnecessary collect() is avoided
- [ ] Large data structures are passed by reference
- [ ] String concatenation uses String::with_capacity or write!
- [ ] impl Trait is preferred over Box<dyn Trait> (when possible)

**Type System**
- [ ] Newtype pattern used to improve type safety
- [ ] Enum matches are exhaustive (no _ wildcard hiding new variants)
- [ ] Lifetimes are kept as simple as possible

## SQL

### Injection Vulnerabilities
```sql
-- ❌ String concatenation (SQL injection risk)
query = "SELECT * FROM users WHERE id = " + user_id

-- ✅ Parameterized queries
query = "SELECT * FROM users WHERE id = ?"
cursor.execute(query, (user_id,))
```

### Performance Issues
- [ ] Missing indexes on filtered/joined columns
- [ ] SELECT * instead of specific columns
- [ ] N+1 query patterns
- [ ] Missing LIMIT on large tables
- [ ] Inefficient subqueries vs JOINs

### Common Mistakes
- [ ] Not handling NULL comparisons correctly
- [ ] Missing transactions for related operations
- [ ] Incorrect JOIN types
- [ ] Case sensitivity issues
- [ ] Date/timezone handling errors

## API Design

### REST Issues
- [ ] Inconsistent resource naming
- [ ] Wrong HTTP methods (POST for idempotent operations)
- [ ] Missing pagination for list endpoints
- [ ] Incorrect status codes
- [ ] Missing rate limiting

### Data Validation
- [ ] Missing input validation
- [ ] Incorrect data type validation
- [ ] Missing length/range checks
- [ ] Not sanitizing user input
- [ ] Trusting client-side validation

## Testing

### Test Quality Issues
- [ ] Testing implementation details instead of behavior
- [ ] Missing edge case tests
- [ ] Flaky tests (non-deterministic)
- [ ] Tests with external dependencies
- [ ] Missing negative tests (error cases)
- [ ] Overly complex test setup
