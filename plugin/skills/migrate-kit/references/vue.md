# Vue Migration Reference

## Vue 2 → Vue 3

This is a **major** migration. Vue 3 rewrites the reactivity system, introduces the Composition API, and has many breaking changes. Use the official `@vue/compat` migration build for gradual migration.

### Breaking Changes

- **Global API:**
  ```javascript
  // Before (Vue 2)
  Vue.component('MyComp', { ... });
  Vue.use(router);
  new Vue({ render: h => h(App) }).$mount('#app');

  // After (Vue 3)
  const app = createApp(App);
  app.component('MyComp', { ... });
  app.use(router);
  app.mount('#app');
  ```

- **`v-model` changes:**
  ```html
  <!-- Vue 2 -->
  <MyComponent v-model="value" />
  <!-- compiles to: :value="value" @input="value = $event" -->

  <!-- Vue 3 -->
  <MyComponent v-model="value" />
  <!-- compiles to: :modelValue="value" @update:modelValue="value = $event" -->

  <!-- Multiple v-models in Vue 3 -->
  <MyComponent v-model:title="title" v-model:content="content" />
  ```

- **`.sync` modifier removed** — use `v-model:propName` instead.

- **`$on`, `$off`, `$once` removed** — no more event bus pattern:
  ```javascript
  // Before (Vue 2 event bus)
  const bus = new Vue();
  bus.$on('event', handler);
  bus.$emit('event', data);

  // After — use mitt or tiny-emitter
  import mitt from 'mitt';
  const bus = mitt();
  bus.on('event', handler);
  bus.emit('event', data);
  ```

- **Filters removed:**
  ```html
  <!-- Before -->
  {{ message | capitalize }}

  <!-- After — use computed or method -->
  {{ capitalize(message) }}
  ```

- **`$children` removed** — use `$refs` or `provide/inject`.

- **Functional components** — simplified syntax, no more `functional: true`:
  ```javascript
  // Vue 3 — just a plain function
  const FunctionalComp = (props) => h('div', props.msg);
  ```

- **Transition class names changed:**
  ```css
  /* Before: v-enter, v-leave */
  /* After: v-enter-from, v-leave-from */
  ```

- **`key` attribute** — required on `v-if`/`v-else` branches, auto-generated on `<template v-for>`.

- **Reactivity system** — Proxies instead of `Object.defineProperty`:
  - Arrays: index assignment now reactive (`arr[0] = val` works)
  - Objects: dynamically added properties are reactive (no more `Vue.set`)
  - `Vue.set` and `Vue.delete` removed

- **Lifecycle hooks renamed:**
  - `beforeDestroy` → `beforeUnmount`
  - `destroyed` → `unmounted`

### Migration Strategy

1. **Use `@vue/compat`** (compatibility build):
   ```bash
   npm install vue@3 @vue/compat
   ```
   ```javascript
   // vue.config.js or vite.config.js
   resolve: {
     alias: { vue: '@vue/compat' }
   }
   ```
2. Fix compat warnings one at a time
3. Once clean, remove `@vue/compat` and switch to plain `vue@3`

### Deps to Update
- `vue-router`: 3.x → 4.x
- `vuex`: 3.x → 4.x (or migrate to Pinia)
- `vuetify`: 2.x → 3.x
- `vue-i18n`: 8.x → 9.x
- `@vue/test-utils`: 1.x → 2.x

---

## Vue 3 Minor Upgrades (3.2 → 3.3 → 3.4 → 3.5)

### 3.2 → 3.3
- `defineOptions()` macro for setting component options in `<script setup>`
- Generic components: `<script setup lang="ts" generic="T">`
- `defineSlots()` for typed slots
- Improved type inference

### 3.3 → 3.4
- `defineModel()` stable — simplified `v-model` in `<script setup>`:
  ```vue
  <!-- Before -->
  <script setup>
  const props = defineProps(['modelValue']);
  const emit = defineEmits(['update:modelValue']);
  </script>

  <!-- After -->
  <script setup>
  const model = defineModel();
  </script>
  ```
- `v-bind` same-name shorthand: `:id` instead of `:id="id"`
- Improved hydration mismatch warnings

### 3.4 → 3.5
- Reactive props destructure (stable):
  ```vue
  <script setup>
  const { count = 0 } = defineProps(['count']);
  // count is reactive!
  </script>
  ```
- `useTemplateRef()` API
- Deferred teleport
- `onWatcherCleanup()` utility

---

## Options API → Composition API

```vue
<!-- Before (Options API) -->
<script>
export default {
  data() { return { count: 0 } },
  computed: { doubled() { return this.count * 2 } },
  methods: { increment() { this.count++ } },
  mounted() { console.log('mounted') }
}
</script>

<!-- After (Composition API with script setup) -->
<script setup>
import { ref, computed, onMounted } from 'vue';
const count = ref(0);
const doubled = computed(() => count.value * 2);
const increment = () => count.value++;
onMounted(() => console.log('mounted'));
</script>
```

---

## Vuex → Pinia

```javascript
// Before (Vuex)
const store = createStore({
  state: { count: 0 },
  mutations: { increment(state) { state.count++ } },
  actions: { asyncIncrement({ commit }) { commit('increment') } },
  getters: { doubled: state => state.count * 2 }
});

// After (Pinia)
const useCounterStore = defineStore('counter', {
  state: () => ({ count: 0 }),
  actions: { increment() { this.count++ } },
  getters: { doubled: (state) => state.count * 2 }
});
// No mutations! Actions can be sync or async.
```

---

## Vue CLI → Vite

1. Remove `@vue/cli-*` deps
2. Install: `npm install -D vite @vitejs/plugin-vue`
3. Create `vite.config.ts`
4. Move `public/index.html` → `index.html` at root
5. Add `<script type="module" src="/src/main.ts"></script>`
6. Rename `VUE_APP_*` env vars → `VITE_*`
7. Update code: `process.env.VUE_APP_*` → `import.meta.env.VITE_*`
8. Update scripts in `package.json`
9. Remove `vue.config.js`, translate settings to `vite.config.ts`
