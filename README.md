# photo_rename

Utility for renaming photo files with easy to organize file names.

## Features

 * Multiple file name formats to choose from
   * Long  - minimize file name collisions by including camera serial number in the file name
   * Short - date and file number combined in a short file name that allows for long descriptions
   * Info  - encoded and original date and file number, sortable by camera serial number
   * Canon - return image files to the original file name assigned by Canon cameras
 * Allows for manual entry of the camera serial number in when it can not be obtained from the image file
 * Organizing files to subdirectories based on extension
 * Batch adding desciption suffix to file names
 * Logging script execution to user data directory

## Usage

Basic usage moving CR2 files to a subdirectory and renaming in the long format:

      photo_rename -f long -o CR2


Get the description of available options

      photo_rename --man



## Install dependencies

   See http://www.cpan.org/modules/INSTALL.html

### Runtime:

      sudo apt install perl-doc
      cpan arybase DateTime File::HomeDir Image::ExifTool Log::Log4perl Math::Fleximal Time::Piece Term::ProgressBar Digest::SHA1

### Development:

      sudo apt install libperl-dev
      cpan PAR::Packer


## Package for distribution:

      pp -o photo_rename(.exe) photo_rename.pl


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
