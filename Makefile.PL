#! /usr/bin/perl -w
# Makefile.PL: Installation configuration for ExtUtils::MakeMaker
use 5.008;
use strict;
use warnings;
use Config qw(%Config);
use ExtUtils::MakeMaker;

# Check if there is any old file
use vars qw(%old_version);
%old_version = qw();
foreach (qw(/usr/sbin/arclog.pl
            /usr/sbin/arclog
            /usr/share/man/man8/arclog.pl.8
            /usr/share/man/man8/arclog.8
            /usr/local/sbin/arclog.pl
            /usr/local/sbin/arclog
            /usr/local/share/man/man8/arclog.pl.8
            /usr/local/share/man/man8/arclog.8)) {
    $old_version{$_} = 1 if -e $_;
}
foreach my $cnf (qw(installman1dir installsiteman1dir installvendorman1dir
                    man1dir man1direxp siteman1dir siteman1direxp sysman
                    vendorman1dir vendorman1direxp)) {
    next unless defined $Config{$cnf} && -d $Config{$cnf};
    $_ = $Config{$cnf};
    s/\/man1$/\/man8/;
    $old_version{"$_/arclog.8"} = 1 if -e "$_/arclog.8";
    $old_version{"$_/arclog.pl.8"} = 1 if -e "$_/arclog.pl.8";
}
foreach my $cnf (qw(installscript installsitescript installvendorscript
                    scriptdir scriptdirexp sitescript sitescriptexp
                    vendorscript vendorscriptexp
                    bin binexp installbin installsitebin installvendorbin
                    sitebin sitebinexp vendorbin vendorbinexp)) {
    next unless defined $Config{$cnf} && -d $Config{$cnf};
    $_ = $Config{$cnf};
    s/\/bin$/\/sbin/;
    $old_version{"$_/arclog"} = 1 if -e "$_/arclog";
    $old_version{"$_/arclog.pl"} = 1 if -e "$_/arclog.pl";
}
if (keys %old_version > 0) {
    $_ = join " ", sort keys %old_version;
    warn << "EOT";
-- Old Files Found
You may remove the following old files after "make install":
  $_
EOT
}

# Optional prerequisite modules
use vars qw(%OPT_PREREQ);
%OPT_PREREQ = (
    "File::MMagic"	=> 0,
    "Compress::Zlib"	=> 0,
    "Compress::Bzip2"	=> 2,
    "Term::ReadKey"	=> 0,
);
delete $OPT_PREREQ{$_}
    foreach grep eval "use $_ $OPT_PREREQ{$_} qw(); 1;", sort keys %OPT_PREREQ;
if (keys %OPT_PREREQ > 0) {
    $_ = join " ", sort keys %OPT_PREREQ;
    warn << "EOT";
-- Optional Prerequisites
You may wish to install these modules altogether.
  $_
EOT
}

WriteMakefile(
    NAME		=> "arclog",
    VERSION_FROM	=> "arclog",
    ABSTRACT		=> "Archive log files monthly",
    AUTHOR		=> "imacat <imacat\@mail.imacat.idv.tw>",
    LICENSE		=> "gpl",
    PREREQ_PM		=> {
        "Date::Parse"		=> 0,
    },
    SIGN		=> 1,
    
    EXE_FILES		=> [ "arclog" ],
    dist		=> {
        COMPRESS	=> "gzip -9",
        SUFFIX		=> ".gz",
    },
    clean		=> {
        FILES		=> "t/logs*",
    },
);

__END__
