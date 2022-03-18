#! /usr/bin/perl -w
# Test all the possible combination of options

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

use 5.005;
use strict;
use warnings;
use diagnostics;
use Test;

BEGIN { plan tests => 3600 }

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

# 1-3600: All possible option combinations
# Test each log file format
foreach my $fmt (@LOG_FORMATS) {
    # Test each source log file type
    foreach my $st (@SOURCE_TYPES) {
        # Test each result file type
        foreach my $rt (@RESULT_TYPES) {
            # Test each keep mode
            foreach my $keep (@KEEP_MODES) {
                # Test each override mode
                foreach my $override (@OVERRIDE_MODES) {
                    $_ = eval {
                        return if $$st{"skip"} || $$rt{"skip"};
                        my ($title, $cmd, $ret_no, $out, $err, $var_dump, $logfile);
                        my ($fr, $frb, @fle, $fle, $flr, %cef, %crf, %tef, %trf);
                        my ($fs, $cs, %cem, @mle, $mt, %cof);
                        rmtree $WORKDIR;
                        mkpath $WORKDIR;
                        $title = join ", ", ($$fmt{"title"}, $$st{"title"},
                            $$rt{"title"}, $$keep{"title"}, $$override{"title"});
                        $logfile = random_word;
                        $fs = catfile($WORKDIR, $logfile . $$st{"suf"});
                        ($cs, $var_dump, %cem) = &{$$fmt{"sub"}}($fs);
                        write_raw_file(catfile($WORKDIR, "$logfile.var-dump"), $var_dump);
                        @mle = sort keys %cem;
                        $mt = pop @mle if $$keep{"tm"};
                        if ($$override{"exists"}) {
                            %cof = make_log_file $$fmt{"sub"},
                                $WORKDIR, "$logfile.%s"  . $$rt{"suf"}, @mle;
                        } else {
                            %cof = map { "$logfile.$_"  . $$rt{"suf"} => "" }
                                @mle;
                        }
                        @fle = qw();
                        push @fle, basename($fs) if !$$keep{"del"};
                        push @fle, "$logfile.var-dump";
                        if ($$override{"ok"}) {
                            push @fle, map "$logfile.$_"  . $$rt{"suf"}, @mle;
                        } else {
                            push @fle, "$logfile.tmp-arclog" if $$keep{"tmp"};
                            push @fle, grep $cof{$_} ne "", keys %cof;
                        }
                        preserve_source $WORKDIR;
                        if (!$$keep{"stdin"}) {
                            @_ = ($arclog, qw(-d -d -d), @{$$keep{"opts"}},
                                @{$$override{"opts"}}, @{$$rt{"opts"}}, $fs);
                            $cmd = join " ", @_;
                            ($ret_no, $out, $err) = run_cmd "", @_;
                        } else {
                            @_ = ($arclog, qw(-d -d -d), @{$$keep{"opts"}},
                                @{$$override{"opts"}}, @{$$rt{"opts"}}, "-",
                                catfile($WORKDIR, $logfile));
                            $cmd = join(" ", @_) . " < " . $fs;
                            ($ret_no, $out, $err) = run_cmd read_raw_file $fs, @_;
                        }
                        ($fle, $flr) = (join(" ", sort @fle), list_files $WORKDIR);
                        %cef = qw();    # Expected content by file
                        %tef = qw();    # Expected file type by file
                        %crf = qw();    # Resulted content by file
                        %trf = qw();    # Resulted file type by file
                        if (!$$keep{"del"}) {
                            $fr = $fs;
                            $frb = basename($fr);
                            $cef{$frb} = !$$keep{"tmp"}? $cs:
                                !$$override{"ok"}? "":
                                $$keep{"tm"}? $cem{$mt}: "";
                            $tef{$frb} = $$st{"type"};
                            ($crf{$frb}, $trf{$frb}) = (read_file $fr, file_type $fr);
                        }
                        if (!$$override{"ok"} && $$keep{"tmp"}) {
                            $frb = "$logfile.tmp-arclog";
                            $fr = catfile($WORKDIR, $frb);
                            ($cef{$frb}, $tef{$frb}) = ($cs, TYPE_TEXT);
                            ($crf{$frb}, $trf{$frb}) = (read_file $fr, file_type $fr);
                        }
                        $frb = "$logfile.var-dump";
                        $fr = catfile($WORKDIR, $frb);
                        ($cef{$frb}, $tef{$frb}) = ($var_dump, TYPE_TEXT);
                        ($crf{$frb}, $trf{$frb}) = (read_file $fr, file_type $fr);
                        foreach my $m (@mle) {
                            $frb = "$logfile.$m" . $$rt{"suf"};
                            $fr = catfile($WORKDIR, $frb);
                            $cef{$frb} = &{$$override{"ce"}}($cof{$frb}, $cem{$m});
                            $tef{$frb} = $$rt{"type"};
                            ($crf{$frb}, $trf{$frb}) = (read_file $fr, file_type $fr);
                        }
                        die "$title\n$cmd\n$out$err"
                            unless $$override{"ok"}? $ret_no == 0: $ret_no != 0;
                        die "$title\n$cmd\nresult files incorrect.\nGot: $flr\nExpected: $fle\nVariables: $var_dump\nOutput:\n$out$err"
                            unless $flr eq $fle;
                        foreach $fr (@fle) {
                            die "$title\n$cmd\n$fr: result type incorrect.\nGot: $trf{$fr}\nExpected: $tef{$fr}\nVariables: $var_dump\nOutput:\n$out$err"
                                unless has_no_file || $trf{$fr} eq $tef{$fr}
                                    || ($tef{$fr} eq TYPE_BZIP2 && -z catfile($WORKDIR, $fr));
                            die "$title\n$cmd\n$fr: result incorrect.\nGot:\n$crf{$fr}\nExpected:\n$cef{$fr}\nVariables: $var_dump\nOutput:\n$out$err"
                                unless $crf{$fr} eq $cef{$fr};
                        }
                        1;
                    };
                    skip($$st{"skip"} || $$rt{"skip"}, $_, 1, $@);
                    clean_up $_ || $$st{"skip"} || $$rt{"skip"}, $WORKDIR, ++$tno;
                    die unless $_ || $$st{"skip"} || $$rt{"skip"};
                }
            }
        }
    }
}
