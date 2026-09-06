# spoz2

**A SPOZ2 says what something is supposed to do.**

SPOZ2 ≈ *supposed to*.

For a software project, a `SPOZ2` file gives humans and AI coding agents a
durable, shared expression of product intent: the gist, intended behaviours,
invariants, constraints and the external standards it answers to — kept
beside the source and versioned with it.

A SPOZ2 earns its place when it stops you having to explain the same
important thing to another AI (or colleague) again.

`spoz2` is a small command-line tool for creating, checking and maintaining
SPOZ2 files. It works completely offline, needs no account, and the files it
reads and writes are plain text that belongs to your project.

## File convention

| File | Meaning |
|------|---------|
| `SPOZ2` | The canonical root intent file for a project. No extension. Sits beside `README.md`, `LICENSE`, `Dockerfile`. |
| `*.spoz2` | Additional or standalone SPOZ2 documents (`docs/security.spoz2`, `api/payments.spoz2`). Same format. |

`README` says *here is what you should know about this project*.
`SPOZ2` says *here is what this project is supposed to do*.

`spoz2.do` is the tooling / product brand. It is **not** a file name: never
create a file called `spoz2.do` in a project.

A large repository may contain several root-style `SPOZ2` files (for example
one per service). `spoz2` uses the nearest one found by walking upward from
the current directory.

## Quick start

```text
$ spoz2 init
Created SPOZ2

$ spoz2 add gist "A tiny service that issues and verifies sign-in codes."
Set gist.

$ spoz2 add invariant "Only one active session may exist per user."
Added invariant.

$ spoz2 add behaviour "A user can request a sign-in code by email."
Added behaviour.

$ spoz2 check
OK SPOZ2
```

Commit the `SPOZ2` file to Git. Its history *is* the history of your intent:

```text
$ spoz2 log
2026-08-23  7c3a129  Clarify session invariant
2026-08-22  12bd092  Add initial SPOZ2

$ spoz2 diff HEAD~1
```

## Commands

```text
spoz2 init                         create a SPOZ2 in the current directory (never overwrites)
spoz2 show [FILE] [SECTION]        print the SPOZ2, or one section (e.g. `spoz2 show gist`)
spoz2 check [FILE]                 validate structure; exit 1 on errors
spoz2 add KIND TEXT [--file=FILE]  append an entry; KIND is gist, behaviour, invariant,
                                   constraint, decision, direction or reference
                                   (gist needs --replace once set)
spoz2 log [FILE]                   Git history of the SPOZ2
spoz2 diff [FILE] [REV [REV]]      Git diff of the SPOZ2 (working tree vs last commit by default)
```

`FILE` is an explicit `.spoz2` document. Without it, the nearest `SPOZ2` in
the current directory or its parents is used, so `spoz2 show` works from deep
inside `src/`.

`spoz2 check` validates *structure* only — that the file parses, has exactly
one non-empty gist, no duplicated sections, and well-formed entries. It does
not, and cannot, judge whether the intent is *good*. That is your job.

## Format

Deliberately small, plain text, Git-friendly, obvious to a human or an LLM:

```text
SPOZ2 0.1

gist:
    A small tool for ...

behaviours:
    - Does X.
    - Does Y, which may run
      onto a continuation line.

invariants:
    - X must always remain true.

constraints:
    - Must run offline.

decisions:
    - Raku, because the author wants to read and change the tool quickly.

direction:
    - Print a compact context block for AI tools (not built yet).

references:
    - eu-cra: <stable clause identifier>
    - acme-policy: SEC-14
```

Rules:

- First line: `SPOZ2 <version>`. Currently `SPOZ2 0.1`.
- A section header is a word at column 0 followed by `:` (`gist:`).
- Everything under a header is indented. `gist` is free text; the other
  sections are lists of `- ` entries. An indented line without `- ` continues
  the previous entry.
- Lines starting with `#` at column 0 are comments.
- Known sections: `gist`, `behaviours`, `invariants`, `constraints`,
  `decisions`, `direction`, `references`. `decisions` records significant
  choices and why; `direction` records where intent is heading, clearly
  separated from what is implemented. Unknown sections are preserved and
  reported as a warning, not an error, so the format can grow.
- A `reference` is a durable pointer to an external authority (a standard, a
  policy, a ticket). SPOZ2 references standards; it does not copy them in.

`spoz2 add` edits the file in place by inserting lines (word-wrapped at 80
columns) — it never rewrites your formatting or comments. Your editor remains
the primary tool.

## Install

Requires [Rakudo](https://rakudo.org) (Raku) and, for `log`/`diff`, Git.

```text
git clone <this repository> spoz2
ln -s "$PWD/spoz2/bin/spoz2" ~/bin/spoz2     # or: cd spoz2 && zef install .
```

`bin/spoz2` finds its own `lib/` when run from a checkout (including via a
symlink), so no install step is strictly necessary.

Tests:

```text
prove --ext .rakutest -e 'raku -Ilib' t/
```

## Principles

- The format and this CLI are open and useful without any service. The file
  belongs to the project.
- No network, no telemetry, no accounts, no database, no TUI.
- History comes from Git, not from an invented versioning scheme.
- Deterministic validation is not a judgement of product thinking.

This project keeps its own `SPOZ2`. Read it.
