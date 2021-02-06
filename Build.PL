#! /usr/bin/perl -w
# Build.PL: Installation configuration for Module::Build
use strict;
use warnings;
use Config qw(%Config);
use Module::Build;

# Check if there is any old file
our (%old_version);
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

my $build = Module::Build->new(
    dist_name		=> "arclog",
    dist_version_from	=> "arclog",
    dist_abstract	=> "Archive log files monthly",
    dist_author		=> "imacat <imacat\@mail.imacat.idv.tw>",
    license		=> "apache_2_0",
    sign		=> 1,
    
    script_files	=> [ "arclog" ],
    requires		=> {
        "perl"			=> "5.8.0",
        "Date::Parse"   	=> 0,
    },
    recommends		=> {
        "File::MMagic"		=> 0,
        "Compress::Zlib"	=> 0,
        "Compress::Bzip2"	=> 2,
        "Term::ReadKey"		=> 0,
    },
    build_requires		=> {
        "Module::Signature"	=> 0,
        "Test::Pod"		=> 0,
    },
    add_to_cleanup	=> [ "t/logs*" ],
);

$build->create_build_script;

__END__
