# Architecture Review Guide

Architecture design review guide to help evaluate whether code architecture is sound and design is appropriate.

## SOLID Principles Checklist

### S - Single Responsibility Principle (SRP)

**Key checks:**
- Does this class/module have only one reason to change?
- Do all methods in the class serve the same purpose?
- Can you describe this class in a single sentence to a non-technical person?

**Warning signs in code review:**
```
⚠️ Class name contains generic words like "And", "Manager", "Handler", "Processor"
⚠️ A class exceeds 200-300 lines of code
⚠️ Class has more than 5-7 public methods
⚠️ Different methods operate on completely different data
```

**Review questions:**
- "What responsibilities does this class have? Can it be split?"
- "If requirement X changes, which methods need updating? What about requirement Y?"

### O - Open/Closed Principle (OCP)

**Key checks:**
- Does adding new functionality require modifying existing code?
- Can new behaviors be added through extension (inheritance, composition)?
- Are there large if/else or switch chains handling different types?

**Warning signs in code review:**
```
⚠️ switch/if-else chains handling different types
⚠️ Adding new functionality requires modifying core classes
⚠️ Type checks (instanceof, typeof) scattered throughout the code
```

**Review questions:**
- "If you need to add a new type of X, which files need to change?"
- "Will this switch statement grow as new types are added?"

### L - Liskov Substitution Principle (LSP)

**Key checks:**
- Can subclasses fully substitute for their parent class?
- Do subclasses change the expected behavior of parent class methods?
- Do subclasses throw exceptions not declared by the parent?

**Warning signs in code review:**
```
⚠️ Explicit type casting
⚠️ Subclass methods throw NotImplementedException
⚠️ Subclass methods have empty implementations or just return
⚠️ Code using the base class needs to check for concrete types
```

**Review questions:**
- "If a subclass replaces the parent class, does the calling code need to change?"
- "Does the subclass method behavior conform to the parent class contract?"

### I - Interface Segregation Principle (ISP)

**Key checks:**
- Are interfaces small and focused?
- Are implementing classes forced to implement methods they don't need?
- Do clients depend on methods they don't use?

**Warning signs in code review:**
```
⚠️ Interface has more than 5-7 methods
⚠️ Implementing classes have empty methods or throw NotImplementedException
⚠️ Interface names are too broad (IManager, IService)
⚠️ Different clients only use a subset of the interface's methods
```

**Review questions:**
- "Are all methods of this interface used by every implementing class?"
- "Can this large interface be split into smaller, specialized interfaces?"

### D - Dependency Inversion Principle (DIP)

**Key checks:**
- Do high-level modules depend on abstractions rather than concrete implementations?
- Is dependency injection used instead of directly instantiating objects?
- Are abstractions defined by high-level modules rather than low-level ones?

**Warning signs in code review:**
```
⚠️ High-level modules directly instantiate concrete low-level classes
⚠️ Importing concrete implementation classes instead of interfaces/abstract classes
⚠️ Configuration and connection strings hard-coded in business logic
⚠️ Difficult to write unit tests for a class
```

**Review questions:**
- "Can this class's dependencies be mocked during testing?"
- "If you swap out the database/API implementation, how many places need to change?"

---

## Architecture Anti-Pattern Recognition

### Critical Anti-Patterns

| Anti-Pattern | Warning Signs | Impact |
|--------|----------|------|
| **Big Ball of Mud** | No clear module boundaries; any code can call any other code | Hard to understand, modify, and test |
| **God Object** | A single class takes on too many responsibilities; knows too much, does too much | High coupling; hard to reuse and test |
| **Spaghetti Code** | Tangled control flow, gotos or deep nesting, hard to trace execution paths | Hard to understand and maintain |
| **Lava Flow** | Ancient code nobody dares touch, lacking documentation and tests | Accumulating technical debt |

### Design Anti-Patterns

| Anti-Pattern | Warning Signs | Recommendation |
|--------|----------|------|
| **Golden Hammer** | Using the same technology/pattern for every problem | Choose the right solution for the problem at hand |
| **Over-Engineering (Gas Factory)** | Solving simple problems with complex solutions; overusing design patterns | Apply the YAGNI principle — start simple, add complexity only when needed |
| **Boat Anchor** | Unused code written for "possible future needs" | Delete unused code; write it when actually needed |
| **Copy-Paste Programming** | Same logic appearing in multiple places | Extract into a shared method or module |

### Review Questions

```markdown
🔴 [blocking] "This class has 2000 lines of code — consider splitting it into multiple focused classes"
🟡 [important] "This logic is duplicated in 3 places — consider extracting it into a shared method?"
💡 [suggestion] "This switch statement could be replaced with the Strategy pattern for easier extensibility"
```

---

## Coupling and Cohesion Assessment

### Types of Coupling (best to worst)

| Type | Description | Example |
|------|------|------|
| **Message Coupling** ✅ | Data passed via parameters | `calculate(price, quantity)` |
| **Data Coupling** ✅ | Sharing simple data structures | `processOrder(orderDTO)` |
| **Stamp Coupling** ⚠️ | Sharing complex data structures but only using part of them | Passing the entire User object but only using name |
| **Control Coupling** ⚠️ | Passing control flags that influence behavior | `process(data, isAdmin=true)` |
| **Common Coupling** ❌ | Sharing global variables | Multiple modules reading/writing the same global state |
| **Content Coupling** ❌ | Directly accessing another module's internals | Directly manipulating another class's private fields |

### Types of Cohesion (best to worst)

| Type | Description | Quality |
|------|------|------|
| **Functional Cohesion** | All elements perform a single task | ✅ Best |
| **Sequential Cohesion** | Output of one step feeds the next | ✅ Good |
| **Communicational Cohesion** | Operating on the same data | ⚠️ Acceptable |
| **Temporal Cohesion** | Tasks executed at the same time | ⚠️ Poor |
| **Logical Cohesion** | Logically related but functionally different | ❌ Bad |
| **Coincidental Cohesion** | No meaningful relationship | ❌ Worst |

### Metrics Reference

```yaml
Coupling metrics:
  CBO (Coupling Between Objects):
    good: < 5
    warning: 5-10
    danger: > 10

  Ce (Efferent Coupling):
    description: How many external classes this class depends on
    good: < 7

  Ca (Afferent Coupling):
    description: How many classes depend on this class
    high value means: Changes have wide impact; stability is important

Cohesion metrics:
  LCOM4 (Lack of Cohesion in Methods):
    1: Single responsibility ✅
    2-3: May need splitting ⚠️
    >3: Should be split ❌
```

### Review Questions

- "How many other modules does this module depend on? Can that be reduced?"
- "How many other places will be affected if this class changes?"
- "Do all methods in this class operate on the same data?"

---

## Layered Architecture Review

### Clean Architecture Layer Check

```
┌─────────────────────────────────────┐
│         Frameworks & Drivers        │ ← Outermost layer: Web, DB, UI
├─────────────────────────────────────┤
│         Interface Adapters          │ ← Controllers, Gateways, Presenters
├─────────────────────────────────────┤
│          Application Layer          │ ← Use Cases, Application Services
├─────────────────────────────────────┤
│            Domain Layer             │ ← Entities, Domain Services
└─────────────────────────────────────┘
          ↑ Dependencies must point inward only ↑
```

### Dependency Rule Check

**Core rule: Source code dependencies can only point toward inner layers**

```typescript
// ❌ Violates dependency rule: Domain layer depends on Infrastructure
// domain/User.ts
import { MySQLConnection } from '../infrastructure/database';

// ✅ Correct: Domain layer defines the interface, Infrastructure implements it
// domain/UserRepository.ts (interface)
interface UserRepository {
  findById(id: string): Promise<User>;
}

// infrastructure/MySQLUserRepository.ts (implementation)
class MySQLUserRepository implements UserRepository {
  findById(id: string): Promise<User> { /* ... */ }
}
```

### Review Checklist

**Layer boundary checks:**
- [ ] Does the Domain layer have external dependencies (database, HTTP, filesystem)?
- [ ] Does the Application layer directly operate on the database or call external APIs?
- [ ] Does the Controller contain business logic?
- [ ] Are there any cross-layer calls (UI calling Repository directly)?

**Separation of concerns checks:**
- [ ] Is business logic separated from presentation logic?
- [ ] Is data access encapsulated in a dedicated layer?
- [ ] Is configuration and environment-related code managed centrally?

### Review Questions

```markdown
🔴 [blocking] "Domain entity directly imports a database connection — this violates the dependency rule"
🟡 [important] "Controller contains business calculation logic — consider moving it to the Service layer"
💡 [suggestion] "Consider using dependency injection to decouple these components"
```

---

## Design Pattern Usage Assessment

### When to Use Design Patterns

| Pattern | When to use | When not to use |
|------|----------|------------|
| **Factory** | Need to create different types of objects; type determined at runtime | Only one type, or type is fixed |
| **Strategy** | Algorithm needs to switch at runtime; multiple interchangeable behaviors | Only one algorithm, or algorithm won't change |
| **Observer** | One-to-many dependency; state changes need to notify multiple objects | Simple direct calls are sufficient |
| **Singleton** | Truly need a globally unique instance, e.g., configuration management | Objects that can be passed via dependency injection |
| **Decorator** | Need to dynamically add responsibilities; avoid inheritance explosion | Responsibilities are fixed; no dynamic composition needed |

### Over-Engineering Warning Signs

```
⚠️ Signs of "Patternitis":

1. A simple if/else replaced by Strategy + Factory + Registry
2. Interfaces with only one implementation
3. Abstraction layers added for "possible future needs"
4. Line count has grown significantly due to pattern application
5. New team members need a long time to understand the code structure
```

### Review Principles

```markdown
✅ Correct pattern usage:
- Solves a real extensibility problem
- Makes code easier to understand and test
- Makes adding new features simpler

❌ Overuse of patterns:
- Using a pattern for its own sake
- Adds unnecessary complexity
- Violates the YAGNI principle
```

### Review Questions

- "What specific problem does using this pattern solve?"
- "What would be wrong with the code if this pattern weren't used?"
- "Does the value this abstraction layer adds outweigh its complexity?"

---

## Scalability Assessment

### Scalability Checklist

**Feature scalability:**
- [ ] Does adding new functionality require modifying core code?
- [ ] Are extension points provided (hooks, plugins, events)?
- [ ] Is configuration externalized (config files, environment variables)?

**Data scalability:**
- [ ] Does the data model support adding new fields?
- [ ] Has data volume growth been considered?
- [ ] Are queries backed by appropriate indexes?

**Load scalability:**
- [ ] Can the system scale horizontally (adding more instances)?
- [ ] Is there state dependency (sessions, local cache)?
- [ ] Are database connections using a connection pool?

### Extension Point Design Check

```typescript
// ✅ Good extensible design: using events/hooks
class OrderService {
  private hooks: OrderHooks;

  async createOrder(order: Order) {
    await this.hooks.beforeCreate?.(order);
    const result = await this.save(order);
    await this.hooks.afterCreate?.(result);
    return result;
  }
}

// ❌ Poor extensible design: hard-coding all behaviors
class OrderService {
  async createOrder(order: Order) {
    await this.sendEmail(order);        // hard-coded
    await this.updateInventory(order);  // hard-coded
    await this.notifyWarehouse(order);  // hard-coded
    return await this.save(order);
  }
}
```

### Review Questions

```markdown
💡 [suggestion] "If a new payment method needs to be supported in the future, is this design easy to extend?"
🟡 [important] "This logic is hard-coded — consider using configuration or the Strategy pattern?"
📚 [learning] "An event-driven architecture would make this feature much easier to extend"
```

---

## Code Structure Best Practices

### Directory Organization

**Organized by feature/domain (recommended):**
```
src/
├── user/
│   ├── User.ts           (entity)
│   ├── UserService.ts    (service)
│   ├── UserRepository.ts (data access)
│   └── UserController.ts (API)
├── order/
│   ├── Order.ts
│   ├── OrderService.ts
│   └── ...
└── shared/
    ├── utils/
    └── types/
```

**Organized by technical layer (not recommended):**
```
src/
├── controllers/     ← different domains mixed together
│   ├── UserController.ts
│   └── OrderController.ts
├── services/
├── repositories/
└── models/
```

### Naming Convention Checks

| Type | Convention | Example |
|------|------|------|
| Class name | PascalCase, noun | `UserService`, `OrderRepository` |
| Method name | camelCase, verb | `createUser`, `findOrderById` |
| Interface name | I prefix or no prefix | `IUserService` or `UserService` |
| Constants | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT` |
| Private fields | Underscore prefix or none | `_cache` or `#cache` |

### File Size Guidelines

```yaml
Recommended limits:
  Single file: < 300 lines
  Single function: < 50 lines
  Single class: < 200 lines
  Function parameters: < 4
  Nesting depth: < 4 levels

When limits are exceeded:
  - Consider splitting into smaller units
  - Use composition over inheritance
  - Extract helper functions or classes
```

### Review Questions

```markdown
🟢 [nit] "This 500-line file could be split by responsibility"
🟡 [important] "Consider organizing the directory structure by feature domain rather than technical layer"
💡 [suggestion] "The function name `process` is too vague — consider renaming it to `calculateOrderTotal`?"
```

---

## Quick Reference Checklist

### 5-Minute Architecture Review

```markdown
□ Are dependencies pointing in the correct direction? (outer layers depend on inner layers)
□ Are there any circular dependencies?
□ Is core business logic decoupled from frameworks/UI/database?
□ Are SOLID principles being followed?
□ Are there any obvious anti-patterns?
```

### Red Flags (must address)

```markdown
🔴 God Object - single class exceeds 1000 lines
🔴 Circular dependency - A → B → C → A
🔴 Domain layer contains framework dependencies
🔴 Hard-coded configuration and secrets
🔴 External service calls without an interface
```

### Yellow Flags (should address)

```markdown
🟡 Coupling Between Objects (CBO) > 10
🟡 Method has more than 5 parameters
🟡 Nesting depth exceeds 4 levels
🟡 Duplicated code block > 10 lines
🟡 Interface with only one implementation
```

---

## Recommended Tools

| Tool | Purpose | Language Support |
|------|------|----------|
| **SonarQube** | Code quality and coupling analysis | Multi-language |
| **NDepend** | Dependency analysis and architecture rules | .NET |
| **JDepend** | Package dependency analysis | Java |
| **Madge** | Module dependency graph | JavaScript/TypeScript |
| **ESLint** | Code standards and complexity checks | JavaScript/TypeScript |
| **CodeScene** | Technical debt and hotspot analysis | Multi-language |

---

## Reference Resources

- [Clean Architecture - Uncle Bob](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [SOLID Principles in Code Review - JetBrains](https://blog.jetbrains.com/upsource/2015/08/31/what-to-look-for-in-a-code-review-solid-principles-2/)
- [Software Architecture Anti-Patterns](https://medium.com/@christophnissle/anti-patterns-in-software-architecture-3c8970c9c4f5)
- [Coupling and Cohesion in System Design](https://www.geeksforgeeks.org/system-design/coupling-and-cohesion-in-system-design/)
- [Design Patterns - Refactoring Guru](https://refactoring.guru/design-patterns)
