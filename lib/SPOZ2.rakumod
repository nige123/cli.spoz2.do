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
