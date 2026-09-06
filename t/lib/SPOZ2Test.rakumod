unit module SPOZ2Test;

#| A fresh temporary directory; removed at process exit.
sub temp-dir(--> IO::Path) is export {
    my $dir = $*TMPDIR.add("spoz2-test-{$*PID}-{(^1_000_000).pick}");
    $dir.mkdir;
    END rm-rf($dir);
    $dir;
}

sub rm-rf(IO::Path $path) is export {
    return unless $path.e;
    if $path.d && !$path.l {
        rm-rf($_) for $path.dir;
        $path.rmdir;
    }
    else {
        $path.unlink;
    }
}

#| Run bin/spoz2 in $cwd; returns (exit-code, stdout, stderr).
sub spoz2(IO::Path $cwd, *@args) is export {
    my $root = $?FILE.IO.resolve.parent(3);
    my $proc = run $*EXECUTABLE, '-I', $root.add('lib').Str,
        $root.add('bin/spoz2').Str, |@args, :cwd($cwd.Str), :out, :err;
    my $out = $proc.out.slurp(:close);
    my $err = $proc.err.slurp(:close);
    $proc.exitcode, $out, $err;
}

#| Can we run git here?  (Tests that need it skip otherwise.)
sub have-git(--> Bool) is export {
    my $p = try run 'git', '--version', :out, :err;
    $p.defined && $p.exitcode == 0;
}
