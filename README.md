# spoz2

**A SPOZ2 says what something is supposed to do.**

SPOZ2 ≈ *supposed to*.

For a software project, a `SPOZ2` file gives humans and AI coding agents a
durable, shared expression of product intent: the gist, intended behaviours,
invariants, constraints and the external standards it answers to - kept
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

## Invariant zero

Every conforming SPOZ2 document incorporates the canonical invariant zero of
its declared format version, whether or not it repeats the text locally.
Omitting the text does not remove the obligation, and no entry in any SPOZ2
may weaken or override it. The short teaching version:

> Help humans thrive. Keep humans in charge. Never fake it.

The canonical text for **SPOZ2 0.0** (the in-development format version):

```text
invariants:
    - Invariant 0.0: humans first. This software exists to help humans
      thrive and respect each person's dignity. It must not cause or assist
      harm to people; no claimed greater good makes a person disposable. It
      must preserve meaningful human oversight: people can understand its
      consequential actions, challenge its decisions, and exercise
      appropriate control, including correction and safe stopping. It must
      honestly represent what it is, what it knows, what it has done, and
      what remains uncertain. No other entry may weaken or override this
      invariant.
```

### Version binding

The format is **version 0.0, in development**: there are no released
versions yet, the canonical text above may still change while 0.0 is being
developed, and every current file and reference carries `SPOZ2 0.0`. The
current canonical text's sha256 (exact one-line UTF-8 text, no trailing
newline):

```text
d072a03f407dc76d63c84c5fc278b2e23cf5527873d32d7e4323763874f56605
```

From the first release onward, each version publishes a frozen canonical
text and digest; changing a word then requires a new format version and a
public change record, existing versions keep their text and digest
forever, and moving a document between versions is an explicit, reviewable
edit to its header line. The digest identifies the adopted text, nothing
more. Stating a rule, or hashing it, does not make software obey it; the
digest exists so nobody can quietly rewrite the obligation a file bound
itself to.

### Supporting obligations

1. **Inheritance.** Descendant and specialist specifications may add
   protections but cannot weaken or override invariant zero.
2. **Bounded responsibility.** Invariant zero creates no general duty to
   intervene outside the system's defined responsibilities and grants no
   additional authority. Within those responsibilities, failures to act
   remain subject to the invariant. (This is the deliberate difference from
   Asimov's first law: no inaction clause, so no mandate to seize control
   "for our own good".)
3. **Human control.** Supporting specifications must identify who can
   authorise, correct and safely stop consequential operations, and how
   affected people can challenge decisions. Being human does not
   automatically authorise someone to control another person's system.
   Software must not expand its own authority or disable oversight without
   explicit, appropriately authorised approval.
4. **Harm and dignity.** Define harm with reference to human safety, rights
   and dignity. Distinguish justified, proportionate burdens from abuse. Do
   not treat every inconvenience as prohibited harm, or invoke aggregate
   benefit to excuse treating someone as disposable.
5. **Honesty in checking.** `spoz2 init` writes the canonical text.
   `spoz2 check` verifies the format binding and any repeated canonical
   text, and reports conflicts it can detect. A successful check describes
   what was verified; it never implies that the software has been proven
   harmless or that all semantic conflicts have been ruled out.

### What the tool enforces, and what stays documentation

Implemented today: `init` seeds the current canonical text first;
`check` verifies the declared version's binding, compares any locally
repeated text against that version's canonical wording, warns on drift or
misplacement, and prints exactly what it verified. Documented obligations
(human control, harm definitions, descendant specifications) are
commitments for authors and reviewers; no parser can enforce them, and
this tool does not pretend to.

## Quick start

```text
$ spoz2 init
asking agent (claude -p) to distill /home/you/signin-codes ...
Created SPOZ2 (4 invariants, agent-drafted)
review it - the draft states intent, and only the maintainer knows intent.
AGENTS.md: installed
```

One command does everything: it drafts the SPOZ2 and installs the agent
entry points it detects - `AGENTS.md` always, plus `CLAUDE.md` and the
portable skill when the repository shows Claude use. No options to look
up, and it never prompts (`--/agents` opts out; `--agents` forces all
three).

By default `init` drafts the first real specification for you: it hands the
scaffold plus the codebase's own account of itself (README, changelog, file
layout) to an agent command - `SPOZ2_AGENT_CMD`, default `claude -p` - and
validates the draft before writing it. Without a working agent it falls back
to a plain scaffold, loudly. `spoz2 init --/agent` skips the agent and writes
the scaffold deliberately. Either way, the file is then yours to maintain:

```text
$ spoz2 add gist --replace "A tiny service that issues and verifies sign-in codes."
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
spoz2 init [--/agent]              create a SPOZ2 in the current directory (never overwrites);
                                   an agent command (SPOZ2_AGENT_CMD, default `claude -p`)
                                   drafts it from the codebase; --/agent writes the scaffold
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

`spoz2 check` validates *structure* only - that the file parses, has exactly
one non-empty gist, no duplicated sections, and well-formed entries. It does
not, and cannot, judge whether the intent is *good*. That is your job.

## Format

Deliberately small, plain text, Git-friendly, obvious to a human or an LLM:

```text
SPOZ2 0.0

gist:
    A small tool for ...

behaviours:
    - Does X.
    - Does Y, which may run
      onto a continuation line.

invariants:
    - Invariant 0.0: humans first. This software exists to help humans
      thrive and respect each person's dignity. It must not cause or assist
      harm to people; no claimed greater good makes a person disposable. It
      must preserve meaningful human oversight: people can understand its
      consequential actions, challenge its decisions, and exercise
      appropriate control, including correction and safe stopping. It must
      honestly represent what it is, what it knows, what it has done, and
      what remains uncertain. No other entry may weaken or override this
      invariant.
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

- First line: `SPOZ2 <version>`. Currently `SPOZ2 0.0`, the in-development
  version (see Version binding above).
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
- The first invariant is invariant zero (see above); `spoz2 check` warns when
  it is missing or not first.

`spoz2 add` edits the file in place by inserting lines (word-wrapped at 80
columns) - it never rewrites your formatting or comments. Your editor remains
the primary tool.

## Agents: make the SPOZ2 easy to follow

The shortest adoption path is just `spoz2 init` - it installs the agent
entry points it detects automatically. In a repository that already has
its SPOZ2:

```text
$ spoz2 agent install --claude --skill
AGENTS.md: installed
CLAUDE.md: installed
.claude/skills/spoz2/SKILL.md: installed
```

`spoz2 agent` prints a self-contained packet for any coding agent: the
canonical adherence protocol, the resolved SPOZ2 path, its format version
and a sha256 of the exact file bytes, the inherited Invariant Zero, and
the specification itself, clearly delimited as project content. `--json`
emits the same as a versioned schema (`spoz2-agent-packet/1`) with
metadata, protocol and specification in separate fields. The command is
read-only, deterministic and fully offline; it fails clearly on a missing
or invalid specification or an unresolved binding rather than inventing a
valid packet.

`spoz2 agent install` writes a short managed section (between
`SPOZ2-AGENT` markers) into `AGENTS.md` - and `CLAUDE.md` with `--claude`
- telling agents to run `spoz2 agent` before planning or changing
anything. `--skill` also generates the official portable skill at
`.claude/skills/spoz2/SKILL.md`, which embeds the full protocol so the
core workflow works even where the CLI is unavailable: read the root
`SPOZ2` directly, apply the protocol, and say that CLI validation and
inherited Invariant Zero resolution were not performed. All integrations
are generated from the one bundled protocol; project invariants stay in
the SPOZ2 file, never in instruction files. Everything outside the marked
sections is preserved, repeat installs are idempotent, and malformed
markers or symlinks escaping the repository make the install fail without
touching anything. `spoz2 init` offers the same install when run
interactively; in scripts, pass `--agents` explicitly (it never prompts).

`spoz2 agent status` reports what is actually on disk: whether the SPOZ2
is present and valid, whether its inherited binding resolves, and which
integrations are current, stale, malformed or absent - with
machine-readable `--json`. Exit codes: plain status is informational and
exits 0; `--strict` is the CI check and exits 1 on an invalid or missing
specification, an unresolved binding, or a stale or malformed managed
section (absent integrations are not failures).

Honesty, kept deliberately: a printed packet proves neither that an agent
read it nor that software conforms; "integration installed" is a
statement about files, not about agent behaviour; `spoz2 check` remains
structural validation, never a semantic proof. Evidence that software
satisfies an invariant comes from the checks an agent actually runs and
reports - the protocol requires agents to distinguish checks run from
checks suggested, and to report per-invariant assessment, evidence and
remaining gaps. CI validation (`spoz2 check`, `spoz2 agent status
--strict`) complements agent instructions; it does not replace review.

## Registering (optional): make your SPOZ2 discoverable

The [SPOZ2 register](https://spoz2.do) gives a project a public
card backed by evidence from its own checkout or CI. Registering requires
signing up first — that happens on the web (email passcode), not in the
CLI; `spoz2 register` walks you through it:

```text
$ spoz2 register
SPOZ2 is not connected to a register yet.
  1. Sign up first (email passcode): https://spoz2.do/start
  2. Create a project there and mint a reporting token (shown once)
  3. Connect this SPOZ2 (add --github to set up GitHub Actions too):
       spoz2 register --url=<the project's reports URL> --token=<the token>
  4. Submit evidence: spoz2 report
```

The reports URL is saved in `.spoz2-register` beside the SPOZ2 (safe to
commit); the token is saved under `~/.config/spoz2/` with mode 0600 and
never in the repository (CI sets `SPOZ2_REGISTER_TOKEN` or `S2R_TOKEN`
instead). `spoz2 report` then submits the register's `s2r-report` evidence
for the exact Git revision: whether the SPOZ2 is present, its sha256
digest, its grammar line, the invariant count and the outcome of a real
`spoz2 check` — **never the text of your SPOZ2**.

With `--github`, register also writes `.github/workflows/spoz2.yml`, which
installs spoz2 (its runtime cached between runs) and runs `spoz2 report` on
every push, so CI evidence carries a real syntax check. It hands the token
to the GitHub CLI on standard input as the repository secret `S2R_TOKEN`,
never overwrites a different workflow without `--force`, and leaves
committing and pushing to you.

Reports are advisory by design: a failed check is submitted honestly, and
a register error exits 0 (pass `--strict` to opt into a failing exit).
Never wire `spoz2 report` into a required merge or release check. These
two commands are the CLI's only network use besides the optional agent
behind `init`; everything else stays offline, and the file format itself
carries no registry fields.

## Install

One command:

```text
curl -fsSL https://raw.githubusercontent.com/nige123/cli.spoz2.do/main/install | sh
```

It fetches spoz2 into `~/.local/share/spoz2`, puts a `spoz2` launcher in
`~/.local/bin`, and verifies it runs. If the runtime spoz2 needs is not
already on your machine, the installer fetches that too - into your home
directory, nothing system-wide, no sudo. Re-running the command updates
spoz2. Git is the one prerequisite.

For the curious: spoz2 is written in [Raku](https://raku.org) and the
runtime is [Rakudo](https://rakudo.org) - but you don't need to know or
care about that to install or use it.

It works across operating systems and CPU architectures: the tool itself
is pure source. Where a prebuilt runtime exists (x86-64 Linux, Intel and
Apple-Silicon macOS) the installer downloads it; on other architectures
(ARM Linux, for example) it builds the runtime from source automatically -
a one-off that needs a C compiler and `make`, and it says so plainly
before starting. On Windows, install Rakudo from
[rakudo.org](https://rakudo.org) and use the manual steps below.

Manual install, if you prefer to see every step:

```text
git clone https://github.com/nige123/cli.spoz2.do spoz2
ln -s "$PWD/spoz2/bin/spoz2" ~/.local/bin/spoz2     # or: cd spoz2 && zef install .
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
- No network, no telemetry, no accounts, no database, no TUI. The one
  exception is the optional agent command behind `init`, which is external,
  visible and skippable; the CLI itself never touches the network.
- History comes from Git, not from an invented versioning scheme.
- Deterministic validation is not a judgement of product thinking.

This project keeps its own `SPOZ2`. Read it.

## Licence and trademark

Apache-2.0 - see `LICENSE`.

spoz2 (tm) is a trademark of [Nige Ltd](https://nigelhamilton.com/#spoz2).
The code is open; the name and marks are Nige Ltd's.
