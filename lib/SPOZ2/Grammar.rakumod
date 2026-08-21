#| The SPOZ2 surface syntax.
#|
#| A .spoz2 file is line oriented:
#|
#|   spoz2 0.1                     format line (first non-blank line)
#|   # comment                     whole-line comments only
#|   system <name>                 block header, column 0
#|     prose ...                   indented lines belong to the block above
#|   invariant <name>              block header, column 0
#|     since <version>             field line (required for invariants)
#|     until <version>             field line (optional)
#|     prose ...                   anything else indented is human language
#|
#| The grammar deliberately knows nothing about meaning: it only carves
#| the file into blocks, fields and prose.  SPOZ2::Actions turns the
#| parse tree into SPOZ2::Model objects, where the semantics live.
unit grammar SPOZ2::Grammar;

token TOP {
    <gap>
    <format-line>
    <gap>
    [ <block> <gap> ]*
    \s*
    [ $ || <.expected-block> ]
}

# --- lines that carry no meaning ----------------------------------------
token gap          { [ <blank-line> | <comment-line> ]* }
token blank-line   { ^^ \h* \n }
token comment-line { ^^ \h* '#' \N* <eol> }
token eol          { \h* [ \n | $ ] }

# --- file header ---------------------------------------------------------
token format-line  { ^^ 'spoz2' \h+ <format=.version> <eol> }

# --- blocks --------------------------------------------------------------
token block { ^^ [ <system> | <invariant> ] }

token system    { 'system'    \h+ <name> <eol> <body> }
token invariant { 'invariant' \h+ <name> <eol> <body> }

# A body is every indented (or blank/comment) line up to the next
# column-0 line.  Fields are tried before prose, so a prose line may not
# begin with a field keyword followed by a space.
token body { [ <field> || <prose> || <blank-line> || <comment-line> ]* }

token field { ^^ \h+ <key=.field-name> \h+ <value=.version> <eol> }
token field-name { 'since' | 'until' }

token prose { ^^ \h+ <!before '#'> <text=.prose-text> <eol> }
token prose-text { \S \N*? <?before \h* [ \n | $ ]> }

# --- atoms ---------------------------------------------------------------
token name    { <[\w-]>+ }
token version { \d+ [ '.' \d+ ]* }

# --- errors --------------------------------------------------------------
method expected-block {
    my $line = self.target.substr(0, self.pos).lines.elems + 1;
    die "SPOZ2 parse error at line $line: expected 'system' or 'invariant' at column 0";
}
