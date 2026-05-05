# Fortran Code Review Guide

> Fortran code review guide focused on modern Fortran (2003/2008/2018) practices, numeric correctness, and scientific computing patterns. Legacy Fortran (77/90) issues are flagged where still commonly encountered.

## Table of Contents

- [Implicit Typing](#implicit-typing)
- [Array Handling](#array-handling)
- [Numeric Precision and Kinds](#numeric-precision-and-kinds)
- [Intent and Pure Procedures](#intent-and-pure-procedures)
- [Modules and Encapsulation](#modules-and-encapsulation)
- [Memory Management](#memory-management)
- [Error Handling](#error-handling)
- [Concurrency: OpenMP and Coarrays](#concurrency-openmp-and-coarrays)
- [Legacy Pitfalls](#legacy-pitfalls)
- [Tooling and Build Checks](#tooling-and-build-checks)
- [Review Checklist](#review-checklist)

---

## Implicit Typing

### Always use `implicit none`

Fortran's implicit typing (variables starting with `i–n` are integers, the rest reals) is a major source of silent bugs.

```fortran
! ❌ Bad: implicit typing active — typo creates a new variable
subroutine compute(x, result)
  real :: x, result
  reslt = x * 2.0   ! typo: 'reslt' is silently a new real variable
  result = reslt
end subroutine

! ✅ Good: implicit none forces explicit declarations
subroutine compute(x, result)
  implicit none
  real, intent(in)  :: x
  real, intent(out) :: result
  result = x * 2.0
end subroutine
```

`implicit none` must appear in every program unit (subroutine, function, module, program). In Fortran 2018, `implicit none (type, external)` also catches undeclared external procedures.

---

## Array Handling

### Prefer assumed-shape over assumed-size

```fortran
! ❌ Bad: assumed-size — shape information is lost, no bounds checking
subroutine fill(a, n)
  implicit none
  integer, intent(in) :: n
  real, intent(out)   :: a(*)   ! compiler cannot check bounds
  a(1:n) = 0.0
end subroutine

! ✅ Good: assumed-shape — shape is passed automatically
subroutine fill(a)
  implicit none
  real, intent(out) :: a(:)
  a = 0.0
end subroutine
```

### Whole-array operations over explicit loops

```fortran
! ❌ Verbose and slower at compile-time optimisation
do i = 1, n
  c(i) = a(i) + b(i)
end do

! ✅ Vectorisable and readable
c = a + b

! ✅ Intrinsics for reductions
total = sum(a)
peak  = maxval(abs(b))
idx   = minloc(a, dim=1)
```

### Watch default lower bounds

Fortran arrays are 1-based by default but can have arbitrary lower bounds. Never assume lower bound is 1 without checking.

```fortran
! ❌ Assumes 1-based
do i = 1, size(a)

! ✅ Uses actual bounds
do i = lbound(a,1), ubound(a,1)

! ✅ Or use whole-array / array section syntax
a(:) = 0.0
```

### Array temporaries in expressions

Watch for hidden temporaries when passing non-contiguous array sections to procedures expecting contiguous storage (e.g. C interop, MPI calls).

```fortran
! This may create a temporary copy
call mpi_send(a(1:n:2), n/2, MPI_DOUBLE_PRECISION, ...)

! ✅ Explicit contiguous copy
contiguous_a = a(1:n:2)
call mpi_send(contiguous_a, n/2, MPI_DOUBLE_PRECISION, ...)
```

---

## Numeric Precision and Kinds

### Never use bare `real` or `double precision` for portable code

```fortran
! ❌ Bad: precision is compiler-dependent
real :: x
double precision :: y

! ✅ Good: use a named kind parameter defined in one place
use kinds_module, only: dp
real(dp) :: x, y
```

Define kinds using `selected_real_kind` or ISO_C_BINDING:

```fortran
module kinds_module
  implicit none
  integer, parameter :: dp = selected_real_kind(15, 307)  ! ~double
  integer, parameter :: sp = selected_real_kind(6, 37)    ! ~single
  integer, parameter :: i4 = selected_int_kind(9)
  integer, parameter :: i8 = selected_int_kind(18)
end module
```

### Literal kind suffixes

```fortran
! ❌ Bad: literal is single precision even when assigned to dp variable
real(dp) :: x = 1.0 / 3.0   ! precision lost before assignment

! ✅ Good: suffix matches the kind
use kinds_module, only: dp
real(dp) :: x = 1.0_dp / 3.0_dp
```

### Integer overflow in size calculations

```fortran
! ❌ Bad: i4 * i4 overflows for large arrays
integer(i4) :: n = 100000
allocate(a(n*n))   ! overflow if n*n > 2^31-1

! ✅ Good: promote to i8
allocate(a(int(n,i8)*int(n,i8)))
```

---

## Intent and Pure Procedures

### Always declare intent

```fortran
! ❌ Bad: intent missing — accidental modification not caught
subroutine process(data, scale, result)
  implicit none
  real :: data(:), scale, result(:)

! ✅ Good: intent documents and enforces the contract
subroutine process(data, scale, result)
  implicit none
  real, intent(in)  :: data(:), scale
  real, intent(out) :: result(:)
```

### Use `pure` and `elemental` where appropriate

`pure` functions have no side effects and enable better optimisation. `elemental` additionally applies element-wise to arrays.

```fortran
! ✅ Pure function: no I/O, no global state modification
pure function sigmoid(x) result(y)
  real, intent(in) :: x
  real :: y
  y = 1.0 / (1.0 + exp(-x))
end function

! ✅ Elemental: automatically works on scalars and arrays
elemental pure function clamp(x, lo, hi) result(y)
  real, intent(in) :: x, lo, hi
  real :: y
  y = min(max(x, lo), hi)
end function

! Applied to an array:
result = clamp(data, 0.0, 1.0)
```

---

## Modules and Encapsulation

### Prefer modules over COMMON blocks

```fortran
! ❌ Bad: COMMON — no type safety, no encapsulation, nightmare to refactor
common /params/ n_atoms, box_length, cutoff

! ✅ Good: module with explicit visibility
module simulation_params
  implicit none
  private
  integer, public, protected :: n_atoms
  real(dp), public, protected :: box_length, cutoff

  public :: set_params
contains
  subroutine set_params(n, box, cut)
    integer, intent(in)  :: n
    real(dp), intent(in) :: box, cut
    n_atoms = n; box_length = box; cutoff = cut
  end subroutine
end module
```

### Use `only` in `use` statements

```fortran
! ❌ Bad: pollutes namespace, breaks on module changes
use simulation_params

! ✅ Good: explicit, documents dependencies
use simulation_params, only: n_atoms, box_length
```

### Module procedure interfaces are automatic

There is no need for explicit interface blocks when calling module procedures — the interface is always known. Explicit interface blocks are only needed for external (non-module) procedures.

---

## Memory Management

### Check ALLOCATE status

```fortran
! ❌ Bad: no error check
allocate(work(n))

! ✅ Good: check and handle
integer :: stat
character(len=256) :: errmsg
allocate(work(n), stat=stat, errmsg=errmsg)
if (stat /= 0) then
  write(*,*) 'Allocation failed: ', trim(errmsg)
  stop 1
end if
```

### Deallocate on all exit paths

```fortran
! ✅ Good: use a cleanup pattern similar to C's goto cleanup
subroutine compute(n)
  implicit none
  integer, intent(in) :: n
  real(dp), allocatable :: tmp(:)
  integer :: stat

  allocate(tmp(n), stat=stat)
  if (stat /= 0) return

  call do_work(tmp)

  deallocate(tmp)
end subroutine
```

Allocatable local variables are automatically deallocated on scope exit in Fortran 2003+, but dummy arguments and module variables are not.

---

## Error Handling

### Use `iostat` and `errmsg` instead of relying on runtime aborts

```fortran
! ❌ Bad: I/O error crashes program with cryptic message
open(unit=10, file='data.txt')
read(10, *) x

! ✅ Good: explicit error handling
integer :: ios
character(len=256) :: iomsg

open(unit=10, file='data.txt', status='old', iostat=ios, iomsg=iomsg)
if (ios /= 0) then
  write(*,'(a,a)') 'Cannot open file: ', trim(iomsg)
  stop 1
end if

read(10, *, iostat=ios, iomsg=iomsg) x
if (ios /= 0) then
  write(*,'(a,a)') 'Read error: ', trim(iomsg)
  stop 1
end if
close(10)
```

### Use `error stop` (Fortran 2008+) instead of bare `stop`

```fortran
! ❌ Legacy: returns exit code 0, misleads CI
stop

! ✅ Modern: exits with non-zero code on error
error stop 'Singular matrix encountered'
```

---

## Concurrency: OpenMP and Coarrays

### OpenMP: watch for race conditions on shared variables

```fortran
! ❌ Bad: race condition on 'total'
!$omp parallel do
do i = 1, n
  total = total + a(i)
end do

! ✅ Good: reduction clause
!$omp parallel do reduction(+:total)
do i = 1, n
  total = total + a(i)
end do
!$omp end parallel do

! ✅ Or use intrinsic
total = sum(a)
```

### OpenMP: avoid implicit shared state in loops

Declare loop variables and temporaries as `private`.

```fortran
!$omp parallel do private(i, tmp)
do i = 1, n
  tmp = expensive(a(i))
  b(i) = transform(tmp)
end do
```

### Coarrays: synchronise before reading remote data

```fortran
! ❌ Bad: no sync — reads stale data from image 1
x = a[1]

! ✅ Good: sync before accessing remote data
sync all
x = a[1]
```

---

## Legacy Pitfalls

### EQUIVALENCE and ENTRY — avoid entirely

`EQUIVALENCE` reinterprets memory as a different type (pre-C UB). `ENTRY` creates multiple entry points into one subroutine — a design smell. Neither has a place in modern Fortran.

### Fixed-form source (`.f`, `.f77`)

Column 1 = comment marker (`C` or `*`), columns 1–5 = label, column 6 = continuation, columns 7–72 = code. When reviewing legacy code, watch for lines silently truncated at column 72.

```fortran
C     ❌ Old fixed-form: easy to introduce invisible bugs
      REAL X
      X = 1.0 + 2.0 +
     &    3.0

! ✅ Free-form (.f90/.f95/.f03): use this for new code
real :: x
x = 1.0 + 2.0 + &
    3.0
```

### Arithmetic IF — never use

```fortran
! ❌ Do not use: branches on sign of expression
IF (x - y) 10, 20, 30

! ✅ Use standard block IF
if (x < y) then
  ...
else if (x == y) then
  ...
else
  ...
end if
```

### Assumed-length character `(*)` in modern code

Replace `character*(*)` dummy arguments with `character(len=*)` (assumed-length, read-only) or `character(len=:), allocatable` (Fortran 2003).

---

## Tooling and Build Checks

```bash
# GFortran: enable all warnings and standard conformance
gfortran -Wall -Wextra -Wimplicit-interface -Wunused \
         -fcheck=all -std=f2018 -O2 ...

# Intel IFX/IFORT: strict conformance
ifx -warn all -stand f18 -check all ...

# NAG Fortran: strictest standard checker
nagfor -C=all -f2018 -w=undef ...

# Static analysis
flint <source>       # Fortran linter
fprettify --indent 2 # auto-formatter

# Sanitizers via GFortran
gfortran -fsanitize=address,undefined -fno-omit-frame-pointer -g ...
```

---

## Review Checklist

### Correctness
- [ ] `implicit none` in every program unit
- [ ] All variables have explicit type declarations
- [ ] Kind parameters used consistently — no bare `real` / `double precision`
- [ ] Literal constants have correct kind suffixes (`1.0_dp` not `1.0`)
- [ ] Array lower bounds not assumed to be 1 without verification
- [ ] Integer overflow impossible in index/size arithmetic

### Design
- [ ] `intent(in/out/inout)` declared for all dummy arguments
- [ ] Assumed-shape `(:)` used instead of assumed-size `(*)`
- [ ] Modules used instead of COMMON blocks
- [ ] `use` statements have `only` lists
- [ ] Pure/elemental used where procedures have no side effects
- [ ] No use of EQUIVALENCE, ENTRY, or arithmetic IF

### Memory
- [ ] ALLOCATE checked with `stat=` and `errmsg=`
- [ ] All allocatable variables deallocated on every exit path (or scope-exit relied on intentionally)
- [ ] No non-contiguous array sections passed to C/MPI expecting contiguous data

### Error Handling
- [ ] I/O operations use `iostat=` / `iomsg=`
- [ ] Errors use `error stop` not bare `stop`
- [ ] Failing allocations produce informative messages

### Concurrency
- [ ] OpenMP reductions use `reduction()` clause, not shared accumulation
- [ ] OpenMP loop temporaries declared `private`
- [ ] Coarray remote accesses preceded by `sync`
