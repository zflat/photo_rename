#!/usr/bin/perl

# See http://www.cpan.org/modules/INSTALL.html to install modules

# TODO: move files of extension .CR2 into a subdirectory named CR2
# (unless inside of that directory...). Maybe have has a command line
# argument or just do this with all non JPEG files.



use File::Basename;

#use 5.010;
use strict;
use Getopt::Long;
use warnings;
use DateTime;
use Math::Base36 ':all';
use File::Copy;
use File::Spec;
use File::Basename;

use Cwd qw(cwd);
use Image::ExifTool qw(:Public);
my $exifTool = new Image::ExifTool;
my $pwd = cwd();
my $short = 0;
my $long = 0;
my $length = 'l';
my $verbose = 0;

Getopt::Long::Configure ('bundling');
GetOptions (
    's|short' => \$short,
    'v|verbose' =>\$verbose,
    );

$long  = !$short;

if($short && $long) {
    print "ERROR: Must select short or long format but not both.\n";
    exit 1;
}

my $count_success = 0;
my $count_fail    = 0;
my $count_skip    = 0;

opendir (DIR, $pwd) or die $!;
while (my $file = readdir(DIR)) {
    if($exifTool->ExtractInfo("$file") == 1) {
        my ($baseName, $parentDir, $extension) = fileparse($file, qr/\.[^.]*$/);
        my $fileNumber = $exifTool->GetValue('FileNumber');
        my $serial     = $exifTool->GetValue('SerialNumber');
        my $taken      = $exifTool->GetValue('DateTimeOriginal');
        my @parts      = split(' ', $taken);
        my @parts_date = split(':', $parts[0]);
        my @parts_time = split(':', $parts[1]);

        # convert hours and min to seconds
        my $secondsTotal = $parts_time[0]*3600
            + $parts_time[1]*60
            + $parts_time[2];
        # reformat the date portion of the string
        my $dateStr = join("", @parts_date);
        my $shortDateStr = substr($parts_date[0], -2)
            .encode_base36($parts_date[1])
            .encode_base36($parts_date[2])
            ;
        my $secSerialStr = 
            sprintf(
                "%06s",
                encode_base36(
                    $secondsTotal.substr($serial, -4)
                )
            );

        my $longName = $dateStr
            .'-'.$secSerialStr
            .'-'.encode_base36($fileNumber =~ s/[^0-9]+//r)
            ;
        $longName = lc($longName);

        my $shortName = $shortDateStr
            .'-'.encode_base36($fileNumber =~ s/[^0-9]+//r)
            ;
        $shortName = lc($shortName);

        my $newName = $file;
        if($short) {
            $newName = $shortName;
        } elsif($long) {
            $newName = $longName;
        }
        my $currPath = File::Spec->catdir(($pwd, $file));
        my $newPath = File::Spec->catdir(($pwd, $newName)).$extension;

        if($verbose) {
            print "$currPath\n";
            print $newPath, "\n";
            print "\n";
        }

        if($currPath eq $newPath) {
            $count_skip++;
        } elsif (move($currPath, $newPath)) {
            $count_success++;
        } else {
            print "Could not rename file ".$currPath,"\n";
            $count_fail++;
        }
    }
}
closedir(DIR);

my $n_files = $count_success+$count_fail+$count_skip;
print "Files Renamed : ".$count_success,"\n";
print "Files Skipped : ".$count_skip,"\n";
print "Files Failed  : ".$count_fail,"\n";
print $n_files." files scanned in total\n";

