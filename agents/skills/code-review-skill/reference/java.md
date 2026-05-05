# Java Code Review Guide

Java review focus areas: Java 17/21 new features, Spring Boot 3 best practices, concurrent programming (virtual threads), JPA performance optimization, and code maintainability.

## Table of Contents

- [Modern Java Features (17/21+)](#modern-java-features-1721)
- [Stream API & Optional](#stream-api--optional)
- [Spring Boot Best Practices](#spring-boot-best-practices)
- [JPA & Database Performance](#jpa--database-performance)
- [Concurrency & Virtual Threads](#concurrency--virtual-threads)
- [Lombok Usage Guidelines](#lombok-usage-guidelines)
- [Exception Handling](#exception-handling)
- [Testing Standards](#testing-standards)
- [Review Checklist](#review-checklist)

---

## Modern Java Features (17/21+)

### Record (Record Classes)

```java
// ❌ Traditional POJO/DTO: too much boilerplate
public class UserDto {
    private final String name;
    private final int age;

    public UserDto(String name, int age) {
        this.name = name;
        this.age = age;
    }
    // getters, equals, hashCode, toString...
}

// ✅ Using Record: concise, immutable, semantically clear
public record UserDto(String name, int age) {
    // Compact constructor for validation
    public UserDto {
        if (age < 0) throw new IllegalArgumentException("Age cannot be negative");
    }
}
```

### Switch Expressions and Pattern Matching

```java
// ❌ Traditional Switch: easy to forget break, verbose and error-prone
String type = "";
switch (obj) {
    case Integer i: // Java 16+
        type = String.format("int %d", i);
        break;
    case String s:
        type = String.format("string %s", s);
        break;
    default:
        type = "unknown";
}

// ✅ Switch expression: no fall-through risk, enforces return value
String type = switch (obj) {
    case Integer i -> "int %d".formatted(i);
    case String s  -> "string %s".formatted(s);
    case null      -> "null value"; // Java 21 null handling
    default        -> "unknown";
};
```

### Text Blocks

```java
// ❌ Concatenating SQL/JSON strings
String json = "{\n" +
              "  \"name\": \"Alice\",\n" +
              "  \"age\": 20\n" +
              "}";

// ✅ Using text blocks: what you see is what you get
String json = """
    {
      "name": "Alice",
      "age": 20
    }
    """;
```

---

## Stream API & Optional

### Avoid Overusing Stream

```java
// ❌ Simple loops don't need Stream (performance overhead + poor readability)
items.stream().forEach(item -> {
    process(item);
});

// ✅ Use for-each directly for simple cases
for (var item : items) {
    process(item);
}

// ❌ Excessively complex Stream chains
List<Dto> result = list.stream()
    .filter(...)
    .map(...)
    .peek(...)
    .sorted(...)
    .collect(...); // hard to debug

// ✅ Break into meaningful steps
var filtered = list.stream().filter(...).toList();
// ...
```

### Correct Use of Optional

```java
// ❌ Using Optional as a parameter or field (serialization issues, increases call complexity)
public void process(Optional<String> name) { ... }
public class User {
    private Optional<String> email; // not recommended
}

// ✅ Optional should only be used as a return value
public Optional<User> findUser(String id) { ... }

// ❌ Using isPresent() + get() defeats the purpose of Optional
Optional<User> userOpt = findUser(id);
if (userOpt.isPresent()) {
    return userOpt.get().getName();
} else {
    return "Unknown";
}

// ✅ Use the functional API
return findUser(id)
    .map(User::getName)
    .orElse("Unknown");
```

---

## Spring Boot Best Practices

### Dependency Injection (DI)

```java
// ❌ Field injection (@Autowired)
// Drawbacks: hard to test (requires reflection injection), hides excessive dependencies, poor immutability
@Service
public class UserService {
    @Autowired
    private UserRepository userRepo;
}

// ✅ Constructor injection
// Benefits: dependencies are explicit, easy to unit test (Mock), fields can be final
@Service
public class UserService {
    private final UserRepository userRepo;

    public UserService(UserRepository userRepo) {
        this.userRepo = userRepo;
    }
}
// 💡 Tip: combine with Lombok @RequiredArgsConstructor to simplify code, but watch out for circular dependencies
```

### Configuration Management

```java
// ❌ Hardcoded configuration values
@Service
public class PaymentService {
    private String apiKey = "sk_live_12345";
}

// ❌ Using @Value scattered throughout the code
@Value("${app.payment.api-key}")
private String apiKey;

// ✅ Use @ConfigurationProperties for type-safe configuration
@ConfigurationProperties(prefix = "app.payment")
public record PaymentProperties(String apiKey, int timeout, String url) {}
```

---

## JPA & Database Performance

### N+1 Query Problem

```java
// ❌ FetchType.EAGER or triggering lazy loading inside a loop
// Entity definition
@Entity
public class User {
    @OneToMany(fetch = FetchType.EAGER) // Dangerous!
    private List<Order> orders;
}

// Business code
List<User> users = userRepo.findAll(); // 1 SQL query
for (User user : users) {
    // If Lazy, this triggers N SQL queries here
    System.out.println(user.getOrders().size());
}

// ✅ Use @EntityGraph or JOIN FETCH
@Query("SELECT u FROM User u JOIN FETCH u.orders")
List<User> findAllWithOrders();
```

### Transaction Management

```java
// ❌ Opening transactions in the Controller layer (holds DB connections too long)
// ❌ Adding @Transactional on private methods (AOP won't intercept them)
@Transactional
private void saveInternal() { ... }

// ✅ Add @Transactional on public methods in the Service layer
// ✅ Explicitly mark read operations with readOnly = true (performance optimization)
@Service
public class UserService {
    @Transactional(readOnly = true)
    public User getUser(Long id) { ... }

    @Transactional
    public void createUser(UserDto dto) { ... }
}
```

### Entity Design

```java
// ❌ Using Lombok @Data on an Entity
// @Data-generated equals/hashCode includes all fields, which may trigger lazy loading causing performance issues or exceptions
@Entity
@Data
public class User { ... }

// ✅ Use only @Getter, @Setter
// ✅ Customize equals/hashCode (typically based on ID)
@Entity
@Getter
@Setter
public class User {
    @Id
    private Long id;

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof User)) return false;
        return id != null && id.equals(((User) o).id);
    }

    @Override
    public int hashCode() {
        return getClass().hashCode();
    }
}
```

---

## Concurrency & Virtual Threads

### Virtual Threads (Java 21+)

```java
// ❌ Traditional thread pool for large numbers of I/O-blocking tasks (resource exhaustion)
ExecutorService executor = Executors.newFixedThreadPool(100);

// ✅ Use virtual threads for I/O-intensive tasks (high throughput)
// Spring Boot 3.2+ enable with: spring.threads.virtual.enabled=true
ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor();

// With virtual threads, blocking operations (e.g. DB queries, HTTP requests) consume almost no OS thread resources
```

### Thread Safety

```java
// ❌ SimpleDateFormat is not thread-safe
private static final SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd");

// ✅ Use DateTimeFormatter (Java 8+)
private static final DateTimeFormatter dtf = DateTimeFormatter.ofPattern("yyyy-MM-dd");

// ❌ HashMap in a multi-threaded environment can cause infinite loops or data loss
// ✅ Use ConcurrentHashMap
Map<String, String> cache = new ConcurrentHashMap<>();
```

---

## Lombok Usage Guidelines

```java
// ❌ Overusing @Builder makes it impossible to enforce required fields
@Builder
public class Order {
    private String id;   // required
    private String note; // optional
}
// Callers may omit id: Order.builder().note("hi").build();

// ✅ For critical business objects, consider writing the Builder or constructor manually to enforce invariants
// Or add validation logic inside the build() method (Lombok @Builder.Default, etc.)
```

---

## Exception Handling

### Global Exception Handling

```java
// ❌ try-catch blocks scattered everywhere, swallowing exceptions or only printing logs
try {
    userService.create(user);
} catch (Exception e) {
    e.printStackTrace(); // should not be used in production
    // return null; // exception swallowed, the caller has no idea what happened
}

// ✅ Custom exceptions + @ControllerAdvice (Spring Boot 3 ProblemDetail)
public class UserNotFoundException extends RuntimeException { ... }

@RestControllerAdvice
public class GlobalExceptionHandler {
    @ExceptionHandler(UserNotFoundException.class)
    public ProblemDetail handleNotFound(UserNotFoundException e) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, e.getMessage());
    }
}
```

---

## Testing Standards

### Unit Tests vs Integration Tests

```java
// ❌ Unit tests depending on a real database or external services
@SpringBootTest // Starts the entire context — slow
public class UserServiceTest { ... }

// ✅ Unit tests using Mockito
@ExtendWith(MockitoExtension.class)
class UserServiceTest {
    @Mock UserRepository repo;
    @InjectMocks UserService service;

    @Test
    void shouldCreateUser() { ... }
}

// ✅ Integration tests using Testcontainers
@Testcontainers
@SpringBootTest
class UserRepositoryTest {
    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15");
    // ...
}
```

---

## Review Checklist

### Basics & Standards
- [ ] Follows Java 17/21 new features (Switch expressions, Records, Text Blocks)
- [ ] Avoids deprecated classes (Date, Calendar, SimpleDateFormat)
- [ ] Do collection operations prefer Stream API or Collections methods?
- [ ] Optional is only used as a return value, not for fields or parameters

### Spring Boot
- [ ] Uses constructor injection instead of @Autowired field injection
- [ ] Configuration properties use @ConfigurationProperties
- [ ] Controllers have a single responsibility; business logic pushed down to Services
- [ ] Global exception handling uses @ControllerAdvice / ProblemDetail

### Database & Transactions
- [ ] Read operations are marked with `@Transactional(readOnly = true)`
- [ ] Check for N+1 queries (EAGER fetch or looped calls)
- [ ] Entity classes do not use @Data; equals/hashCode are correctly implemented
- [ ] Database indexes cover the query conditions

### Concurrency & Performance
- [ ] Are virtual threads considered for I/O-intensive tasks?
- [ ] Are thread-safe classes used correctly (ConcurrentHashMap vs HashMap)?
- [ ] Is lock granularity appropriate? Avoid I/O operations inside locks

### Maintainability
- [ ] Critical business logic has adequate unit test coverage
- [ ] Logging is appropriate (using Slf4j, avoid System.out)
- [ ] Magic values are extracted as constants or enums
