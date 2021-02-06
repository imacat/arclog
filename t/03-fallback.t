#! /usr/bin/perl -w
# Test fallback behavior

# Copyright (c) 2007-2021 imacat.
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

use 5.005;
use strict;
use warnings;
use diagnostics;
use Test;

BEGIN { plan tests => 5 }

use File::Basename qw(basename);
use File::Path qw(mkpath rmtree);
use File::Spec::Functions qw(catdir catfile updir);
use FindBin;
use lib $FindBin::Bin;
use _helper;
our ($WORKDIR, $arclog, $tno);

$WORKDIR = catdir($FindBin::Bin, "logs");
$arclog = catfile($FindBin::Bin, updir, "blib", "script", "arclog");
$tno = 0;

# 1-4: STDIN keep fall back
foreach my $kt (@KEEP_MODES) {
    next if $$kt{"stdin"} || $$kt{"title"} eq "keep all";
    $_ = eval {
        my ($title, $cmd, $ret_no, $out, $err, @var_dump, %logfiles);
        my ($fr, $frb, @fle, $fle, $flr, %cef, %crf, %tef, %trf);
        my ($num, @fs, @cs, @cem, @mle, %cof, $opref, $oprfb, $stdin);
        my (@st, $fmt, $rt);
        rmtree $WORKDIR;
        mkpath $WORKDIR;
        $fmt = $LOG_FORMATS[int rand @LOG_FORMATS];
        # A random available compression
        do {
            $rt = $RESULT_TYPES[int rand @RESULT_TYPES];
        } until !($$rt{"type"} eq TYPE_GZIP && has_no_gzip)
                && !($$rt{"type"} eq TYPE_BZIP2 && has_no_bzip2);
        $title = join ", ", "STDIN keep fall back", $$kt{"title"},
            $$fmt{"title"}, $$rt{"title"};
        # (2-4 times available compression) log files
        $_ = 2 + (has_no_gzip? 0: 2) + (has_no_bzip2? 0: 2);
        $num = $_ + int rand $_;
        $stdin = int rand $num;
        my %types = qw();
        # At least 2 files for each available compression
        foreach my $st (@SOURCE_TYPES) {
            next if ($$st{"type"} eq TYPE_GZIP && has_no_gzip)
                    || ($$st{"type"} eq TYPE_BZIP2 && has_no_bzip2);
            @_ = grep !exists $types{$_}, (0...$num-1);
            $types{$_[int rand @_]} = $st;
            @_ = grep !exists $types{$_}, (0...$num-1);
            $types{$_[int rand @_]} = $st;
        }
        # Set random compression on the rest files
        foreach (grep !exists $types{$_}, (0...$num-1)) {
            do {
                $types{$_} = $SOURCE_TYPES[int rand @SOURCE_TYPES];
            } until !(${$types{$_}}{"type"} eq TYPE_GZIP && has_no_gzip)
                    && !(${$types{$_}}{"type"} eq TYPE_BZIP2 && has_no_bzip2);
        }
        @st = map $types{$_}, (0...$num-1);
        @fs = qw();
        @cs = qw();
        @cem = qw();
        @var_dump = qw();
        @fle = qw();
        %logfiles = qw();
        for (my $k = 0; $k < $num; $k++) {
            my ($logfile, $cs, $var_dump);
            do { $logfile = random_word } until !exists $logfiles{$logfile};
            $logfiles{$logfile} = 1;
            $logfile .= ${$st[$k]}{"suf"};
            push @fs, catfile($WORKDIR, $logfile);
            ($cs, $var_dump, %types) = &{$$fmt{"sub"}}($fs[$k]);
            push @cs, $cs;
            push @cem, {%types};
            push @fle, $logfile;
            push @var_dump, $var_dump;
            write_raw_file(catfile($WORKDIR, "$logfile.var-dump"), $var_dump);
            push @fle, "$logfile.var-dump";
        }
        %types = qw();
        %types = (%types, map { $_ => 1 } keys %$_) foreach @cem;
        @mle = sort keys %types;
        do { $oprfb = random_word } until !exists $logfiles{$oprfb};
        $opref = catfile($WORKDIR, $oprfb);
        %cof = make_log_file $$fmt{"sub"},
            $WORKDIR, "$oprfb.%s" . $$rt{"suf"}, @mle;
        push @fle, map "$oprfb.$_" . $$rt{"suf"}, @mle;
        preserve_source $WORKDIR;
        @_ = @fs;
        $_[$stdin] = "-";
        @_ = ($arclog, qw(-d -d -d -o a), @{$$kt{"opts"}}, @{$$rt{"opts"}}, @_, $opref);
        $cmd = join(" ", @_) . " < " . $fs[$stdin];
        ($ret_no, $out, $err) = run_cmd read_raw_file $fs[$stdin], @_;
        ($fle, $flr) = (join(" ", sort @fle), list_files $WORKDIR);
        %cef = qw();    # Expected content by file
        %tef = qw();    # Expected file type by file
        %crf = qw();    # Resulted content by file
        %trf = qw();    # Resulted file type by file
        for (my $k = 0; $k < $num; $k++) {
            $fr = $fs[$k];
            $frb = basename($fr);
            ($cef{$frb}, $tef{$frb}) = ($cs[$k], ${$st[$k]}{"type"});
            ($crf{$frb}, $trf{$frb}) = (read_file $fr, file_type $fr);
            $fr = $fs[$k] . ".var-dump";
            $frb = basename($fr);
            ($cef{$frb}, $tef{$frb}) = ($var_dump[$k], TYPE_TEXT);
            ($crf{$frb}, $trf{$frb}) = (read_file $fr, file_type $fr);
        }
        foreach my $m (@mle) {
            $fr = "$opref.$m" . $$rt{"suf"};
            $frb = basename($fr);
            $cef{$frb} = $cof{$frb}
                . join "", map(exists $$_{$m}? $$_{$m}: "", @cem);
            $tef{$frb} = $$rt{"type"};
            ($crf{$frb}, $trf{$frb}) = (read_file $fr, file_type $fr);
        }
        die "$title\n$cmd\n$out$err" unless $ret_no == 0;
        die "$title\n$cmd\nresult files incorrect.\nGot: $flr\nExpected: $fle\nOutput:\n$out$err"
            unless $flr eq $fle;
        foreach $fr (@fle) {
            die "$title\n$cmd\n$fr: result type incorrect.\nGot: $trf{$fr}\nExpected: $tef{$fr}\nOutput:\n$out$err"
                unless has_no_file || $trf{$fr} eq $tef{$fr};
            die "$title\n$cmd\n$fr: result incorrect.\nGot:\n$crf{$fr}\nExpected:\n$cef{$fr}\nOutput:\n$out$err"
                unless $crf{$fr} eq $cef{$fr};
        }
        1;
    };
    ok($_, 1, $@);
    clean_up $_, $WORKDIR, ++$tno;
}

# 5: STDIN override ask fall back
$_ = eval {
    my ($title, $cmd, $ret_no, $out, $err, @var_dump, %logfiles);
    my ($fr, $frb, @fle, $fle, $flr, %cef, %crf, %tef, %trf);
    my ($num, @fs, @cs, @cem, @mle, %cof, $opref, $oprfb, $stdin);
    my (@st, $fmt, $rt);
    rmtree $WORKDIR;
    mkpath $WORKDIR;
    $fmt = $LOG_FORMATS[int rand @LOG_FORMATS];
    # A random available compression
    do {
        $rt = $RESULT_TYPES[int rand @RESULT_TYPES];
    } until !($$rt{"type"} eq TYPE_GZIP && has_no_gzip)
            && !($$rt{"type"} eq TYPE_BZIP2 && has_no_bzip2);
    $title = join ", ", "STDIN override ask fall back",
        $$fmt{"title"}, $$rt{"title"};
    # (2-4 times available compression) log files
    $_ = 2 + (has_no_gzip? 0: 2) + (has_no_bzip2? 0: 2);
    $num = $_ + int rand $_;
    $stdin = int rand $num;
    my %types = qw();
    # At least 2 files for each available compression
    foreach my $st (@SOURCE_TYPES) {
        next if ($$st{"type"} eq TYPE_GZIP && has_no_gzip)
                || ($$st{"type"} eq TYPE_BZIP2 && has_no_bzip2);
        @_ = grep !exists $types{$_}, (0...$num-1);
        $types{$_[int rand @_]} = $st;
        @_ = grep !exists $types{$_}, (0...$num-1);
        $types{$_[int rand @_]} = $st;
    }
    # Set random compression on the rest files
    foreach (grep !exists $types{$_}, (0...$num-1)) {
        do {
            $types{$_} = $SOURCE_TYPES[int rand @SOURCE_TYPES];
        } until !(${$types{$_}}{"type"} eq TYPE_GZIP && has_no_gzip)
                && !(${$types{$_}}{"type"} eq TYPE_BZIP2 && has_no_bzip2);
    }
    @st = map $types{$_}, (0...$num-1);
    @fs = qw();
    @cs = qw();
    @cem = qw();
    @var_dump = qw();
    @fle = qw();
    %logfiles = qw();
    for (my $k = 0; $k < $num; $k++) {
        my ($logfile, $cs, $var_dump);
        do { $logfile = random_word } until !exists $logfiles{$logfile};
        $logfiles{$logfile} = 1;
        $logfile .= ${$st[$k]}{"suf"};
        push @fs, catfile($WORKDIR, $logfile);
        ($cs, $var_dump, %types) = &{$$fmt{"sub"}}($fs[$k]);
        push @cs, $cs;
        push @cem, {%types};
        push @fle, $logfile;
        push @var_dump, $var_dump;
        write_raw_file(catfile($WORKDIR, "$logfile.var-dump"), $var_dump);
        push @fle, "$logfile.var-dump";
    }
    %types = qw();
    %types = (%types, map { $_ => 1 } keys %$_) foreach @cem;
    @mle = sort keys %types;
    do { $oprfb = random_word } until !exists $logfiles{$oprfb};
    $opref = catfile($WORKDIR, $oprfb);
    %cof = make_log_file $$fmt{"sub"},
        $WORKDIR, "$oprfb.%s" . $$rt{"suf"}, @mle;
    push @fle, grep $cof{$_} ne "", keys %cof;
    preserve_source $WORKDIR;
    @_ = @fs;
    $_[$stdin] = "-";
    @_ = ($arclog, qw(-d -d -d -o ask), @{$$rt{"opts"}}, @_, $opref);
    $cmd = join(" ", @_) . " < " . $fs[$stdin];
    ($ret_no, $out, $err) = run_cmd read_raw_file $fs[$stdin], @_;
    ($fle, $flr) = (join(" ", sort @fle), list_files $WORKDIR);
    %cef = qw();    # Expected content by file
    %tef = qw();    # Expected file type by file
    %crf = qw();    # Resulted content by file
    %trf = qw();    # Resulted file type by file
    for (my $k = 0; $k < $num; $k++) {
        $fr = $fs[$k];
        $frb = basename($fr);
        ($cef{$frb}, $tef{$frb}) = ($cs[$k], ${$st[$k]}{"type"});
        ($crf{$frb}, $trf{$frb}) = (read_file $fr, file_type $fr);
        $fr = $fs[$k] . ".var-dump";
        $frb = basename($fr);
        ($cef{$frb}, $tef{$frb}) = ($var_dump[$k], TYPE_TEXT);
        ($crf{$frb}, $trf{$frb}) = (read_file $fr, file_type $fr);
    }
    foreach my $m (@mle) {
        $fr = "$opref.$m" . $$rt{"suf"};
        $frb = basename($fr);
        ($cef{$frb}, $tef{$frb}) = ($cof{$frb}, $$rt{"type"});
        ($crf{$frb}, $trf{$frb}) = (read_file $fr, file_type $fr);
    }
    die "$title\n$cmd\n$out$err" unless $ret_no != 0;
    die "$title\n$cmd\nresult files incorrect.\nGot: $flr\nExpected: $fle\nOutput:\n$out$err"
        unless $flr eq $fle;
    foreach $fr (@fle) {
        die "$title\n$cmd\n$fr: result type incorrect.\nGot: $trf{$fr}\nExpected: $tef{$fr}\nOutput:\n$out$err"
            unless has_no_file || $trf{$fr} eq $tef{$fr};
        die "$title\n$cmd\n$fr: result incorrect.\nGot:\n$crf{$fr}\nExpected:\n$cef{$fr}\nOutput:\n$out$err"
            unless $crf{$fr} eq $cef{$fr};
    }
    1;
};
ok($_, 1, $@);
clean_up $_, $WORKDIR, ++$tno;
