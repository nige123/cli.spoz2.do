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
