unit module SPOZ2::Git;

#| Run git in the directory of $file.  Returns (exit-code, stdout, stderr).
#| If git cannot be run at all, exit-code is 127 and stderr explains why.
sub git(IO::Path $file, *@args) is export {
    my $proc = try run 'git', '-C', $file.parent.Str, |@args, :out, :err;
    without $proc {
        return 127, '', 'git is not installed or cannot be run';
    }
    my $out = $proc.out.slurp(:close);
    my $err = $proc.err.slurp(:close);
    return $proc.exitcode, $out, $err;
}

#| True when $file is tracked by a Git repository.
sub git-tracked(IO::Path $file --> Bool) is export {
    my ($rc, $, $) = git($file, 'ls-files', '--error-unmatch', '--', $file.basename);
    $rc == 0;
}

#| Concise history of $file, or Nil when there is none.
sub git-log(IO::Path $file --> Str) is export {
    return Nil unless git-tracked($file);
    my ($rc, $out, $) = git($file, 'log', '--date=short',
        '--format=%ad  %h  %s', '--follow', '--', $file.basename);
    return Nil if $rc != 0 || $out.trim eq '';
    $out;
}

#| Diff for $file via Git.  With no revisions, compares the working tree
#| with the last commit (or the index when there is no commit yet).
#| Returns (exit-code, stdout, stderr); exit-code 127 means no Git.
sub git-diff(IO::Path $file, *@revs) is export {
    return 127, '', "No Git history available for {$file.basename}" unless git-tracked($file);
    my @spec = @revs;
    if !@spec {
        my ($rc, $, $) = git($file, 'rev-parse', '--verify', '--quiet', 'HEAD');
        @spec = 'HEAD' if $rc == 0;
    }
    git($file, 'diff', '--no-color', |@spec, '--', $file.basename);
}
