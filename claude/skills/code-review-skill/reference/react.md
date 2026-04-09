# React Code Review Guide

React review focus areas: Hooks rules, appropriate performance optimization, component design, and modern React 19/RSC patterns.

## Table of Contents

- [Basic Hooks Rules](#basic-hooks-rules)
- [useEffect Patterns](#useeffect-patterns)
- [useMemo / useCallback](#usememo--usecallback)
- [Component Design](#component-design)
- [Error Boundaries & Suspense](#error-boundaries--suspense)
- [Server Components (RSC)](#server-components-rsc)
- [React 19 Actions & Forms](#react-19-actions--forms)
- [Suspense & Streaming SSR](#suspense--streaming-ssr)
- [TanStack Query v5](#tanstack-query-v5)
- [Review Checklists](#review-checklists)

---

## Basic Hooks Rules

```tsx
// ❌ Calling Hooks conditionally — violates the Rules of Hooks
function BadComponent({ isLoggedIn }) {
  if (isLoggedIn) {
    const [user, setUser] = useState(null);  // Error!
  }
  return <div>...</div>;
}

// ✅ Hooks must be called at the top level of a component
function GoodComponent({ isLoggedIn }) {
  const [user, setUser] = useState(null);
  if (!isLoggedIn) return <LoginPrompt />;
  return <div>{user?.name}</div>;
}
```

---

## useEffect Patterns

```tsx
// ❌ Missing or incomplete dependency array
function BadEffect({ userId }) {
  const [user, setUser] = useState(null);
  useEffect(() => {
    fetchUser(userId).then(setUser);
  }, []);  // Missing userId dependency!
}

// ✅ Complete dependency array
function GoodEffect({ userId }) {
  const [user, setUser] = useState(null);
  useEffect(() => {
    let cancelled = false;
    fetchUser(userId).then(data => {
      if (!cancelled) setUser(data);
    });
    return () => { cancelled = true; };  // Cleanup function
  }, [userId]);
}

// ❌ Using useEffect for derived state (anti-pattern)
function BadDerived({ items }) {
  const [filteredItems, setFilteredItems] = useState([]);
  useEffect(() => {
    setFilteredItems(items.filter(i => i.active));
  }, [items]);  // Unnecessary effect + extra render
  return <List items={filteredItems} />;
}

// ✅ Compute directly during render, or use useMemo
function GoodDerived({ items }) {
  const filteredItems = useMemo(
    () => items.filter(i => i.active),
    [items]
  );
  return <List items={filteredItems} />;
}

// ❌ Using useEffect for event responses
function BadEventEffect() {
  const [query, setQuery] = useState('');
  useEffect(() => {
    if (query) {
      analytics.track('search', { query });  // Should be in the event handler
    }
  }, [query]);
}

// ✅ Perform side effects in event handlers
function GoodEvent() {
  const [query, setQuery] = useState('');
  const handleSearch = (q: string) => {
    setQuery(q);
    analytics.track('search', { query: q });
  };
}
```

---

## useMemo / useCallback

```tsx
// ❌ Over-optimization — constants don't need useMemo
function OverOptimized() {
  const config = useMemo(() => ({ timeout: 5000 }), []);  // Pointless
  const handleClick = useCallback(() => {
    console.log('clicked');
  }, []);  // Pointless if not passed to a memo component
}

// ✅ Only optimize when necessary
function ProperlyOptimized() {
  const config = { timeout: 5000 };  // Simple object defined directly
  const handleClick = () => console.log('clicked');
}

// ❌ useCallback dependencies always change
function BadCallback({ data }) {
  // data is a new object on every render, making useCallback ineffective
  const process = useCallback(() => {
    return data.map(transform);
  }, [data]);
}

// ✅ useMemo + useCallback used together with React.memo
const MemoizedChild = React.memo(function Child({ onClick, items }) {
  return <div onClick={onClick}>{items.length}</div>;
});

function Parent({ rawItems }) {
  const items = useMemo(() => processItems(rawItems), [rawItems]);
  const handleClick = useCallback(() => {
    console.log(items.length);
  }, [items]);
  return <MemoizedChild onClick={handleClick} items={items} />;
}
```

---

## Component Design

```tsx
// ❌ Defining a component inside another component — creates a new component on every render
function BadParent() {
  function ChildComponent() {  // New function on every render!
    return <div>child</div>;
  }
  return <ChildComponent />;
}

// ✅ Define components outside
function ChildComponent() {
  return <div>child</div>;
}
function GoodParent() {
  return <ChildComponent />;
}

// ❌ Props are always new object references
function BadProps() {
  return (
    <MemoizedComponent
      style={{ color: 'red' }}  // New object on every render
      onClick={() => {}}         // New function on every render
    />
  );
}

// ✅ Stable references
const style = { color: 'red' };
function GoodProps() {
  const handleClick = useCallback(() => {}, []);
  return <MemoizedComponent style={style} onClick={handleClick} />;
}
```

---

## Error Boundaries & Suspense

```tsx
// ❌ No error boundary
function BadApp() {
  return (
    <Suspense fallback={<Loading />}>
      <DataComponent />  {/* An error will crash the entire app */}
    </Suspense>
  );
}

// ✅ Error Boundary wrapping Suspense
function GoodApp() {
  return (
    <ErrorBoundary fallback={<ErrorUI />}>
      <Suspense fallback={<Loading />}>
        <DataComponent />
      </Suspense>
    </ErrorBoundary>
  );
}
```

---

## Server Components (RSC)

```tsx
// ❌ Using client-side features in a Server Component
// app/page.tsx (Server Component by default)
function BadServerComponent() {
  const [count, setCount] = useState(0);  // Error! No hooks in RSC
  return <button onClick={() => setCount(c => c + 1)}>{count}</button>;
}

// ✅ Extract interactive logic into a Client Component
// app/counter.tsx
'use client';
function Counter() {
  const [count, setCount] = useState(0);
  return <button onClick={() => setCount(c => c + 1)}>{count}</button>;
}

// app/page.tsx (Server Component)
async function GoodServerComponent() {
  const data = await fetchData();  // Can await directly
  return (
    <div>
      <h1>{data.title}</h1>
      <Counter />  {/* Client component */}
    </div>
  );
}

// ❌ Misplaced 'use client' — makes the entire tree a client component
// layout.tsx
'use client';  // This makes all child components client components
export default function Layout({ children }) { ... }

// ✅ Only use 'use client' on components that require interactivity
// Isolate client logic to leaf components
```

---

## React 19 Actions & Forms

React 19 introduced the Actions system and new form-handling Hooks, simplifying async operations and optimistic updates.

### useActionState

```tsx
// ❌ Traditional approach: multiple state variables
function OldForm() {
  const [isPending, setIsPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [data, setData] = useState(null);

  const handleSubmit = async (formData: FormData) => {
    setIsPending(true);
    setError(null);
    try {
      const result = await submitForm(formData);
      setData(result);
    } catch (e) {
      setError(e.message);
    } finally {
      setIsPending(false);
    }
  };
}

// ✅ React 19: useActionState manages everything together
import { useActionState } from 'react';

function NewForm() {
  const [state, formAction, isPending] = useActionState(
    async (prevState, formData: FormData) => {
      try {
        const result = await submitForm(formData);
        return { success: true, data: result };
      } catch (e) {
        return { success: false, error: e.message };
      }
    },
    { success: false, data: null, error: null }
  );

  return (
    <form action={formAction}>
      <input name="email" />
      <button disabled={isPending}>
        {isPending ? 'Submitting...' : 'Submit'}
      </button>
      {state.error && <p className="error">{state.error}</p>}
    </form>
  );
}
```

### useFormStatus

```tsx
// ❌ Prop-drilling form state
function BadSubmitButton({ isSubmitting }) {
  return <button disabled={isSubmitting}>Submit</button>;
}

// ✅ useFormStatus accesses the parent <form> state (no props needed)
import { useFormStatus } from 'react-dom';

function SubmitButton() {
  const { pending, data, method, action } = useFormStatus();
  // Note: must be used inside a child component of <form>
  return (
    <button disabled={pending}>
      {pending ? 'Submitting...' : 'Submit'}
    </button>
  );
}

// ❌ useFormStatus called at the same level as the form — doesn't work
function BadForm() {
  const { pending } = useFormStatus();  // Cannot get state here!
  return (
    <form action={action}>
      <button disabled={pending}>Submit</button>
    </form>
  );
}

// ✅ useFormStatus must be called inside a child component of <form>
function GoodForm() {
  return (
    <form action={action}>
      <SubmitButton />  {/* useFormStatus is called inside here */}
    </form>
  );
}
```

### useOptimistic

```tsx
// ❌ Waiting for server response before updating UI
function SlowLike({ postId, likes }) {
  const [likeCount, setLikeCount] = useState(likes);
  const [isPending, setIsPending] = useState(false);

  const handleLike = async () => {
    setIsPending(true);
    const newCount = await likePost(postId);  // Waiting...
    setLikeCount(newCount);
    setIsPending(false);
  };
}

// ✅ useOptimistic for instant feedback, automatic rollback on failure
import { useOptimistic } from 'react';

function FastLike({ postId, likes }) {
  const [optimisticLikes, addOptimisticLike] = useOptimistic(
    likes,
    (currentLikes, increment: number) => currentLikes + increment
  );

  const handleLike = async () => {
    addOptimisticLike(1);  // Update UI immediately
    try {
      await likePost(postId);  // Sync in background
    } catch {
      // React automatically rolls back to the original likes value
    }
  };

  return <button onClick={handleLike}>{optimisticLikes} likes</button>;
}
```

### Server Actions (Next.js 15+)

```tsx
// ❌ Client-side API call
'use client';
function ClientForm() {
  const handleSubmit = async (formData: FormData) => {
    const res = await fetch('/api/submit', {
      method: 'POST',
      body: formData,
    });
    // ...
  };
}

// ✅ Server Action + useActionState
// actions.ts
'use server';
export async function createPost(prevState: any, formData: FormData) {
  const title = formData.get('title');
  await db.posts.create({ title });
  revalidatePath('/posts');
  return { success: true };
}

// form.tsx
'use client';
import { createPost } from './actions';

function PostForm() {
  const [state, formAction, isPending] = useActionState(createPost, null);
  return (
    <form action={formAction}>
      <input name="title" />
      <SubmitButton />
    </form>
  );
}
```

---

## Suspense & Streaming SSR

Suspense and Streaming are core features of React 18+, widely used in frameworks like Next.js 15 in 2025.

### Basic Suspense

```tsx
// ❌ Traditional loading state management
function OldComponent() {
  const [data, setData] = useState(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    fetchData().then(setData).finally(() => setIsLoading(false));
  }, []);

  if (isLoading) return <Spinner />;
  return <DataView data={data} />;
}

// ✅ Declarative loading state with Suspense
function NewComponent() {
  return (
    <Suspense fallback={<Spinner />}>
      <DataView />  {/* Uses use() or Suspense-compatible data fetching internally */}
    </Suspense>
  );
}
```

### Multiple Independent Suspense Boundaries

```tsx
// ❌ Single boundary — all content loads together
function BadLayout() {
  return (
    <Suspense fallback={<FullPageSpinner />}>
      <Header />
      <MainContent />  {/* Slow */}
      <Sidebar />      {/* Fast */}
    </Suspense>
  );
}

// ✅ Independent boundaries — each section streams independently
function GoodLayout() {
  return (
    <>
      <Header />  {/* Shows immediately */}
      <div className="flex">
        <Suspense fallback={<ContentSkeleton />}>
          <MainContent />  {/* Loads independently */}
        </Suspense>
        <Suspense fallback={<SidebarSkeleton />}>
          <Sidebar />      {/* Loads independently */}
        </Suspense>
      </div>
    </>
  );
}
```

### Next.js 15 Streaming

```tsx
// app/page.tsx - Automatic Streaming
export default async function Page() {
  // This await does not block the entire page
  const data = await fetchSlowData();
  return <div>{data}</div>;
}

// app/loading.tsx - Automatic Suspense boundary
export default function Loading() {
  return <Skeleton />;
}
```

### use() Hook (React 19)

```tsx
// ✅ Read a Promise inside a component
import { use } from 'react';

function Comments({ commentsPromise }) {
  const comments = use(commentsPromise);  // Automatically triggers Suspense
  return (
    <ul>
      {comments.map(c => <li key={c.id}>{c.text}</li>)}
    </ul>
  );
}

// Parent creates the Promise, child consumes it
function Post({ postId }) {
  const commentsPromise = fetchComments(postId);  // No await
  return (
    <article>
      <PostContent id={postId} />
      <Suspense fallback={<CommentsSkeleton />}>
        <Comments commentsPromise={commentsPromise} />
      </Suspense>
    </article>
  );
}
```

---

## TanStack Query v5

TanStack Query is the most popular data-fetching library in the React ecosystem; v5 is the current stable version.

### Basic Configuration

```tsx
// ❌ Incorrect default configuration
const queryClient = new QueryClient();  // Default config may not be suitable

// ✅ Recommended production configuration
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 5,  // Data is fresh for 5 minutes
      gcTime: 1000 * 60 * 30,    // Garbage collected after 30 minutes (renamed in v5)
      retry: 3,
      refetchOnWindowFocus: false,  // Decide based on your needs
    },
  },
});
```

### queryOptions (New in v5)

```tsx
// ❌ Duplicating queryKey and queryFn definitions
function Component1() {
  const { data } = useQuery({
    queryKey: ['users', userId],
    queryFn: () => fetchUser(userId),
  });
}

function prefetchUser(queryClient, userId) {
  queryClient.prefetchQuery({
    queryKey: ['users', userId],  // Duplicated!
    queryFn: () => fetchUser(userId),  // Duplicated!
  });
}

// ✅ queryOptions for a single definition with type safety
import { queryOptions } from '@tanstack/react-query';

const userQueryOptions = (userId: string) =>
  queryOptions({
    queryKey: ['users', userId],
    queryFn: () => fetchUser(userId),
  });

function Component1({ userId }) {
  const { data } = useQuery(userQueryOptions(userId));
}

function prefetchUser(queryClient, userId) {
  queryClient.prefetchQuery(userQueryOptions(userId));
}

// getQueryData is also type-safe
const user = queryClient.getQueryData(userQueryOptions(userId).queryKey);
```

### Common Pitfalls

```tsx
// ❌ staleTime of 0 causes excessive requests
useQuery({
  queryKey: ['data'],
  queryFn: fetchData,
  // staleTime defaults to 0, causing a refetch every time the component mounts
});

// ✅ Set a reasonable staleTime
useQuery({
  queryKey: ['data'],
  queryFn: fetchData,
  staleTime: 1000 * 60,  // Won't re-fetch within 1 minute
});

// ❌ Using unstable references in queryFn
function BadQuery({ filters }) {
  useQuery({
    queryKey: ['items'],  // queryKey doesn't include filters!
    queryFn: () => fetchItems(filters),  // Changes to filters won't trigger a re-fetch
  });
}

// ✅ queryKey includes all parameters that affect the data
function GoodQuery({ filters }) {
  useQuery({
    queryKey: ['items', filters],  // filters is part of the queryKey
    queryFn: () => fetchItems(filters),
  });
}
```

### useSuspenseQuery

> **Important limitations**: useSuspenseQuery differs significantly from useQuery — understand the limitations before choosing it.

#### useSuspenseQuery Limitations

| Feature | useQuery | useSuspenseQuery |
|------|----------|------------------|
| `enabled` option | ✅ Supported | ❌ Not supported |
| `placeholderData` | ✅ Supported | ❌ Not supported |
| `data` type | `T \| undefined` | `T` (guaranteed to have a value) |
| Error handling | `error` property | Throws to Error Boundary |
| Loading state | `isLoading` property | Suspends to Suspense |

#### Alternatives When `enabled` Is Not Supported

```tsx
// ❌ Using useQuery + enabled for conditional queries
function BadSuspenseQuery({ userId }) {
  const { data } = useSuspenseQuery({
    queryKey: ['user', userId],
    queryFn: () => fetchUser(userId),
    enabled: !!userId,  // useSuspenseQuery doesn't support enabled!
  });
}

// ✅ Use component composition for conditional rendering
function GoodSuspenseQuery({ userId }) {
  // useSuspenseQuery guarantees data is T, not T | undefined
  const { data } = useSuspenseQuery({
    queryKey: ['user', userId],
    queryFn: () => fetchUser(userId),
  });
  return <UserProfile user={data} />;
}

function Parent({ userId }) {
  if (!userId) return <NoUserSelected />;
  return (
    <Suspense fallback={<UserSkeleton />}>
      <GoodSuspenseQuery userId={userId} />
    </Suspense>
  );
}
```

#### Error Handling Differences

```tsx
// ❌ useSuspenseQuery has no error property
function BadErrorHandling() {
  const { data, error } = useSuspenseQuery({...});
  if (error) return <Error />;  // error is always null!
}

// ✅ Use Error Boundary to handle errors
function GoodErrorHandling() {
  return (
    <ErrorBoundary fallback={<ErrorMessage />}>
      <Suspense fallback={<Loading />}>
        <DataComponent />
      </Suspense>
    </ErrorBoundary>
  );
}

function DataComponent() {
  // Errors are thrown to the Error Boundary
  const { data } = useSuspenseQuery({
    queryKey: ['data'],
    queryFn: fetchData,
  });
  return <Display data={data} />;
}
```

#### When to Choose useSuspenseQuery

```tsx
// ✅ Good use cases:
// 1. Data is always required (unconditional queries)
// 2. Component must have data before it can render
// 3. Using React 19 Suspense patterns
// 4. Server components + client hydration

// ❌ Poor use cases:
// 1. Conditional queries (triggered by user action)
// 2. Need placeholderData or initial data
// 3. Need to handle loading/error state inside the component
// 4. Multiple queries with dependencies on each other

// ✅ Use useSuspenseQueries for multiple independent queries
function MultipleQueries({ userId }) {
  const [userQuery, postsQuery] = useSuspenseQueries({
    queries: [
      { queryKey: ['user', userId], queryFn: () => fetchUser(userId) },
      { queryKey: ['posts', userId], queryFn: () => fetchPosts(userId) },
    ],
  });
  // Both queries run in parallel; the component renders when both are done
  return <Profile user={userQuery.data} posts={postsQuery.data} />;
}
```

### Optimistic Updates (Simplified in v5)

```tsx
// ❌ Manually managing cache for optimistic updates (complex)
const mutation = useMutation({
  mutationFn: updateTodo,
  onMutate: async (newTodo) => {
    await queryClient.cancelQueries({ queryKey: ['todos'] });
    const previousTodos = queryClient.getQueryData(['todos']);
    queryClient.setQueryData(['todos'], (old) => [...old, newTodo]);
    return { previousTodos };
  },
  onError: (err, newTodo, context) => {
    queryClient.setQueryData(['todos'], context.previousTodos);
  },
  onSettled: () => {
    queryClient.invalidateQueries({ queryKey: ['todos'] });
  },
});

// ✅ v5 simplified: use variables for optimistic UI
function TodoList() {
  const { data: todos } = useQuery(todosQueryOptions);
  const { mutate, variables, isPending } = useMutation({
    mutationFn: addTodo,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['todos'] });
    },
  });

  return (
    <ul>
      {todos?.map(todo => <TodoItem key={todo.id} todo={todo} />)}
      {/* Optimistically show the todo being added */}
      {isPending && <TodoItem todo={variables} isOptimistic />}
    </ul>
  );
}
```

### v5 Status Field Changes

```tsx
// v4: isLoading indicated first load or subsequent fetch
// v5: isPending means no data; isLoading = isPending && isFetching

const { data, isPending, isFetching, isLoading } = useQuery({...});

// isPending: no data in cache (first load)
// isFetching: a request is in progress (including background refresh)
// isLoading: isPending && isFetching (loading for the first time)

// ❌ Directly migrating v4 code
if (isLoading) return <Spinner />;  // Behavior may differ in v5

// ✅ Be explicit about intent
if (isPending) return <Spinner />;  // Show loading when there's no data
// or
if (isLoading) return <Spinner />;  // Show loading on first load
```

---

## Review Checklists

### Hooks Rules

- [ ] Hooks are called at the top level of the component/custom Hook
- [ ] No Hooks called inside conditions or loops
- [ ] useEffect dependency arrays are complete
- [ ] useEffect has cleanup functions (subscriptions/timers/requests)
- [ ] Not using useEffect to compute derived state

### Performance Optimization (Moderation Principle)

- [ ] useMemo/useCallback only used where truly needed
- [ ] React.memo used together with stable prop references
- [ ] No child components defined inside parent components
- [ ] No new objects/functions created in JSX (unless passed to non-memo components)
- [ ] Long lists use virtualization (react-window/react-virtual)

### Component Design

- [ ] Component has a single responsibility and is under 200 lines
- [ ] Logic and presentation are separated (Custom Hooks)
- [ ] Props interface is clear and uses TypeScript
- [ ] Avoid Props Drilling (consider Context or composition)

### State Management

- [ ] State is colocated (minimal necessary scope)
- [ ] Complex state uses useReducer
- [ ] Global state uses Context or a state library
- [ ] Avoid unnecessary state (derive > store)

### Error Handling

- [ ] Critical sections have Error Boundaries
- [ ] Suspense is used with Error Boundaries
- [ ] Async operations have error handling

### Server Components (RSC)

- [ ] 'use client' only used on components that need interactivity
- [ ] Server Components don't use Hooks/event handlers
- [ ] Client components are kept as close to leaf nodes as possible
- [ ] Data fetching is done in Server Components

### React 19 Forms

- [ ] useActionState used instead of multiple useState calls
- [ ] useFormStatus called inside a child component of the form
- [ ] useOptimistic not used for critical business operations (payments, etc.)
- [ ] Server Actions correctly marked with 'use server'

### Suspense & Streaming

- [ ] Suspense boundaries divided based on user experience needs
- [ ] Each Suspense has a corresponding Error Boundary
- [ ] Meaningful fallbacks provided (skeleton screens > spinners)
- [ ] Avoid awaiting slow data at the layout level

### TanStack Query

- [ ] queryKey includes all parameters that affect the data
- [ ] A reasonable staleTime is set (not the default 0)
- [ ] useSuspenseQuery does not use enabled
- [ ] Related queries are invalidated after a successful mutation
- [ ] Understand the difference between isPending and isLoading

### Testing

- [ ] Using @testing-library/react
- [ ] Using screen to query elements
- [ ] Using userEvent instead of fireEvent
- [ ] Prefer *ByRole queries
- [ ] Test behavior, not implementation details
