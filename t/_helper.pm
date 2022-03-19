# _helper.pm - A simple test suite helper

# Copyright (c) 2007-2022 imacat.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

package _helper;
use 5.005;
use strict;
use warnings;
use base qw(Exporter);
our ($VERSION, @EXPORT);
$VERSION = "0.01";
@EXPORT = qw(
    read_file read_raw_file write_file write_raw_file
    run_cmd where_is file_type list_files preserve_source clean_up
    has_no_file has_no_gzip has_no_bzip2 has_no_xz
    make_log_file
    make_apache_log_file make_syslog_log_file
    make_ntp_log_file make_apache_ssl_log_file make_modified_iso_log_file
    random_word
    TYPE_TEXT TYPE_GZIP TYPE_BZIP2 TYPE_XZ
    @LOG_FORMATS @SOURCE_TYPES @RESULT_TYPES @KEEP_MODES @OVERRIDE_MODES);
# Prototype declaration
sub this_file();
sub read_file($);
sub read_raw_file($);
sub write_file($$);
sub write_raw_file($$);
sub run_cmd($@);
sub where_is($);
sub file_type($);
sub list_files($);
sub preserve_source($);
sub clean_up($$$);
sub has_no_file();
sub has_no_gzip();
sub has_no_bzip2();
sub has_no_xz();
sub make_log_file($$$@);
sub make_apache_log_file($;$);
sub make_syslog_log_file($;$);
sub make_ntp_log_file($;$);
sub make_apache_ssl_log_file($;$);
sub make_modified_iso_log_file($;$);
sub month_range($);
sub random_month_ranges();
sub split_months(\@);
sub insert_malformed(\@);
sub random_word();
sub random_ip();
sub random_domain();

use Data::Dumper;
use ExtUtils::MakeMaker qw();
use Fcntl qw(:seek);
use File::Basename qw(basename);
use File::Copy qw(copy);
use File::Path qw(mkpath rmtree);
use File::Spec::Functions qw(splitdir catdir catfile path);
use File::Temp qw(tempfile);
use Time::Local qw(timelocal);
$Data::Dumper::Indent = 1;

our (%WHERE_IS, $HAS_NO_FILE, $HAS_NO_GZIP, $HAS_NO_BZIP2, $HAS_NO_XZ);
%WHERE_IS = qw();
undef $HAS_NO_FILE;
undef $HAS_NO_GZIP;
undef $HAS_NO_BZIP2;
undef $HAS_NO_XZ;

use constant TYPE_TEXT => "text/plain";
use constant TYPE_GZIP => "application/x-gzip";
use constant TYPE_BZIP2 => "application/x-bzip2";
use constant TYPE_XZ => "application/x-xz";

our (@LOG_FORMATS, @SOURCE_TYPES, @RESULT_TYPES, @KEEP_MODES, @OVERRIDE_MODES);
# All the log format information
@LOG_FORMATS = (
    {   "title" => "Apache access log",
        "sub"   => \&make_apache_log_file, },
    {   "title" => "Syslog",
        "sub"   => \&make_syslog_log_file, },
    {   "title" => "NTP",
        "sub"   => \&make_ntp_log_file, },
    {   "title" => "Apache SSL engine log",
        "sub"   => \&make_apache_ssl_log_file, },
    {   "title" => "modified ISO 8601 date/time",
        "sub"   => \&make_modified_iso_log_file, }, );
# All the source type information
@SOURCE_TYPES = (
    {   "title" => "plain text source",
        "type"  => TYPE_TEXT,
        "suf"   => "",
        "skip"  => 0, },
    {   "title" => "gzip source",
        "type"  => TYPE_GZIP,
        "suf"   => ".gz",
        "skip"  => has_no_gzip, },
    {   "title" => "bzip2 source",
        "type"  => TYPE_BZIP2,
        "suf"   => ".bz2",
        "skip"  => has_no_bzip2, },
    {   "title" => "xz source",
        "type"  => TYPE_XZ,
        "suf"   => ".xz",
        "skip"  => has_no_xz, }, );
# All the result type information
@RESULT_TYPES = (
    {   "title" => "default compress",
        "type"  => TYPE_GZIP,
        "suf"   => ".gz",
        "skip"  => has_no_gzip,
        "opts"  => [], },
    {   "title" => "gzip compress",
        "type"  => TYPE_GZIP,
        "suf"   => ".gz",
        "skip"  => has_no_gzip,
        "opts"  => [qw(-c g)], },
    {   "title" => "bzip2 compress",
        "type"  => TYPE_BZIP2,
        "suf"   => ".bz2",
        "skip"  => has_no_bzip2,
        "opts"  => [qw(-c b)], },
    {   "title" => "xz compress",
        "type"  => TYPE_XZ,
        "suf"   => ".xz",
        "skip"  => has_no_xz,
        "opts"  => [qw(-c x)], },
    {   "title" => "no compress",
        "type"  => TYPE_TEXT,
        "suf"   => "",
        "skip"  => 0,
        "opts"  => [qw(-c n)], }, );
# All the keep mode information
@KEEP_MODES = (
    {   "title" => "keep default",
        "opts"  => [],
        "tm"    => 1,
        "del"   => 0,
        "tmp"   => 1,
        "stdin" => 0, },
    {   "title" => "keep all",
        "opts"  => [qw(-k a)],
        "tm"    => 0,
        "del"   => 0,
        "tmp"   => 0,
        "stdin" => 0, },
    {   "title" => "keep delete",
        "opts"  => [qw(-k d)],
        "tm"    => 0,
        "del"   => 1,
        "tmp"   => 1,
        "stdin" => 0, },
    {   "title" => "keep restart",
        "opts"  => [qw(-k r)],
        "tm"    => 0,
        "del"   => 0,
        "tmp"   => 1,
        "stdin" => 0, },
    {   "title" => "keep this month",
        "opts"  => [qw(-k t)],
        "tm"    => 1,
        "del"   => 0,
        "tmp"   => 1,
        "stdin" => 0, },
    {   "title" => "keep STDIN",
        "opts"  => [],
        "tm"    => 0,
        "del"   => 0,
        "tmp"   => 0,
        "stdin" => 1, }, );
# All the override mode information
@OVERRIDE_MODES = (
    {   "title"     => "override no existing",
        "opts"      => [],
        "exists"    => 0,
        "ok"        => 1,
        "ce"        => sub { $_[1]; }, },
    {   "title"     => "override default",
        "opts"      => [],
        "exists"    => 1,
        "ok"        => 0,
        "ce"        => sub { $_[0]; }, },
    {   "title"     => "override overwrite",
        "opts"      => [qw(-o o)],
        "exists"    => 1,
        "ok"        => 1,
        "ce"        => sub { $_[1]; }, },
    {   "title"     => "override append",
        "opts"      => [qw(-o a)],
        "exists"    => 1,
        "ok"        => 1,
        "ce"        => sub { $_[0] . $_[1]; }, },
    {   "title"     => "override ignore",
        "opts"      => [qw(-o i)],
        "exists"    => 1,
        "ok"        => 1,
        "ce"        => sub { $_[0] || $_[1]; }, },
    {   "title"     => "override fail",
        "opts"      => [qw(-o f)],
        "exists"    => 1,
        "ok"        => 0,
        "ce"        => sub { $_[0]; }, }, );

# Return the name of this file
sub this_file() { basename($0); }

# A simple reader to read a log file in any supported format
sub read_file($) {
    local ($_, %_);
    my ($file, $content);
    $file = $_[0];

    # non-existing file
    return undef if !-e $file;

    # a gzip compressed file
    if ($file =~ /\.gz$/) {
        # IO::Uncompress::Gunzip
        if (eval { require IO::Uncompress::Gunzip; 1; }) {
            my $gz;
            $content = "";
            $gz = IO::Uncompress::Gunzip->new($file)
                                        or die this_file . ": $file: $IO::Uncompress::Gunzip::GunzipError";
            $content = join "", <$gz>;
            $gz->close                  or die this_file . ": $file: $IO::Uncompress::Gunzip::GunzipError";
            return $content;

        # gzip executable
        } else {
            my ($PH, $CMD);
            $CMD = where_is "gzip";
            $CMD = "\"$CMD\" -cd \"$file\"";
            open $PH, "$CMD |"          or die this_file . ": $CMD: $!";
            $content = join "", <$PH>;
            close $PH                   or die this_file . ": $CMD: $!";
            return $content;
        }

    # a bzip compressed file
    } elsif ($file =~ /\.bz2$/) {
        # IO::Uncompress::Bunzip2
        if (eval { require IO::Uncompress::Bunzip2; 1; }) {
            my $bz;
            $content = "";
            $bz = IO::Uncompress::Bunzip2->new($file)
                                        or die this_file . ": $file: $IO::Uncompress::Bunzip2::Bunzip2Error";
            $content = join "", <$bz>;
            $bz->close                  or die this_file . ": $file: $IO::Uncompress::Bunzip2::Bunzip2Error";
            return $content;

        # bzip2 executable
        } else {
            my ($PH, $CMD);
            $CMD = where_is "bzip2";
            $CMD = "bzip2 -cd \"$file\"";
            open $PH, "$CMD |"          or die this_file . ": $CMD: $!";
            $content = join "", <$PH>;
            close $PH                   or die this_file . ": $CMD: $!";
            return $content;
        }

    # an xz compressed file
    } elsif ($file =~ /\.xz$/) {
        # IO::Uncompress::UnXz
        if (eval { require IO::Uncompress::UnXz; 1; }) {
            my $xz;
            $content = "";
            $xz = IO::Uncompress::UnXz->new($file)
                                        or die this_file . ": $file: $IO::Uncompress::UnXz::UnXzError";
            $content = join "", <$xz>;
            $xz->close                  or die this_file . ": $file: $IO::Uncompress::UnXz::UnXzError";
            return $content;

        # xz executable
        } else {
            my ($PH, $CMD);
            $CMD = where_is "xz";
            $CMD = "xz -cd \"$file\"";
            open $PH, "$CMD |"          or die this_file . ": $CMD: $!";
            $content = join "", <$PH>;
            close $PH                   or die this_file . ": $CMD: $!";
            return $content;
        }

    # a plain text file
    } else {
        my $FH;
        open $FH, $file                 or die this_file . ": $file: $!";
        $content = join "", <$FH>;
        close $FH                       or die this_file . ": $file: $!";
        return $content;
    }
}

# A raw file reader
sub read_raw_file($) {
    local ($_, %_);
    my ($file, $content, $FH, $size);
    $file = $_[0];

    # non-existing file
    return undef if !-e $file;

    $size = (stat $file)[7];
    open $FH, $file                     or die this_file . ": $file: $!";
    binmode $FH                         or die this_file . ": $file: $!";
    (read($FH, $content, $size) == $size)
                                        or die this_file . ": $file: $!";
    close $FH                           or die this_file . ": $file: $!";
    return $content;
}

# A simple writer to write a log file in any supported format
sub write_file($$) {
    local ($_, %_);
    my ($file, $content);
    ($file, $content) = @_;

    # a gzip compressed file
    if ($file =~ /\.gz$/) {
        # IO::Compress::Gzip
        if (eval { require IO::Compress::Gzip; 1; }) {
            my $gz;
            $gz = IO::Compress::Gzip->new($file)
                                        or die this_file . ": $file: $IO::Compress::Gzip::GzipError";
            ($gz->write($content) == length $content)
                                        or die this_file . ": $file: $IO::Compress::Gzip::GzipError";
            $gz->close                  or die this_file . ": $file: $IO::Compress::Gzip::GzipError";
            return;

        # gzip executable
        } else {
            my ($PH, $CMD);
            $CMD = where_is "gzip";
            $CMD = "\"$CMD\" -c9f > \"$file\"";
            open $PH, "| $CMD"          or die this_file . ": $CMD: $!";
            print $PH $content          or die this_file . ": $CMD: $!";
            close $PH                   or die this_file . ": $CMD: $!";
            return;
        }

    # a bzip compressed file
    } elsif ($file =~ /\.bz2$/) {
        # IO::Compress::Bzip2
        if (eval { require IO::Compress::Bzip2; 1; }) {
            my $bz;
            $bz = IO::Compress::Bzip2->new($file)
                                        or die this_file . ": $file: $IO::Compress::Bzip2::Bzip2Error";
            ($bz->write($content) == length $content)
                                        or die this_file . ": $file: $IO::Compress::Bzip2::Bzip2Error";
            $bz->close                  or die this_file . ": $file: $IO::Compress::Bzip2::Bzip2Error";
            return;

        # bzip2 executable
        } else {
            my ($PH, $CMD);
            $CMD = where_is "bzip2";
            $CMD = "\"$CMD\" -9f > \"$file\"";
            open $PH, "| $CMD"        or die this_file . ": $CMD: $!";
            print $PH $content        or die this_file . ": $CMD: $!";
            close $PH                 or die this_file . ": $CMD: $!";
            return;
        }

    # an xz compressed file
    } elsif ($file =~ /\.xz$/) {
        # IO::Compress::Xz
        if (eval { require IO::Compress::Xz; 1; }) {
            my $xz;
            $xz = IO::Compress::Xz->new($file)
                                        or die this_file . ": $file: $IO::Compress::Xz::XzError";
            ($xz->write($content) == length $content)
                                        or die this_file . ": $file: $IO::Compress::Xz::XzError";
            $xz->close                  or die this_file . ": $file: $IO::Compress::Xz::XzError";
            return;

        # xz executable
        } else {
            my ($PH, $CMD);
            $CMD = where_is "xz";
            $CMD = "\"$CMD\" -9f > \"$file\"";
            open $PH, "| $CMD"        or die this_file . ": $CMD: $!";
            print $PH $content        or die this_file . ": $CMD: $!";
            close $PH                 or die this_file . ": $CMD: $!";
            return;
        }

    # a plain text file
    } else {
        my $FH;
        open $FH, ">$file"              or die this_file . ": $file: $!";
        print $FH $content              or die this_file . ": $file: $!";
        close $FH                       or die this_file . ": $file: $!";
        return;
    }
}

# A raw file writer
sub write_raw_file($$) {
    local ($_, %_);
    my ($file, $content, $FH);
    ($file, $content) = @_;

    open $FH, ">$file"                  or die this_file . ": $file: $!";
    binmode $FH                         or die this_file . ": $file: $!";
    print $FH $content                  or die this_file . ": $file: $!";
    close $FH                           or die this_file . ": $file: $!";
    return;
}

# Run a command and return the result
sub run_cmd($@) {
    local ($_, %_);
    my ($ret_no, $out, $err, $in, @cmd, $cmd, $OUT, $ERR, $STDOUT, $STDERR, $PH);
    ($in, @cmd) = @_;

    $err = "Running " . join(" ", map "\"$_\"", @cmd) . "\n";
    $out = "";

    open $STDOUT, ">&", \*STDOUT        or die this_file . ": STDOUT: $!";
    open $STDERR, ">&", \*STDERR        or die this_file . ": STDERR: $!";
    $OUT = tempfile                     or die this_file . ": tempfile: $!";
    binmode $OUT                        or die this_file . ": tempfile: $!";
    $ERR = tempfile                     or die this_file . ": tempfile: $!";
    binmode $ERR                        or die this_file . ": tempfile: $!";
    open STDOUT, ">&", $OUT             or die this_file . ": tempfile: $!";
    binmode STDOUT                      or die this_file . ": tempfile: $!";
    open STDERR, ">&", $ERR             or die this_file . ": tempfile: $!";
    binmode STDERR                      or die this_file . ": tempfile: $!";

    $cmd = join " ", map "\"$_\"", @cmd;
    if ($^O eq "MSWin32") {
        open $PH, "| $cmd"              or die this_file . ": $cmd: $!";
    } else {
        open $PH, "|-", @cmd            or die this_file . ": $cmd: $!";
    }
    binmode $PH                         or die this_file . ": $cmd: $!";
    print $PH $in                       or die this_file . ": $cmd: $!";
    close $PH;
    $ret_no = $?;

    open STDOUT, ">&", $STDOUT          or die this_file . ": tempfile: $!";
    open STDERR, ">&", $STDERR          or die this_file . ": tempfile: $!";

    seek $OUT, 0, SEEK_SET              or die this_file . ": tempfile: $!";
    $out = join "", <$OUT>;
    close $OUT                          or die this_file . ": tempfile: $!";
    seek $ERR, 0, SEEK_SET              or die this_file . ": tempfile: $!";
    $err = join "", <$ERR>;
    close $ERR                          or die this_file . ": tempfile: $!";

    return ($ret_no, $out, $err);
}

# Find an executable
#   Code inspired from CPAN::FirstTime
sub where_is($) {
    local ($_, %_);
    my ($file, $path);
    $file = $_[0];
    return $WHERE_IS{$file} if exists $WHERE_IS{$file};
    foreach my $dir (path) {
        return ($WHERE_IS{$file} = $path)
            if defined($path = MM->maybe_command(catfile($dir, $file)));
    }
    return ($WHERE_IS{$file} = undef);
}

# Find the file type
sub file_type($) {
    local ($_, %_);
    my $file;
    $file = $_[0];
    return undef unless -e $file;
    # Use File::MMagic
    if (eval { require File::MMagic; 1; }) {
        $_ = File::MMagic->new->checktype_filename($file);
        return "application/x-gzip" if /gzip/;
        return "application/x-bzip2" if /bzip2/;
        return "application/x-xz" if /xz/;
        # All else are text/plain
        return "text/plain";
    }
    # Use file executable
    if (defined($_ = where_is "file")) {
        $_ = join "", `"$_" "$file"`;
        return "application/x-gzip" if /gzip/;
        return "application/x-bzip2" if /bzip2/;
        return "application/x-xz" if /: XZ/;
        # All else are text/plain
        return "text/plain";
    }
    # No type checker available
    return undef;
}

# Obtain the files list in a directory
sub list_files($) {
    local ($_, %_);
    my ($dir, $DH);
    $dir = $_[0];
    @_ = qw();
    opendir $DH, $dir                   or die this_file . ": $dir: $!";
    while (defined($_ = readdir $DH)) {
        next if $_ eq "." || $_ eq ".." || !-f "$dir/$_";
        push @_, $_;
    }
    closedir $DH                        or die this_file . ": $dir: $!";
    return join " ", sort @_;
}

# Preserve the source test files
sub preserve_source($) {
    local ($_, %_);
    my ($dir, $DH);
    $dir = $_[0];
    @_ = qw();
    opendir $DH, $dir                   or die this_file . ": $dir: $!";
    while (defined($_ = readdir $DH)) {
        next if $_ eq "." || $_ eq ".." || !-f "$dir/$_";
        push @_, $_;
    }
    closedir $DH                        or die this_file . ": $dir: $!";
    rmtree "$dir/source";
    mkpath "$dir/source";
    write_raw_file "$dir/source/$_", read_raw_file "$dir/$_"
        foreach @_;
    return;
}

# Clean up the test files
sub clean_up($$$) {
    local ($_, %_);
    my ($r, $dir, $test_no, $test_name, $c);
    ($r, $dir, $test_no) = @_;
    # Nothing to clean up
    return unless -e $dir;
    # Success
    if ($r) {
        rmtree $dir;
        return;
    }
    # Fail - keep the test files for failure investigation
    $test_name = basename((caller)[1]);
    $test_name =~ s/\.t$//;
    $c = 1;
    $c++ while -e ($_ = "$dir.$test_name.$test_no.$c");
    rename $dir, $_                     or die this_file . ": $dir, $_: $!";
    return;
}

# If we have the file type checker somewhere
sub has_no_file() {
    $HAS_NO_FILE = eval { require File::MMagic; 1; }
                || defined where_is "file"?
            0: "File::MMagic or file executable not available"
        if !defined $HAS_NO_FILE;
    return $HAS_NO_FILE;
}

# If we have gzip support somewhere
sub has_no_gzip() {
    $HAS_NO_GZIP = eval { require IO::Compress::Gzip; require IO::Uncompress::Gunzip; 1; }
                || defined where_is "gzip"?
            0: "IO::Compress::Gzip or gzip executable not available"
        if !defined $HAS_NO_GZIP;
    return $HAS_NO_GZIP;
}

# If we have bzip2 support somewhere
sub has_no_bzip2() {
    $HAS_NO_BZIP2 = eval { require IO::Compress::Bzip2; require IO::Uncompress::Bunzip2; 1; }
                || defined where_is "bzip2"?
            0: "IO::Compress::Bzip2 v2 or bzip2 executable not available"
        if !defined $HAS_NO_BZIP2;
    return $HAS_NO_BZIP2;
}

# If we have xz support somewhere
sub has_no_xz() {
    $HAS_NO_XZ = eval { require IO::Compress::Xz; require IO::Uncompress::UnXz; 1; }
                || defined where_is "xz"?
            0: "IO::Compress::Xz or xz executable not available"
        if !defined $HAS_NO_XZ;
    return $HAS_NO_XZ;
}

# Create a random existing log file
sub make_log_file($$$@) {
    local ($_, %_);
    my ($make_log_file, $dir, $filename_pattern, @months, %contents);
    ($make_log_file, $dir, $filename_pattern, @months) = @_;

    # Find a non-decided month and have an existing log
    $_{$_[int rand @_]} = 1 if (@_ = grep !exists $_{$_}, @months) > 0;
    # Find a non-decided month and not have an existing log
    $_{$_[int rand @_]} = 0 if (@_ = grep !exists $_{$_}, @months) > 0;
    # Decide the remain months randomly
    $_{$_} = int rand 2 foreach grep !exists $_{$_}, @months;
    %contents = qw();
    foreach my $m (@months) {
        my ($file, $path);
        $file = sprintf($filename_pattern, $m);
        $path = catfile($dir, $file);
        if ($_{$m}) {
            $contents{$file} = (&$make_log_file($path, $m))[0];
        } else {
            $contents{$file} = "";
        }
    }

    return %contents;
}

# Create a random Apache access log file
sub make_apache_log_file($;$) {
    local ($_, %_);
    my ($file, $month, @logs, $content, @ranges, %months, $var_dump, $tz);
    ($file, $month) = @_;

    @logs = qw();

    # Time zone
    $tz = (-12 + (int rand 53) / 2) * 3600;
    # To be removed
    #$tz = -12 + (int rand 53) / 2;
    #$tz = sprintf "%+05d", int($tz) * 100 + ($tz - int($tz)) * 60;

    # Get the range of a month
    if (defined $month) {
        @ranges = month_range $month;
    # Get the range of some previous months
    } else {
        @ranges = random_month_ranges;
    }
    for (my $i = 0; $i + 1 < @ranges; $i++) {
        my $hosts;
        # 2-5 hosts
        $hosts = 2 + int rand 4;
        # Generate the visit time of each host
        for (my $j = 0; $j < $hosts; $j++) {
            my ($host, $t, $user, $http_ver, @host_logs, $count);
            # Host type: 1: IP, 0: domain name
            $host = int rand 2? random_ip: random_domain;
            $t = $ranges[$i] + int rand($ranges[$i + 1] - $ranges[$i]);
            $user = (0, 0, 1)[int rand 3]? "-": random_word;
            $http_ver = (qw(HTTP/1.1 HTTP/1.1 HTTP/1.1 HTTP/1.0))[int rand 4];
            # 3-5 log records for each host
            $count = 3 + int rand 3;
            @host_logs = qw();
            while (@host_logs < $count) {
                my ($time, $method, $url, $dirs, @dirs, $type, $status, $size);
                # Time text
                @_ = gmtime($t + $tz);
                $_[5] += 1900;
                $_[4] = (qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec))[$_[4]];
                $time = sprintf "%02d/%s/%04d:%02d:%02d:%02d %+05d",
                    @_[3,4,5,2,1,0],
                    int($tz / 3600) * 100 + ($tz - int($tz / 3600) * 3600) / 60;

                $method = (qw(GET GET GET HEAD POST))[int rand 5];

                # Generate a random URL
                # 0-3 levels of directories
                $dirs = int rand 4;
                @dirs = qw();
                push @dirs, "/" . random_word while @dirs < $dirs;
                $type = ("", qw(html html txt css png jpg))[int rand 7];
                if ($type eq "") {
                    $url = join("", @dirs) . "/";
                } else {
                    $url = join("", @dirs) . "/" . random_word . ".$type";
                }

                $status = (200, 200, 200, 200, 304, 400, 403, 404)[int rand 8];
                if ($status == 304) {
                    $size = 0;
                } else {
                    $size = 200 + int rand 35000;
                }
                push @host_logs, {
                        "time"      => $t,
                        "record"    => sprintf("%s - %s [%s] \"%s %s %s\" %d %d\n",
                            $host, $user, $time,
                            $method, $url, $http_ver, $status, $size),
                    };

                # 0-2 seconds later
                $t += int rand 3;
            }
            push @logs, @host_logs;
            # 0-5 seconds later
            $t += int rand 6;
        }
    }

    # Sort by time
    # A series of requests from a same host may run cross the next host
    # So we need to sort again
    @logs = sort { $$a{"time"} <=> $$b{"time"} } @logs;

    # Variables used, for failure investigation
    $var_dump = Data::Dumper->Dump([\@logs, $tz], [qw($logs $tz)]);

    # Split by months
    %months = split_months @logs;
    # Drop the time and keep the records
    @logs = map $$_{"record"}, @logs;
    # Insert 1-2 malformed lines
    insert_malformed @logs;

    # Compose the content
    $content = join "", @logs;
    # Output the file
    write_file($file, $content);
    # Return the content
    return $content, $var_dump, %months;
}

# Create a random Syslog log file
sub make_syslog_log_file($;$) {
    local ($_, %_);
    my ($file, $month, @logs, $content, @ranges, %months, $var_dump);
    my (@hosts, $hosts);
    ($file, $month) = @_;

    @logs = qw();

    # 3-5 hosts
    $hosts = 3 + int rand 3;
    @hosts = qw();
    push @hosts, random_word while @hosts < $hosts;

    # Get the range of a month
    if (defined $month) {
        @ranges = month_range $month;
    # Get the range of some previous months
    } else {
        @ranges = random_month_ranges;
    }
    for (my $i = 0; $i + 1 < @ranges; $i++) {
        my (@month_logs, $count, @t);
        # 5-12 log records for each month
        $count = 5 + int rand 8;
        @month_logs = qw();
        # Generate the time of each record
        @t = qw();
        push @t, $ranges[$i] + int rand($ranges[$i + 1] - $ranges[$i])
            while @t < $count;
        foreach my $t (sort @t) {
            my ($time, $host, $app, $pid, $msg);
            # Time text
            @_ = localtime $t;
            $_[5] += 1900;
            $_[4] = (qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec))[$_[4]];
            $time = sprintf "%s %2d %02d:%02d:%02d", @_[4,3,2,1,0];
            $host = $hosts[int rand scalar @hosts];
            $app = (qw(kernel sendmail sshd su CRON), random_word, random_word)[int rand 5];
            # PID 2-65535 (PID 1 is init)
            $pid = 2 + int rand 65533;
            # 3-12 words for each message
            $_ = 3 + int rand 10;
            @_ = qw();
            push @_, random_word while @_ < $_;
            $msg = join " ", @_;

            push @month_logs, {
                    "time"      => $t,
                    "record"    => sprintf("%s %s %s[%d] %s\n",
                        $time, $host, $app, $pid, $msg),
                };
        }
        push @logs, @month_logs;
    }

    # Variables used, for failure investigation
    $var_dump = Data::Dumper->Dump([\@logs], [qw($logs)]);

    # Split by months
    %months = split_months @logs;
    # Drop the time and keep the records
    @logs = map $$_{"record"}, @logs;
    # Insert 1-2 malformed lines
    insert_malformed @logs;

    # Compose the content
    $content = join "", @logs;
    # Output the file
    write_file($file, $content);
    # Return the content
    return $content, $var_dump, %months;
}

# Create a random NTP log file
sub make_ntp_log_file($;$) {
    local ($_, %_);
    my ($file, $month, @logs, $content, @ranges, %months, $var_dump);
    my ($pid, $peers, @peers, $refs, @refs);
    ($file, $month) = @_;

    @logs = qw();

    # PID 2-65535 (PID 1 is init)
    $pid = 2 + int rand 65533;
    # 3-5 peers
    $peers = 3 + int rand 3;
    @peers = qw();
    push @peers, random_ip while @peers < $peers;
    # 2-3 references
    $refs = 2 + int rand 2;
    push @refs, random_ip while @refs < $refs;

    # Get the range of a month
    if (defined $month) {
        @ranges = month_range $month;
    # Get the range of some previous months
    } else {
        @ranges = random_month_ranges;
    }
    for (my $i = 0; $i + 1 < @ranges; $i++) {
        my (@month_logs, $count, @t);
        # 5-12 log records for each month
        $count = 5 + int rand 8;
        @month_logs = qw();
        # Generate the time of each record
        @t = qw();
        push @t, $ranges[$i] + int rand($ranges[$i + 1] - $ranges[$i])
            while @t < $count;
        foreach my $t (sort @t) {
            my ($time, $type, $msg);
            # Time text
            @_ = localtime $t;
            $_[5] += 1900;
            $_[4] = (qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec))[$_[4]];
            $time = sprintf "%2d %s %02d:%02d:%02d", @_[3,4,2,1,0];
            # PID change - chance 2.73%, 50% change to total 25 records
            $pid = 2 + int rand 65533
                if rand() < 0.0273;
            $type = int rand 3;
            # Type 0 - peer reachability
            if ($type == 0) {
                my ($peer, $events);
                # 1-15 events
                $events = 1 + int rand 15;
                $peer = $peers[int rand @peers];
                # Reachable
                if (int rand 5 > 1) {
                    $msg = "peer $peer event 'event_reach' (0x84) status 'unreach, conf, auth, $events events, event_reach' (0xe0f4)";
                # Unreachable
                } else {
                    $msg = "peer $peer event 'event_unreach' (0x83) status 'unreach, conf, auth, $events events, event_unreach' (0xe0f3)";
                }
            # Type 1 - reference host
            } elsif ($type == 1) {
                my ($ref_host, $stratum);
                $ref_host = $refs[int rand @refs];
                # Stratum 2-4
                $stratum = 2 + int rand 2;
                $msg = "synchronized to $ref_host, stratum $stratum";
            # Type 2 - clock set
            } elsif ($type == 2) {
                my ($off, $freq, $err, $poll);
                $off = (rand() - 0.5) / 10;
                $freq = rand() * -10;
                $err = rand() / 20;
                # poll 4-10
                $poll = 4 + int rand 7;
                $msg = sprintf "offset %8.6f sec freq %6.3f ppm error %8.6f poll %d",
                    $off, $freq, $err, $poll;
            }

            push @month_logs, {
                    "time"      => $t,
                    "record"    => sprintf("%s ntpd[%d] %s\n",
                        $time, $pid, $msg),
                };
        }
        push @logs, @month_logs;
    }

    # Variables used, for failure investigation
    $var_dump = Data::Dumper->Dump([\@logs], [qw($logs)]);

    # Split by months
    %months = split_months @logs;
    # Drop the time and keep the records
    @logs = map $$_{"record"}, @logs;
    # Insert 1-2 malformed lines
    insert_malformed @logs;

    # Compose the content
    $content = join "", @logs;
    # Output the file
    write_file($file, $content);
    # Return the content
    return $content, $var_dump, %months;
}

# Create a random Apache SSL engine log file
sub make_apache_ssl_log_file($;$) {
    local ($_, %_);
    my ($file, $month, @logs, $content, @ranges, %months, $var_dump);
    my $host;
    ($file, $month) = @_;

    @logs = qw();

    $host = random_domain;

    # Get the range of a month
    if (defined $month) {
        @ranges = month_range $month;
    # Get the range of some previous months
    } else {
        @ranges = random_month_ranges;
    }
    for (my $i = 0; $i + 1 < @ranges; $i++) {
        my (@month_logs, $count, @t);
        # 3-5 visitors for each month
        $count = 3 + int rand 3;
        @month_logs = qw();
        # Generate the time of each record
        @t = qw();
        push @t, $ranges[$i] + int rand($ranges[$i + 1] - $ranges[$i])
            while @t < $count;
        foreach my $t (sort @t) {
            my ($time, $pid, $remote, $priority, $child, $msg);
            # Time text
            @_ = localtime $t;
            $_[5] += 1900;
            $_[4] = (qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec))[$_[4]];
            $time = sprintf "%02d/%s/%04d %02d:%02d:%02d", @_[3,4,5,2,1,0];
            # PID 2-65535 (PID 1 is init)
            $pid = 2 + int rand 65533;
            # Remote client
            $remote = random_ip;
            # Child number
            $child = int rand 15;

            # Error
            if (int rand 5 == 1) {
                $priority = "error";
                $msg = "SSL handshake failed (server $host:443, client $remote) (OpenSSL library error follows)";
                push @month_logs, {
                        "time"      => $t,
                        "record"    => sprintf("[%s %05d] [%s]  %s\n",
                            $time, $pid, $priority, $msg),
                    };
                $msg = "OpenSSL: error:1408E0F4:SSL routines:SSL3_GET_MESSAGE:unexpected message";
                push @month_logs, {
                        "time"      => $t,
                        "record"    => sprintf("[%s %05d] [%s]  %s\n",
                            $time, $pid, $priority, $msg),
                    };

            # Info
            } else {
                $priority = "info";
                $msg = "Connection to child $child established (server $host:443, client $remote)";
                push @month_logs, {
                        "time"      => $t,
                        "record"    => sprintf("[%s %05d] [%s]  %s\n",
                            $time, $pid, $priority, $msg),
                    };
                $msg = "Seeding PRNG with 1164 bytes of entropy";
                push @month_logs, {
                        "time"      => $t,
                        "record"    => sprintf("[%s %05d] [%s]  %s\n",
                            $time, $pid, $priority, $msg),
                    };
                # 1: bad
                if (int rand 2) {
                    $msg = "Spurious SSL handshake interrupt[Hint: Usually just one of those OpenSSL confusions!?]";
                    push @month_logs, {
                            "time"      => $t,
                            "record"    => sprintf("[%s %05d] [%s]  %s\n",
                                $time, $pid, $priority, $msg),
                        };
                # 2: success
                } else {
                    my $reqs;
                    # 1-5 requests
                    $reqs = 1 + int rand 5;
                    for (my $j = 1; $j <= $reqs; $j++) {
                        if ($j == 1) {
                            $msg = "Initial (No.$j) HTTPS request received for child $child ($host:443)"
                        } else {
                            $msg = "Subsequent (No.$j) HTTPS request received for child $child ($host:443)"
                        }
                        push @month_logs, {
                                "time"      => $t,
                                "record"    => sprintf("[%s %05d] [%s]  %s\n",
                                    $time, $pid, $priority, $msg),
                            };
                    }
                    $msg = "Connection to child $child closed with standard shutdown (server $host:443, client $remote)";
                    push @month_logs, {
                            "time"      => $t,
                            "record"    => sprintf("[%s %05d] [%s]  %s\n",
                                $time, $pid, $priority, $msg),
                        };
                }
            }
        }
        push @logs, @month_logs;
    }

    # Variables used, for failure investigation
    $var_dump = Data::Dumper->Dump([\@logs], [qw($logs)]);

    # Split by months
    %months = split_months @logs;
    # Drop the time and keep the records
    @logs = map $$_{"record"}, @logs;
    # Insert 1-2 malformed lines
    insert_malformed @logs;

    # Compose the content
    $content = join "", @logs;
    # Output the file
    write_file($file, $content);
    # Return the content
    return $content, $var_dump, %months;
}

# Create a random modified ISO 8861 date/time log file
sub make_modified_iso_log_file($;$) {
    local ($_, %_);
    my ($file, $month, @logs, $content, @ranges, %months, $var_dump, $tz);
    ($file, $month) = @_;

    @logs = qw();

    # Time zone
    $tz = (-12 + (int rand 53) / 2) * 3600;
    # To be removed
    #$tz = -12 + (int rand 53) / 2;
    #$tz = sprintf "%+05d", int($tz) * 100 + ($tz - int($tz)) * 60;

    # Get the range of a month
    if (defined $month) {
        @ranges = month_range $month;
    # Get the range of some previous months
    } else {
        @ranges = random_month_ranges;
    }
    for (my $i = 0; $i + 1 < @ranges; $i++) {
        my (@month_logs, $count, @t);
        # 5-12 log records for each month
        $count = 3 + int rand 3;
        @month_logs = qw();
        # Generate the time of each record
        @t = qw();
        push @t, $ranges[$i] + int rand($ranges[$i + 1] - $ranges[$i])
            while @t < $count;
        foreach my $t (sort @t) {
            my ($time, $id, $msg);
            # Time text
            @_ = gmtime($t + $tz);
            $_[5] += 1900;
            $_[4]++;
            $time = sprintf "%04d-%02d-%02d %02d:%02d:%02d %+05d",
                @_[5,4,3,2,1,0],
                int($tz / 3600) * 100 + ($tz - int($tz / 3600) * 3600) / 60;
            # identity
            $id = random_word;
            # 3-12 words for each message
            $_ = 3 + int rand 10;
            @_ = qw();
            push @_, random_word while @_ < $_;
            $msg = join " ", @_;
            push @month_logs, {
                    "time"      => $t,
                    "record"    => sprintf("[%s] %s: %s\n",
                        $time, $id, $msg),
                };
        }
        push @logs, @month_logs;
    }

    # Variables used, for failure investigation
    $var_dump = Data::Dumper->Dump([\@logs, $tz], [qw($logs $tz)]);

    # Split by months
    %months = split_months @logs;
    # Drop the time and keep the records
    @logs = map $$_{"record"}, @logs;
    # Insert 1-2 malformed lines
    insert_malformed @logs;

    # Compose the content
    $content = join "", @logs;
    # Output the file
    write_file($file, $content);
    # Return the content
    return $content, $var_dump, %months;
}

# Get the range of a specific month
sub month_range($) {
    local ($_, %_);
    my ($month, @range);
    $month = $_[0];
    # Sanity check
    return unless $month =~ /^(\d{4})(\d{2})$/;
    @range = qw();
    # The beginning of the month
    @_ = (0, 0, 0, 1, $2 - 1, $1 - 1900);
    return unless defined($_ = timelocal(@_[0...6]));
    push @range, $_;
    # The beginning of the next month
    $_[4]++;
    if ($_[4] > 11) {
        $_[4] = 0;
        $_[5]++;
    }
    return unless defined($_ = timelocal(@_[0...6]));
    push @range, $_;
    return @range;
}

# Get the range of some previous months
sub random_month_ranges() {
    local ($_, %_);
    my ($num, @range);
    # 1-3 previous months
    $num = 1 + int rand 3;
    @range = qw();
    unshift @range, time;
    @_ = (0, 0, 0, 1, (localtime)[4,5]);
    unshift @range, timelocal(@_);
    for (my $i = 0; $i < $num; $i++) {
        $_[4]--;
        if ($_[4] < 0) {
            $_[4] = 11;
            $_[5]--;
        }
        unshift @range, timelocal(@_);
    }
    return @range;
}

# Split the log records by months
sub split_months(\@) {
    local ($_, %_);
    my ($logs, %months);
    $logs = $_[0];

    %months = qw();
    foreach (@$logs) {
        my $month;
        @_ = localtime $$_{"time"};
        $month = sprintf "%04d%02d", $_[5] + 1900, $_[4] + 1;
        $months{$month} = "" if !exists $months{$month};
        $months{$month} .= $$_{"record"};
    }

    return %months;
}

# Insert 1-2 malformed lines
sub insert_malformed(\@) {
    local ($_, %_);
    my ($logs, $malformed);
    $logs = $_[0];

    $malformed = 1 + int rand 2;
    while ($malformed > 0) {
        my $line;
        # Generate the random malformed line
        $_ = 3 + int rand 5;
        @_ = qw();
        push @_, random_word while @_ < $_;
        $line = join(" ", @_) . ".\n";
        $line =~ s/^(.)/uc $1/e;
        # The position to insert the line
        # The position cannot be 0 - or we cannot judge the log format
        $_ = 1 + int rand(@$logs - 1);
        $logs = [@$logs[0...$_], $line, @$logs[$_+1...$#$logs]];
        $malformed--;
    }

    return;
}

# Supply a random English word
sub random_word() {
    local ($_, %_);
    @_ = qw(
hard-to-find striped poor scene miniature marble error shelter clear settle
march breath tested symptomatic delicate road punish grain fabulous camp
authority love system placid bake maddening sleep precious crabby lovely jolly
wrist park common volleyball tick judicious degree alluring hydrant oatmeal
aboard light spare delirious unwritten unnatural existence deadpan cagey
disastrous station fear dam adorable grape event silent extra-large shame meaty
husky drag religion extra-small pot valuable deceive obese seed history
wholesale tremble delightful leather cabbage death tub loss twig hate noxious
trashy sleet bleach quizzical familiar nappy teaching private yak turkey foolish
concentrate reject tacit goofy men ajar communicate);
    return $_[int rand @_];
}

# Supply a random IP
sub random_ip() {
    return join ".", (int rand 255, int rand 255,
        int rand 255, 1 + int rand 254);
}

# Supply a random domain
sub random_domain() {
    local ($_, %_);
    # Generate a random domain name
    # 3-5 levels, end with net or com
    $_ = 2 + int rand 3;
    @_ = qw();
    push @_, random_word while @_ < $_;
    push @_, (qw(net com))[int rand 2];
    return join ".", @_;
}

1;

__END__
