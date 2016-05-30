#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <iostream>
#include "easyexif/exif.h"

int main () {
  std::cout<<"Usage:"<<std::endl;
  std::cout << PARSE_EXIF_ERROR_NO_JPEG << std::endl;
  return 0;
}
