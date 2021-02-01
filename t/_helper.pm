# _helper.pm - A simple test suite helper

# Copyright (c) 2007 imacat
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

package _helper;
use 5.005;
use strict;
use warnings;
use base qw(Exporter);
use vars qw($VERSION @EXPORT);
$VERSION = "0.01";
@EXPORT = qw();
push @EXPORT, qw(fread frread fwrite frwrite);
push @EXPORT, qw(runcmd whereis ftype flist prsrvsrc cleanup);
push @EXPORT, qw(nofile nogzip nobzip2);
push @EXPORT, qw(mkrndlog_existing);
push @EXPORT, qw(mkrndlog_apache mkrndlog_syslog);
push @EXPORT, qw(mkrndlog_ntp mkrndlog_apachessl mkrndlog_modfiso);
push @EXPORT, qw(randword);
push @EXPORT, qw(TYPE_PLAIN TYPE_GZIP TYPE_BZIP2);
push @EXPORT, qw(@LOGFMTS @SRCTYPES @RESTYPES @KEEPTYPES @OVERTYPES);
# Prototype declaration
sub thisfile();
sub fread($);
sub frread($);
sub fwrite($$);
sub frwrite($$);
sub runcmd($@);
sub whereis($);
sub ftype($);
sub flist($);
sub prsrvsrc($);
sub cleanup($$$);
sub nofile();
sub nogzip();
sub nobzip2();
sub mkrndlog_existing($$$@);
sub mkrndlog_apache($;$);
sub mkrndlog_syslog($;$);
sub mkrndlog_ntp($;$);
sub mkrndlog_apachessl($;$);
sub mkrndlog_modfiso($;$);
sub monrng_one($);
sub monrng_rand();
sub split_months(\@);
sub insert_malformed(\@);
sub randword();
sub randip();
sub randdomain();

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

use vars qw(%WHEREIS $NOFILE $NOGZIP $NOBZIP2);
%WHEREIS = qw();
undef $NOFILE;
undef $NOGZIP;
undef $NOBZIP2;

use constant TYPE_PLAIN => "text/plain";
use constant TYPE_GZIP => "application/x-gzip";
use constant TYPE_BZIP2 => "application/x-bzip2";

use vars qw(@LOGFMTS @SRCTYPES @RESTYPES @KEEPTYPES @OVERTYPES);
# All the log format information
@LOGFMTS = (    {   "title" => "Apache acecss log",
                    "sub"   => \&mkrndlog_apache, },
                {   "title" => "Syslog",
                    "sub"   => \&mkrndlog_syslog, },
                {   "title" => "NTP",
                    "sub"   => \&mkrndlog_ntp, },
                {   "title" => "Apache SSL engine log",
                    "sub"   => \&mkrndlog_apachessl, },
                {   "title" => "modified ISO 8601 date/time",
                    "sub"   => \&mkrndlog_modfiso, }, );
# All the source type information
@SRCTYPES = (   {   "title" => "plain text source",
                    "type"  => TYPE_PLAIN,
                    "suf"   => "",
                    "skip"  => 0, },
                {   "title" => "gzip source",
                    "type"  => TYPE_GZIP,
                    "suf"   => ".gz",
                    "skip"  => nogzip, },
                {   "title" => "bzip2 source",
                    "type"  => TYPE_BZIP2,
                    "suf"   => ".bz2",
                    "skip"  => nobzip2, }, );
# All the result type information
@RESTYPES = (   {   "title" => "default compress",
                    "type"  => TYPE_GZIP,
                    "suf"   => ".gz",
                    "skip"  => nogzip,
                    "opts"  => [], },
                {   "title" => "gzip compress",
                    "type"  => TYPE_GZIP,
                    "suf"   => ".gz",
                    "skip"  => nogzip,
                    "opts"  => [qw(-c g)], },
                {   "title" => "bzip2 compress",
                    "type"  => TYPE_BZIP2,
                    "suf"   => ".bz2",
                    "skip"  => nobzip2,
                    "opts"  => [qw(-c b)], },
                {   "title" => "no compress",
                    "type"  => TYPE_PLAIN,
                    "suf"   => "",
                    "skip"  => 0,
                    "opts"  => [qw(-c n)], }, );
# All the keep type information
@KEEPTYPES = (  {   "title" => "keep default",
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
# All the override type information
@OVERTYPES = (  {   "title" => "override no existing",
                    "opts"  => [],
                    "mkex"  => 0,
                    "ok"    => 1,
                    "ce"    => sub { $_[1]; }, },
                {   "title" => "override default",
                    "opts"  => [],
                    "mkex"  => 1,
                    "ok"    => 0,
                    "ce"    => sub { $_[0]; }, },
                {   "title" => "override overwrite",
                    "opts"  => [qw(-o o)],
                    "mkex"  => 1,
                    "ok"    => 1,
                    "ce"    => sub { $_[1]; }, },
                {   "title" => "override append",
                    "opts"  => [qw(-o a)],
                    "mkex"  => 1,
                    "ok"    => 1,
                    "ce"    => sub { $_[0] . $_[1]; }, },
                {   "title" => "override ignore",
                    "opts"  => [qw(-o i)],
                    "mkex"  => 1,
                    "ok"    => 1,
                    "ce"    => sub { $_[0] || $_[1]; }, },
                {   "title" => "override fail",
                    "opts"  => [qw(-o f)],
                    "mkex"  => 1,
                    "ok"    => 0,
                    "ce"    => sub { $_[0]; }, }, );

# thisfile: Return the name of this file
sub thisfile() { basename($0); }

# fread: A simple reader to read a log file in any supported format
sub fread($) {
    local ($_, %_);
    my ($file, $content);
    $file = $_[0];
    
    # non-existing file
    return undef if !-e $file;
    
    # a gzip compressed file
    if ($file =~ /\.gz$/) {
        # Compress::Zlib
        if (eval {  require Compress::Zlib;
                    import Compress::Zlib qw(gzopen);
                    1; }) {
            my ($FH, $gz);
            $content = "";
            open $FH, $file             or die thisfile . ": $file: $!";
            $gz = gzopen($FH, "rb")     or die thisfile . ": $file: $!";
            while (1) {
                ($gz->gzread($_, 10240) != -1)
                                        or die thisfile . ": $file: " . $gz->gzerror;
                $content .= $_;
                last if length $_ < 10240;
            }
            $gz->gzclose                and die thisfile . ": $file: " . $gz->gzerror;
            return $content;
        
        # gzip executable
        } else {
            my ($PH, $CMD);
            $CMD = whereis "gzip";
            $CMD = "\"$CMD\" -cd \"$file\"";
            open $PH, "$CMD |"          or die thisfile . ": $CMD: $!";
            $content = join "", <$PH>;
            close $PH                   or die thisfile . ": $CMD: $!";
            return $content;
        }
    
    # a bzip compressed file
    } elsif ($file =~ /\.bz2$/) {
        # Compress::Bzip2
        if (eval {  require Compress::Bzip2;
                    import Compress::Bzip2 2.00;
                    import Compress::Bzip2 qw(bzopen);
                    1; }) {
            my ($FH, $bz);
            $content = "";
            open $FH, $file             or die thisfile . ": $file: $!";
            $bz = bzopen($FH, "rb")     or die thisfile . ": $file: $!";
            while (1) {
                ($bz->bzread($_, 10240) != -1)
                                        or die thisfile . ": $file: " . $bz->bzerror;
                $content .= $_;
                last if length $_ < 10240;
            }
            $bz->bzclose                and die thisfile . ": $file: " . $bz->bzerror;
            return $content;
        
        # bzip2 executable
        } else {
            my ($PH, $CMD);
            $CMD = whereis "bzip2";
            $CMD = "bzip2 -cd \"$file\"";
            open $PH, "$CMD |"          or die thisfile . ": $CMD: $!";
            $content = join "", <$PH>;
            close $PH                   or die thisfile . ": $CMD: $!";
            return $content;
        }
    
    # a plain text file
    } else {
        my $FH;
        open $FH, $file                 or die thisfile . ": $file: $!";
        $content = join "", <$FH>;
        close $FH                       or die thisfile . ": $file: $!";
        return $content;
    }
}

# frread: A raw file reader
sub frread($) {
    local ($_, %_);
    my ($file, $content, $FH, $size);
    $file = $_[0];
    
    # non-existing file
    return undef if !-e $file;
    
    $size = (stat $file)[7];
    open $FH, $file                     or die thisfile . ": $file: $!";
    binmode $FH                         or die thisfile . ": $file: $!";
    (read($FH, $content, $size) == $size)
                                        or die thisfile . ": $file: $!";
    close $FH                           or die thisfile . ": $file: $!";
    return $content;
}

# fwrite: A simple writer to write a log file in any supported format
sub fwrite($$) {
    local ($_, %_);
    my ($file, $content);
    ($file, $content) = @_;
    
    # a gzip compressed file
    if ($file =~ /\.gz$/) {
        # Compress::Zlib
        if (eval {  require Compress::Zlib;
                    import Compress::Zlib qw(gzopen);
                    1; }) {
            my ($FH, $gz);
            open $FH, ">$file"          or die thisfile . ": $file: $!";
            $gz = gzopen($FH, "wb9")    or die thisfile . ": $file: $!";
            ($gz->gzwrite($content) == length $content)
                                        or die thisfile . ": $file: " . $gz->gzerror;
            $gz->gzclose                and die thisfile . ": $file: " . $gz->gzerror;
            return;
        
        # gzip executable
        } else {
            my ($PH, $CMD);
            $CMD = whereis "gzip";
            $CMD = "\"$CMD\" -c9f > \"$file\"";
            open $PH, "| $CMD"          or die thisfile . ": $CMD: $!";
            print $PH $content          or die thisfile . ": $CMD: $!";
            close $PH                   or die thisfile . ": $CMD: $!";
            return;
        }
    
    # a bzip compressed file
    } elsif ($file =~ /\.bz2$/) {
        # Compress::Bzip2
        if (eval {  require Compress::Bzip2;
                    import Compress::Bzip2 2.00;
                    import Compress::Bzip2 qw(bzopen);
                    1; }) {
            my ($FH, $bz);
            open $FH, ">$file"          or die thisfile . ": $file: $!";
            $bz = bzopen($FH, "wb9")    or die thisfile . ": $file: $!";
            ($bz->bzwrite($content, length $content) == length $content)
                                        or die thisfile . ": $file: " . $bz->bzerror;
            $bz->bzclose                and die thisfile . ": $file: " . $bz->bzerror;
            return;
        
        # bzip2 executable
        } else {
            my ($PH, $CMD);
            $CMD = whereis "bzip2";
            $CMD = "\"$CMD\" -9f > \"$file\"";
            open $PH, "| $CMD"        or die thisfile . ": $CMD: $!";
            print $PH $content        or die thisfile . ": $CMD: $!";
            close $PH                 or die thisfile . ": $CMD: $!";
            return;
        }
    
    # a plain text file
    } else {
        my $FH;
        open $FH, ">$file"              or die thisfile . ": $file: $!";
        print $FH $content              or die thisfile . ": $file: $!";
        close $FH                       or die thisfile . ": $file: $!";
        return;
    }
}

# frwrite: A raw file writer
sub frwrite($$) {
    local ($_, %_);
    my ($file, $content, $FH);
    ($file, $content) = @_;
    
    open $FH, ">$file"                  or die thisfile . ": $file: $!";
    binmode $FH                         or die thisfile . ": $file: $!";
    print $FH $content                  or die thisfile . ": $file: $!";
    close $FH                           or die thisfile . ": $file: $!";
    return;
}

# runcmd: Run a command and return the result
sub runcmd($@) {
    local ($_, %_);
    my ($retno, $out, $err, $in, @cmd, $cmd, $OUT, $ERR, $STDOUT, $STDERR, $PH);
    ($in, @cmd) = @_;
    
    $err = "Running " . join(" ", map "\"$_\"", @cmd) . "\n";
    $out = "";
    
    open $STDOUT, ">&", \*STDOUT        or die thisfile . ": STDOUT: $!";
    open $STDERR, ">&", \*STDERR        or die thisfile . ": STDERR: $!";
    $OUT = tempfile                     or die thisfile . ": tempfile: $!";
    binmode $OUT                        or die thisfile . ": tempfile: $!";
    $ERR = tempfile                     or die thisfile . ": tempfile: $!";
    binmode $ERR                        or die thisfile . ": tempfile: $!";
    open STDOUT, ">&", $OUT             or die thisfile . ": tempfile: $!";
    binmode STDOUT                      or die thisfile . ": tempfile: $!";
    open STDERR, ">&", $ERR             or die thisfile . ": tempfile: $!";
    binmode STDERR                      or die thisfile . ": tempfile: $!";
    
    $cmd = join " ", map "\"$_\"", @cmd;
    if ($^O eq "MSWin32") {
        open $PH, "| $cmd"              or die thisfile . ": $cmd: $!";
    } else {
        open $PH, "|-", @cmd            or die thisfile . ": $cmd: $!";
    }
    binmode $PH                         or die thisfile . ": $cmd: $!";
    print $PH $in                       or die thisfile . ": $cmd: $!";
    close $PH;
    $retno = $?;
    
    open STDOUT, ">&", $STDOUT          or die thisfile . ": tempfile: $!";
    open STDERR, ">&", $STDERR          or die thisfile . ": tempfile: $!";
    
    seek $OUT, 0, SEEK_SET              or die thisfile . ": tempfile: $!";
    $out = join "", <$OUT>;
    close $OUT                          or die thisfile . ": tempfile: $!";
    seek $ERR, 0, SEEK_SET              or die thisfile . ": tempfile: $!";
    $err = join "", <$ERR>;
    close $ERR                          or die thisfile . ": tempfile: $!";
    
    return ($retno, $out, $err);
}

# whereis: Find an executable
#   Code inspired from CPAN::FirstTime
sub whereis($) {
    local ($_, %_);
    my ($file, $path);
    $file = $_[0];
    return $WHEREIS{$file} if exists $WHEREIS{$file};
    foreach my $dir (path) {
        return ($WHEREIS{$file} = $path)
            if defined($path = MM->maybe_command(catfile($dir, $file)));
    }
    return ($WHEREIS{$file} = undef);
}

# ftype: Find the file type
sub ftype($) {
    local ($_, %_);
    my $file;
    $file = $_[0];
    return undef unless -e $file;
    # Use File::MMagic
    if (eval { require File::MMagic; 1; }) {
        $_ = new File::MMagic->checktype_filename($file);
        return "application/x-gzip" if /gzip/;
        return "application/x-bzip2" if /bzip2/;
        # All else are text/plain
        return "text/plain";
    }
    # Use file executable
    if (defined($_ = whereis "file")) {
        $_ = join "", `"$_" "$file"`;
        return "application/x-gzip" if /gzip/;
        return "application/x-bzip2" if /bzip2/;
        # All else are text/plain
        return "text/plain";
    }
    # No type checker available
    return undef;
}

# flist: Obtain the files list in a directory
sub flist($) {
    local ($_, %_);
    my ($dir, $DH);
    $dir = $_[0];
    @_ = qw();
    opendir $DH, $dir                   or die thisfile . ": $dir: $!";
    while (defined($_ = readdir $DH)) {
        next if $_ eq "." || $_ eq ".." || !-f "$dir/$_";
        push @_, $_;
    }
    closedir $DH                        or die thisfile . ": $dir: $!";
    return join " ", sort @_;
}

# prsrvsrc: Preserve the source test files
sub prsrvsrc($) {
    local ($_, %_);
    my ($dir, $DH);
    $dir = $_[0];
    @_ = qw();
    opendir $DH, $dir                   or die thisfile . ": $dir: $!";
    while (defined($_ = readdir $DH)) {
        next if $_ eq "." || $_ eq ".." || !-f "$dir/$_";
        push @_, $_;
    }
    closedir $DH                        or die thisfile . ": $dir: $!";
    rmtree "$dir/source";
    mkpath "$dir/source";
    frwrite "$dir/source/$_", frread "$dir/$_"
        foreach @_;
    return;
}

# cleanup: Clean up the test files
sub cleanup($$$) {
    local ($_, %_);
    my ($r, $dir, $testno, $testname, $c);
    ($r, $dir, $testno) = @_;
    # Nothing to clean up
    return unless -e $dir;
    # Success
    if ($r) {
        rmtree $dir;
        return;
    }
    # Fail - keep the test files for failure investigation
    $testname = basename((caller)[1]);
    $testname =~ s/\.t$//;
    $c = 1;
    $c++ while -e ($_ = "$dir.$testname.$testno.$c");
    rename $dir, $_                     or die thisfile . ": $dir, $_: $!";
    return;
}

# nofile: If we have the file type checker somewhere
sub nofile() {
    $NOFILE = eval { require File::MMagic; 1; }
                || defined whereis "file"?
            0: "File::MMagic or file executable not available"
        if !defined $NOFILE;
    return $NOFILE;
}

# nogzip: If we have gzip support somewhere
sub nogzip() {
    $NOGZIP = eval { require Compress::Zlib; 1; }
                || defined whereis "gzip"?
            0: "Compress::Zlib or gzip executable not available"
        if !defined $NOGZIP;
    return $NOGZIP;
}

# nobzip2: If we have bzip2 support somewhere
sub nobzip2() {
    $NOBZIP2 = eval { require Compress::Bzip2; import Compress::Bzip2 2.00; 1; }
                || defined whereis "bzip2"?
            0: "Compress::Bzip2 v2 or bzip2 executable not available"
        if !defined $NOBZIP2;
    return $NOBZIP2;
}

# mkrndlog_existing: Create a random existing log file
sub mkrndlog_existing($$$@) {
    local ($_, %_);
    my ($mkrndlog, $dir, $filepat, @months, %contents);
    ($mkrndlog, $dir, $filepat, @months) = @_;
    
    # Find a non-decided month and have an existing log
    $_{$_[int rand @_]} = 1 if (@_ = grep !exists $_{$_}, @months) > 0;
    # Find a non-decided month and not have an existing log
    $_{$_[int rand @_]} = 0 if (@_ = grep !exists $_{$_}, @months) > 0;
    # Decide the remain months randomly
    $_{$_} = int rand 2 foreach grep !exists $_{$_}, @months;
    %contents = qw();
    foreach my $m (@months) {
        my ($file, $path);
        $file = sprintf($filepat, $m);
        $path = catfile($dir, $file);
        if ($_{$m}) {
            $contents{$file} = (&$mkrndlog($path, $m))[0];
        } else {
            $contents{$file} = "";
        }
    }
    
    return %contents;
}

# mkrndlog_apache: Create a random Apache access log file
sub mkrndlog_apache($;$) {
    local ($_, %_);
    my ($file, $month, @logs, $content, @monrng, %months, $vardump, $tz);
    ($file, $month) = @_;
    
    @logs = qw();
    
    # Time zone
    $tz = (-12 + (int rand 53) / 2) * 3600;
    # To be removed
    #$tz = -12 + (int rand 53) / 2;
    #$tz = sprintf "%+05d", int($tz) * 100 + ($tz - int($tz)) * 60;
    
    # Get the range of a month
    if (defined $month) {
        @monrng = monrng_one $month;
    # Get the range of some previous months
    } else {
        @monrng = monrng_rand;
    }
    for (my $i = 0; $i + 1 < @monrng; $i++) {
        my $hosts;
        # 2-5 hosts
        $hosts = 2 + int rand 4;
        # Generate the visit time of each host
        for (my $j = 0; $j < $hosts; $j++) {
            my ($host, $t, $user, $htver, @hlogs, $hlogs);
            # Host type: 1: IP, 0: domain name
            $host = int rand 2? randip: randdomain;
            $t = $monrng[$i] + int rand($monrng[$i + 1] - $monrng[$i]);
            $user = (0, 0, 1)[int rand 3]? "-": randword;
            $htver = (qw(HTTP/1.1 HTTP/1.1 HTTP/1.1 HTTP/1.0))[int rand 4];
            # 3-5 log records for each host
            $hlogs = 3 + int rand 3;
            @hlogs = qw();
            while (@hlogs < $hlogs) {
                my ($ttxt, $method, $url, $dirs, @dirs, $type, $status, $size);
                # Time text
                @_ = gmtime($t + $tz);
                $_[5] += 1900;
                $_[4] = (qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec))[$_[4]];
                $ttxt = sprintf "%02d/%s/%04d:%02d:%02d:%02d %+05d",
                    @_[3,4,5,2,1,0],
                    int($tz / 3600) * 100 + ($tz - int($tz / 3600) * 3600) / 60;
                
                $method = (qw(GET GET GET HEAD POST))[int rand 5];
                
                # Generate a random URL
                # 0-3 levels of directories
                $dirs = int rand 4;
                @dirs = qw();
                push @dirs, "/" . randword while @dirs < $dirs;
                $type = ("", qw(html html txt css png jpg))[int rand 7];
                if ($type eq "") {
                    $url = join("", @dirs) . "/";
                } else {
                    $url = join("", @dirs) . "/" . randword . ".$type";
                }
                
                $status = (200, 200, 200, 200, 304, 400, 403, 404)[int rand 8];
                if ($status == 304) {
                    $size = 0;
                } else {
                    $size = 200 + int rand 35000;
                }
                push @hlogs, {
                        "time"      => $t,
                        "record"    => sprintf("%s - %s [%s] \"%s %s %s\" %d %d\n",
                            $host, $user, $ttxt,
                            $method, $url, $htver, $status, $size),
                    };
                
                # 0-2 seconds later
                $t += int rand 3;
            }
            push @logs, @hlogs;
            # 0-5 seconds later
            $t += int rand 6;
        }
    }
    
    # Sort by time
    # A series of requests from a same host may run cross the next host
    # So we need to sort again
    @logs = sort { $$a{"time"} <=> $$b{"time"} } @logs;
    
    # Variables used, for failure investigation
    $vardump = Data::Dumper->Dump([\@logs, $tz], [qw($logs $tz)]);
    
    # Split by months
    %months = split_months @logs;
    # Drop the time and keep the records
    @logs = map $$_{"record"}, @logs;
    # Insert 1-2 malformed lines
    insert_malformed @logs;
    
    # Compose the content
    $content = join "", @logs;
    # Output the file
    fwrite($file, $content);
    # Return the content
    return $content, $vardump, %months;
}

# mkrndlog_syslog: Create a random Syslog log file
sub mkrndlog_syslog($;$) {
    local ($_, %_);
    my ($file, $month, @logs, $content, @monrng, %months, $vardump);
    my (@hosts, $hosts);
    ($file, $month) = @_;
    
    @logs = qw();
    
    # 3-5 hosts
    $hosts = 3 + int rand 3;
    @hosts = qw();
    push @hosts, randword while @hosts < $hosts;
    
    # Get the range of a month
    if (defined $month) {
        @monrng = monrng_one $month;
    # Get the range of some previous months
    } else {
        @monrng = monrng_rand;
    }
    for (my $i = 0; $i + 1 < @monrng; $i++) {
        my (@mlogs, $mlogs, @t);
        # 5-12 log records for each month
        $mlogs = 5 + int rand 8;
        @mlogs = qw();
        # Generate the time of each record
        @t = qw();
        push @t, $monrng[$i] + int rand($monrng[$i + 1] - $monrng[$i])
            while @t < $mlogs;
        foreach my $t (sort @t) {
            my ($ttxt, $host, $app, $pid, $msg);
            # Time text
            @_ = localtime $t;
            $_[5] += 1900;
            $_[4] = (qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec))[$_[4]];
            $ttxt = sprintf "%s %2d %02d:%02d:%02d", @_[4,3,2,1,0];
            $host = $hosts[int rand scalar @hosts];
            $app = (qw(kernel sendmail sshd su CRON), randword, randword)[int rand 5];
            # PID 2-65535 (PID 1 is init)
            $pid = 2 + int rand 65533;
            # 3-12 words for each message
            $_ = 3 + int rand 10;
            @_ = qw();
            push @_, randword while @_ < $_;
            $msg = join " ", @_;
            
            push @mlogs, {
                    "time"      => $t,
                    "record"    => sprintf("%s %s %s[%d] %s\n",
                        $ttxt, $host, $app, $pid, $msg),
                };
        }
        push @logs, @mlogs;
    }
    
    # Variables used, for failure investigation
    $vardump = Data::Dumper->Dump([\@logs], [qw($logs)]);
    
    # Split by months
    %months = split_months @logs;
    # Drop the time and keep the records
    @logs = map $$_{"record"}, @logs;
    # Insert 1-2 malformed lines
    insert_malformed @logs;
    
    # Compose the content
    $content = join "", @logs;
    # Output the file
    fwrite($file, $content);
    # Return the content
    return $content, $vardump, %months;
}

# mkrndlog_ntp: Create a random NTP log file
sub mkrndlog_ntp($;$) {
    local ($_, %_);
    my ($file, $month, @logs, $content, @monrng, %months, $vardump);
    my ($pid, $peers, @peers, $refs, @refs);
    ($file, $month) = @_;
    
    @logs = qw();
    
    # PID 2-65535 (PID 1 is init)
    $pid = 2 + int rand 65533;
    # 3-5 peers
    $peers = 3 + int rand 3;
    @peers = qw();
    push @peers, randip while @peers < $peers;
    # 2-3 references
    $refs = 2 + int rand 2;
    push @refs, randip while @refs < $refs;
    
    # Get the range of a month
    if (defined $month) {
        @monrng = monrng_one $month;
    # Get the range of some previous months
    } else {
        @monrng = monrng_rand;
    }
    for (my $i = 0; $i + 1 < @monrng; $i++) {
        my (@mlogs, $mlogs, @t);
        # 5-12 log records for each month
        $mlogs = 5 + int rand 8;
        @mlogs = qw();
        # Generate the time of each record
        @t = qw();
        push @t, $monrng[$i] + int rand($monrng[$i + 1] - $monrng[$i])
            while @t < $mlogs;
        foreach my $t (sort @t) {
            my ($ttxt, $type, $msg);
            # Time text
            @_ = localtime $t;
            $_[5] += 1900;
            $_[4] = (qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec))[$_[4]];
            $ttxt = sprintf "%2d %s %02d:%02d:%02d", @_[3,4,2,1,0];
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
                my ($refhost, $stratum);
                $refhost = $refs[int rand @refs];
                # Stratum 2-4
                $stratum = 2 + int rand 2;
                $msg = "synchronized to $refhost, stratum $stratum";
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
            
            push @mlogs, {
                    "time"      => $t,
                    "record"    => sprintf("%s ntpd[%d] %s\n",
                        $ttxt, $pid, $msg),
                };
        }
        push @logs, @mlogs;
    }
    
    # Variables used, for failure investigation
    $vardump = Data::Dumper->Dump([\@logs], [qw($logs)]);
    
    # Split by months
    %months = split_months @logs;
    # Drop the time and keep the records
    @logs = map $$_{"record"}, @logs;
    # Insert 1-2 malformed lines
    insert_malformed @logs;
    
    # Compose the content
    $content = join "", @logs;
    # Output the file
    fwrite($file, $content);
    # Return the content
    return $content, $vardump, %months;
}

# mkrndlog_apachessl: Create a random Apache SSL engine log file
sub mkrndlog_apachessl($;$) {
    local ($_, %_);
    my ($file, $month, @logs, $content, @monrng, %months, $vardump);
    my $host;
    ($file, $month) = @_;
    
    @logs = qw();
    
    $host = randdomain;
    
    # Get the range of a month
    if (defined $month) {
        @monrng = monrng_one $month;
    # Get the range of some previous months
    } else {
        @monrng = monrng_rand;
    }
    for (my $i = 0; $i + 1 < @monrng; $i++) {
        my (@mlogs, $mlogs, @t);
        # 3-5 visitors for each month
        $mlogs = 3 + int rand 3;
        @mlogs = qw();
        # Generate the time of each record
        @t = qw();
        push @t, $monrng[$i] + int rand($monrng[$i + 1] - $monrng[$i])
            while @t < $mlogs;
        foreach my $t (sort @t) {
            my ($ttxt, $pid, $remote, $priority, $child, $msg);
            # Time text
            @_ = localtime $t;
            $_[5] += 1900;
            $_[4] = (qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec))[$_[4]];
            $ttxt = sprintf "%02d/%s/%04d %02d:%02d:%02d", @_[3,4,5,2,1,0];
            # PID 2-65535 (PID 1 is init)
            $pid = 2 + int rand 65533;
            # Remote client
            $remote = randip;
            # Child number
            $child = int rand 15;
            
            # Error
            if (int rand 5 == 1) {
                $priority = "error";
                $msg = "SSL handshake failed (server $host:443, client $remote) (OpenSSL library error follows)";
                push @mlogs, {
                        "time"      => $t,
                        "record"    => sprintf("[%s %05d] [%s]  %s\n",
                            $ttxt, $pid, $priority, $msg),
                    };
                $msg = "OpenSSL: error:1408E0F4:SSL routines:SSL3_GET_MESSAGE:unexpected message";
                push @mlogs, {
                        "time"      => $t,
                        "record"    => sprintf("[%s %05d] [%s]  %s\n",
                            $ttxt, $pid, $priority, $msg),
                    };
            
            # Info
            } else {
                $priority = "info";
                $msg = "Connection to child $child established (server $host:443, client $remote)";
                push @mlogs, {
                        "time"      => $t,
                        "record"    => sprintf("[%s %05d] [%s]  %s\n",
                            $ttxt, $pid, $priority, $msg),
                    };
                $msg = "Seeding PRNG with 1164 bytes of entropy";
                push @mlogs, {
                        "time"      => $t,
                        "record"    => sprintf("[%s %05d] [%s]  %s\n",
                            $ttxt, $pid, $priority, $msg),
                    };
                # 1: bad
                if (int rand 2) {
                    $msg = "Spurious SSL handshake interrupt[Hint: Usually just one of those OpenSSL confusions!?]";
                    push @mlogs, {
                            "time"      => $t,
                            "record"    => sprintf("[%s %05d] [%s]  %s\n",
                                $ttxt, $pid, $priority, $msg),
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
                        push @mlogs, {
                                "time"      => $t,
                                "record"    => sprintf("[%s %05d] [%s]  %s\n",
                                    $ttxt, $pid, $priority, $msg),
                            };
                    }
                    $msg = "Connection to child $child closed with standard shutdown (server $host:443, client $remote)";
                    push @mlogs, {
                            "time"      => $t,
                            "record"    => sprintf("[%s %05d] [%s]  %s\n",
                                $ttxt, $pid, $priority, $msg),
                        };
                }
            }
        }
        push @logs, @mlogs;
    }
    
    # Variables used, for failure investigation
    $vardump = Data::Dumper->Dump([\@logs], [qw($logs)]);
    
    # Split by months
    %months = split_months @logs;
    # Drop the time and keep the records
    @logs = map $$_{"record"}, @logs;
    # Insert 1-2 malformed lines
    insert_malformed @logs;
    
    # Compose the content
    $content = join "", @logs;
    # Output the file
    fwrite($file, $content);
    # Return the content
    return $content, $vardump, %months;
}

# mkrndlog_modfiso: Create a random modified ISO 8861 date/time log file
sub mkrndlog_modfiso($;$) {
    local ($_, %_);
    my ($file, $month, @logs, $content, @monrng, %months, $vardump, $tz);
    ($file, $month) = @_;
    
    @logs = qw();
    
    # Time zone
    $tz = (-12 + (int rand 53) / 2) * 3600;
    # To be removed
    #$tz = -12 + (int rand 53) / 2;
    #$tz = sprintf "%+05d", int($tz) * 100 + ($tz - int($tz)) * 60;
    
    # Get the range of a month
    if (defined $month) {
        @monrng = monrng_one $month;
    # Get the range of some previous months
    } else {
        @monrng = monrng_rand;
    }
    for (my $i = 0; $i + 1 < @monrng; $i++) {
        my (@mlogs, $mlogs, @t);
        # 5-12 log records for each month
        $mlogs = 3 + int rand 3;
        @mlogs = qw();
        # Generate the time of each record
        @t = qw();
        push @t, $monrng[$i] + int rand($monrng[$i + 1] - $monrng[$i])
            while @t < $mlogs;
        foreach my $t (sort @t) {
            my ($ttxt, $id, $msg);
            # Time text
            @_ = gmtime($t + $tz);
            $_[5] += 1900;
            $_[4]++;
            $ttxt = sprintf "%04d-%02d-%02d %02d:%02d:%02d %+05d",
                @_[5,4,3,2,1,0], 
                int($tz / 3600) * 100 + ($tz - int($tz / 3600) * 3600) / 60;
            # identity
            $id = randword;
            # 3-12 words for each message
            $_ = 3 + int rand 10;
            @_ = qw();
            push @_, randword while @_ < $_;
            $msg = join " ", @_;
            push @mlogs, {
                    "time"      => $t,
                    "record"    => sprintf("[%s] %s: %s\n",
                        $ttxt, $id, $msg),
                };
        }
        push @logs, @mlogs;
    }
    
    # Variables used, for failure investigation
    $vardump = Data::Dumper->Dump([\@logs, $tz], [qw($logs $tz)]);
    
    # Split by months
    %months = split_months @logs;
    # Drop the time and keep the records
    @logs = map $$_{"record"}, @logs;
    # Insert 1-2 malformed lines
    insert_malformed @logs;
    
    # Compose the content
    $content = join "", @logs;
    # Output the file
    fwrite($file, $content);
    # Return the content
    return $content, $vardump, %months;
}

# monrng_one: Get the range of a specific month
sub monrng_one($) {
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

# monrng_rand: Get the range of some previous months
sub monrng_rand() {
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

# split_months: Split the log records by months
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

# insert_malformed: Insert 1-2 malformed lines
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
        push @_, randword while @_ < $_;
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

# randword: Supply a random English word
sub randword() {
    local ($_, %_);
    @_ = qw(
culminates spector thule tamil sages fasten bothers intricately librarian
mist criminate impressive scissor trance standardizing enabler athenians
planers decisions salvation wetness fibers cowardly winning call stockton
bifocal rapacious steak reinserts overhaul glaringly playwrights wagoner
garland hampered effie messy despaired orthodoxy bacterial bernardine driving
danization vapors uproar sects litmus sutton lacrosse);
    return $_[int rand @_];
}

# randip: Supply a random IP
sub randip() {
    return join ".", (int rand 255, int rand 255,
        int rand 255, 1 + int rand 254);
}

# randdomain: Supply a random domain
sub randdomain() {
    local ($_, %_);
    # Generate a random domain name
    # 3-5 levels, end with net or com
    $_ = 2 + int rand 3;
    @_ = qw();
    push @_, randword while @_ < $_;
    push @_, (qw(net com))[int rand 2];
    return join ".", @_;
}

1;

__END__
