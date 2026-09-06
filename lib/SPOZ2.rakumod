unit module SPOZ2;

use SPOZ2::Document;
use SPOZ2::Git;

constant VERSION is export = '0.1.0';

#| A user-facing error: message only, no stack trace.
class X::SPOZ2 is Exception {
    has Str $.message is required;
}
sub user-error(Str $message) { X::SPOZ2.new(:$message).throw }

constant ROOT-NAME is export = 'SPOZ2';

# ---------------------------------------------------------------- discovery

#| Walk upward from $start looking for a root SPOZ2 file.
sub find-root(IO::Path $start = $*CWD --> IO::Path) is export {
    my $dir = $start.resolve;
    loop {
        my $candidate = $dir.add(ROOT-NAME);
        return $candidate if $candidate.f;
        my $parent = $dir.parent;
        return Nil if $parent eq $dir;
        $dir = $parent;
    }
}

#| True when a CLI argument names a SPOZ2 document rather than a section or revision.
sub looks-like-file(Str $arg --> Bool) is export {
    $arg.ends-with('.spoz2') || $arg.IO.basename eq ROOT-NAME;
}

#| The document to operate on: an explicit path, or the nearest root SPOZ2.
sub resolve-target(Str $file?, IO::Path :$cwd = $*CWD --> IO::Path) is export {
    with $file {
        my $path = $file.IO.is-absolute ?? $file.IO !! $cwd.add($file);
        user-error("$file: no such file") unless $path.f;
        return $path;
    }
    find-root($cwd) // user-error(
        "No SPOZ2 found in this directory or its parents.\nRun 'spoz2 init' to create one.");
}

#| How a path is shown in messages: relative to the working directory.
sub display-name(IO::Path $path, IO::Path :$cwd = $*CWD --> Str) is export {
    my $rel = $path.resolve.relative($cwd.resolve);
    $rel.starts-with('../../..') ?? $path.resolve.Str !! $rel;
}

# ---------------------------------------------------------------- init

sub template(--> Str) is export {
    qq:to/END/;
    SPOZ2 {FORMAT-VERSION}

    # What is this project supposed to do?
    # Humans and AI tools should treat this file as the authoritative
    # expression of intent.  Edit it directly or use `spoz2 add ...`.

    gist:
        {GIST-PLACEHOLDER}

    behaviours:

    invariants:

    constraints:

    decisions:

    references:
    END
}

#| Create a root SPOZ2 in $dir.  Refuses to overwrite.
sub init(IO::Path :$dir = $*CWD --> IO::Path) is export {
    my $path = $dir.add(ROOT-NAME);
    user-error("{ROOT-NAME} already exists here; not overwriting") if $path.e;
    $path.spurt(template());
    $path;
}

# ---------------------------------------------------------------- show

#| Text of the whole document, or of one section (dedented body only).
sub show-text(IO::Path $path, Str $section? --> Str) is export {
    my $doc = SPOZ2::Document.load($path);
    without $section { return $doc.source }

    my @found = $doc.sections-named($section);
    user-error("no section '$section' in {$path.basename}") unless @found;

    my @out;
    for @found -> $s {
        my $from = $s.line;              # 1-based header line
        my $to   = $s.last-line;
        my @body = $doc.lines[$from .. $to - 1];   # lines after header up to last content
        my $indent = $s.indent // '';
        @out.append: @body.map({ .starts-with($indent) ?? .substr($indent.chars) !! .trim-leading });
    }
    @out.join("\n") ~ "\n";
}

# ---------------------------------------------------------------- check

#| Parse and validate.  Returns the Document; caller inspects .problems.
sub check-doc(IO::Path $path --> SPOZ2::Document) is export {
    SPOZ2::Document.load($path);
}

# ---------------------------------------------------------------- add

#| Add an entry to $path.  Returns the section name written to.
sub add-entry(IO::Path $path, Str $noun, Str $text, Bool :$replace = False --> Str) is export {
    my $section = %NOUN-SECTION{$noun}
        // user-error("unknown kind '$noun'; use one of: {%NOUN-SECTION.keys.sort.join(', ')}");
    my $value = $text.trim;
    user-error("nothing to add: text is empty") if $value eq '';

    my $doc   = SPOZ2::Document.load($path);
    my @found = $doc.sections-named($section);
    user-error("{$path.basename} has more than one '$section:' section; fix it before adding")
        if @found > 1;

    my @lines = $doc.lines;
    my @new   = entry-lines($section, $value, @found ?? (@found[0].indent // INDENT) !! INDENT);

    if !@found {
        # Create the section: before the next known section in canonical order
        # if one exists, otherwise at the end of the file.
        my $rank = { @KNOWN-SECTIONS.first($_, :k) // Inf };
        my $next = $doc.sections.first({ $rank(.name) > $rank($section) });
        with $next {
            my $at = $next.line - 1;                 # 0-based index of its header
            while $at > 0 && @lines[$at - 1] eq '' { @lines.splice($at - 1, 1); $at-- }
            @lines.splice($at, 0, '', "$section:", |@new, '');
        }
        else {
            @lines.push('') if @lines && @lines[*-1] ne '';
            @lines.append: "$section:", |@new;
        }
    }
    elsif $section eq 'gist' {
        my $s    = @found[0];
        my $text = $s.text.trim;
        if $text ne '' && $text ne GIST-PLACEHOLDER && !$replace {
            user-error("gist is already set; use --replace to replace it");
        }
        # replace every line between the header and last content line
        @lines.splice($s.line, $s.last-line - $s.line, @new);
    }
    else {
        @lines.splice(@found[0].last-line, 0, @new);
    }

    $path.spurt(@lines.join("\n") ~ "\n");
    $section;
}

#| Lines to insert for one entry, wrapped to WRAP-WIDTH (the parser joins
#| continuation lines with a space, so wrapping is lossless).
sub entry-lines(Str $section, Str $value, Str $indent) {
    my $first = $section eq 'gist' ?? $indent !! $indent ~ '- ';
    my $rest  = $section eq 'gist' ?? $indent !! $indent ~ '  ';
    my @out;
    for $value.lines -> $paragraph {
        for wrap($paragraph, WRAP-WIDTH - $rest.chars) -> $line {
            @out.push: (@out ?? $rest !! $first) ~ $line;
        }
    }
    @out;
}

#| Greedy word wrap; a single over-long word stays on its own line.
sub wrap(Str $text, Int $width) {
    my @lines;
    my $line = '';
    for $text.words -> $word {
        if $line eq '' { $line = $word }
        elsif $line.chars + 1 + $word.chars <= $width { $line ~= ' ' ~ $word }
        else { @lines.push($line); $line = $word }
    }
    @lines.push($line) if $line ne '';
    @lines || ('',);
}

# ---------------------------------------------------------------- log / diff

sub log-text(IO::Path $path --> Str) is export {
    git-log($path) // "No Git history available for {$path.basename}\n";
}

#| Returns (exit-code, stdout, stderr) from Git.
sub diff-result(IO::Path $path, *@revs) is export {
    git-diff($path, |@revs);
}
