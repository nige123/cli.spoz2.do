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
