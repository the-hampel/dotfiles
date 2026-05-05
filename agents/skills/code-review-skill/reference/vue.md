# Vue 3 Code Review Guide

> A Vue 3 Composition API code review guide covering core topics including the reactivity system, Props/Emits, Watchers, Composables, and Vue 3.5 new features.

## Table of Contents

- [Reactivity System](#reactivity-system)
- [Props & Emits](#props--emits)
- [Vue 3.5 New Features](#vue-35-new-features)
- [Watchers](#watchers)
- [Template Best Practices](#template-best-practices)
- [Composables](#composables)
- [Performance Optimization](#performance-optimization)
- [Review Checklist](#review-checklist)

---

## Reactivity System

### Choosing Between ref and reactive

```vue
<!-- ✅ Use ref for primitives -->
<script setup lang="ts">
const count = ref(0)
const name = ref('Vue')

// ref requires .value to access
count.value++
</script>

<!-- ✅ Use reactive for objects/arrays (optional) -->
<script setup lang="ts">
const state = reactive({
  user: null,
  loading: false,
  error: null
})

// reactive is accessed directly
state.loading = true
</script>

<!-- 💡 Modern best practice: use ref for everything, for consistency -->
<script setup lang="ts">
const user = ref<User | null>(null)
const loading = ref(false)
const error = ref<Error | null>(null)
</script>
```

### Destructuring a reactive Object

```vue
<!-- ❌ Destructuring reactive loses reactivity -->
<script setup lang="ts">
const state = reactive({ count: 0, name: 'Vue' })
const { count, name } = state  // Loses reactivity!
</script>

<!-- ✅ Use toRefs to maintain reactivity -->
<script setup lang="ts">
const state = reactive({ count: 0, name: 'Vue' })
const { count, name } = toRefs(state)  // Maintains reactivity
// Or just use ref directly
const count = ref(0)
const name = ref('Vue')
</script>
```

### computed Side Effects

```vue
<!-- ❌ Side effects inside computed -->
<script setup lang="ts">
const fullName = computed(() => {
  console.log('Computing...')  // Side effect!
  otherRef.value = 'changed'   // Mutating other state!
  return `${firstName.value} ${lastName.value}`
})
</script>

<!-- ✅ computed is only for derived state -->
<script setup lang="ts">
const fullName = computed(() => {
  return `${firstName.value} ${lastName.value}`
})
// Put side effects in watch or event handlers
watch(fullName, (name) => {
  console.log('Name changed:', name)
})
</script>
```

### shallowRef Optimization

```vue
<!-- ❌ Using ref with large objects causes deep conversion -->
<script setup lang="ts">
const largeData = ref(hugeNestedObject)  // Deep reactive, high performance cost
</script>

<!-- ✅ Use shallowRef to avoid deep conversion -->
<script setup lang="ts">
const largeData = shallowRef(hugeNestedObject)

// Only a full replacement will trigger an update
function updateData(newData) {
  largeData.value = newData  // ✅ Triggers update
}

// ❌ Mutating nested properties will NOT trigger an update
// largeData.value.nested.prop = 'new'

// Use triggerRef to manually trigger an update when needed
import { triggerRef } from 'vue'
largeData.value.nested.prop = 'new'
triggerRef(largeData)
</script>
```

---

## Props & Emits

### Directly Mutating Props

```vue
<!-- ❌ Directly mutating props -->
<script setup lang="ts">
const props = defineProps<{ user: User }>()
props.user.name = 'New Name'  // Never directly mutate props!
</script>

<!-- ✅ Use emit to notify the parent to update -->
<script setup lang="ts">
const props = defineProps<{ user: User }>()
const emit = defineEmits<{
  update: [name: string]
}>()
const updateName = (name: string) => emit('update', name)
</script>
```

### defineProps Type Declarations

```vue
<!-- ❌ defineProps without type declarations -->
<script setup lang="ts">
const props = defineProps(['title', 'count'])  // No type checking
</script>

<!-- ✅ Use type declarations + withDefaults -->
<script setup lang="ts">
interface Props {
  title: string
  count?: number
  items?: string[]
}
const props = withDefaults(defineProps<Props>(), {
  count: 0,
  items: () => []  // Object/array defaults require a factory function
})
</script>
```

### defineEmits Type Safety

```vue
<!-- ❌ defineEmits without types -->
<script setup lang="ts">
const emit = defineEmits(['update', 'delete'])  // No type checking
emit('update', someValue)  // Parameter types are unsafe
</script>

<!-- ✅ Full type definitions -->
<script setup lang="ts">
const emit = defineEmits<{
  update: [id: number, value: string]
  delete: [id: number]
  'custom-event': [payload: CustomPayload]
}>()

// Now we have full type checking
emit('update', 1, 'new value')  // ✅
emit('update', 'wrong')  // ❌ TypeScript error
</script>
```

---

## Vue 3.5 New Features

### Reactive Props Destructure (3.5+)

```vue
<!-- Before Vue 3.5: destructuring loses reactivity -->
<script setup lang="ts">
const props = defineProps<{ count: number }>()
// Had to use props.count or toRefs
</script>

<!-- ✅ Vue 3.5+: destructuring maintains reactivity -->
<script setup lang="ts">
const { count, name = 'default' } = defineProps<{
  count: number
  name?: string
}>()

// count and name automatically stay reactive!
// Can be used directly in templates and watch
watch(() => count, (newCount) => {
  console.log('Count changed:', newCount)
})
</script>

<!-- ✅ Using with default values -->
<script setup lang="ts">
const {
  title,
  count = 0,
  items = () => []  // Function as default value (for objects/arrays)
} = defineProps<{
  title: string
  count?: number
  items?: () => string[]
}>()
</script>
```

### defineModel (3.4+)

```vue
<!-- ❌ Traditional v-model implementation: verbose -->
<script setup lang="ts">
const props = defineProps<{ modelValue: string }>()
const emit = defineEmits<{ 'update:modelValue': [value: string] }>()

// Needs a computed property for two-way binding
const value = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val)
})
</script>

<!-- ✅ defineModel: clean v-model implementation -->
<script setup lang="ts">
// Automatically handles props and emit
const model = defineModel<string>()

// Use directly
model.value = 'new value'  // Automatically emits
</script>
<template>
  <input v-model="model" />
</template>

<!-- ✅ Named v-model -->
<script setup lang="ts">
// Implementation for v-model:title
const title = defineModel<string>('title')

// With default value and options
const count = defineModel<number>('count', {
  default: 0,
  required: false
})
</script>

<!-- ✅ Multiple v-models -->
<script setup lang="ts">
const firstName = defineModel<string>('firstName')
const lastName = defineModel<string>('lastName')
</script>
<template>
  <!-- Parent usage: <MyInput v-model:first-name="first" v-model:last-name="last" /> -->
</template>

<!-- ✅ v-model modifiers -->
<script setup lang="ts">
const [model, modifiers] = defineModel<string>()

// Check for a modifier
if (modifiers.capitalize) {
  // Handle the .capitalize modifier
}
</script>
```

### useTemplateRef (3.5+)

```vue
<!-- Traditional approach: ref attribute matches variable name -->
<script setup lang="ts">
const inputRef = ref<HTMLInputElement | null>(null)
</script>
<template>
  <input ref="inputRef" />
</template>

<!-- ✅ useTemplateRef: clearer template ref syntax -->
<script setup lang="ts">
import { useTemplateRef } from 'vue'

const input = useTemplateRef<HTMLInputElement>('my-input')

onMounted(() => {
  input.value?.focus()
})
</script>
<template>
  <input ref="my-input" />
</template>

<!-- ✅ Dynamic ref -->
<script setup lang="ts">
const refKey = ref('input-a')
const dynamicInput = useTemplateRef<HTMLInputElement>(refKey)
</script>
```

### useId (3.5+)

```vue
<!-- ❌ Manually generated IDs may conflict -->
<script setup lang="ts">
const id = `input-${Math.random()}`  // Not SSR-safe!
</script>

<!-- ✅ useId: SSR-safe unique IDs -->
<script setup lang="ts">
import { useId } from 'vue'

const id = useId()  // e.g. 'v-0'
</script>
<template>
  <label :for="id">Name</label>
  <input :id="id" />
</template>

<!-- ✅ Using in form components -->
<script setup lang="ts">
const inputId = useId()
const errorId = useId()
</script>
<template>
  <label :for="inputId">Email</label>
  <input
    :id="inputId"
    :aria-describedby="errorId"
  />
  <span :id="errorId" class="error">{{ error }}</span>
</template>
```

### onWatcherCleanup (3.5+)

```vue
<!-- Traditional approach: third argument of watch -->
<script setup lang="ts">
watch(source, async (value, oldValue, onCleanup) => {
  const controller = new AbortController()
  onCleanup(() => controller.abort())
  // ...
})
</script>

<!-- ✅ onWatcherCleanup: more flexible cleanup -->
<script setup lang="ts">
import { onWatcherCleanup } from 'vue'

watch(source, async (value) => {
  const controller = new AbortController()
  onWatcherCleanup(() => controller.abort())

  // Can be called anywhere, not limited to the top of the callback
  if (someCondition) {
    const anotherResource = createResource()
    onWatcherCleanup(() => anotherResource.dispose())
  }

  await fetchData(value, controller.signal)
})
</script>
```

### Deferred Teleport (3.5+)

```vue
<!-- ❌ Teleport target must exist at mount time -->
<template>
  <Teleport to="#modal-container">
    <!-- Will error if #modal-container does not exist -->
  </Teleport>
</template>

<!-- ✅ defer attribute delays mounting -->
<template>
  <Teleport to="#modal-container" defer>
    <!-- Waits for the target element to exist before mounting -->
    <Modal />
  </Teleport>
</template>
```

---

## Watchers

### watch vs watchEffect

```vue
<script setup lang="ts">
// ✅ watch: explicitly specifies dependencies, lazy execution
watch(
  () => props.userId,
  async (userId) => {
    user.value = await fetchUser(userId)
  }
)

// ✅ watchEffect: automatically collects dependencies, runs immediately
watchEffect(async () => {
  // Automatically tracks props.userId
  user.value = await fetchUser(props.userId)
})

// 💡 Selection guide:
// - Need the old value? Use watch
// - Need lazy execution? Use watch
// - Complex dependencies? Use watchEffect
</script>
```

### watch Cleanup Functions

```vue
<!-- ❌ watch without a cleanup function may cause memory leaks -->
<script setup lang="ts">
watch(searchQuery, async (query) => {
  const controller = new AbortController()
  const data = await fetch(`/api/search?q=${query}`, {
    signal: controller.signal
  })
  results.value = await data.json()
  // If query changes rapidly, old requests won't be cancelled!
})
</script>

<!-- ✅ Use onCleanup to clean up side effects -->
<script setup lang="ts">
watch(searchQuery, async (query, _, onCleanup) => {
  const controller = new AbortController()
  onCleanup(() => controller.abort())  // Cancel old request

  try {
    const data = await fetch(`/api/search?q=${query}`, {
      signal: controller.signal
    })
    results.value = await data.json()
  } catch (e) {
    if (e.name !== 'AbortError') throw e
  }
})
</script>
```

### watch Options

```vue
<script setup lang="ts">
// ✅ immediate: run once immediately
watch(
  userId,
  async (id) => {
    user.value = await fetchUser(id)
  },
  { immediate: true }
)

// ✅ deep: deep watching (high performance cost, use with care)
watch(
  state,
  (newState) => {
    console.log('State changed deeply')
  },
  { deep: true }
)

// ✅ flush: 'post': runs after DOM update
watch(
  source,
  () => {
    // Can safely access the updated DOM
    // nextTick is no longer needed
  },
  { flush: 'post' }
)

// ✅ once: true (Vue 3.4+): only runs once
watch(
  source,
  (value) => {
    console.log('Will only run once:', value)
  },
  { once: true }
)
</script>
```

### Watching Multiple Sources

```vue
<script setup lang="ts">
// ✅ Watching multiple refs
watch(
  [firstName, lastName],
  ([newFirst, newLast], [oldFirst, oldLast]) => {
    console.log(`Name changed from ${oldFirst} ${oldLast} to ${newFirst} ${newLast}`)
  }
)

// ✅ Watching specific properties of a reactive object
watch(
  () => [state.count, state.name],
  ([count, name]) => {
    console.log(`count: ${count}, name: ${name}`)
  }
)
</script>
```

---

## Template Best Practices

### Keys in v-for

```vue
<!-- ❌ Using index as key in v-for -->
<template>
  <li v-for="(item, index) in items" :key="index">
    {{ item.name }}
  </li>
</template>

<!-- ✅ Use a unique identifier as key -->
<template>
  <li v-for="item in items" :key="item.id">
    {{ item.name }}
  </li>
</template>

<!-- ✅ Composite key (when there's no unique ID) -->
<template>
  <li v-for="(item, index) in items" :key="`${item.name}-${item.type}-${index}`">
    {{ item.name }}
  </li>
</template>
```

### v-if and v-for Priority

```vue
<!-- ❌ Using v-if and v-for together -->
<template>
  <li v-for="user in users" v-if="user.active" :key="user.id">
    {{ user.name }}
  </li>
</template>

<!-- ✅ Use computed to filter -->
<script setup lang="ts">
const activeUsers = computed(() =>
  users.value.filter(user => user.active)
)
</script>
<template>
  <li v-for="user in activeUsers" :key="user.id">
    {{ user.name }}
  </li>
</template>

<!-- ✅ Or wrap with a template element -->
<template>
  <template v-for="user in users" :key="user.id">
    <li v-if="user.active">
      {{ user.name }}
    </li>
  </template>
</template>
```

### Event Handling

```vue
<!-- ❌ Inline complex logic -->
<template>
  <button @click="items = items.filter(i => i.id !== item.id); count--">
    Delete
  </button>
</template>

<!-- ✅ Use methods -->
<script setup lang="ts">
const deleteItem = (id: number) => {
  items.value = items.value.filter(i => i.id !== id)
  count.value--
}
</script>
<template>
  <button @click="deleteItem(item.id)">Delete</button>
</template>

<!-- ✅ Event modifiers -->
<template>
  <!-- Prevent default behavior -->
  <form @submit.prevent="handleSubmit">...</form>

  <!-- Stop propagation -->
  <button @click.stop="handleClick">...</button>

  <!-- Run only once -->
  <button @click.once="handleOnce">...</button>

  <!-- Keyboard modifiers -->
  <input @keyup.enter="submit" @keyup.esc="cancel" />
</template>
```

---

## Composables

### Composable Design Principles

```typescript
// ✅ Good composable design
export function useCounter(initialValue = 0) {
  const count = ref(initialValue)

  const increment = () => count.value++
  const decrement = () => count.value--
  const reset = () => count.value = initialValue

  // Return reactive refs and methods
  return {
    count: readonly(count),  // Readonly to prevent external mutation
    increment,
    decrement,
    reset
  }
}

// ❌ Don't return .value
export function useBadCounter() {
  const count = ref(0)
  return {
    count: count.value  // ❌ Loses reactivity!
  }
}
```

### Passing Props to a Composable

```vue
<!-- ❌ Passing props to a composable loses reactivity -->
<script setup lang="ts">
const props = defineProps<{ userId: string }>()
const { user } = useUser(props.userId)  // Loses reactivity!
</script>

<!-- ✅ Use toRef or computed to maintain reactivity -->
<script setup lang="ts">
const props = defineProps<{ userId: string }>()
const userIdRef = toRef(props, 'userId')
const { user } = useUser(userIdRef)  // Maintains reactivity
// Or use computed
const { user } = useUser(computed(() => props.userId))

// ✅ Vue 3.5+: use destructuring directly
const { userId } = defineProps<{ userId: string }>()
const { user } = useUser(() => userId)  // Getter function
</script>
```

### Async Composable

```typescript
// ✅ Async composable pattern
export function useFetch<T>(url: MaybeRefOrGetter<string>) {
  const data = ref<T | null>(null)
  const error = ref<Error | null>(null)
  const loading = ref(false)

  const execute = async () => {
    loading.value = true
    error.value = null

    try {
      const response = await fetch(toValue(url))
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`)
      }
      data.value = await response.json()
    } catch (e) {
      error.value = e as Error
    } finally {
      loading.value = false
    }
  }

  // Automatically re-fetch when URL is reactive and changes
  watchEffect(() => {
    toValue(url)  // Track dependency
    execute()
  })

  return {
    data: readonly(data),
    error: readonly(error),
    loading: readonly(loading),
    refetch: execute
  }
}

// Usage
const { data, loading, error, refetch } = useFetch<User[]>('/api/users')
```

### Lifecycle and Cleanup

```typescript
// ✅ Correctly handling lifecycle in a composable
export function useEventListener(
  target: MaybeRefOrGetter<EventTarget>,
  event: string,
  handler: EventListener
) {
  // Add listener after component mounts
  onMounted(() => {
    toValue(target).addEventListener(event, handler)
  })

  // Remove listener when component unmounts
  onUnmounted(() => {
    toValue(target).removeEventListener(event, handler)
  })
}

// ✅ Use effectScope to manage side effects
export function useFeature() {
  const scope = effectScope()

  scope.run(() => {
    // All reactive effects are inside this scope
    const state = ref(0)
    watch(state, () => { /* ... */ })
    watchEffect(() => { /* ... */ })
  })

  // Clean up all effects
  onUnmounted(() => scope.stop())

  return { /* ... */ }
}
```

---

## Performance Optimization

### v-memo

```vue
<!-- ✅ v-memo: caches a subtree to avoid re-rendering -->
<template>
  <div v-for="item in list" :key="item.id" v-memo="[item.id === selected]">
    <!-- Only re-renders when item.id === selected changes -->
    <ExpensiveComponent :item="item" :selected="item.id === selected" />
  </div>
</template>

<!-- ✅ Used together with v-for -->
<template>
  <div
    v-for="item in list"
    :key="item.id"
    v-memo="[item.name, item.status]"
  >
    <!-- Only re-renders when name or status changes -->
  </div>
</template>
```

### defineAsyncComponent

```vue
<script setup lang="ts">
import { defineAsyncComponent } from 'vue'

// ✅ Lazy-load a component
const HeavyChart = defineAsyncComponent(() =>
  import('./components/HeavyChart.vue')
)

// ✅ With loading and error states
const AsyncModal = defineAsyncComponent({
  loader: () => import('./components/Modal.vue'),
  loadingComponent: LoadingSpinner,
  errorComponent: ErrorDisplay,
  delay: 200,  // Delay showing loading state (prevents flash)
  timeout: 3000  // Timeout duration
})
</script>
```

### KeepAlive

```vue
<template>
  <!-- ✅ Cache dynamic components -->
  <KeepAlive>
    <component :is="currentTab" />
  </KeepAlive>

  <!-- ✅ Specify which components to cache -->
  <KeepAlive include="TabA,TabB">
    <component :is="currentTab" />
  </KeepAlive>

  <!-- ✅ Limit cache size -->
  <KeepAlive :max="10">
    <component :is="currentTab" />
  </KeepAlive>
</template>

<script setup lang="ts">
// KeepAlive component lifecycle hooks
onActivated(() => {
  // When component is activated (restored from cache)
  refreshData()
})

onDeactivated(() => {
  // When component is deactivated (entering cache)
  pauseTimers()
})
</script>
```

### Virtual Lists

```vue
<!-- ✅ Use virtual scrolling for large lists -->
<script setup lang="ts">
import { useVirtualList } from '@vueuse/core'

const { list, containerProps, wrapperProps } = useVirtualList(
  items,
  { itemHeight: 50 }
)
</script>
<template>
  <div v-bind="containerProps" style="height: 400px; overflow: auto">
    <div v-bind="wrapperProps">
      <div v-for="item in list" :key="item.data.id" style="height: 50px">
        {{ item.data.name }}
      </div>
    </div>
  </div>
</template>
```

---

## Review Checklist

### Reactivity System
- [ ] ref used for primitives, reactive for objects (or ref for everything consistently)
- [ ] No destructuring of reactive objects (or toRefs is used)
- [ ] Reactivity is maintained when passing props to composables
- [ ] shallowRef/shallowReactive used for large objects as an optimization
- [ ] No side effects inside computed

### Props & Emits
- [ ] defineProps uses TypeScript type declarations
- [ ] Complex default values use withDefaults + factory functions
- [ ] defineEmits has complete type definitions
- [ ] Props are never directly mutated
- [ ] Consider using defineModel to simplify v-model (Vue 3.4+)

### Vue 3.5 New Features (if applicable)
- [ ] Reactive Props Destructure used to simplify prop access
- [ ] useTemplateRef used instead of ref attribute
- [ ] useId used in forms to generate SSR-safe IDs
- [ ] onWatcherCleanup used for complex cleanup logic

### Watchers
- [ ] watch/watchEffect has appropriate cleanup functions
- [ ] Async watchers handle race conditions
- [ ] flush: 'post' used for watchers that operate on the DOM
- [ ] Avoid over-using watchers (prefer computed)
- [ ] Consider once: true for one-time watches

### Templates
- [ ] v-for uses a unique and stable key
- [ ] v-if and v-for not on the same element
- [ ] Event handlers use methods instead of inline complex logic
- [ ] Large lists use virtual scrolling

### Composables
- [ ] Related logic is extracted into composables
- [ ] Composables return reactive refs (not .value)
- [ ] Pure functions are not wrapped as composables
- [ ] Side effects are cleaned up when the component unmounts
- [ ] effectScope used to manage complex side effects

### Performance
- [ ] Large components are split into smaller ones
- [ ] defineAsyncComponent used for lazy loading
- [ ] Avoid unnecessary reactive conversions
- [ ] v-memo used for expensive list rendering
- [ ] KeepAlive used to cache dynamic components
