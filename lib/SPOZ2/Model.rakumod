#| Semantic representation of a SPOZ2 specification.
#|
#| These classes know nothing about the file syntax.  They hold the
#| intent, and answer the one question the first slice cares about:
#| "which invariants apply to version V?"
unit module SPOZ2::Model;

#| A named statement of intended behaviour, bound to a version range.
#| Applies to versions V where since <= V and (no until, or V < until).
class Invariant is export {
    has Str     $.name  is required;
    has Version $.since is required;
    has Version $.until;              # optional: retired at this version
    has Str     $.text = '';

    method covers(Version $v --> Bool) {
        return False if $v < $!since;
        return False if $!until.defined and $v >= $!until;
        True;
    }

    method range-str(--> Str) {
        $!until.defined ?? "$!since ..^ $!until" !! "$!since .."
    }
}

#| The software being described.
class System is export {
    has Str $.name is required;
    has Str $.text = '';
}

#| A whole specification: one system, many invariant entries (history
#| included).  Entries are kept in file order and never discarded.
class Spec is export {
    has Version    $.format is required;
    has System     $.system is required;
    has Invariant  @.entries;

    #| All entries sharing a name, oldest `since` first.
    method history(Str $name --> Seq) {
        @!entries.grep(*.name eq $name).sort(*.since)
    }

    #| Distinct invariant names, in first-appearance order.
    method names(--> Seq) { @!entries.map(*.name).unique }

    #| The invariants that govern version $v.
    #| For each name, the entry with the greatest `since` not after $v
    #| is the governing one; it applies unless it has been retired.
    method invariants-at(Version $v --> Seq) {
        gather for self.names -> $name {
            my $current = self.history($name).grep(*.since <= $v).tail;
            take $current if $current.defined and $current.covers($v);
        }
    }

    #| Every version at which something changes, ascending.
    method versions(--> Seq) {
        @!entries.map({ .since, (.until // Empty) }).flat.unique(:as(*.Str)).sort
    }

    #| What changed in intent between versions $a and $b: invariants
    #| that newly govern, that stopped governing, that are governed by
    #| a different entry, and that are unchanged.
    method changes(Version $a, Version $b --> Map) {
        my %at-a = self.invariants-at($a).map({ .name => $_ });
        my %at-b = self.invariants-at($b).map({ .name => $_ });
        my @names = self.names;
        Map.new:
            added   => @names.grep({ %at-b{$_}:exists and %at-a{$_}:!exists })
                             .map({ %at-b{$_} }).List,
            retired => @names.grep({ %at-a{$_}:exists and %at-b{$_}:!exists })
                             .map({ %at-a{$_} }).List,
            changed => @names.grep({ %at-a{$_}:exists and %at-b{$_}:exists
                                     and %at-a{$_} !=== %at-b{$_} })
                             .map({ (%at-a{$_}, %at-b{$_}) }).List,
            same    => @names.grep({ %at-a{$_}:exists and %at-a{$_} === %at-b{$_} }).List;
    }

    #| Structural checks that the grammar cannot express.
    #| Returns a list of problems; empty means the spec is well formed.
    method problems(--> List) {
        my @problems;
        for @!entries -> $e {
            if $e.until.defined and $e.until <= $e.since {
                @problems.push: "invariant {$e.name}: until ({$e.until}) must be after since ({$e.since})";
            }
        }
        for self.names -> $name {
            my @h = self.history($name);
            for @h.rotor(2 => -1) -> ($a, $b) {
                if $a.since == $b.since {
                    @problems.push: "invariant $name: two entries with since {$a.since}";
                }
            }
        }
        @problems.List;
    }
}

#| The append-only history check.  $new is a legal evolution of $old
#| when every entry in $old survives unchanged: an entry (identified by
#| name + since) may gain an `until` it did not have (retirement) and
#| may have prose appended, but existing prose, an existing `until`,
#| and the entry itself may never be altered or removed.
#| Returns a list of violations; empty means history is preserved.
sub guard-history(Spec $old, Spec $new --> List) is export {
    my @violations;

    if $old.system.name ne $new.system.name {
        @violations.push: "system renamed: '{$old.system.name}' is now '{$new.system.name}'";
    }

    my %new-entry = $new.entries.map({ ("{.name} @ {.since}") => $_ });

    for $old.entries -> $o {
        my $n = %new-entry{"{$o.name} @ {$o.since}"};
        without $n {
            @violations.push: "entry removed: invariant {$o.name} since {$o.since}";
            next;
        }
        if $o.until.defined {
            if !$n.until.defined {
                @violations.push: "retirement removed: invariant {$o.name} since {$o.since} lost until {$o.until}";
            }
            elsif $n.until != $o.until {
                @violations.push: "retirement changed: invariant {$o.name} since {$o.since} until {$o.until} is now until {$n.until}";
            }
        }
        unless $o.text eq '' or $n.text eq $o.text or $n.text.starts-with($o.text ~ "\n") {
            @violations.push: "prose rewritten: invariant {$o.name} since {$o.since} (existing prose may only be appended to)";
        }
    }

    @violations.List;
}
