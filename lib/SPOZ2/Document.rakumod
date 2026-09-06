unit class SPOZ2::Document;

#| The SPOZ2 format version this tool reads and writes.
constant FORMAT-VERSION is export = '0.1';

#| Placeholder gist written by `spoz2 init`.  `check` treats it as empty.
constant GIST-PLACEHOLDER is export = '<What is this thing supposed to do?>';

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
        if $_ ne FORMAT-VERSION {
            self!problem(1, "unsupported SPOZ2 version '$_' (this tool understands {FORMAT-VERSION})", :warning);
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
}
