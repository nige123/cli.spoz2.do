unit class SPOZ2::Document;

#| The SPOZ2 format version.  0.0 is IN DEVELOPMENT: there are no other
#| users yet, so the numbering was retro-fitted to start here (user
#| ruling, 2026-09-10) and the canonical text below may still change
#| while 0.0 is being developed.  Version immutability discipline (a
#| frozen text and digest per version, changes only via a new version
#| with a public change record) begins with the first release.
constant FORMAT-VERSION is export = '0.0';
constant @KNOWN-VERSIONS is export = ('0.0',);

#| Placeholder gist written by `spoz2 init`.  `check` treats it as empty.
constant GIST-PLACEHOLDER is export = '<What is this thing supposed to do?>';

#| Invariant zero: every conforming SPOZ2 incorporates the canonical
#| invariant zero of its format version, whether or not it repeats the
#| text locally (inheritance).  Omitting the text does not remove the
#| obligation; no entry may weaken or override it.  `init` seeds it;
#| `check` verifies the binding and any locally repeated text.  The
#| digest identifies the adopted text, nothing more: stating a rule, or
#| hashing it, does not make software obey it.
constant INVARIANT-ZERO is export =
    "Invariant 0: humans first. Help people thrive, and respect each person's "
    ~ 'dignity. Do no harm, and no greater good makes a person disposable. Keep '
    ~ 'humans in charge: explain consequential actions, accept challenge and '
    ~ 'correction, and stop safely when asked. Be honest about what this is, '
    ~ 'what it knows, what it has done, and what is uncertain. No other entry '
    ~ 'may weaken this.';

#| sha256 of the exact one-line UTF-8 canonical text, no trailing newline.
constant INVARIANT-ZERO-DIGEST is export =
    'b0c2482d4298e5bbbcb8de5b9da507a27668ed2fba28e46a414bafc1f4152360';

#| The short teaching version, for pages and slides, never for files.
constant INVARIANT-ZERO-SHORT is export =
    'Help humans thrive. Keep humans in charge. Never fake it.';

#| The designations that identify invariant zero, however the rest is
#| worded: 'Invariant 0:' now, plus the older 'Invariant 0.0:' and the
#| frozen 'Invariant zero:' spellings still found in existing files.
constant INVARIANT-ZERO-LEAD is export = 'Invariant 0:';
constant INVARIANT-ZERO-LEAD-DOTTED is export = 'Invariant 0.0:';
constant INVARIANT-ZERO-LEAD-LEGACY is export = 'Invariant zero:';
sub is-invariant-zero-text(Str $t --> Bool) is export {
    $t.starts-with(INVARIANT-ZERO-LEAD)
        || $t.starts-with(INVARIANT-ZERO-LEAD-DOTTED)
        || $t.starts-with(INVARIANT-ZERO-LEAD-LEGACY)
}

#| The explicit number of an invariant entry ('Invariant 3: ...' gives
#| '3'), or Str when the entry is unnumbered.  Numbers are plain
#| monotonic integers; 0 is the format's foundation invariant.
sub invariant-number(Str $t --> Str) is export {
    $t ~~ /^ 'Invariant ' (\d+) ':' / ?? ~$0 !! Str;
}

#| Known top-level sections, in canonical order, with their kind.
#| 'text' sections hold free text; 'list' sections hold "- " entries.
constant %SECTION-KIND is export =
    gist        => 'text',
    behaviours  => 'list',
    invariants  => 'list',
    constraints => 'list',
    decisions   => 'list',
    direction   => 'list',
    references  => 'list';

constant @KNOWN-SECTIONS is export = <gist behaviours invariants constraints decisions direction references>;

#| Singular nouns accepted by `spoz2 add`, mapped to their section.
constant %NOUN-SECTION is export =
    gist       => 'gist',
    behaviour  => 'behaviours',
    invariant  => 'invariants',
    constraint => 'constraints',
    decision   => 'decisions',
    direction  => 'direction',
    reference  => 'references';

#| Default indentation for entries written by this tool.
constant INDENT is export = '    ';

#| Entries written by this tool are wrapped at this width.
constant WRAP-WIDTH is export = 80;

class Problem {
    has Int  $.line    is required;
    has Str  $.message is required;
    has Bool $.warning = False;
    method Str(--> Str) { ($!warning ?? 'warning: ' !! '') ~ $!message }
}

class Item {
    has Int $.line is required;
    has Str $.text is required;
}

class Section {
    has Str  $.name is required;
    has Int  $.line is required;          # line of the "name:" header
    has Str  $.kind is required;          # text | list | unknown
    has Int  $.last-line is rw;           # last content line (header if none)
    has Str  $.indent is rw;              # indent of first entry, if any
    has Str  @.lines;                     # raw text lines (text sections)
    has Item @.items;                     # entries (list sections)

    method text(--> Str)     { @!lines.join("\n") }
    method is-empty(--> Bool) { !@!lines && !@!items }
}

has Str      $.source is required;
has IO::Path $.path;
has Str      $.version;
has Section  @.sections;
has Problem  @.problems;
has Str      @.lines;                     # raw source lines, 1-based via [line-1]

method load(IO::Path() $path --> SPOZ2::Document) {
    self.parse($path.slurp, :$path);
}

method parse(Str $source, IO::Path :$path --> SPOZ2::Document) {
    my $doc = self.bless(:$source, :$path);
    $doc!parse-lines;
    $doc!validate;
    $doc;
}

method section(Str $name --> Section) { @!sections.first(*.name eq $name) }
method sections-named(Str $name)      { @!sections.grep(*.name eq $name) }
method errors   { @!problems.grep(!*.warning) }
method warnings { @!problems.grep(*.warning) }
method ok(--> Bool) { !self.errors }

#| One line describing the invariant-zero binding this parse established.
#| `spoz2 check` prints it, so a successful check says what was verified
#| and never implies more.
method invariant-zero-status(--> Str) {
    my $v = ($!version.defined && $!version (elem) @KNOWN-VERSIONS) ?? $!version !! Str;
    return 'invariant zero: binding not established (unknown format version)' without $v;
    my $digest = INVARIANT-ZERO-DIGEST.substr(0, 12);
    my $inv    = self.section('invariants');
    my $zero   = $inv ?? $inv.items.first({ is-invariant-zero-text(.text) }) !! Nil;
    with $zero {
        return squish-ws(.text) eq squish-ws(INVARIANT-ZERO)
            ?? "invariant zero: repeated locally, matches the canonical SPOZ2 $v text (sha256 $digest)"
            !! "invariant zero: repeated locally but differs from the canonical SPOZ2 $v text (sha256 $digest binds regardless)";
    }
    "invariant zero: inherited from SPOZ2 $v (sha256 $digest); not repeated locally, still binding";
}

#| Problems sorted by line, formatted as "NAME:LINE: message".
method report(Str :$name = ($!path ?? $!path.Str !! 'SPOZ2')) {
    @!problems.sort(*.line).map({ "$name:{.line}: {.Str}" });
}

method !problem(Int $line, Str $message, Bool :$warning = False) {
    @!problems.push: Problem.new(:$line, :$message, :$warning);
}

method !parse-lines() {
    @!lines = $!source.lines;
    my Bool $header-seen = False;
    my Section $current;

    for @!lines.kv -> $i, $raw {
        my $n    = $i + 1;
        my $line = $raw.trim-trailing;

        next if $line eq '';                 # blank
        next if $line.starts-with('#');      # full-line comment at column 0

        if !$header-seen {
            $header-seen = True;
            if $line ~~ /^ 'SPOZ2' \s+ (\S+) $/ {
                $!version = ~$0;
                next;
            }
            self!problem($n, "expected 'SPOZ2 {FORMAT-VERSION}' header on the first line");
            # fall through and treat this line normally
        }

        if $line ~~ /^ (<[\w-]>+) ':' $/ {
            my $name = ~$0;
            if self.section($name) -> $dup {
                self!problem($n, "duplicate section '$name' (first defined at line {$dup.line})");
            }
            my $kind = %SECTION-KIND{$name} // 'unknown';
            $current = Section.new(:$name, :line($n), :$kind, :last-line($n));
            @!sections.push: $current;
            next;
        }

        if $line ~~ /^ \S/ {
            if $line ~~ /^ 'SPOZ2' \s/ {
                self!problem($n, "unexpected second 'SPOZ2' header");
            }
            else {
                self!problem($n, "unexpected text at column 0: '{$line.substr(0, 40)}' (section headers look like 'name:'; entries are indented)");
            }
            next;
        }

        # An indented line: content belonging to the current section.
        without $current {
            self!problem($n, "entry before any section header");
            next;
        }

        $current.last-line = $n;
        my $indent  = $line.match(/^ \s+/).Str;
        my $content = $line.trim-leading;
        $current.indent //= $indent;

        if $current.kind eq 'text' {
            $current.lines.push: $content;
            next;
        }

        if $content ~~ /^ '-' [\s+ (.*)]? $/ {
            my $text = $0 ?? $0.Str.trim !! '';
            self!problem($n, "empty entry in section '{$current.name}'") if $text eq '';
            $current.items.push: Item.new(:line($n), :$text);
        }
        elsif $current.items {
            # continuation of the previous entry
            my $last = $current.items.pop;
            $current.items.push: Item.new(:line($last.line), :text($last.text ~ ' ' ~ $content));
        }
        elsif $current.kind eq 'list' {
            self!problem($n, "expected a '- ' entry in section '{$current.name}'");
        }
        else {
            # unknown section with free text: keep it as text
            $current.lines.push: $content;
        }
    }

    unless $header-seen {
        self!problem(1, "expected 'SPOZ2 {FORMAT-VERSION}' header (file is empty)");
    }
}

method !validate() {
    with $!version {
        if $_ !(elem) @KNOWN-VERSIONS {
            self!problem(1, "unsupported SPOZ2 version '$_' (this tool understands {@KNOWN-VERSIONS.join(' and ')})", :warning);
        }
    }

    my @gists = self.sections-named('gist');
    if !@gists {
        self!problem(@!lines.elems max 1, "missing 'gist:' section");
    }
    else {
        my $gist = @gists[0];
        my $text = $gist.text.trim;
        if $text eq '' {
            self!problem($gist.line, "gist is empty");
        }
        elsif $text eq GIST-PLACEHOLDER {
            self!problem($gist.line, "gist is still the placeholder from 'spoz2 init'");
        }
    }

    for @!sections -> $s {
        next if %SECTION-KIND{$s.name}:exists;
        self!problem($s.line, "unknown section '{$s.name}'", :warning);
    }

    # Invariant zero binds through the format version: a file that omits
    # the text is still bound by it (inheritance).  Warnings, never errors.
    my $v     = ($!version.defined && $!version (elem) @KNOWN-VERSIONS) ?? $!version !! Str;
    my $canon = $v.defined ?? INVARIANT-ZERO !! Str;
    my $inv   = self.section('invariants');
    my $first = $inv ?? $inv.items.head !! Nil;
    my $zero  = $inv ?? $inv.items.first({ is-invariant-zero-text(.text) }) !! Nil;
    if $zero.defined {
        unless $first.defined && is-invariant-zero-text($first.text) {
            self!problem($zero.line,
                "invariant zero ('humans come first') should be the first invariant", :warning);
        }
        if $canon.defined && squish-ws($zero.text) ne squish-ws($canon) {
            self!problem($zero.line,
                "invariant zero text differs from the canonical SPOZ2 $v wording (the canonical text binds regardless)",
                :warning);
        }
    }
    # Omission is legitimate: the binding is inherited from the format
    # version and reported by invariant-zero-status.

    # Numbered invariants are references; a duplicate number defeats the
    # reference, so it is an error.  Unnumbered entries stay valid.
    if $inv.defined {
        my %first-line;
        for $inv.items -> $item {
            my $n = invariant-number($item.text);
            next without $n;
            with %first-line{$n} -> $at {
                self!problem($item.line, "duplicate invariant number '$n' (first used at line $at)");
            }
            else { %first-line{$n} = $item.line }
        }
    }
}

#| Whitespace-insensitive comparison for canonical text (entries are
#| wrapped and rejoined; spacing must not defeat the match).
my sub squish-ws(Str $s --> Str) { $s.words.join(' ') }
