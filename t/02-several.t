#! /usr/bin/perl -w
# Test archiving several log files at once

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

use 5.005;
use strict;
use warnings;
use diagnostics;
use Test;

BEGIN { plan tests => 16 }

use File::Basename qw(basename);
use File::Path qw(mkpath rmtree);
use File::Spec::Functions qw(catdir catfile updir);
use FindBin;
use lib $FindBin::Bin;
use _helper;
use vars qw($WORKDIR $arclog $tno);

$WORKDIR = catdir($FindBin::Bin, "logs");
$arclog = catfile($FindBin::Bin, updir, "blib", "script", "arclog");
$tno = 0;

# 1-16: Archiving several log files at once
foreach my $rt (@RESTYPES) {
    my $skip;
    $skip = 0;
    # 1: Source log files listed as the arguments
    $_ = eval {
        if (    ($$rt{"type"} eq TYPE_GZIP && nogzip)
                || ($$rt{"type"} eq TYPE_BZIP2 && nobzip2)) {
            $skip = 1;
            return;
        }
        my ($title, $cmd, $retno, $out, $err, @vardump, %logfiles);
        my ($fr, $frb, @fle, $fle, $flr, %cef, %crf, %tef, %trf);
        my ($num, @fs, @cs, @cem, @mle, %cof, $opref, $oprfb, $mt);
        my (@st, $fmt);
        rmtree $WORKDIR;
        mkpath $WORKDIR;
        $fmt = $LOGFMTS[int rand @LOGFMTS];
        $title = join ", ", "several log files", "all listed as arguments",
            $$fmt{"title"}, $$rt{"title"};
        # (2-4 times available compression) log files
        $_ = 2 + (nogzip? 0: 2) + (nobzip2? 0: 2);
        $num = $_ + int rand $_;
        %_ = qw();
        # At least 2 files for each available compression
        foreach my $st (@SRCTYPES) {
            next if ($$st{"type"} eq TYPE_GZIP && nogzip)
                    || ($$st{"type"} eq TYPE_BZIP2 && nobzip2);
            @_ = grep !exists $_{$_}, (0...$num-1);
            $_{$_[int rand @_]} = $st;
            @_ = grep !exists $_{$_}, (0...$num-1);
            $_{$_[int rand @_]} = $st;
        }
        # Set random compression on the rest files
        foreach (grep !exists $_{$_}, (0...$num-1)) {
            do {
                $_{$_} = $SRCTYPES[int rand @SRCTYPES];
            } until !(${$_{$_}}{"type"} eq TYPE_GZIP && nogzip)
                    && !(${$_{$_}}{"type"} eq TYPE_BZIP2 && nobzip2);
        }
        @st = map $_{$_}, (0...$num-1);
        @fs = qw();
        @cs = qw();
        @cem = qw();
        @vardump = qw();
        @fle = qw();
        %logfiles = qw();
        for (my $k = 0; $k < $num; $k++) {
            my ($logfile, $cs, $vardump);
            do { $logfile = randword } until !exists $logfiles{$logfile};
            $logfiles{$logfile} = 1;
            $logfile .= ${$st[$k]}{"suf"};
            push @fs, catfile($WORKDIR, $logfile);
            ($cs, $vardump, %_) = &{$$fmt{"sub"}}($fs[$k]);
            push @cs, $cs;
            push @cem, {%_};
            push @fle, $logfile;
            push @vardump, $vardump;
            frwrite(catfile($WORKDIR, "$logfile.vardump"), $vardump);
            push @fle, "$logfile.vardump";
        }
        %_ = qw();
        %_ = (%_, map { $_ => 1 } keys %$_) foreach @cem;
        @mle = sort keys %_;
        $mt = pop @mle;
        do { $oprfb = randword } until !exists $logfiles{$oprfb};
        $opref = catfile($WORKDIR, $oprfb);
        %cof = mkrndlog_existing $$fmt{"sub"},
            $WORKDIR, "$oprfb.%s" . $$rt{"suf"}, @mle;
        push @fle, map "$oprfb.$_" . $$rt{"suf"}, @mle;
        prsrvsrc $WORKDIR;
        @_ = ($arclog, qw(-d -d -d -o a), @{$$rt{"opts"}}, @fs, $opref);
        $cmd = join(" ", @_);
        ($retno, $out, $err) = runcmd "", @_;
        ($fle, $flr) = (join(" ", sort @fle), flist $WORKDIR);
        %cef = qw();    # Expected content by file
        %tef = qw();    # Expected file type by file
        %crf = qw();    # Resulted content by file
        %trf = qw();    # Resulted file type by file
        for (my $k = 0; $k < $num; $k++) {
            $fr = $fs[$k];
            $frb = basename($fr);
            ($cef{$frb}, $tef{$frb}) = (${$cem[$k]}{$mt}, ${$st[$k]}{"type"});
            ($crf{$frb}, $trf{$frb}) = (fread $fr, ftype $fr);
            $fr = $fs[$k] . ".vardump";
            $frb = basename($fr);
            ($cef{$frb}, $tef{$frb}) = ($vardump[$k], TYPE_PLAIN);
            ($crf{$frb}, $trf{$frb}) = (fread $fr, ftype $fr);
        }
        foreach my $m (@mle) {
            $fr = "$opref.$m" . $$rt{"suf"};
            $frb = basename($fr);
            $cef{$frb} = $cof{$frb}
                . join "", map(exists $$_{$m}? $$_{$m}: "", @cem);
            $tef{$frb} = $$rt{"type"};
            ($crf{$frb}, $trf{$frb}) = (fread $fr, ftype $fr);
        }
        die "$title\n$cmd\n$out$err" unless $retno == 0;
        die "$title\n$cmd\nresult files incorrect.\nGot: $flr\nExpected: $fle\nOutput:\n$out$err"
            unless $flr eq $fle;
        foreach $fr (@fle) {
            die "$title\n$cmd\n$fr: result type incorrect.\nGot: $trf{$fr}\nExpected: $tef{$fr}\nOutput:\n$out$err"
                unless nofile || $trf{$fr} eq $tef{$fr};
            die "$title\n$cmd\n$fr: result incorrect.\nGot:\n$crf{$fr}\nExpected:\n$cef{$fr}\nOutput:\n$out$err"
                unless $crf{$fr} eq $cef{$fr};
        }
        1;
    };
    skip($skip, $_, 1, $@);
    cleanup $_ || $skip, $WORKDIR, ++$tno;
    
    # 2-4: One of the source log files is read from STDIN
    # The file type at STDIN
    foreach my $ststdin (@SRCTYPES) {
        $skip = 0;
        $_ = eval {
            if (    ($$rt{"type"} eq TYPE_GZIP && nogzip)
                    || ($$rt{"type"} eq TYPE_BZIP2 && nobzip2)
                    || ($$ststdin{"type"} eq TYPE_GZIP && nogzip)
                    || ($$ststdin{"type"} eq TYPE_BZIP2 && nobzip2)) {
                $skip = 1;
                return;
            }
            my ($title, $cmd, $retno, $out, $err, @vardump, %logfiles);
            my ($fr, $frb, @fle, $fle, $flr, %cef, %crf, %tef, %trf);
            my ($num, @fs, @cs, @cem, @mle, %cof, $opref, $oprfb, $stdin);
            my (@st, $fmt);
            rmtree $WORKDIR;
            mkpath $WORKDIR;
            $fmt = $LOGFMTS[int rand @LOGFMTS];
            $title = join ", ", "several log files", "one read from STDIN",
                "STDIN " . $$ststdin{"title"}, $$rt{"title"};
            # (2-4 times available compression) log files
            $_ = 2 + (nogzip? 0: 2) + (nobzip2? 0: 2);
            $num = $_ + int rand $_;
            %_ = qw();
            # At least 2 files for each available compression
            foreach my $st (@SRCTYPES) {
                next if ($$st{"type"} eq TYPE_GZIP && nogzip)
                        || ($$st{"type"} eq TYPE_BZIP2 && nobzip2);
                @_ = grep !exists $_{$_}, (0...$num-1);
                $_{$_[int rand @_]} = $st;
                @_ = grep !exists $_{$_}, (0...$num-1);
                $_{$_[int rand @_]} = $st;
            }
            # Set random compression on the rest files
            foreach (grep !exists $_{$_}, (0...$num-1)) {
                do {
                    $_{$_} = $SRCTYPES[int rand @SRCTYPES];
                } until !(${$_{$_}}{"type"} eq TYPE_GZIP && nogzip)
                        && !(${$_{$_}}{"type"} eq TYPE_BZIP2 && nobzip2);
            }
            # Choose the STDIN from the matching compression
            @_ = grep ${$_{$_}}{"type"} eq $$ststdin{"type"}, (0...$num-1);
            $stdin = $_[int rand @_];
            @st = map $_{$_}, (0...$num-1);
            @fs = qw();
            @cs = qw();
            @cem = qw();
            @vardump = qw();
            @fle = qw();
            %logfiles = qw();
            for (my $k = 0; $k < $num; $k++) {
                my ($logfile, $cs, $vardump);
                do { $logfile = randword } until !exists $logfiles{$logfile};
                $logfiles{$logfile} = 1;
                $logfile .= ${$st[$k]}{"suf"};
                push @fs, catfile($WORKDIR, $logfile);
                ($cs, $vardump, %_) = &{$$fmt{"sub"}}($fs[$k]);
                push @cs, $cs;
                push @cem, {%_};
                push @fle, $logfile;
                push @vardump, $vardump;
                frwrite(catfile($WORKDIR, "$logfile.vardump"), $vardump);
                push @fle, "$logfile.vardump";
            }
            %_ = qw();
            %_ = (%_, map { $_ => 1 } keys %$_) foreach @cem;
            @mle = sort keys %_;
            do { $oprfb = randword } until !exists $logfiles{$oprfb};
            $opref = catfile($WORKDIR, $oprfb);
            %cof = mkrndlog_existing $$fmt{"sub"},
                $WORKDIR, "$oprfb.%s" . $$rt{"suf"}, @mle;
            push @fle, map "$oprfb.$_" . $$rt{"suf"}, @mle;
            prsrvsrc $WORKDIR;
            @_ = @fs;
            $_[$stdin] = "-";
            @_ = ($arclog, qw(-d -d -d -k a -o a), @{$$rt{"opts"}}, @_, $opref);
            $cmd = join(" ", @_) . " < " . $fs[$stdin];
            ($retno, $out, $err) = runcmd frread $fs[$stdin], @_;
            ($fle, $flr) = (join(" ", sort @fle), flist $WORKDIR);
            %cef = qw();    # Expected content by file
            %tef = qw();    # Expected file type by file
            %crf = qw();    # Resulted content by file
            %trf = qw();    # Resulted file type by file
            for (my $k = 0; $k < $num; $k++) {
                $fr = $fs[$k];
                $frb = basename($fr);
                ($cef{$frb}, $tef{$frb}) = ($cs[$k], ${$st[$k]}{"type"});
                ($crf{$frb}, $trf{$frb}) = (fread $fr, ftype $fr);
                $fr = $fs[$k] . ".vardump";
                $frb = basename($fr);
                ($cef{$frb}, $tef{$frb}) = ($vardump[$k], TYPE_PLAIN);
                ($crf{$frb}, $trf{$frb}) = (fread $fr, ftype $fr);
            }
            foreach my $m (@mle) {
                $fr = "$opref.$m" . $$rt{"suf"};
                $frb = basename($fr);
                $cef{$frb} = $cof{$frb}
                    . join "", map(exists $$_{$m}? $$_{$m}: "", @cem);
                $tef{$frb} = $$rt{"type"};
                ($crf{$frb}, $trf{$frb}) = (fread $fr, ftype $fr);
            }
            die "$title\n$cmd\n$out$err" unless $retno == 0;
            die "$title\n$cmd\nresult files incorrect.\nGot: $flr\nExpected: $fle\nOutput:\n$out$err"
                unless $flr eq $fle;
            foreach $fr (@fle) {
                die "$title\n$cmd\n$fr: result type incorrect.\nGot: $trf{$fr}\nExpected: $tef{$fr}\nOutput:\n$out$err"
                    unless nofile || $trf{$fr} eq $tef{$fr};
                die "$title\n$cmd\n$fr: result incorrect.\nGot:\n$crf{$fr}\nExpected:\n$cef{$fr}\nOutput:\n$out$err"
                    unless $crf{$fr} eq $cef{$fr};
            }
            1;
        };
        skip($skip, $_, 1, $@);
        cleanup $_ || $skip, $WORKDIR, ++$tno;
    }
}
