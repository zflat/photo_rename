#!/usr/bin/perl

# Install dependencies
#   (http://www.cpan.org/modules/INSTALL.html)
# Runtime:
#   cpan Image::ExifTool
#   cpan Math::Base36
# Development:
#   cpan PAR:Packer
#
# Build binary:
# pp -o photo_rename(.exe) photo_rename.pl

use constant VERSION => "0.1.0";
use 5.010;
use strict;
use Getopt::Long;
use Pod::Usage;
use warnings;
use DateTime;
use Math::Base36 ':all';
use File::Copy;
use File::Spec;
use File::Basename;
use Cwd qw(cwd);
use Image::ExifTool qw(:Public);

my $exifTool    = new Image::ExifTool;
my $pwd         = cwd();
my $short       = 0;
my $long        = 0;
my $info        = 0;
my $format      = 0;
my $verbose     = 0;
my $showHelp    = 0;
my $showMan     = 0;
my $argOrganize = "";
my $descArg     = "";
my $serialArg10 = "";
my $serialArg36 = "";

Getopt::Long::Configure ('bundling');
GetOptions (
    'f|format=s'      => \$format,
    'serial10=s'      => \$serialArg10,
    'serial36=s'      => \$serialArg36,
    'v|verbose'       => \$verbose,
    '-h|help'         => \$showHelp,
    'man'             => \$showMan,
    'd|description=s'	=> \$descArg,
    'o|organize=s'    => \$argOrganize,
    ) or pod2usage(2);
pod2usage(1) if $showHelp;
pod2usage(-exitval => 0, -verbose => 2) if $showMan;

print "photo_rename version ",VERSION,"\n";
if(!$format || !length($format)) {
    print "No action to perform without format option.\n";
    print "For more information:\n\t--help\n\t\tHelp text\n\t--man\n\t\tThe manual\n";
    exit 1;
}

if(length($serialArg36)) {
    $serialArg10 = decode_base36($serialArg36);
}

my @organizeExt   = split(',', $argOrganize);
my $count_success = 0;
my $count_fail    = 0;
my $count_skip    = 0;
my $count_ignore  = 0;

opendir (DIR, $pwd) or die $!;

while (my $file = readdir(DIR)) {
    my $fileNumber = "" ;
    my $serial     = "" ;
    my $taken      = "" ;
    my $imageID    = "" ;
    my $strIdInfo  = "" ;
    if($exifTool->ExtractInfo("$file") == 1) {
        $fileNumber = $exifTool->GetValue('FileNumber');
        $serial     = $exifTool->GetValue('SerialNumber');
        $taken      = $exifTool->GetValue('DateTimeOriginal');

        if(defined $serial && length($serial)){
            $strIdInfo = $serial;
        } elsif (length($serialArg10)) {
            $strIdInfo = $serialArg10;
        }  
    }
    my $hasEXIF = length($taken);
    if( $hasEXIF && length($fileNumber) && length($strIdInfo)) {
        my ($baseName, $parentDir, $extension) = fileparse($file, qr/\.[^.]*$/);

        my $desc = (length($descArg) > 0) ? $descArg : "";
        my $desc_index = index($baseName, "_", 0);
        if($desc_index < 8) {
            $desc_index = index($baseName, "_", $desc_index+1);
        }
        if($desc_index > 0 ) {
            $desc = substr($baseName, $desc_index+1);
        }

        my @partsTaken = split(' ', $taken);
        my @parts_date = split(':', $partsTaken[0]);
        my @parts_time = split(':', $partsTaken[1]);

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
        my $secSerialStr = encode_base36($secondsTotal.substr($strIdInfo, -4), 6);

        my %formatName;
        $formatName{'long'} = $dateStr
            .'-'.$secSerialStr
            .'-'.encode_base36($fileNumber =~ s/[^0-9]+//r)
            ;
        $formatName{'long'} = lc($formatName{'long'});

        $formatName{'short'} = $shortDateStr
            .'-'.encode_base36($fileNumber =~ s/[^0-9]+//r)
            .(length($desc)  ? '_'.$desc : '')
            ;
        $formatName{'short'} = lc($formatName{'short'});

        $formatName{'info'} = encode_base36(substr($strIdInfo, -4), 3)
            .'-'.$dateStr
            .'-'.encode_base36($secondsTotal, 6)
            .'-'.encode_base36($fileNumber =~ s/[^0-9]+//r)
            .'-'.($fileNumber =~ s/[_]+//r)
            .((length($desc)) ? '_'.$desc : '')
            ;
        $formatName{'info'} = lc($formatName{'info'});
        $formatName{'canon'} = 'IMG_'.substr($fileNumber, -4);

        my $newName = defined $formatName{$format} ? $formatName{$format} : $baseName;
        my $subDir = "";
        foreach my $ext (@organizeExt) {
            if(lc($extension) eq '.'.lc($ext)) {
                $subDir = $ext;
            }
        }

        if(length($subDir)) {
            my $subPath = File::Spec->catdir($pwd, $subDir);
            if(!-d $subPath) {
                mkdir $subPath or die "Failed to create path: $subPath";
            }
        }

        my $currPath = File::Spec->catdir($pwd, $file);
        my $newPath  = File::Spec->catdir($pwd, $subDir, $newName).$extension;

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
    } elsif ( $hasEXIF) {
        print "Ignoring file $file due to incomplete exif data.\n";
        $count_ignore++;
    }
}
closedir(DIR);

my $n_files = $count_success+$count_fail+$count_skip;
print "Files Renamed  : ".$count_success,"\n";
print "Files Skipped  : ".$count_skip,"\n";
print "Files Failed   : ".$count_fail,"\n";
print "Files Ignored  : ".$count_ignore,"\n";
print $n_files." files scanned in total\n";

__END__

=head1 NAME

photo_rename - rename photos using exiftool data

=head1 SYNOPSIS

photo_rename [options] 

=head1 OPTIONS

=over 8

=item -f B<--format>=[value]

Format as 'short', 'info', 'long', 'canon'

=item B<--serial10>=[value]

Manually specify camera serial number containing digits 0-9 only (base 10 encoding).

=item B<--serial36>=[value]

Manually specify camera serial number containing letters and numbers (base 36 encoding).

=item -d B<--description>=[value]

Add a description to files that do not already have one for formats supporting descriptions (short, info...)

=item -o B<--organize>=[value]

Comma separated list of file extensions to move into a subdirectory of the same name as the extension

=item -v B<--verbose>

Print script debugging information

=item -h B<--help>

Print a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

Utility to rename photos in a directory based on exifdata and optionally add description and move to a folder based on file extension.

=cut
