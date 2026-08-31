#| SPOZ2 — describes what software is supposed to be doing, in a form
#| humans and AI can both read.  This module is the small public front
#| door: parse text or a file into a SPOZ2::Model::Spec.
use SPOZ2::Grammar;
use SPOZ2::Actions;
use SPOZ2::Model;
unit module SPOZ2;

sub parse-spoz2(Str $text --> Spec) is export {
    my $m = SPOZ2::Grammar.parse($text, actions => SPOZ2::Actions.new)
        or die "SPOZ2: could not parse specification";
    $m.made;
}

sub parse-spoz2-file(IO() $path --> Spec) is export {
    parse-spoz2($path.slurp);
}

#| Append a new invariant entry to spec text and return the new text.
#| This is the only write operation: it appends, so history survives by
#| construction — and that is still verified (parse + problems + guard)
#| before the new text is returned.  Same name + later since supersedes.
sub add-invariant(Str $text, Str :$name!, Str :$since!, Str :$prose! --> Str) is export {
    die "SPOZ2: invalid invariant name '$name' (word characters and hyphens only)"
        unless $name ~~ /^ <[\w-]>+ $/;
    die "SPOZ2: invalid version '$since'"
        unless $since ~~ /^ \d+ [ '.' \d+ ]* $/;
    die "SPOZ2: an invariant needs prose — the text is its meaning"
        unless $prose.trim;

    my $old = parse-spoz2($text);

    my $entry = "invariant $name\n  since $since\n"
              ~ wrap-prose($prose.trim);
    my $new-text = $text.subst(/\s* $/, "\n\n") ~ $entry;

    my $new = parse-spoz2($new-text);
    if $new.problems -> @p {
        die "SPOZ2: refusing to add — { @p.join('; ') }";
    }
    if guard-history($old, $new) -> @v {
        die "SPOZ2: refusing to add — { @v.join('; ') }";
    }
    $new-text;
}

#| Retire an invariant: add `until` to its latest entry, optionally
#| appending the reason as prose.  These are the only two edits ever
#| made to an existing entry, and both are legal under the guard —
#| which is verified before the new text is returned.
sub retire-invariant(Str $text, Str :$name!, Str :$until!, Str :$reason = '' --> Str) is export {
    die "SPOZ2: invalid version '$until'"
        unless $until ~~ /^ \d+ [ '.' \d+ ]* $/;

    my $old = parse-spoz2($text);
    my @h = $old.history($name);
    die "SPOZ2: no invariant named '$name'" unless @h;
    my $target = @h.tail;
    die "SPOZ2: '$name' (since {$target.since}) is already retired (until {$target.until})"
        if $target.until.defined;

    # locate the target entry's block in the text by name + since
    my @lines = $text.lines;
    my ($block-start, $block-end);
    my $i = 0;
    while $i < @lines {
        if @lines[$i] ~~ /^ 'invariant' \h+ (<[\w-]>+) \h* $/ and ~$0 eq $name {
            my $j = $i + 1;
            my $since;
            while $j < @lines and @lines[$j] !~~ /^\S/ {
                $since = Version.new(~$0) if @lines[$j] ~~ /^ \h+ 'since' \h+ (\S+)/;
                $j++;
            }
            if $since.defined and $since == $target.since {
                ($block-start, $block-end) = $i, $j;
                last;
            }
            $i = $j;
        }
        else { $i++ }
    }
    die "SPOZ2: could not locate the entry for '$name' since {$target.since} in the text"
        without $block-start;

    my $since-idx = ($block-start ..^ $block-end).first({ @lines[$_] ~~ /^ \h+ 'since' \h/ });
    @lines.splice($since-idx + 1, 0, "  until $until");
    $block-end++;
    if $reason.trim {
        my $last = ($block-start ..^ $block-end).grep({ @lines[$_].trim ne '' }).tail;
        @lines.splice($last + 1, 0, wrap-prose($reason.trim).lines);
    }
    my $new-text = @lines.join("\n") ~ "\n";

    my $new = parse-spoz2($new-text);
    if $new.problems -> @p {
        die "SPOZ2: refusing to retire — { @p.join('; ') }";
    }
    if guard-history($old, $new) -> @v {
        die "SPOZ2: refusing to retire — { @v.join('; ') }";
    }
    $new-text;
}

#| A starter .spoz2 for a codebase: the mechanical half of distilling.
#| The judgement half — reading the code and writing the invariants as
#| intent — belongs to an agent or human afterwards.
sub distill-scaffold(Str :$name!, Str :$version! --> Str) is export {
    die "SPOZ2: invalid version '$version'"
        unless $version ~~ /^ \d+ [ '.' \d+ ]* $/;
    my $sys = $name.lc.subst(/<-[\w-]>+/, '-', :g).subst(/^ '-'+ | '-'+ $/, '', :g);
    die "SPOZ2: cannot make a system name from '$name'" unless $sys;

    qq:to/END/;
    spoz2 0.1

    # $sys described in SPOZ2: intended behaviour, not implementation.
    # Distilled starting at version $version.  History starts here —
    # earlier versions are not reconstructed.
    #
    # SPOZ2 conventions: an invariant is a named rule bound to versions
    # (since, and until when retired).  History is append-only: a change
    # of intent is a NEW entry with the same name and a later "since";
    # old entries stay and remain authoritative for their versions.
    # Never edit or delete an existing entry.  "spoz2 guard" enforces
    # this; "spoz2 add" and "spoz2 retire" are the safe write paths.
    #
    # TODO (agent or human): read the codebase and replace the system
    # prose below, then write the invariants — the rules that matter,
    # each as self-contained prose, all "since $version".  State intent
    # (what must hold and why), not implementation detail.

    system $sys
      TODO: what this system is for, in a few sentences of plain prose.
    END
}

#| Parse an agent's drafted entry.  The agent replies in a fixed plain
#| shape (name: / since: / prose: then continuation lines) so no JSON
#| dependency is needed.  Code fences and surrounding chatter before
#| the "name:" line are tolerated; everything after "prose:" is prose.
sub parse-agent-entry(Str $response --> Map) is export {
    my @lines = $response.lines.grep({ !.starts-with('```') });
    my $start = @lines.first(*.starts-with('name:'), :k);
    die "SPOZ2: agent reply has no 'name:' line:\n$response" without $start;

    my ($name, $since, @prose);
    for @lines[$start .. *] -> $line {
        if !$since.defined and $line ~~ /^ 'since:' \s* (\S+) / {
            $since = ~$0;
        }
        elsif !$name and $line ~~ /^ 'name:' \s* (\S+) / {
            $name = ~$0;
        }
        elsif $line ~~ /^ 'prose:' \s* (.*) / {
            @prose.push: ~$0;
        }
        elsif @prose {
            @prose.push: $line.trim;
        }
    }
    die "SPOZ2: agent reply has no 'since:' line:\n$response" without $since;
    die "SPOZ2: agent reply has no 'prose:' line:\n$response" unless @prose;
    Map.new: name => $name, since => $since, prose => @prose.join("\n").trim;
}

#| Lay prose out as indented lines: existing line breaks are kept, and
#| long lines are wrapped at word boundaries to stay readable.
sub wrap-prose(Str $prose --> Str) {
    my @out;
    for $prose.lines -> $line {
        my $current = '';
        for $line.words -> $word {
            if $current and ($current ~ ' ' ~ $word).chars > 70 {
                @out.push: $current;
                $current = $word;
            }
            else {
                $current = $current ?? "$current $word" !! $word;
            }
        }
        @out.push: $current if $current;
    }
    @out.map({ "  $_\n" }).join;
}
