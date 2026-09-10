unit module SPOZ2::Register;

use SPOZ2;
use SPOZ2::Document;
use SPOZ2::Git;

#| Client for the SPOZ2 register (register.spoz2.do): the two commands
#| behind it (spoz2 register, spoz2 report) are the CLI's only network
#| opt-ins besides the agent behind init.  A report follows the register's
#| s2r-report contract and carries presence, digest, counts and check
#| outcomes - never the text of the SPOZ2.

constant REGISTER-START  is export = 'https://register.spoz2.do/start';
constant REPORT-SCHEMA   is export = 's2r-report/1';

# ---------------------------------------------------------- connection

#| The file beside a SPOZ2 naming where it reports to.  Holds the reports
#| URL only - never the token, which stays outside the repository.
sub register-file(IO::Path $spoz2 --> IO::Path) is export {
    $spoz2.parent.add('.spoz2-register');
}

sub register-url(IO::Path $spoz2 --> Str) is export {
    my $f = register-file($spoz2);
    $f.f ?? $f.slurp.trim !! Str;
}

sub save-register-url(IO::Path $spoz2, Str $url --> IO::Path) is export {
    my $f = register-file($spoz2);
    $f.spurt($url.trim ~ "\n");
    $f;
}

#| Tokens live under the user's config directory, keyed by reports URL,
#| one "URL<TAB>token" per line, mode 0600.
sub token-store(--> IO::Path) is export {
    my $base = %*ENV<XDG_CONFIG_HOME> ?? %*ENV<XDG_CONFIG_HOME>.IO !! $*HOME.add('.config');
    $base.add('spoz2').add('tokens');
}

sub save-token(Str $url, Str $token) is export {
    my $store = token-store();
    $store.parent.mkdir;
    $store.parent.chmod(0o700);
    my @lines = $store.f ?? $store.lines.grep({ .split("\t")[0] ne $url }) !! ();
    @lines.push: "$url\t$token";
    $store.spurt(@lines.join("\n") ~ "\n");
    $store.chmod(0o600);
}

#| The token for a reports URL: environment first (CI), then the store.
sub token-for(Str $url --> Str) is export {
    with %*ENV<SPOZ2_REGISTER_TOKEN> // %*ENV<S2R_TOKEN> { return .Str }
    my $store = token-store();
    return Str unless $store.f;
    with $store.lines.first({ .split("\t")[0] eq $url }) { return .split("\t")[1].Str }
    Str;
}

# ------------------------------------------------------------ evidence

sub register-error(Str $message) { X::SPOZ2.new(:$message).throw }

#| Evidence about one SPOZ2, mirroring the register's s2r-report contract.
sub collect-report(IO::Path $spoz2, Str :$release, Str :$run-id --> Hash) is export {
    my ($rc, $out, $) = git($spoz2, 'rev-parse', 'HEAD');
    my $revision = $out.trim;
    register-error('not in a Git repository; evidence must bind to an exact revision')
        unless $rc == 0 && $revision ~~ /^ <[0..9 a..f]> ** 40 $/;

    my %declaration = present => $spoz2.f;
    my %checks;
    if $spoz2.f {
        %declaration<digest> = sha256-file($spoz2);
        my $doc = SPOZ2::Document.load($spoz2);
        %declaration<grammar_version>  = "SPOZ2 {$doc.version}" with $doc.version;
        %declaration<invariant_count> = $doc.section('invariants') ?? $doc.section('invariants').items.elems !! 0;
        %checks<syntax> = %( outcome => $doc.ok ?? 'passed' !! 'failed' );
    }

    my %report =
        schema_version => REPORT-SCHEMA,
        report_id      => $revision.substr(0, 12) ~ '-' ~ time,
        revision       => $revision,
        declaration    => %declaration,
        checks         => %checks,
        tool           => "spoz2/{VERSION}",
        observed_at    => DateTime.now.utc.truncated-to('second').Str;
    %report<release_label> = $_ with $release;
    %report<run_id>        = $_ with $run-id;
    %report;
}

sub sha256-file(IO::Path $f --> Str) {
    my $p = try run 'sha256sum', $f.Str, :out, :err;
    register-error('sha256sum is required to fingerprint the SPOZ2 and was not found')
        unless $p.defined && $p.exitcode == 0;
    $p.out.slurp(:close).words.head.Str;
}

# ---------------------------------------------------------------- JSON

#| Canonical JSON (sorted keys), enough for the report payload.
sub json-encode(\v --> Str) is export {
    return 'null' without v;
    given v {
        when Bool        { v ?? 'true' !! 'false' }
        when Str         { json-str(v) }
        when Numeric     { v.Str }
        when Associative { '{' ~ v.pairs.sort(*.key).map({ json-str(.key.Str) ~ ':' ~ json-encode(.value) }).join(',') ~ '}' }
        when Positional  { '[' ~ v.map({ json-encode($_) }).join(',') ~ ']' }
        default          { json-str(v.Str) }
    }
}

sub json-str(Str $s --> Str) {
    my $out = $s.subst(/ <[\\"]> /, { '\\' ~ $_ }, :g);
    $out .= subst(/ <:Cc> /, { sprintf '\u%04x', .Str.ord }, :g);
    '"' ~ $out ~ '"';
}

# -------------------------------------------------------------- submit

#| POST the report with curl (external, like Git).  Returns (status, body);
#| status 0 means curl was missing or the register was unreachable.  The
#| token travels in a 0600 header file, not on the command line.
sub submit-report(Str $url, Str $token, Str $body --> List) is export {
    my $dir = $*TMPDIR.add("spoz2-{$*PID}-{(^1_000_000).pick}");
    $dir.mkdir;
    $dir.chmod(0o700);
    my $hdr = $dir.add('auth');
    $hdr.spurt("Authorization: Bearer $token\n");
    $hdr.chmod(0o600);
    LEAVE { .unlink for (try $dir.dir) // (); try $dir.rmdir }

    my $p = try run 'curl', '-sS', '--max-time', '15',
        '-o', '-', '-w', '\n%{http_code}',
        '-X', 'POST',
        '-H', 'Content-Type: application/json',
        '-H', '@' ~ $hdr.Str,
        '--data-binary', '@-', $url, :in, :out, :err;
    return (0, 'curl is required to talk to the register and was not found') without $p;
    $p.in.print($body);
    try $p.in.close;
    my $out = $p.out.slurp(:close);
    my $err = $p.err.slurp(:close);
    return (0, $err.trim || 'network request failed') if $p.exitcode != 0;

    my @lines = $out.lines;
    my $code  = (try @lines.tail.Int) // 0;
    ($code, @lines.head(* - 1).join("\n"));
}
