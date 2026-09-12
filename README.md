# spoz2

**A SPOZ2 says what your software is supposed to do.**

Code tells you what software does. The `SPOZ2` file beside it says what the
software is *supposed* to do: the gist, the behaviours people rely on, the
invariants that must stay true. People read it. AI agents read it first. It
outlives every rewrite.

`spoz2` is a small command-line tool for writing and checking those files. It
works offline, needs no account, and everything it writes is plain text that
belongs to your project.

## Install

```text
curl -fsSL https://raw.githubusercontent.com/nige123/cli.spoz2.do/main/install | sh
```

That puts a `spoz2` launcher in `~/.local/bin`. If your machine needs the
runtime, the installer fetches it into your home directory. Nothing
system-wide, no sudo. Run the same command again to update. Git is the only
prerequisite.

Rather see every step?

```text
git clone https://github.com/nige123/cli.spoz2.do spoz2
ln -s "$PWD/spoz2/bin/spoz2" ~/.local/bin/spoz2     # or: cd spoz2 && zef install .
```

spoz2 is written in [Raku](https://raku.org), though you never need to think
about that. It runs anywhere: where a prebuilt runtime exists the installer
downloads one, and elsewhere it builds one for you and says so first. On
Windows, install [Rakudo](https://rakudo.org) and use the manual steps.

Run the tests with `prove --ext .rakutest -e 'raku -Ilib' t/`.

## Start

```text
$ spoz2 init
asking agent (claude -p) to distill /home/you/signin-codes ...
Created SPOZ2 (4 invariants, agent-drafted)
review it - the draft states intent, and only the maintainer knows intent.
AGENTS.md: installed
```

One command drafts your first SPOZ2 from the codebase's own account of itself,
and installs the agent entry points it finds. It never overwrites, and it never
prompts. Use `--/agent` for a plain scaffold instead.

Then the file is yours to keep true:

```text
$ spoz2 add gist --replace "A tiny service that issues and verifies sign-in codes."
$ spoz2 add invariant "Only one active session may exist per user."
$ spoz2 add behaviour "A user can request a sign-in code by email."
$ spoz2 check
OK SPOZ2
```

Commit it. Its Git history is the history of your intent, and `spoz2 log` reads
it back to you.

## Commands

```text
spoz2 init [--/agent]              write a SPOZ2 here, drafted by an agent (never overwrites)
spoz2 show [FILE] [SECTION]        print the file, or one section
spoz2 show invariant N             print invariant number N
spoz2 check [FILE]                 validate the structure; exit 1 on errors
spoz2 add KIND TEXT                add a gist, behaviour, invariant, constraint,
                                   decision, direction or reference
spoz2 log [FILE]                   the Git history of your intent
spoz2 diff [FILE] [REV [REV]]      what changed, working tree by default
spoz2 agent [install|status]       hand the specification to a coding agent
spoz2 register / spoz2 report      connect to the register and submit evidence
```

Without a `FILE`, spoz2 uses the nearest `SPOZ2` above you, so it works from
deep inside `src/`.

`spoz2 check` proves the file parses and is well formed. It cannot tell you
whether the intent is any good. That part stays yours.

## The file

`SPOZ2` has no extension and sits beside `README.md`. Extra documents take the
`.spoz2` suffix, like `docs/security.spoz2`. A README says what you should know
about a project. A SPOZ2 says what the project is supposed to do.

```text
SPOZ2 0.0

gist:
    A small service that issues and verifies sign-in codes.

behaviours:
    - A user can request a sign-in code by email.
    - A code expires ten minutes after it is issued, and can run
      onto a continuation line.

invariants:
    - Invariant 0: humans first. This software exists to help humans ...
    - Invariant 1: only one active session may exist per user.

constraints:
    - Runs offline.

decisions:
    - 2026-08-22: codes, not passwords, because nobody reuses a code.

direction:
    - Passkeys, once the invariants above are settled.

references:
    - eu-cra: <stable clause identifier>
```

A few rules keep it readable by people and machines alike:

- The first line names the format version. Today that is `SPOZ2 0.0`.
- A section header sits at column 0 and ends in `:`. Everything under it is
  indented. `gist` is free text, the rest are `- ` entries, and a further
  indented line continues the entry above.
- Lines starting with `#` are comments, for humans.
- Invariants carry stable numbers, so you can point at `Invariant 3` and be
  understood. `spoz2 add invariant` numbers them for you.
- `decisions` records a choice and why. `direction` is where you are heading,
  kept apart from what the software already does. A reference points at a
  standard, it never copies one in.
- Unknown sections are kept and reported as a warning, so the format can grow.

`spoz2 add` inserts lines and leaves your formatting and comments alone. Your
editor is still the main tool.

## Invariant zero: humans first

Every SPOZ2 opens with the same first law, and it arrives with the format
whether or not your file repeats the words.

> Help humans thrive. Keep humans in charge. Never fake it.

Nothing in a SPOZ2 may weaken it. `spoz2 init` writes the canonical text,
`spoz2 check` verifies the binding and any local copy, and a passing check
never means the software is safe or its claims are true.

The full text, the version story and the obligations that come with it are in
[docs/invariant-zero.md](docs/invariant-zero.md).

## Agents

`spoz2 agent` prints a self-contained packet for any coding agent: the
adherence protocol, the resolved path and digest, invariant zero, and your
specification. `spoz2 agent install` writes a short managed section into
`AGENTS.md`, and `CLAUDE.md` with `--claude`, telling agents to read it before
they plan or change anything. `--skill` adds a portable skill for places the
CLI cannot reach. `spoz2 agent status --strict` is the version for CI.

A packet proves neither that an agent read it nor that the software conforms.
Evidence comes from the checks an agent actually ran, which is why the protocol
asks it to separate those from the ones it merely suggests.

## Register your SPOZ2

Optional, and free to start. The [SPOZ2 register](https://spoz2.do) gives a
project a public card backed by evidence from its own checkout or CI.

```text
$ spoz2 register
SPOZ2 is not connected to a register yet.
  1. Sign up first (email passcode): https://spoz2.do/start
  2. Create a project there and mint a reporting token (shown once)
  3. Connect this SPOZ2 (add --github to set up GitHub Actions too):
       spoz2 register --url=<the project's reports URL> --token=<the token>
  4. Submit evidence: spoz2 report
```

`spoz2 report` submits evidence for one Git revision: whether the SPOZ2 is
there, its digest, its grammar line, how many invariants it holds, and the
outcome of a real check. The text of your SPOZ2 stays with you. Add `--github`
and register writes the workflow too, so every push reports.

Reports are advisory. A failed check is submitted honestly, a register error
still exits 0, and `spoz2 report` does not belong in a required merge check.

## Principles

- The format and the tool are useful on their own, with no service attached.
  The file belongs to your project.
- Offline by default. The only network calls are the register commands you ask
  for, and the optional agent behind `init`.
- History comes from Git, not from a versioning scheme we invented.
- A structural check is never a judgement of your product thinking.

This project keeps its own `SPOZ2`. Read it.

## Licence and trademark

Apache-2.0, see `LICENSE`.

spoz2 (tm) is a trademark of [Nige Ltd](https://nigelhamilton.com/#spoz2). The
code is open. The name and marks are Nige Ltd's.
