# SPOZ2

**SPOZ2 describes what software is supposed to be doing, in a form humans and
AI can both understand.**

A `.spoz2` file sits beside a codebase and states the system's intended
behaviour as named, version-bound **invariants**.  It evolves with the
software, and it keeps its own history.

## Why it exists

Code tells you what a system *does*.  It rarely tells you what it is
*supposed* to do, or which of its behaviours are load-bearing and which are
accidents.  That gap is where humans and AI agents go wrong: they preserve
accidents, break intent, or silently change the rules.

SPOZ2 records intent separately from implementation so that it can be used to:

- create new software
- retrofit a baseline of intent onto an existing system
- guide changes and extensions
- translate or reimplement a system on another platform
- give AI agents authoritative constraints while they work on a codebase

## Implementation vs. intended behaviour

A SPOZ2 file is **not** a description of the current code.  It is the set of
things that must be true of the software, whatever the code currently happens
to do.  If the code and the SPOZ2 disagree, one of them is wrong — and finding
out which is the point.

## Invariants

An invariant is a named statement that must hold for the versions it applies
to.  Its **meaning is its prose**.  The structure around it exists only to give
it identity and scope:

```text
invariant one-active-now
  since 1.0
  A human may have only one active NOW item at any time.
  Starting a new NOW item ends the previous one.
```

## Version-bound invariants, and why they change

Invariants are authoritative but not immutable.  When intent changes, a new
entry with the **same name** and a later `since` is added.  The old entry is
never deleted: it stays authoritative for the versions it covered, and the pair
together record *how* intent moved and why.

```text
invariant one-active-now
  since 2.0
  A human may have at most one active NOW item per workspace.
  Version 2.0 introduced workspaces ...
```

An invariant can also be retired without replacement by giving it an `until`.
For any version *V* and name, the governing entry is the one with the greatest
`since` not after *V*, unless it has been retired at or before *V*.

## Deliberately strict here, loose there

SPOZ2 is strict where precision buys something — names, versions, the shape of
a file — and loose everywhere meaning lives.  Prose is never required to be
machine-executable.  SPOZ2 is not a programming language and is not trying to
become one.  New structure is only added when real use shows it is worth more
than the flexibility it removes.

The syntax is young and expected to change; the format line (`spoz2 0.1`)
exists so that it can.

## Files

```text
lib/SPOZ2/Grammar.rakumod   the Raku grammar (syntax only)
lib/SPOZ2/Actions.rakumod   parse tree -> model
lib/SPOZ2/Model.rakumod     Spec / System / Invariant, and "what applies at V?"
lib/SPOZ2.rakumod           parse-spoz2 / parse-spoz2-file
bin/spoz2                   tiny CLI: check | at | history
examples/now.spoz2          the first example: a focus tool across two versions
examples/invoicing.spoz2    a non-software example: the rules governing a company's invoices,
                            versioned by date (2020.07.15) as the law and contracts change
spoz2.spoz2                 SPOZ2 describing itself
t/                          tests
```

## Running

Needs Raku (tested with Rakudo 2026.07).  No dependencies.

```sh
# tests
prove --ext .rakutest -e 'raku -Ilib' t   # or: for t in t/*.rakutest; do raku -Ilib $t; done

# parse and validate a file
bin/spoz2 check examples/now.spoz2

# which invariants govern version 2.0?
bin/spoz2 at examples/now.spoz2 2.0

# how has one invariant changed over time?
bin/spoz2 history examples/now.spoz2 one-active-now

# add a new invariant entry (same name + later since supersedes; old entry stays)
bin/spoz2 add examples/now.spoz2 one-active-now 3.0 "The new rule, as prose."
bin/spoz2 add examples/now.spoz2 one-active-now 3.0 < prose.txt   # prose from stdin

# has history been rewritten?  (exit 1 if so — suitable for CI / pre-commit)
bin/spoz2 guard old.spoz2 new.spoz2   # compare two revisions
bin/spoz2 guard spoz2.spoz2           # compare working file against git HEAD
```

`guard` enforces "do not rewrite history" mechanically.  Between two
revisions of a file, entries may be added, an entry may gain an `until`
(retirement), and prose may be appended — but an existing entry's prose,
`until`, or presence may never change.  Anything a model or human rewrites
in place is reported and the check fails.

From Raku:

```raku
use SPOZ2;
my $spec = parse-spoz2-file('examples/now.spoz2');
.say for $spec.invariants-at(v2.0).map(*.name);
```
