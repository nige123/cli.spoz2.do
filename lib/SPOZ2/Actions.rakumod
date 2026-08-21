#| Builds SPOZ2::Model objects from a SPOZ2::Grammar parse tree.
use SPOZ2::Model;
unit class SPOZ2::Actions;

method TOP($/) {
    my @blocks  = $<block>».made;
    my @systems = @blocks.grep(System);
    die "SPOZ2: expected exactly one 'system' block, found {@systems.elems}"
        unless @systems.elems == 1;
    make Spec.new(
        format  => $<format-line><format>.made,
        system  => @systems[0],
        entries => @blocks.grep(Invariant),
    );
}

method block($/)   { make ($<system> // $<invariant>).made }
method version($/) { make Version.new(~$/) }
method prose($/)   { make ~$<text> }

method system($/) {
    make System.new(name => ~$<name>, text => $<body>.made<text>);
}

method invariant($/) {
    my %b = $<body>.made;
    die "SPOZ2: invariant {$<name>} has no 'since'" unless %b<since>;
    make Invariant.new(
        name  => ~$<name>,
        since => %b<since>,
        until => %b<until> // Version,   # type object when absent
        text  => %b<text>,
    );
}

#| A body becomes a hash: the fields by name, plus the prose as `text`.
method body($/) {
    my %b;
    for $<field> -> $f {
        my $key = ~$f<key>;
        die "SPOZ2: duplicate field '$key'" if %b{$key}:exists;
        %b{$key} = $f<value>.made;
    }
    %b<text> = $<prose>».made.join("\n");
    make %b;
}
