`arclog` - Archive the Log Files Monthly
========================================


Description
-----------

`arclog` archives the log files monthly.  It strips off previous
months’ log records from the log file, and save them to compressed
archive files named `logfile.yyyymm`.  It then saves the hard disk
space and prevents potential attacks on log files.

Currently, `arclog` supports [Apache] access log, Syslog, [NTP],
Apache 1 SSL engine log, and my own bracketed, modified ISO date/time
log file formats, and gzip and bzip2 compression methods.  Several
software projects log (or can log) in a format compatible with the
Apache access log, like [CUPS], [ProFTPD], [Pure-FTPd]… etc., and
`arclog` can archive their Apache-like log files, too.

Caution
=======

* *Archival takes time*.  To reduce the time occupying the source log
  file, `arclog` copies the content of the source log file to a
  temporary working file and restart the source log file first.  Then
  `arclog` can take its time working on the temporary working file.
  However, please note:

  1. If you have a huge log file (several hundreds of MBs), merely
     copying still takes a lot of time.  You had better stop logging
     first, archive the log file and restart logging, to avoid racing
     condition in writing.  If you archive the log file periodically,
     it shall not grow too big.

  2. If `arclog` stops in the middle of the execution, it will leave a
     temporary working file.  The next time `arclog` runs, it stops
     when it sees that temporary working file.  You have to process
     that temporary working file first.  That temporary working file
     is merely a copy of the original log file.  You can rename and
     archive it like an ordinary log file to solve this.

* Do not sort unless you have a particular reason.  Sorting has the
  following potential problems:

  1. Sorting may *eat huge memory* on large log files.  The amount of
     the memory required depends on the number of records in each
     archived month.  Modern Linux and MS-Windows kill processes that
     eat too much memory, but it still takes minutes, and your system
     hangs for that.  I do not know other operating systems.  Try at
     your own risk.

  2. The time unit of all recognized log formats is *second*.  Log
     records happen in a same second are sorted by the log file order
     (if you are archiving several log files at a time) and then the
     log record order.  I try to ensure that the sorted archived
     records are in a correct order of the happening events, but I
     cannot guarantee.  You have to watch out if the order in a second
     is important.

* Be careful on the Syslog and NTP log files:  Syslog and NTP does not
  record the year.  `arclog` uses [Date::Parse] to parse the date,
  which assumes the year between this month and last next month if the
  year is missing.  For example, if today is 2001/6/8, it assumes the
  year between 2001/6/30 back to 2000/7/1.  This is fair.  However, if
  you do have a Syslog or NTP log file that has records older than one
  year, do not use `arclog`.  It will destroy your log file.

* If read from `STDIN`, please note:

  1. You *must* specify the output prefix if you want to read from
     `STDIN`, since what it needs is an output pathname prefix, not an
     output file.

  2. `STDIN` cannot be deleted, restarted or partially kept.  If you
     read from `STDIN`, the keep mode is always "keep all".  If you
     archive several source log files including `STDIN`, the keep mode
     will be "keep all" for all source log files, to prevent disaster.

  3. The answers of the `ask` mode is obtained from `STDIN`, too.
     Since you have only one `STDIN`, you cannot specify the ask mode
     while reading from `STDIN`.  It falls back to the fail mode in
     that case.

* I suggest that you install [File::MMagic] instead of counting on the
  `file` executable.  The internal magic file of File::MMagic works
  better than the `file` executable.  `arclog` treats everything not
  gzip nor bzip2 compressed as plain text.  When a compressed log file
  is wrongly recognized as an image, `arclog` treats it as plain text,
  reads directly from it, and fails.  This does not hurt the source
  log files, but is still annoying.

[Date::Parse]: https://metacpan.org/release/TimeDate
[File::MMagic]: https://metacpan.org/release/File-MMagic


System Requirement
------------------

1. Perl, version 5.8.0 or above.  `arclog` uses 3-argument open() to
   duplicate file handles, which is only supported since 5.8.0.  I
   have not successfully port this onto earlier versions yet.  Please
   tell me if you made it.  You can run `perl -v` to see your current
   Perl version.  If you do not have Perl, or if you have an older
   version of Perl, you can download and install/upgrade it from the
   [Perl website].  If you are using MS-Windows, you can download and
   install [ActiveState ActivePerl].

2. Required Perl modules:

   * [Date::Parse]

     This is used to parse the timestamp of the log records.  You can
     download and install Date::Parse from the CPAN archive, or
     install it with the CPAN shell:

         cpan Date::Parse

     or with the CPANPLUS shell:

         cpanp i Date::Parse

     For Debian/Ubuntu:

         sudo apt install libtimedate-perl

     For Red Hat/Fedora/CentOS:

         sudo yum install perl-TimeDate

     For FreeBSD:

         ports install p5-TimeDate

     For ActivePerl:

         ppm install TimeDate

3. Optional Perl modules:

   * [File::MMagic]

     This is used to check the file type.  If this is not available,
     `arclog` tries the `file` executable instead.  If that is not
     available, too, `arclog` judges the file type by its name suffix
     (extension).  In that case `arclog` fails when reading from
     `STDIN`.  You can download and install File::MMagic from the CPAN
     archive, or install it with the CPAN shell:

         cpan File::MMagic

     or with the CPANPLUS shell:

         cpanp i File::MMagic

     For Debian/Ubuntu:

         sudo apt install libfile-mmagic-perl

     For Red Hat/Fedora/CentOS:

         sudo yum install perl-File-MMagic

     For FreeBSD:

         ports install p5-File-MMagic

     For ActivePerl:

         ppm install File-MMagic

     The alternative `file.exe` for MS-Windows can be obtained from
     the [GnuWin32] home page.  Be sure to save it as `file.exe`
     somewhere in your `PATH`.

   * [Compress::Zlib]

     This is used to support reading/writing the gzip compressed
     files.  It is only needed when gzip compressed files are
     encountered.  If it is not available, `arclog` tries the `gzip`
     executable instead.  If that is not available, too, `arclog`
     fails.  You can download and install Compress::Zlib from the CPAN
     archive, or install it with the CPAN shell:

         cpan Compress::Zlib

     or with the CPANPLUS shell:

         cpanp i Compress::Zlib

     For Debian/Ubuntu:

         sudo apt install libcompress-zlib-perl

     For Red Hat/Fedora/CentOS:

         sudo yum install perl-Compress-Zlib

     For FreeBSD:

         ports install p5-Compress-Zlib

     For ActivePerl:

         ppm install Compress-Zlib

     The alternative `gzip.exe` for MS-Windows can be obtained from
     [the gzip website].  Be sure to save it as `gzip.exe` somewhere
     in your `PATH`.

   * [Compress::Bzip2] version 2 or above.

     This is used to support reading/writing the bzip2 compressed
     files.  It is only needed when bzip2 compressed files are
     encountered.  If it is not available, `arclog` tries the `bzip2`
     executable instead.  If that is not available, too, `arclog`
     fails.  Notice that older versions before 2 does not work, since
     the file I/O compression was not implemented yet.  You can
     download and install Compress::Bzip2 from the CPAN archive, or
     install it with the CPAN shell:

         cpan Compress::Bzip2

     or with the CPANPLUS shell:

         cpanp i Compress::Bzip2

     For Debian/Ubuntu:

         sudo apt install libcompress-bzip2-perl

     For Red Hat/Fedora/CentOS:

         sudo yum install perl-Compress-Bzip2

     For FreeBSD:

         ports install p5-Compress-Bzip2

     For ActivePerl:

         ppm install Compress-Bzip2

     The alternative `bzip2.exe` for MS-Windows can be obtained from
     [the bzip2 website].  Be sure to save it as `bzip2.exe` somewhere
     in your `PATH`.

   * [Term::ReadKey]

     This is used to display the progress bar.  The progress bar is a
     good visual feedback of what `arclog` is currently doing, but
     `arclog` is safe without it.  You can download and install
     Term::ReadKey from the CPAN archive, or install it with the
     CPAN shell:

         cpan Term::ReadKey

     or with the CPANPLUS shell:

         cpanp i Term::ReadKey

     For Debian/Ubuntu:

         sudo apt install libterm-readkey-perl

     For Red Hat/Fedora/CentOS:

         sudo yum install perl-TermReadKey

     For FreeBSD:

         ports install p5-Term-ReadKey

     For ActivePerl:

         ppm install TermReadKey

[Perl website]: https://www.perl.org
[ActiveState ActivePerl]: https://www.activestate.com
[Date::Parse]: https://metacpan.org/release/TimeDate
[File::MMagic]: https://metacpan.org/release/File-MMagic
[GnuWin32]: http://gnuwin32.sourceforge.net
[Compress::Zlib]: https://metacpan.org/release/Compress-Zlib
[the gzip website]: https://www.gzip.org
[Compress::Bzip2]: https://metacpan.org/release/Compress-Bzip2
[the bzip2 website]: http://www.bzip.org
[Term::ReadKey]: https://metacpan.org/release/TermReadKey


Download
--------

`arclog` is hosted is on…

* [arclog project on GitHub]

* [arclog project on SourceForge]

You can always download the newest version of `arclog` from…

* [arclog download on SourceForge]

* [Tavern IMACAT’s FTP directory]

imacat’s PGP public key is at…

* [imacat’s PGP key at Tavern IMACAT’s]

[arclog project on GitHub]: https://github.com/imacat/arclog
[arclog project on SourceForge]: https://sf.net/p/arclog
[arclog download on SourceForge]: https://sourceforge.net/projects/arclog/files
[Tavern IMACAT’s FTP directory]: https://ftp.imacat.idv.tw/pub/arclog/
[imacat’s PGP key at Tavern IMACAT’s]: https://www.imacat.idv.tw/me/pgpkey.asc


Install
-------

If you are upgrading from `arclog.pl` 2.1.1dev4 or earlier, please
read the upgrade instruction later in this document.

### Install with [ExtUtils::MakeMaker]

`arclog` uses standard Perl installation with ExtUtils::MakeMaker.
Follow these steps:

    % perl Makefile.PL
    % make
    % make test
    % make install

When running `make install`, make sure you have the privilege to
write to the installation location.  This usually requires the `root`
privilege.

If you are using ActivePerl under MS-Windows, you should use `nmake`
instead of `make`.  [nmake can be obtained from the Microsoft FTP site.]

If you want to install into another location, you can set the
`PREFIX`.  For example, to install into your home when you are not
`root`:

    % perl Makefile.PL PREFIX=/home/jessica

Refer to the documentation of ExtUtils::MakeMaker for more
installation options (by running `perldoc ExtUtils::MakeMaker`).

### Install with [Module::Build]

You can install with Module::Build instead, if you prefer.  Follow
these steps:

    % perl Build.PL
    % ./Build
    % ./Build test
    % ./Build install

When running `./Build install`, make sure you have the privilege to
write to the installation location.  This usually requires the `root`
privilege.

If you want to install into another location, you can set the
`--prefix`.  For example, to install into your home when you are not
`root`:

    % perl Build.PL --prefix=/home/jessica

Refer to the documentation of Module::Build for more installation
options (by running `perldoc Module::Build`).

[ExtUtils::MakeMaker]: https://metacpan.org/release/ExtUtils-MakeMaker
[nmake can be obtained from the Microsoft FTP site.]: ftp://ftp.microsoft.com/Softlib/MSLFILES/nmake15.exe
[Module::Build]: https://metacpan.org/release/Module-Build


Upgrade Instruction
-------------------

Here are a few hints for people upgrading from 2.1.1dev4 or earlier:

### The Script Name is Changed from `arclog.pl` to `arclog`

This is obvious.  If you have any scripts or cron jobs that are
running `arclog`, remember to modify your script for the new name.
Of course, you can rename `arclog` to `arclog.pl`.  It still works.

The reason I changed the script and project name is that:  A dot `.`
in the project name is not valid everywhere.  At least SourceForge
don’t accept it.  Besides, `arclog` is enough for a script name under
UNIX.  The `.pl` file name suffix/extension may be convenient on
MS-Windows, but MS-Windows users won’t run it with explorer file name
association anyway, and there is a `pl2bat` to convert `arclog` to
`arclog.bat`, which would make more sense.  The only disadvantage is
that I was using `UltraEdit`, which depends on the file name extension
for the syntax highlighting rules.  I can manually set it anyway.  I’m
using `gedit` on Linux now.  This is not a problem anymore.


### The Default Installation Location Is at `/usr/bin`

Also, the man page is at `/usr/share/man/man1/arclog.1`.  This is to
follow Perl’s standard convention, and to avoid breaking
ExtUtils::MakeMaker with future versions.

When you run `perl Makefile.PL` or `perl Build.PL`, it hints a
list of existing old files to be removed.  Please delete them
manually.

If you saved them in other places, you have to delete them yourself.

Also, if you have any scripts or cron jobs that are running `arclog`,
remember to modify your script for the new `arclog` location.  Of
course, you can copy `arclog` to the original location.  It still
works.


### The Argument of `--keep` and `--override` Options Are Required Now

Support for omitting the `--keep` or `--override` arguments are
removed.  This helps to avoid confusion for the log file name and the
option arguments.


Options
-------

    ./arclog [options] logfile… [output]
    ./arclog [-h|-v]

* `logfile`

  The log file to be archived.  Specify `-` to read from `STDIN`.
  You can specify multiple log files.  `gzip` or `bzip2` compressed
  files are supported.

* `output`

  The prefix of the output files.  The output files are named as
  `output.yyyymm`, i.e., `output.200101`, `output.200102`.  If not
  specified, the default is the same as the log file.  You must
  specify this if you want to read from `STDIN`.  You cannot specify
  `-` (`STDOUT`), since `arclog` needs a name prefix, not the output
  file.

* `-c`, `--compress method`

  Specify the compression method for the archived files.  Log files
  usually have large number of similar lines.  Compress them saves you
  lots of disk spaces.  (And this is why we want to archive them.)
  The following compression methods are supported:

  * `g`, `gzip`

    Compress with `gzip`.  This is the default.  `arclog` can use
    `Compress::Zlib` to compress instead of calling `gzip`.  This can
    be safer and faster for not calling foreign binaries.  If
    `Compress::Zlib` is not installed, it tries `gzip` instead.  If
    `gzip` is not available, either, it fails.

  * `b`, `bzip2`

    Compress with `bzip2`.  `arclog` can use `Compress::Bzip2` to
    compress instead of calling `bzip2`.  This can be safer and faster
    for not calling foreign binaries.  If `Compress::Bzip2` is not
    installed, it tries `bzip2` instead.  If `bzip2` is not available,
    either, it fails.

  * `n`, `none`

    No compression at all.  (Why? :p)

* `--nocompress`

  Do not compress the archived files.  This is equivalent to
  `--compress none`.

* `-s`, `--sort`

  Sort the records by time (and then the record order).  Sorting eats
  huge memory and CPU, so it is disabled by default.  Refer to the
  description above for a detailed illustration on sorting.

* `--nosort`

  Do not sort the records.  This is the default.

* `-o`, `--override mode`

  What to do with the existing archived files.  The following modes
  are supported:

  * `o`, `overwrite`

    Overwrite existing target files.  You will lose these existing
    records.  Use with care.  This is helpful if you are sure the
    main log file has the most complete records.

  * `a`, `append`

    Append the records to the existing target files.  You may destroy
    the log file completely by putting irrelevant entries altogether
    by accident.  Use with care.  This is helpful if you append want
    to merge 2 or more log files, for example, 2 log files of
    different periods.

  * `i`, `ignore`

    Ignore any existing target file, and discard all the records of
    those months.  You will lose these log records.  Use with care.
    This is helpful if you are supplying log records for the missing
    months, or if you are merging the log records in a complex manner.

  * `f`, `fail`

    Stop whenever a target file exists, to prevent destroying existing
    files by accident.  This should be mostly desired when run from
    some automatic mechanism, like `crontab`.  So, this is the default
    if no terminal is found at `STDIN`.

  * `ask`

    Ask you what to do when a target file exists.  This should be
    mostly desired if you are running `arclog` interactively.  So,
    this is the default if a terminal is found at `STDIN`.  The
    answers are read from `STDIN`.  Since you have only one `STDIN`,
    you cannot specify this mode if you want read the log file from
    `STDIN`.  In that case, it falls back to the `fail` mode.  Also,
    if `arclog` cannot get its answer from `STDIN`, for example, on a
    closed `STDIN` from `crontab`, it falls back to `fail` mode.

* `-k`, `--keep mode`

  What to keep in the source file.  Currently, the following modes are
  supported:

  * `a`, `all`

    Keep the source file after records are archived.

  * `r`, `restart`

    Restart the source log file after records are archived.

  * `d`, `delete`

    Delete the source log file after records are archived.

  * `t`, `this-month`

    Archive and strip records of previous months off from the log
    file.  Keep the records of this month in the source log file, to
    be archived next month.  This is designed to be run from `crontab`
    monthly, so this is the default.

* `-d`, `--debug`

  Show the detailed debugging messages.  More `-d` to be more
  detailed.

* `-q`, `--quiet`

  Hush!  Only yell on error.

* `-h`, `--help`

  Display the help message and exit.

* `-v`, `--version`

  Output version information and exit.


Documentation
-------------

Type `perldoc arclog` to read the `arclog` manual.


News, Changes and Updates
-------------------------

Refer to the `Changes` for changes, bug fixes, updates, new functions,
etc.


Support
-------

The `arclog` project is hosted on GitHub.  Address your issues on the
GitHub issue tracker https://github.com/imacat/arclog/issues.


License
-------

    Copyright (C) 2001-2021 imacat.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.


imacat ^_*'  
2007/12/3  
<imacat@mail.imacat.idv.tw>  
https://www.imacat.idv.tw  
