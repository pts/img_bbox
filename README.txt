img_bbox.pl: Perl script to detect file format and media parameters
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
img_bbox.pl is a standalone Perl script that can detect file format,
width, height, bounding box and other meta-information from image files.
Supported vector formats are:
PDF, Flash SWF, EPS, PS, DVI and FIG. Supported raster image formats are:
GIF, JPEG, PNG, TIFF, XPM, XBM1, XBM, PNM, PBM, PGM, PPM, PCX, LBM, other
IFF, Windows and OS/2 BMP, MIFF, Gimp XCF, Windows ICO, Adobe PSD, FBM,
SunRaster, CMUWM, Utah RLE, Photo CD PCD, XWD, GEM, McIDAS, PM, SGI IRIS,
FITS, VICAR, PDS, FIT, Fax G3, Targa TGA and Faces.
Detecting 10 video and 8 audio file formats (and using mplayer(1) to report
parameters such as video dimensions) are also supported.

Example usage:

  $ ./img_bbox.pl --long FILENAME.IMAGE

img_bbox.pl is old software which is unlikely to get bugfixes or features.
New users should consider mediafileinfo.py
(https://github.com/pts/pymediafileinfo) instead.

Advantages of img_bbox.pl over mediafileinfo.py:

* It can get PDF width and height for many old PDF files without an xref
  stream.
* If reports the full (4-coordinate) and high resolution bounding box for
  PostScript and DVI documents.
* It supports many obscure old (pre-2000) image file formats.

Advantages of mediafileinfo.py over img_bbox.pl:

* It can detect and report media parameters from most modern audio, video
  and media container formats (e.g. MP3, AC3; H.264; MP4, MKV, MPEG-TS,
  MPEG-PS).
* It ranks matching file formats by the number of bits matched, thus it
  supports file formats without a signature in the beginning, or with
  overlapping header values.
* It can do a recursive scan in subdirectories.
* It can report last modification time and SHA-256 checksum for each file
  read.

Advantages of both mediafileinfo.py and img_bbox.pl over the Linux file(1)
command (https://www.gnu.org/software/fileutils/fileutils.html) and
binwalk (https://github.com/ReFirmLabs/binwalk):

* They (the former) can detect image width and height even for file formats
  (e.g. JPEG) where the file offset of these fields is not constant.

__END__
