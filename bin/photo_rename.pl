#!/usr/bin/perl
#
#
#    photo_rename
#    Copyright (C) 2016 William Wedler
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>

use constant VERSION => "0.3.0";
use 5.022;
use strict;
use Try::Tiny;
use Getopt::Long;
use Pod::Usage;
use warnings;
use DateTime;
use Time::Piece;
use Math::Fleximal;
use File::Copy;
use File::Spec;
use File::Basename;
use File::HomeDir;
use Cwd qw(cwd);
use Image::ExifTool qw(:Public);
use Log::Log4perl qw(get_logger);
use Term::ProgressBar;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use Digest::SHA1  qw(sha1_hex);

sub encode_base26 {
    my ($val, $padding) = @_;
    # Ensure the value passed only contains digits
    # Fix for values like "20230608201337DRO"
    # that give error "truncated in parse".
    my $digits = $val =~ s/\D//rg;
    my $num = new Math::Fleximal($digits, [0..9]);
    my $retVal = $num->change_flex(["A".."Z"])->to_str();
    $padding = $padding - length($retVal) if defined $padding;
    $retVal = '0' x $padding . $retVal if defined $padding && $padding > 0;
    return $retVal;
}

sub decode_base26 {
    my $val = uc(shift);
    my $num = new Math::Fleximal($val, ["A".."Z"]);
    my $retVal = $num->change_flex([0..9])->to_str();
    return $retVal;
}

sub decode_serial {
    my $val = uc(shift);
    my $num = 0;

    if($val =~ /^[0-9]+$/) {
        # base 10
        return $val;
    }

    if($val =~ /^[A-Z]+$/) {
        # base 26
        $num = new Math::Fleximal($val, ["A".."Z"]);
    } elsif($val =~ /^[0-9A-F]+$/) {
        # base 16
        $num = new Math::Fleximal($val, [0..9,"A".."F"]);
    }

    if(!$num) {
        # fallback to handle any other encoding
        my $hashed = uc(sha1_hex($val));
        $num = new Math::Fleximal($hashed, [0..9,"A".."F"]);
    }

    my $retVal = $num->change_flex([0..9])->to_str();
    return $retVal;
}

my $exifTool    = new Image::ExifTool;
my $pwd         = cwd();
my $showHelp    = 0;
my $showMan     = 0;
my $showAbout   = 0;
my $verbose     = 0;
my $short       = 0;
my $long        = 0;
my $info        = 0;
my $format      = 0;
my $matchArg    = 1;
my $argOrganize = "";
my $descArg     = "";
my $serialArg   = "";
my $serialArg10 = "";
my $argDate     = "";
my $argTags     = "";

sub renamePhoto {
    my (
        $f,
        $pwd,
        $format,
        $descArg,
        $serialArg10,
        $matchArg,
        @orgExt
        ) = @_;
    my $desc = $descArg && (length($descArg) > 0) ? $descArg : "";
    my $desc_index = index($f->{"baseName"}, "_", 0);
    if($desc_index < 8) {
        $desc_index = index($f->{"baseName"}, "_", $desc_index+1);
    }
    if($desc_index > 0 ) {
        $desc = substr($f->{"baseName"}, $desc_index+1);
    }
    my @partsTaken = split(' ', $f->{"taken"});
    my @parts_date = split(':', $partsTaken[0]);
    my @parts_time = split(':', $partsTaken[1]);

    # convert hours and min to seconds
    my $secondsTotal = $parts_time[0]*3600
        + $parts_time[1]*60
        + $parts_time[2];
    # reformat the date portion of the string
    my $dateStr      = join("", @parts_date);
    my $takenTime    = Time::Piece->strptime($f->{"taken"}, "%Y:%m:%d  %T");
    my $shortDateStr = substr($parts_date[0], -2)
        .encode_base26($takenTime->yday, 3)
        ;
    my $secSerialStr = encode_base26($secondsTotal . substr($f->{"strIdInfo"}, -4), 7);

    my %formatName;
    $formatName{'long'} = $dateStr
        .'-'.$secSerialStr
        .'-'.encode_base26($f->{"strFileNum"} =~ s/[^0-9]+//r)
        ;
    $formatName{'long'} = $formatName{'long'};

    $formatName{'short'} = $shortDateStr
        .'-'.encode_base26($f->{"strFileNum"} =~ s/[^0-9]+//r)
        .(length($desc)  ? '_'.$desc : '')
        ;
    $formatName{'short'} = $formatName{'short'};
    my $infoFileNum = (defined $f->{"fileNumber"} && length($f->{"fileNumber"}))
        ? $f->{"fileNumber"}
    : (substr($f->{"strFileNum"}, -1*length($f->{"docName"} =~ s/[^0-9]+//r)) =~ s/[_]+//r);
    $formatName{'info'} = encode_base26(substr($f->{"strIdInfo"}, -4), 3)
        .'-'.$dateStr
        .'-'.encode_base26($secondsTotal, 4)
        .'-'.encode_base26($f->{"strFileNum"} =~ s/[^0-9]+//r)
        .'-'.$infoFileNum
        .((length($desc)) ? '_'.$desc : '')
        ;
    $formatName{'info'} = $formatName{'info'};
    $formatName{'canon'} = 'IMG_'.substr($f->{"strFileNum"}, -4);

    my $newName = defined $formatName{$format} ? $formatName{$format} : $f->{"baseName"};
    my $subDir = "";
    foreach my $ext (@orgExt) {
        if(lc($f->{"extension"}) eq '.'.lc($ext)) {
            $subDir = $ext;
        }
    }

    if(length($subDir)) {
        my $subPath = File::Spec->catdir($pwd, $subDir);
        if(!-d $subPath) {
            mkdir $subPath or die "Failed to create path: $subPath";
        }
    }

    my $currPath = File::Spec->catdir($pwd, $f->{'file'});
    my $newPath  = File::Spec->catdir($pwd, $subDir, $newName).$f->{"extension"};

    if($verbose) {
        print "$currPath => $newPath\n";
    }

    if($currPath eq $newPath) {
        return (0, $newPath);
    } elsif (move($currPath, $newPath)) {
        if($matchArg && exists $f->{'matches'}) {
            my @matches   = $f->{'matches'};
            my $n_matches = scalar(@matches);
            for(my $j=0; $j<$n_matches; $j++) {
                my $match     = $matches[$j];
                my $mCurrPath = $currPath.$match->{'extension'};
                my $mNewPath  = $newPath.$match->{'extension'};
                if(!move($mCurrPath, $mNewPath)) {
                    if($verbose) {
                        warn("Matching $match->{'file'} not renamed");
                    }
                }
            }
        }
        return (1, $newPath);
    } else {
        return (-1, $newPath);
    }
}

my $dataDir = File::Spec->catdir(File::HomeDir->my_data, 'photo_rename');
if(!-d $dataDir) {
    mkdir $dataDir or die "Failed to create path: $dataDir";
}

my $logName = "photo_rename";
my $logPath = File::Spec->catdir($dataDir, "$logName.log");
my @logStat = stat $logPath;
if(scalar(@logStat) >= 7 && $logStat[7] > 1e6) {
    # Current log file is too large

    my $minLogN;
    my $maxLogN;
    my $logCount = 0;
    # Get the min and max log number and count of log files
    opendir (DIR, $dataDir) or die $!;
    while (my $file = readdir(DIR)) {
        my ($logBase, $logDir, $logExt) = fileparse($file, qr/\.[^.]*$/);
        my $atFront = index $logBase, $logName;
        if($atFront == 0) {
            my $logN = substr($logBase, length($logName));
            if(length($logN)) {
                $logCount++;
                $logN = $logN+0;
                if(!$minLogN || $minLogN>$logN) {
                    $minLogN = $logN;
                }
                if(!$maxLogN || $maxLogN<$logN) {
                    $maxLogN = $logN;
                }
            }
        }
    }

    if($logCount > 100) {
        # Too many old log files so remove the oldest log
        unlink File::Spec->catdir(
            $dataDir,
            "$logName$minLogN.log"
            );
    }
    # move the current log to the next available number
    my $nextLogN = sprintf("%4d", ($maxLogN+1));
    move(File::Spec->catdir(
             $dataDir,
             "$logName.log"),
         File::Spec->catdir(
             $dataDir,
             "$logName$nextLogN.log"),
        );
}

my %log_config = (
    "log4perl.category.PhotoRename"                      => "INFO",
    "log4perl.rootLogger"                                => "ERROR, LOGFILE",
    "log4perl.appender.LOGFILE"                          => "Log::Log4perl::Appender::File",
    "log4perl.appender.LOGFILE"                          => "Log::Log4perl::Appender::File",
    "log4perl.appender.LOGFILE.filename"                 => $logPath,
    "log4perl.appender.LOGFILE.mode"                     => "append",
    "log4perl.appender.LOGFILE.layout"                   =>"PatternLayout",
    "log4perl.appender.LOGFILE.layout.ConversionPattern" =>"%F:%L [%c] %d - %m%n",
    );

Log::Log4perl->init( \%log_config);
my $log = Log::Log4perl->get_logger("PhotoRename");

Getopt::Long::Configure ('bundling');
GetOptions (
    'f|format=s'      => \$format,
    's|serial=s'      => \$serialArg,
    'date=s'          => \$argDate,
    'v|verbose'       => \$verbose,
    '-h|help'         => \$showHelp,
    '-m|match'        => \$matchArg,
    'man'             => \$showMan,
    'about'           => \$showAbout,
    'd|description=s'	=> \$descArg,
    'o|organize=s'    => \$argOrganize,
    't|tags=s'        => \$argTags,
    ) or pod2usage(2);

if($showAbout) {
    print "photo_rename  Copyright (C) 2016  William Wedler\n";
    print "This program comes with ABSOLUTELY NO WARRANTY;\n";
    print "This is free software, and you are welcome to redistribute it\n";
    print "under certain the conditions of the GPLv3 license;\n";
    print "Version ",VERSION,"\n";
    print "Logging path: $logPath\n";
    print "Realbin path: $FindBin::RealBin\n";
    exit(0);
}

pod2usage(1) if $showHelp;
pod2usage(-exitval => 0, -verbose => 2) if $showMan;

if(!$format || !length($format)) {
    print "No action to perform because the required --format option was not given\n";
    print "Available options for more information:\n",
    "\t--help\t\tHelp text\n",
    "\t--man\t\tThe manual\n",
    "\t--about\t\tProgram information\n";
    exit 1;
}

if(length($serialArg)) {
    $serialArg10 = decode_serial($serialArg);
    if($verbose) {
        print "Serial base 10: $serialArg10\n";
    }
    $log->info("Serial base 10: $serialArg10\n");
}

if(length($argDate)) {
    # verify that the date has the correct format
    try {
        my $dateParsed = Time::Piece->strptime($argDate, "%Y:%m:%d  %T");
        if( !length($dateParsed->day)) {
            print "Invalid date argument\n";
            exit(1);
        }
    } catch {
        print "Invalid date argument\n";
        exit(1);
    }
}



my @organizeExt   = split(',', $argOrganize);
my @keywordsArr   = split(',', $argTags);
my $count_success = 0;
my $count_fail    = 0;
my $count_skip    = 0;
my $count_ignore  = 0;

$log->info("Running in current directory: $pwd, selected format: $format");

# read directory contents into an array
opendir (DIR, $pwd) or die $!;
my @dirFiles = grep { (!/^\./)} readdir(DIR);
closedir(DIR);
my $n_dirFiles = scalar(@dirFiles);
my %photoFiles;

my $next_update = 0;
my $progressExif = Term::ProgressBar->new({name => 'Reading EXIF',
                                           count => $n_dirFiles,
                                      });
for(my $i=0; $i<$n_dirFiles; $i++) {
    my $file = $dirFiles[$i];
    my ($baseName, $parentDir, $extension) = fileparse($file, qr/\.[^.]*$/);
    my %f=(
        file      => $file,
        baseName  => $baseName,
        parentDir => $parentDir,
        extension => $extension
        );
    my $hasEXIF = 0;

    if($exifTool->ExtractInfo("$file") == 1) {
        $hasEXIF = !!length($exifTool->GetValue('ColorSpace'))
            || !!length($exifTool->GetValue('ImageSize'));

        $f{"fileNumber"} = $exifTool->GetValue('FileNumber');
        $f{"docName"}    = $exifTool->GetValue('DocumentName');
        $f{"serial"}     = $exifTool->GetValue('SerialNumber');
        $f{"taken"}      = $exifTool->GetValue('DateTimeOriginal');

        if(defined $f{"serial"} && length($f{"serial"})) {
            $f{"strIdInfo"} = $f{"serial"};
        } elsif (length($serialArg10)) {
            $f{"strIdInfo"} = $serialArg10;
        } else {
            $log->warn("No ID information found or provided for file " . $file);
        }
        $f{"completeEXIF"} = !!length($f{"strIdInfo"});

        if((!defined $f{"taken"} || !length($f{"taken"}))) {
            # override missing date taken info with the given date
            if(length($argDate)) {
                $f{"taken"} =  $argDate;
            } else {
                $log->warn("No date taken information found or provided for file ".$file);
                $f{"completeEXIF"} = 0;
            }
        }
    }

    if($hasEXIF) {
        if($verbose) {
            print "docName: $f{'docName'}\n" if defined $f{"docName"};
        }
        # Write keywords to the photo file
        if( scalar @keywordsArr ) {
            my @keywords0 = $exifTool->GetValue('Keywords', 'ValueConv');
            my %seen;
            my @keywords1 = grep( !$seen{$_}++, @keywords0, @keywordsArr);
            $exifTool->SetNewValue(Keywords => '', AddValue => 0);
            $exifTool->WriteInfo($file);
            $exifTool->SetNewValue();
            foreach my $tag (@keywords1) {
                $exifTool->SetNewValue(Keywords => $tag);
            }
            $exifTool->WriteInfo($file);
        }
        if(!defined $f{"docName"} || !length($f{"docName"})) {
            if($verbose) {
                print "Setting DocumentName:$file\n";
            }
            $log->info("Setting DocumentName:$file");
            my $success = $exifTool->SetNewValue('DocumentName', $baseName);
            $success = $exifTool->WriteInfo($file);
            if($success) {
                $f{"docName"} = $baseName;
            }
        }
        if(defined $f{"fileNumber"} && length($f{"fileNumber"})) {
            $f{"strFileNum"} = $f{"fileNumber"};
        } elsif(defined $f{"docName"} && length($f{"docName"})) {
            $f{"strFileNum"} = ($f{"docName"} =~ s/[^0-9]+//r);
            # Give the fileNumber a prefix so that it
            # is at least 7 digits in length
            my $pre = 7-length($f{"strFileNum"});
            if($pre > 0) {
                $pre = 10**($pre-1);
                $f{"strFileNum"} = $pre.$f{"strFileNum"};
            }
        }
        $f{"completeEXIF"} = $f{"completeEXIF"} && !!length($f{"strFileNum"});
        $photoFiles{$file} = \%f;
    }
    $next_update = $progressExif->update($i) if $i > $next_update;
}
$progressExif->update($n_dirFiles) if $n_dirFiles >= $next_update;

# Scan for matching sidecar files
for(my $i=0; $i<$n_dirFiles; $i++) {
    my $file = $dirFiles[$i];
    my ($baseName, $parentDir, $extension) = fileparse($file, qr/\.[^.]*$/);
    if( exists $photoFiles{$baseName}) {
        my %fMatch =(
            file      => $file,
            baseName  => $baseName,
            parentDir => $parentDir,
            extension => $extension
            );
        if(!exists $photoFiles{$baseName}->{'matches'}) {
            $photoFiles{$baseName}->{'matches'} = (\%fMatch);
            my @matches = $photoFiles{$baseName}->{'matches'};
        } else {
            my @matches = $photoFiles{$baseName}->{'matches'};
            push @matches, \%fMatch;
        }
    }
}


my @photoFileNames = keys %photoFiles;
my $n_photos = scalar(@photoFileNames);
my $progressPhoto = Term::ProgressBar->new({name => 'Renaming photos',
                                       count => $n_photos,
                                      });
$next_update = 0;
for(my $i=0; $i<$n_photos; $i++) {
    my $fName = $photoFileNames[$i];
    my $f     = $photoFiles{$fName};
    my $currPath = File::Spec->catdir($pwd, $f->{"file"});
    if($f->{"completeEXIF"}) {
        my ($result, $newPath) = renamePhoto(
            $f,
            $pwd,
            $format,
            $descArg,
            $serialArg10,
            $matchArg,
            @organizeExt
            );
        $log->info("$currPath => $newPath");
        if($result == 0) {
            if($verbose) {
                warn("$currPath skipped");
            }
            $log->warn("$currPath skipped");
            $count_skip++;
        } elsif ($result > 0) {
            $count_success++;
        } else {
            $log->logwarn("Could not rename file ".$currPath);
            $count_fail++;
        }
    } else {
        $log->logwarn("Ignoring file ".$f->{"file"}." due to incomplete exif data.");
        if(!length($f->{"strFileNum"})) {
            $log->logwarn("Missing file num from exif data");
        }
        if(!length($f->{"strIdInfo"})) {
            $log->logwarn("Missing ID info (camera serial) from exif data.");
        }

        $count_ignore++;
    }

    $next_update = $progressPhoto->update($i) if $i > $next_update;
}
$progressPhoto->update($n_photos) if $n_photos >= $next_update;
my $n_files = $count_success+$count_fail+$count_skip;
print "Files Renamed  : ".$count_success,"\n";
print "Files Skipped  : ".$count_skip,"\n";
print "Files Failed   : ".$count_fail,"\n";
print "Files Ignored  : ".$count_ignore,"\n";
print "------------------\n";
print "Photos Total   : ".$n_files,"\n";


__END__
=head1 NAME

photo_rename - rename photos for organizing and archiving

=head1 SYNOPSIS

photo_rename [options]

=head1 OPTIONS

=over 8

=item -f B<--format>=[value]

Format as 'short', 'info', 'long', 'canon'

=item -s B<--serial>=[value]

Manually specify the camera serial number. The last 4 digits are used after converting to base 10 if not base 10 already. Converts from (in order of priority) base 16, base 26, or base 16 of the SHA1 hash of B<value>.

=item B<--date>=[value]

Manually specify the date taken if it is not saved in the EXIF data. (YYYY:MM:DD hh:mm:ss)

=item -d B<--description>=[value]

Add a description to files that do not already have one for formats supporting descriptions (short, info...)

=item -o B<--organize>=[value]

Comma separated list of file extensions to move into a subdirectory of the same name as the extension

=item -t B<--tags>=[value]

Comma separated list of keywords to save to the 'Keywords' EXIF data of each photo processed

=item -m B<--match>

Also rename files that contain the image file name as a prefix for the file. An example would be renaming sidecard files that have the image file name plus an extension. Defaults to 1 (true).

=item -v B<--verbose>

Print script debugging information

=item -h B<--help>

Print a brief help message and exits.

=item B<--man>

Prints the manual page and exits.


=item B<--about>

Prints information about the program including version number and copyright.

=back

=head1 DESCRIPTION

Rename photos in the current working directory with new file names based on exif data. Photo files can have a description appended to their file names and can be moved to a folder based on file extension if those options are selected.


=head2 Formats

=head3 "long"

                          YYYYMMDD-xxxxxxx-nnnnn.ext
                          \__/|/|/ \_____/ \___/ \_/
                    Year __|  | |    |       |    |
                   Month _____| |    |       |    |
                     Day _______|    |       |    |
Combined time and serial ____________|       |    |
number (base 26 encoded)                     |    |
   File number (base 26) ____________________|    |
               Extension _________________________|

=head3 "short"

                         YYddd-fffff_*.ext
                         |/\_/ \___/\| \_/
                 Year ___|  |    |   |  |
           Day of the ______|    |   |  |
       year (base 26)            |   |  |
File number (base 26) ___________|   |  |
 Optional description _______________|  |
            Extension __________________|


=head3 "info"

        sss-YYYYMMDD-tttt-ffff-FFFF_*.ext
        \_/ \__/|/|/ \__/ \__/ \__/\| \_/
Serial __|   |  | |   |    |    |   |  |
             |  | |   |    |    |   |  |
  Year ______|  | |   |    |    |   |  |
 Month _________| |   |    |    |   |  |
   Day ___________|   |    |    |   |  |
                      |    |    |   |  |
Time     _____________|    |    |   |  |
(sec b26)                  |    |   |  |
                           |    |   |  |
File   ____________________|    |   |  |
num.                            |   |  |
(b26)                           |   |  |
                                |   |  |
File   _________________________|   |  |
num.                                |  |
                                    |  |
Opt.   _____________________________|  |
desc.                                  |
                                       |
Extn. _________________________________|

=head3 "canon"

                 IMG_nnnn_*.ext
                 \__/\__/|/ \_/
                  |   |  |   |
         Prefix __|   |  |   |
   Image number ______|  |   |
     Opt. desc. _________|   |
      Extension _____________|

=cut
