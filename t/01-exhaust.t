#! /usr/bin/perl -w
# Test all the possible combination of options

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

BEGIN { plan tests => 2160 }

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

# 1-2160: All possible option combinations
# Test each log file format
foreach my $fmt (@LOGFMTS) {
    # Test each source log file type
    foreach my $st (@SRCTYPES) {
        # Test each result file type
        foreach my $rt (@RESTYPES) {
            # Test each keep type
            foreach my $kt (@KEEPTYPES) {
                # Test each override type
                foreach my $ot (@OVERTYPES) {
                    $_ = eval {
                        return if $$st{"skip"} || $$rt{"skip"};
                        my ($title, $cmd, $retno, $out, $err, $vardump, $logfile);
                        my ($fr, $frb, @fle, $fle, $flr, %cef, %crf, %tef, %trf);
                        my ($fs, $cs, %cem, @mle, $mt, %cof);
                        rmtree $WORKDIR;
                        mkpath $WORKDIR;
                        $title = join ", ", ($$fmt{"title"}, $$st{"title"},
                            $$rt{"title"}, $$kt{"title"}, $$ot{"title"});
                        $logfile = randword;
                        $fs = catfile($WORKDIR, $logfile . $$st{"suf"});
                        ($cs, $vardump, %cem) = &{$$fmt{"sub"}}($fs);
                        frwrite(catfile($WORKDIR, "$logfile.vardump"), $vardump);
                        @mle = sort keys %cem;
                        $mt = pop @mle if $$kt{"tm"};
                        if ($$ot{"mkex"}) {
                            %cof = mkrndlog_existing $$fmt{"sub"},
                                $WORKDIR, "$logfile.%s"  . $$rt{"suf"}, @mle;
                        } else {
                            %cof = map { "$logfile.$_"  . $$rt{"suf"} => "" }
                                @mle;
                        }
                        @fle = qw();
                        push @fle, basename($fs) if !$$kt{"del"};
                        push @fle, "$logfile.vardump";
                        if ($$ot{"ok"}) {
                            push @fle, map "$logfile.$_"  . $$rt{"suf"}, @mle;
                        } else {
                            push @fle, "$logfile.tmp-arclog" if $$kt{"tmp"};
                            push @fle, grep $cof{$_} ne "", keys %cof;
                        }
                        prsrvsrc $WORKDIR;
                        if (!$$kt{"stdin"}) {
                            @_ = ($arclog, qw(-d -d -d), @{$$kt{"opts"}},
                                @{$$ot{"opts"}}, @{$$rt{"opts"}}, $fs);
                            $cmd = join " ", @_;
                            ($retno, $out, $err) = runcmd "", @_;
                        } else {
                            @_ = ($arclog, qw(-d -d -d), @{$$kt{"opts"}},
                                @{$$ot{"opts"}}, @{$$rt{"opts"}}, "-",
                                catfile($WORKDIR, $logfile));
                            $cmd = join(" ", @_) . " < " . $fs;
                            ($retno, $out, $err) = runcmd frread $fs, @_;
                        }
                        ($fle, $flr) = (join(" ", sort @fle), flist $WORKDIR);
                        %cef = qw();    # Expected content by file
                        %tef = qw();    # Expected file type by file
                        %crf = qw();    # Resulted content by file
                        %trf = qw();    # Resulted file type by file
                        if (!$$kt{"del"}) {
                            $fr = $fs;
                            $frb = basename($fr);
                            $cef{$frb} = !$$kt{"tmp"}? $cs:
                                !$$ot{"ok"}? "":
                                $$kt{"tm"}? $cem{$mt}: "";
                            $tef{$frb} = $$st{"type"};
                            ($crf{$frb}, $trf{$frb}) = (fread $fr, ftype $fr);
                        }
                        if (!$$ot{"ok"} && $$kt{"tmp"}) {
                            $frb = "$logfile.tmp-arclog";
                            $fr = catfile($WORKDIR, $frb);
                            ($cef{$frb}, $tef{$frb}) = ($cs, TYPE_PLAIN);
                            ($crf{$frb}, $trf{$frb}) = (fread $fr, ftype $fr);
                        }
                        $frb = "$logfile.vardump";
                        $fr = catfile($WORKDIR, $frb);
                        ($cef{$frb}, $tef{$frb}) = ($vardump, TYPE_PLAIN);
                        ($crf{$frb}, $trf{$frb}) = (fread $fr, ftype $fr);
                        foreach my $m (@mle) {
                            $frb = "$logfile.$m" . $$rt{"suf"};
                            $fr = catfile($WORKDIR, $frb);
                            $cef{$frb} = &{$$ot{"ce"}}($cof{$frb}, $cem{$m});
                            $tef{$frb} = $$rt{"type"};
                            ($crf{$frb}, $trf{$frb}) = (fread $fr, ftype $fr);
                        }
                        die "$title\n$cmd\n$out$err"
                            unless $$ot{"ok"}? $retno == 0: $retno != 0;
                        die "$title\n$cmd\nresult files incorrect.\nGot: $flr\nExpected: $fle\nVariables: $vardump\nOutput:\n$out$err"
                            unless $flr eq $fle;
                        foreach $fr (@fle) {
                            die "$title\n$cmd\n$fr: result type incorrect.\nGot: $trf{$fr}\nExpected: $tef{$fr}\nVariables: $vardump\nOutput:\n$out$err"
                                unless nofile || $trf{$fr} eq $tef{$fr}
                                    || ($tef{$fr} eq TYPE_BZIP2 && -z catfile($WORKDIR, $fr));
                            die "$title\n$cmd\n$fr: result incorrect.\nGot:\n$crf{$fr}\nExpected:\n$cef{$fr}\nVariables: $vardump\nOutput:\n$out$err"
                                unless $crf{$fr} eq $cef{$fr};
                        }
                        1;
                    };
                    skip($$st{"skip"} || $$rt{"skip"}, $_, 1, $@);
                    cleanup $_ || $$st{"skip"} || $$rt{"skip"}, $WORKDIR, ++$tno;
                    die unless $_ || $$st{"skip"} || $$rt{"skip"};
                }
            }
        }
    }
}
