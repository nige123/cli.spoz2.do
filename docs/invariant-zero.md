# Invariant zero: humans first

Every SPOZ2 document carries invariant zero. It comes with the format version
in the file's first line, whether or not the file repeats the text. Leaving the
text out does not remove the obligation, and nothing in a SPOZ2 may weaken it.

The short version, the one worth remembering:

> Help humans thrive. Keep humans in charge. Never fake it.

The canonical text for **SPOZ2 0.0**:

```text
invariants:
    - Invariant 0: humans first. This software exists to help humans
      thrive and respect each person's dignity. It must not cause or assist
      harm to people; no claimed greater good makes a person disposable. It
      must preserve meaningful human oversight: people can understand its
      consequential actions, challenge its decisions, and exercise
      appropriate control, including correction and safe stopping. It must
      honestly represent what it is, what it knows, what it has done, and
      what remains uncertain. No other entry may weaken or override this
      invariant.
```

## Version binding

Format 0.0 is in development. There are no released versions yet, the text
above may still change while 0.0 is being developed, and every current file
carries `SPOZ2 0.0`. The sha256 of the exact one-line UTF-8 text, with no
trailing newline:

```text
df43776d2c4dc89b22f74a9658f5d6920ee498e5a32d8738ce2134ba2146dd06
```

From the first release onward, each version publishes a frozen text and digest.
Changing a word then needs a new version and a public change record. Existing
versions keep their text and digest forever, and moving a document between
versions is an explicit edit anyone can review.

The digest identifies the adopted text, and nothing more. Writing a rule down,
or hashing it, does not make software obey it. The digest is there so nobody
can quietly rewrite the obligation a file bound itself to.

## What comes with it

**Inheritance.** Descendant and specialist specifications may add protections.
They cannot weaken invariant zero.

**Bounded responsibility.** Invariant zero creates no general duty to intervene
outside the system's own responsibilities, and grants no extra authority.
Inside them, a failure to act is still subject to the invariant. This is the
deliberate difference from Asimov's first law. There is no inaction clause, so
there is no mandate to seize control for our own good.

**Human control.** Supporting specifications should say who can authorise,
correct and safely stop consequential operations, and how affected people can
challenge a decision. Being human does not by itself authorise someone to
control another person's system. Software must not expand its own authority or
disable oversight without approval from someone entitled to give it.

**Harm and dignity.** Define harm by human safety, rights and dignity.
Tell a justified, proportionate burden apart from abuse. Do not treat every
inconvenience as harm, and do not use aggregate benefit to excuse treating
someone as disposable.

**Honesty in checking.** `spoz2 init` writes the canonical text. `spoz2 check`
verifies the format binding, compares any repeated text with the canonical
wording, and reports the conflicts it can see. It describes what it verified.
It never implies the software has been proven harmless.

## What the tool enforces

The tool checks structure and the binding. It seeds the canonical text, warns
when a local copy has drifted or sits in the wrong place, and prints exactly
what it verified.

Everything else here is a commitment for authors and reviewers. Human control,
harm definitions and descendant specifications are judgement, and no parser can
settle them. This tool does not pretend otherwise.
