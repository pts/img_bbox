#! /bin/sh
eval '(exit $?0)' && eval 'PERL_BADLANG=x;PATH="$PATH:.";export PERL_BADLANG\
;exec perl -x -S -- "$0" ${1+"$@"};#'if 0;eval 'setenv PERL_BADLANG x\
;setenv PATH "$PATH":.;exec perl -x -S -- "$0" $argv:q;#'.q
#!perl -w
+push@INC,'.';$0=~/(.*)/s;do(index($1,"/")<0?"./$1":$1);die$@if$@__END__+if 0
;#Don't touch/remove lines 1--7: https://pts.github.io/Magic.Perl.Header

#
# img_bbox.pl -- Perl script to detect file format and media parameters
# by pts@fazekas.hu at Sat Dec  7 21:31:01 CET 2002
#
# img_bbox.pl is a standalone Perl script that can detect file format,
# width, height, bounding box and
# other meta-information from image files. Supported vector formats are:
# PDF, Flash SWF, EPS, PS, DVI and FIG. Supported raster image formats are:
# GIF, JPEG, PNG, TIFF, XPM, XBM1, XBM, PNM, PBM, PGM, PPM, PCX, LBM, other
# IFF, Windows and OS/2 BMP, MIFF, Gimp XCF, Windows ICO, Adobe PSD, FBM,
# SunRaster, CMUWM, Utah RLE, Photo CD PCD, XWD, GEM, McIDAS, PM, SGI IRIS,
# FITS, VICAR, PDS, FIT, Fax G3, Targa TGA and Faces.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#

package just; BEGIN{$INC{'just.pm'}='just.pm'}
BEGIN{ $just::VERSION=2 }
sub end(){1}
sub main(){}

BEGIN{$ INC{'integer.pm'}='integer.pm'} {
package integer;
use just;
# by pts@fazekas.hu at Wed Jan 10 12:42:08 CET 2001
sub import   { $^H |= 1 }
sub unimport { $^H &= ~1 }
just::end}

BEGIN{$ INC{'strict.pm'}='strict.pm'} {
package strict;
use just;
# by pts@fazekas.hu at Wed Jan 10 12:42:08 CET 2001
require 5.002;
sub bits {
  (grep{'refs'eq$_}@_ && 2)|
  (grep{'subs'eq$_}@_ && 0x200)|
  (grep{'vars'eq$_}@_ && 0x400)|
  ($@ || 0x602)
}
sub import { shift; $^H |= bits @_ }
sub unimport { shift; $^H &= ~ bits @_ }
just::end}

BEGIN{$ INC{'Pts/string.pm'}='Pts/string.pm'} {
package Pts::string;
# by pts@fazekas.hu at Sat Dec 21 21:32:18 CET 2002
use just;
use integer;
use strict;

#** @param $_[0] a string
#** @param $_[1] index of first bit to return. Bit 128 of byte 0 is index 0.
#** @param $_[2] number of bits to return (<=32)
#** @return an integer (negative on overflow), bit at $_[1] is its MSB
sub get_bits_msb($$$) {
  # assume: use integer;
  my $loop=$_[1];
  my $count=$_[2];
  my $ret=0;
  ($ret+=$ret+(1&(vec($_[0],$loop>>3,8)>>(7-($loop&7)))), $loop++) while $count--!=0;
  $ret
}

#** @param $_[0] a string
#** @return value if $_[0] represents a floating point numeric constant
#**   in the C language (without the LU etc. modifiers) -- or undef. Returns
#**   undef for integer constants
sub c_floatval($) {
  my $S=$_[0];
  no integer; # very important; has local scope
  return 0.0+$S if $S=~/\A[+-]?(?:[0-9]*\.[0-9]+|[0-9]+\.])(?:[eE][+-]?[0-9]+)?\Z(?!\n)/;
  undef
}

#** @param $_[0] a string
#** @return value if $_[0] represents a floating point or integer numeric
#**   constant in the C language (without the LU etc. modifiers) -- or undef
sub c_numval($) {
  my $S=$_[0];
  no integer; # very important; has local scope
  return 0+$S if $S=~/\A[+-]?(?:[0-9]*\.[0-9]+(?:[eE][+-]?[0-9]+)?|[0-9]+\.?)\Z(?!\n)/;
  undef
}

#** @param $_[0] a string
#** @return the integer value of $_[0] in C -- or undef
sub c_intval($) {
  my $S=$_[0];
  my $neg=1;
  $neg=-1 if $S=~s@\A([+-])@@ and '-'eq$1;
  return $neg*hex $1 if $S=~/\A0[xX]([0-9a-fA-F]+)\Z(?!\n)/;
  return $neg*oct $1 if $S=~/\A0([0-7]+)\Z(?!\n)/;
  return $neg*$1     if $S=~/\A([0-9]+)\Z(?!\n)/;
  undef
}

sub import {
  no strict 'refs';
  my $package = (caller())[0];
  shift; # my package
  for my $p (@_ ? @_ : qw{get_bits_msb c_floatval c_numval c_intval}) { *{$package."::$p"}=\&{$p} }
}

just::end}

BEGIN{$ INC{'Htex/dimen.pm'}='Htex/dimen.pm'} {
package Htex::dimen;
# by pts@fazekas.hu at Sat Dec 21 21:26:15 CET 2002
use just;
use integer;
use strict;
use Pts::string qw(c_numval);

my %bp_mul;
{ no integer; %bp_mul=(
  'bp'=>1, # 1 bp = 1 bp (big point)
  'in'=>72, # 1 in = 72 bp (inch)
  'pt'=>72/72.27, # 1 pt = 72/72.27 bp (point)
  'pc'=>12*72/72.27, # 1 pc = 12*72/72.27 bp (pica)
  'dd'=>1238/1157*72/72.27, # 1 dd = 1238/1157*72/72.27 bp (didot point) [about 1.06601110141206 bp]
  'cc'=>12*1238/1157*72/72.27, # 1 cc = 12*1238/1157*72/72.27 bp (cicero)
  'sp'=>72/72.27/65536, # 1 sp = 72/72.27/65536 bp (scaled point)
  'cm'=>72/2.54, # 1 cm = 72/2.54 bp (centimeter)
  'mm'=>7.2/2.54, # 1 mm = 7.2/2.54 bp (millimeter)
) }

#** @param $_[0] a (real or integer) number, optionally postfixed by a
#**        TeX dimension specifier (default=bp)
#** @return the number in bp, or undef
sub dimen2bp($) {
  no integer;
  my $S=$_[0];
  my $mul;
  $mul=$bp_mul{$1} if $S=~s/\s*([a-z][a-z0-9]+)\Z(?!\n)// and exists $bp_mul{$1};
  my $val=c_numval($S);
  $val*=$mul if defined $val and defined $mul;
  $val
}

just::end}

BEGIN{$ INC{'Htex/ImgBBox.pm'}='Htex/ImgBBox.pm'} {
package Htex::ImgBBox;
#
# ImgBBox -- detect file format and media parameters
# by pts@fazekas.hu at Sat Dec  7 21:31:01 CET 2002
# JustLib2 at Sat Dec 21 21:29:21 CET 2002
#
# Dat: we know most of xloadimage-1.16, most of of file(1)-debian-potato,
#   all of sam2p-0.40, all of xv-3.10
# Dat: only in xloadimage: g3Ident,        g3Load,        "G3 FAX Image", (hard to identify file format)
# Dat: only in xloadimage: macIdent,       macLoad,       "MacPaint Image", (stupid, black-white)
# Imp: multiple paper sizes
#
use just;
use integer;
use strict;
use Htex::dimen;
use Pts::string;
# use Data::Dumper;

# Dat: BBoxInfo is a hashref:
# Dat: Info.* keys has FileFormat-dependent meaning (thus Info.depth may have
#      different meanings for different FileFormats)
# { 'FileFormat' => 'TIFF' # ...
#   'SubFormat' => 'PPM'
#   'Error' => 0
#   'LLX' => ... # lower left x (usually 0)
#   'LLY' => ... # lower left y (usually 0)
#   'URX' => ... # upper right x (usually width)
#   'URY' => ... # upper right y (usually height)
# }

# Dat: \usepackage[hiresbb]{graphicx}
# Dat: pdfTeX graphicx.sty doesn't respect PDF CropBox. For
#      /MediaBox[a b c d], \ht=d, \wd=c, and no overwrite below (a,b)

# ---

#** import will set them
my $have_pdf;
my $have_paper;

#** May moves the file offset, but only relatively (SEEK_CUR).
#** @param $_[0] \*FILE
#** @return BBoxInfo
sub calc($) {
  my $F=$_[0];
  my $dummy;
  my @L;
  my $head;
  #** BBoxInfo to return
  my $bbi={
    # 'FileFormat' => '.IO.error',
    'FileFormat' => 'unknown',
    'LLX' => 0, 'LLY' => 0, # may be float; in `bp'
    # 'URX' => 0, 'URY' => 0 # default: missing; may be float; in `bp'
  };
  binmode $F;
  if (0>read $F, $head, 256) { IOerr: $bbi->{Error}="IO: $!"; goto done }
  if (length($head)==0) { $bbi->{FileFormat}='Empty'; return $bbi }
  if ($head=~m@\A\s*/[*]\s+XPM\s+[*]/@) { # XPM
    $bbi->{FileFormat}='XPM';
    goto IOerr if !seek $F, -length($head), 1;
    select($F); $/='"'; select(STDOUT); <$F>;
    $head=<$F>;
    if ($head!~/\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+).*"\Z(?!\n)/s) { SYerr: $bbi->{Error}='syntax'; goto done }
    # width, height, length(palette), length(pixelchar)
    $bbi->{URX}=0+$1;
    $bbi->{URY}=0+$2;
  } elsif ($head=~m@\A\s*\/\*\s*Format_version=\S*\s+@i) {
    $bbi->{FileFormat}='XBM1'; # ??
    goto IOerr if 0>read $F, $head, 256-length($head), length($head);
    $head=~s@\*\/.*@@s; # keep only header
    goto SYerr if $head!~m@\s+Width=(\d+)@i;
    $bbi->{URX}=0+$1;
    goto SYerr if $head!~m@\s+Height=(\d+)@i;
    $bbi->{URY}=0+$1;
  } elsif ($head=~m@\A(?:/[*].*?[*]/)?\s*#define\s+.*?_width\s+(\d+)\s*#define\s+.*?_height\s+(\d+)\s*@) { # XBM (1)
    # Dat: this `if' must be after checking XPM
    # Imp: recognise a longer comment (that does not fit into $head)
    $bbi->{FileFormat}='XBM';
    $bbi->{URX}=0+$1;
    $bbi->{URY}=0+$2;
  } elsif ($head=~m@\A(?:/[*].*?[*]/)?\s*#define\s+.*?_height\s+(\d+)\s*#define\s+.*?_width\s+(\d+)\s*@) { # XBM (2)
    $bbi->{FileFormat}='XBM';
    $bbi->{URX}=0+$2;
    $bbi->{URY}=0+$1;
  } elsif (substr($head,0,8) eq "JG\004\016\0\0\0\0") {
    # vvv AOL browser proprietary lossy compressed raster image format,
    # supported only by the AOL browser and Internet Explorer
    $bbi->{FileFormat}='ART';
  } elsif ($head=~m@\AP([1-6])[\s#]@) { # PNM
    $bbi->{FileFormat}='PNM';
    my @subformats=qw{- PBM.text PGM.text PPM.text PBM.raw PGM.raw PPM.raw};
    my @colorspaces=qw(- Gray Gray RGB Gray Gray RGB);
    $bbi->{SubFormat}=$subformats[0+$1];
    $bbi->{ColorSpace}=$colorspaces[0+$1];
    goto IOerr if 0>read $F, $head, 1024-length($head), length($head);
    $head=~s@#.*@@g; # remove comments
    goto SYerr if ($head!~/\AP[1-6]\s+(\d+)\s+(\d+)\s/);
    $bbi->{URX}=0+$1; $bbi->{URY}=0+$2;
  } elsif (substr($head, 0, 4) eq "MM\000\052" or substr($head, 0, 4) eq "II\052\000") {
    $bbi->{FileFormat}='TIFF';
    my $LONG="N";
    my $SHORT="n";
    if (substr($head, 0, 1) eq "I") {
      $bbi->{SubFormat}='LSBfirst';
      $LONG="V"; $SHORT="v";
    } else {
      $bbi->{SubFormat}='MSBfirst';
    }
    my($dummy,$ifd_ofs)=unpack $LONG.$LONG, $head;
    goto IOerr if !seek $F, $ifd_ofs-length($head), 1;
    my $ifd_len;
    goto IOerr if 2!=read $F, $ifd_len, 2;
    $ifd_len=unpack($SHORT,$ifd_len);
    while ($ifd_len--!=0) {
      my($entry,$tag,$type,$count,$value);
      goto IOerr if 12!=read $F, $entry, 12;
      ($tag,$type,$count)=unpack($SHORT.$SHORT.$LONG, $entry);
      # vvv Dat: we discard tags with $value longer than 4 bytes
      #     Unfortunately BitsPerSample may be such a tag for RGB
         if ($type==3) { $value=unpack($SHORT,substr($entry,8,2)) }
      elsif ($type==4) { $value=unpack($LONG, substr($entry,8,4)) }
      else { $value=vec($entry,8,8); }
         if ($tag==256 and $count==1) { $bbi->{URX}=$value } # ImageWidth
      elsif ($tag==257 and $count==1) { $bbi->{URY}=$value } # ImageLength
      elsif ($tag==258 and $count<=2) { $bbi->{BitsPerSample}=$value }
      elsif ($tag==259) { $bbi->{"Info.Compression"}=$value }
      elsif ($tag==254) { $bbi->{"Info.NewSubfileType"}=$value }
      elsif ($tag==255) { $bbi->{"Info.SubfileType"}=$value }
      elsif ($tag==262) { $bbi->{"Info.PhotometricInterpretation"}=$value }
      elsif ($tag==263) { $bbi->{"Info.Thresholding"}=$value }
      elsif ($tag==264) { $bbi->{"Info.CellWidth"}=$value }
      elsif ($tag==265) { $bbi->{"Info.CellLength"}=$value }
      elsif ($tag==266) { $bbi->{"Info.FillOrder"}=$value }
      elsif ($tag==274) { $bbi->{"Info.Orientation"}=$value }
      elsif ($tag==277) { $bbi->{SamplesPerPixel}=$value }
      elsif ($tag==278) { $bbi->{"Info.RowsPerStrip"}=$value }
      elsif ($tag==280) { $bbi->{"Info.MinSampleValue"}=$value }
      elsif ($tag==281) { $bbi->{"Info.MaxSampleValue"}=$value }
      elsif ($tag==284) { $bbi->{"Info.PlanarConfiguration"}=$value }
      elsif ($tag==290) { $bbi->{"Info.GrayResponseUnit"}=$value }
      elsif ($tag==296) { $bbi->{"Info.ResolutionUnit"}=$value }
      elsif ($tag==338 and $count<=2) { $bbi->{"Info.ExtraSamples"}=$value }
    }
  } elsif ($head=~/\A\12[\0-\005]\001[\001-\10]/) {
    $bbi->{FileFormat}='PCX'; # PC Paintbrush image
    ($dummy,$bbi->{LLX},$bbi->{LLY},$bbi->{URX},$bbi->{URY})=unpack("A4vvvv",$head);
    $bbi->{URX}++; $bbi->{URY}++;
    # pinfo->w = 1+ (hdr[PCX_XMAXL] + ((int) hdr[PCX_XMAXH]<<8)) - (hdr[PCX_XMINL] + ((int) hdr[PCX_XMINH]<<8));
    # pinfo->h = 1+ (hdr[PCX_YMAXL] + ((int) hdr[PCX_YMAXH]<<8)) - (hdr[PCX_YMINL] + ((int) hdr[PCX_YMINH]<<8));
  } elsif ($head=~/\AGIF(8[79]a)/) {
    $bbi->{FileFormat}='GIF';
    $bbi->{SubFormat}=$1;
    ($dummy,$bbi->{URX},$bbi->{URY})=unpack("A6vv",$head);
  } elsif ($head=~/\A(\377+\330)\377/) {
    $bbi->{FileFormat}='JPEG';
    die if !seek $F, length($1)-length($head), 1;
    my $id_rgb=0;
    my $had_jfif=0;
    my $cpp;
    my $colortransform=-1; # as defined by the Adobe APP14 marker
    my $tag;
    my $w;
    while (1) {
      goto IOerr if !defined($tag=getc($F)) or ord($tag)!=255;
      1 while defined($tag=getc($F)) and 255==($tag=ord($tag));
      goto IOerr if !defined($tag);
      ##printf "0x%02x\n", $tag;
      if ($tag==0xC0) { # SOF0 marker: Baseline JPEG file
        $bbi->{SubFormat}='Baseline';
        goto IOerr if 2!=read $F, $w, 2;
        $dummy=unpack('n',$w)-2; # length includes itself
        goto IOerr if $dummy<9 or $dummy!=read($F, $w, $dummy);
        $bbi->{BitsPerSample}=vec($w,0,8);
        $bbi->{URY}=(vec($w,1,8)<<8)|vec($w,2,8);
        $bbi->{URX}=(vec($w,3,8)<<8)|vec($w,4,8);
        $cpp=vec($w,5,8);
        goto SYerr if ($dummy-=6)!=3*$cpp or $cpp>6 or $cpp<1;
        $bbi->{'Info.hvs'}=vec($w,7,8); # HVSamples ?
        $id_rgb=1 if $cpp==3 and $w=~/\A......R..G..B/s;
      } elsif (0xC1<=$tag and $tag<=0xCF and $tag!=0xC4 and $tag!=0xC8 and $tag!=0xCC) { # SOFn
        $bbi->{Subformat}="SOF".($tag-0xC0);
        goto IOerr if 2!=read $F, $w, 2;
        # vvv BUGFIX at Sat Dec 20 21:55:43 CET 2003
        $dummy=unpack('n',$w)-2; # length includes itself
        goto IOerr if $dummy<5 or $dummy!=read($F, $w, $dummy);
        $bbi->{BitsPerSample}=vec($w,0,8);
        $bbi->{URY}=(vec($w,1,8)<<8)|vec($w,2,8);
        $bbi->{URX}=(vec($w,3,8)<<8)|vec($w,4,8);
        $cpp=vec($w,5,8);
        if (!(($dummy-=6)!=3*$cpp or $cpp>6 or $cpp<1)) {
          $bbi->{'Info.hvs'}=vec($w,7,8) if length($w)>7; # HVSamples ?
          $id_rgb=1 if $cpp==3 and $w=~/\A......R..G..B/s;
        }
        last
      } elsif ($tag==0xD9 or $tag==0xDA) { # EOI or SOS marker; we're almost done
        if (!defined $cpp) {
        } elsif ($cpp==1) {
          $bbi->{'ColorSpace'}='Gray';
        } elsif ($cpp==3) {
          $bbi->{'ColorSpace'}='YCbCr';
          if ($had_jfif!=0 or $colortransform==1) {}
          elsif ($colortransform==0 or $id_rgb) { $bbi->{'ColorSpace'}='RGB' }
        } elsif ($cpp==4) {
          $bbi->{'ColorSpace'}='CMYK';
          if ($colortransform==2) { $bbi->{'ColorSpace'}='YCCK' }
        }
        last
      } else {
        # skip over a variable-length block; assumes proper length marker
        # ($tag==0xE0) # APP0: JFIF application-specific marker
        # ($tag==0xEE) # APP14: Adobe application-specific marker
        goto IOerr if 2!=read $F, $w, 2;
        $dummy=unpack('n',$w)-2; # length includes itself
        goto IOerr if $dummy!=read $F, $w, $dummy;
        $colortransform=ord($1) if
          $tag==0xEE and $dummy==12 and $w=~/\AAdobe[\001-\377].....(.)/s;
        $had_jfif=1 if
          $tag==0xE0 and $dummy==14 and $w=~/\AJFIF\0/;
      } ## IF
    } ## WHILE
    $bbi->{'Info.id_rgb'}=$id_rgb;
    $bbi->{'Info.had_jfif'}=$had_jfif;
    $bbi->{'Info.ColorTransform'}=$colortransform;
    $bbi->{SamplesPerPixel}=$cpp;
  } elsif (substr($head,0,8) eq "\211PNG\r\n\032\n") {
    $bbi->{FileFormat}='PNG';
    goto SYerr if $head!~/\A........\0\0\0[\15-\77]IHDR/s;
    # die length $head; # 256
    ($dummy,$bbi->{URX},$bbi->{URY},$bbi->{BitsPerComponent},
      $bbi->{"info.ColorType"},$bbi->{"info.Compression"},
      $bbi->{"info.Filter"},$bbi->{"info.Interlace"})=unpack("A16NNCCCCC",$head);
  } elsif (substr($head,0,5) eq "%PDF-") {
    $bbi->{FileFormat}='PDF'; # Adobe Portable Document Format
    # Dat: this routine cannot read encrypted PDF files
    # Dat: example $bbi return: {
    #        'URY' => 792, 'LLX' => '0', 'LLY' => '0', 'URX' => 612
    #        'FileFormat' => 'PDF', 'SubFormat' => '1.2', 'Info.linearized' => 1, 'Info.binary' => 'Binary',
    #        'Info.MediaBox' => [ 0, 0, 612, 792 ],
    #        'Info.CropBox' => [ 41, 63, 572, 729 ],
    #      };
    # Dat: $bbi->{'Info.num_pages'} is not reported for Linearized PDF.
    # Imp: report much more specific error messages
    # Imp: better distinguish between IOerr and SYerr
    $bbi->{SubFormat}=$1 if $head=~/\A%PDF-([\d.]+)/;
    $bbi->{'Info.binary'}=($head=~/\A[^\r\n]+[\r\n]+[ -~]*[^\n\r -~]/) ? 'Binary' : 'Clean7Bit';
    # die $have_pdf;
    goto done if !$have_pdf;
    # if ($head=~m@\A(?:%[^\r\n]*[\r\n])*.{0,40}/Linearized@s and $head=~m@\A(?:%[^\r\n]*[\r\n])*.{0,200}/O\s+(\d+)@s) {
    my $had_pdfboxes=($head=~m@/Type\s*/pdfboxes%@); # `%' is important
    $head=pdf_rewrite($head,1);
    my $page1obj;
    $bbi->{'Info.linearized'}=0;
    $bbi->{'Info.pdfboxes'}=0;
    if (defined $head) {
      $head=~s@\bendobj.*@@s;
      if ($had_pdfboxes) {
        # a hint of very strict format, by 
        $head="";
        goto IOerr if !seek($F, 0, 0) or 20>read($F, $head, 2048);
        goto SYerr unless $head=~/\d\s+\d+\s+obj\s*(.*?)\bendobj/s;
        $head=$1; goto SYerr unless $head=~m@/Type\s*/pdfboxes%@;
        while ($head=~m@^\s*/(\w+Box)\s*\[\s*(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s*\]@gm) {
          ## print "($1) ($2) ($3) ($4) ($5)\n";
          ($bbi->{LLX},$bbi->{LLY},$bbi->{URX},$bbi->{URY})=($2,$3,$4,$5) if $1 eq 'MediaBox';
          $bbi->{"Info.$1"}=[$2,$3,$4,$5];
        }
        $bbi->{'Info.pdfboxes'}=1;
        goto done;
      } elsif ($head=~m@/Linearized\s+@ and $head=~m@/O\s+(\d+)@) {
        $bbi->{'Info.linearized'}=1;
        $page1obj=$bbi->{'Info.page1obj'}=$1+0;
      }
    }
    goto IOerr if !seek $F, -1024, 2 and !seek $F, 0, 0;
    goto IOerr if 1>read $F, $head, 1024;
    goto SYerr if $head!~/startxref\s+(\d+)\s*%%EOF\s*\Z(?!\n)/
              and $head!~/startxref\s+(\d+)\s*%%EOF/;
    # ^^^ Dat: some PDF files contain binary junk at the end
    my $xref_ofs=$1+0;
    goto IOerr if !seek $F, $xref_ofs, 0;
    # die pdf_read_obj($F);
    my $xref=[];
    my $trailer=pdf_read_xref($F,$xref);
    goto SYerr if !defined $trailer;
    
    my $pages;
    my $type;
    if (!defined $page1obj) { do_pdf_slow:
      ## die $trailer;
      ## die pdf_ref($F,$xref,37550,0);
      ## die pdf_get($F,$xref,$trailer,'/ID');
      ## die pdf_get($F,$xref,$trailer,'/Root');
      ## die pdf_get($F,$xref,$trailer,'/Size');
      ## die pdf_get($F,$xref,$trailer,'/Sizez');

      my $root=pdf_get($F,$xref,$trailer,'/Root');
      goto IOerr if !defined $root; goto SYerr if !length $root;
      $type=pdf_get($F,$xref,$root,'/Type');
      goto IOerr if !defined $type; goto SYerr if $type ne ' /Catalog';
      # die $root;
      # vvv Dat: reading xref for /Pages in a linearized PDF is quite slow
      $pages=pdf_get($F,$xref,$root,'/Pages');
      goto IOerr if !defined $pages; goto SYerr if !length $pages;
      ## die $pages;
      my $kids;
      
      while (1) {
        $type=pdf_get($F,$xref,$pages,'/Type');
        goto IOerr if !defined $type;
        last if $type ne ' /Pages';
        pdf_get_boxes($F, $xref, $pages, $bbi);
        $kids=pdf_get($F,$xref,$pages,'/Kids');
        goto IOerr if !defined $kids; goto SYerr if !length $kids;
        ## die $kids;
        $pages=pdf_get($F,$xref,$kids,0);
        ## die $pages;
        goto IOerr if !defined $pages; goto SYerr if !length $pages;
      }
      goto SYerr if $type ne ' /Page';
      # Dat: cannot set $page1obj properly here, because it might be a direct object
      $bbi->{'Info.page1obj'}=$Htex::PDFread::pdf_last_ref0;
    } else {
      # die $page1obj;
      $pages=pdf_ref($F, $xref, $page1obj, 0);
      goto IOerr if !defined $pages;
      $type=pdf_get($F,$xref,$pages,'/Type');
      goto IOerr if !defined $type;
      goto SYerr if $type ne ' /Page';
      my $mediabox=pdf_get($F,$xref,$pages,'/MediaBox');
      goto IOerr if !defined $mediabox;
      goto do_pdf_slow if !length $mediabox;
    }
    pdf_get_boxes($F, $xref, $pages, $bbi);
  } elsif (substr($head,0,4) eq "%!PS") {
    # Dat: the user should not trust Val.languagelevel blindly. There are far
    #      too many PS files hanging around that do not conform to any standard.
    $bbi->{FileFormat}=$bbi->{SubFormat}=
      ($head=~/\A[^\n\r]*?\bEPSF-/) ? "EPS" : "PS";
    goto SYerr if $head!~s@[^\n\r]*[\n\r]+@@;
    # vvv Dat `+' is `or' with full boolean eval
    until ($head=~s@[\n\r]%%EndComments.*@@s + $head=~s@[\n\r](?:[^%]|%[^%]).*@@s) {
      goto IOerr if 0>read $F, $head, 1024, length($head);
    }
    my $headlen=length($head);
    $head=~s@(?:\r\n|\n\r|[\n\r])@\n@g; # uniformize newlines
    $head=~s@\s*\n%%[+]\s*@ @g; # unify line continuations
    my %H;
    my $had_hires=0; # HiresBoundingBox overrides normal
    my $val;
    while ($head=~/^%%([A-Za-z]+):?\s*((?:.*\S)?)/gm) {
      next if $2 ne '(atend)';
      # read additional ADSC comments from the last 1024 bytes of the file
      goto IOerr if !seek $F, -1024, 2 and !seek $F, 0, 0; # Dat: seek to EOF
      $dummy=tell $F;
      goto IOerr if $dummy<$headlen and $headlen-$dummy!=read $F, $val, $headlen-$dummy;
      goto IOerr if 0>read $F, $val, 1024;
      $val=~s@(?:\r\n|\n\r|[\n\r])@\n@g; # uniformize newlines
      $val=~s@\s*\n%%[+]\s*@ @g; # unify line continuations
      $val=~s@^(?:[^%]|%[^%]).*\n?@@mg; # remove non-DSC lines
      # vvv Dat: appending is schemantically correct here
      $head.="\n$val"; last
    }
    while ($head=~/^%%([A-Za-z]+):?[ \t]*((?:.*\S)?)/gm) { # iterate over Adobe DSC comments
      $dummy=lc($1); $val=$2;
      next if $dummy eq 'enddata' or $dummy eq 'trailer' or $dummy eq 'eof';
      $bbi->{"Val.$dummy"}=$2;
      if ($dummy eq 'documentdata') {
        $dummy=lc($2);
        $bbi->{'Info.binary'}='Clean7Bit' if $dummy eq 'clean7bit';
        $bbi->{'Info.binary'}='Clean8Bit' if $dummy eq 'clean8bit';
        $bbi->{'Info.binary'}='Binary' if $dummy eq 'binary';
      } elsif ($dummy eq 'creator' and $val=~/\bMetaPost\b/) {
        $bbi->{FileFormat}='EPS';
        $bbi->{SubFormat}='MPS'; # useful for graphicP.sty
      } elsif ($dummy eq 'boundingbox' and $val=~/\A([+-]?\d+)\s+([+-]?\d+)\s+([+-]?\d+)\s+([+-]?\d+)\Z(?!\n)/) {
        ($bbi->{LLX},$bbi->{LLY},$bbi->{URX},$bbi->{URY})=($1+0,$2+0,$3+0,$4+0) if !$had_hires;
      } elsif (($dummy eq 'hiresboundingbox' or $dummy eq 'exactboundingbox')
          and $val=~/\A([+-]?[0-9eE.-]+)\s+([+-]?[0-9eE.-]+)\s+([+-]?[0-9eE.-]+)\s+([+-]?[0-9eE.-]+)\Z(?!\n)/
          and  defined c_numval($1) and defined c_numval($2) and defined c_numval($3) and defined c_numval($4)
         ) {
        # Dat: capitalized names are: HiResBoundingBox, ExactBoundingBox
        no integer;
        ($bbi->{LLX},$bbi->{LLY},$bbi->{URX},$bbi->{URY})=($1+0,$2+0,$3+0,$4+0);
        $had_hires=1;
      }
    }
  } elsif ($head=~/\AFORM....ILBMBMHD/s) {
    $bbi->{FileFormat}='LBM';
    ($dummy,$bbi->{URX},$bbi->{URY})=unpack("A20nn",$head);
  } elsif ($head=~/\AFORM....(RGB[8N])/s) { # /etc/magic
    $bbi->{FileFormat}="IFF.$1";
    # dimension info not available
  } elsif ($head=~/\ABM....\0\0\0\0....[\014-\177]\0\0\0/s) { # PC bitmaps (OS/2, Windoze BMP files)  (Greg Roelofs, newt@uchicago.edu)
    # https://en.wikipedia.org/wiki/BMP_file_format
    $bbi->{FileFormat}='BMP';
    if (vec($head,14,8)<40) {
      $bbi->{SubFormat}='OS/2 1.x';
      ($dummy,$bbi->{URX},$bbi->{URY})=unpack("A18vv",$head);
    } elsif (vec($head,14,8)>=40) {
      $bbi->{SubFormat}='Windows';
      ($dummy,$bbi->{URX},$bbi->{URY},$dummy,$bbi->{"Info.depth"})=unpack("A18VVvv",$head);
    } else { goto SYerr }
  } elsif (substr($head,0,10) eq "\367\002\001\203\222\300\34;\0\0") { FF__DVI:
    $bbi->{FileFormat}='DVI';
    # read 1st page of the DVI file, look for TeX \special{papersize=21cm,29.7cm},
    # as understood by dvips and xdvi
    ($dummy,$bbi->{'Info.version_id'},$bbi->{'Info.numerator'},
      $bbi->{'Info.denominator'},$bbi->{'Info.magnification'})=unpack('CCNNN',$head);
    goto IOerr if !seek $F, 15-length($head), 1;
    $dummy=vec($head,14,8);
    goto IOerr if $dummy!=read $F, $bbi->{'Info.jobname'}, $dummy;
    my($tag,$action);
    my @actions=(0)x256; # skip that char
    $actions[139]=15; # Bop
    @actions[248,249,140]=(16,16,16,16); # stop parsing file
    @actions[128,133,143,148,153,157,162,167,235]=(1,1,1,1,1,1,1,1,1); # read 1 extra bytes
    @actions[129,134,144,149,154,158,163,168,236]=(2,2,2,2,2,2,2,2,2); # read 2 extra bytes
    @actions[130,135,145,150,155,159,164,169,237]=(3,3,3,3,3,3,3,3,3); # read 2 extra bytes
    @actions[131,136,146,151,156,160,165,170,238]=(4,4,4,4,4,4,4,4,4); # read 2 extra bytes
    @actions[132,137]=(8,8); # read 8 extra bytes
    @actions[243,244,245,246]=(17,18,19,20); # Fnt_def
    @actions[239,240,241,242]=(33,34,35,36); # Special (XXX)
    while (1) {
      goto IOerr if !defined($tag=getc($F)); # Dat: EOF is error
      $tag=$actions[ord($tag)];
      if ($tag==0) {
      } elsif ($tag==16) {
        last
      } elsif ($tag==15) { # Bop
        last if exists $bbi->{'Info.page1_nr'};
        goto IOerr if 44!=read $F, $dummy, 44;
        $bbi->{'Info.page1_nr'}=unpack "N", $dummy;
      } else {
        # read number of ($tag&15) bytes in MSBfirst byte order
        $dummy="\0\0\0\0";
        goto IOerr if ($tag&15)!=read $F, $dummy, ($tag&15), 4;
        $dummy=unpack("N",substr($dummy,-4));
        if ($tag>=33) { # Special
          goto IOerr if $dummy!=read $F, $tag, $dummy;
          @L=split /\s*=\s*/, $tag, 2;
          if ($#L) {
            $bbi->{"Val.$L[0]"}=$L[1];
            if ($L[0] eq 'papersize') {
              @L=split /,/, $L[1], 2;
              $bbi->{URX}=Htex::dimen::dimen2bp($L[0]);
              $bbi->{URY}=Htex::dimen::dimen2bp($L[1]);
              if (!defined $bbi->{URX} or !defined $bbi->{URY}) {
                delete $bbi->{URX}; delete $bbi->{URY};
              }
            }
          } else { $bbi->{'Info.special'}=$tag; }
        } elsif ($tag>=17) { # Fnt_def
          goto IOerr if 14!=read $F, $tag, 14;
          $dummy=vec($tag,12,8)+vec($tag,13,8);
          goto IOerr if $dummy!=read $F, $tag, $dummy;
        }
      } # IF 
    } # WHILE
  } elsif ($head=~/\Aid=ImageMagick\r?\n/) {
    $bbi->{FileFormat}='MIFF';
    # goto IOerr if 0>read $F, $head, 128-length($head), length($head);
    goto SYerr if $head!~/\bcolumns=(\d+)\s+rows=(\d+)/;
    $bbi->{URX}=0+$1; $bbi->{URY}=0+$2;
  } elsif (substr($head,0,3) eq 'FWS') {
    $bbi->{FileFormat}='SWF'; # Macromedia ShockWave Flash
    my $nbits=get_bits_msb($head, 64, 5);
    no integer;
    $bbi->{URX}=get_bits_msb($head, 69+  $nbits, $nbits)/20.0;
    $bbi->{LLX}=get_bits_msb($head, 69,          $nbits)/20.0;
    $bbi->{URY}=get_bits_msb($head, 69+3*$nbits, $nbits)/20.0;
    $bbi->{LLY}=get_bits_msb($head, 69+2*$nbits, $nbits)/20.0;
  } elsif (substr($head,0,14) eq "gimp xcf file\0") { # GIMP XCF image data
    $bbi->{SubFormat}='version.000';
   do_XCF:
    $bbi->{FileFormat}='XCF';
    ($dummy,$bbi->{URX},$bbi->{URY},$dummy)=unpack("A14NNN", $head);
       if ($dummy==0) { $bbi->{ColorSpace}='RGB' }
    elsif ($dummy==1) { $bbi->{ColorSpace}='Gray' }
    elsif ($dummy==2) { $bbi->{ColorSpace}='Indexed' }
  } elsif ($head=~/\Agimp xcf v(\d\d\d)\0/) {
    $bbi->{SubFormat}="version.$1";
    goto do_XCF;
  } elsif ($head=~/\A\0\0\001\0[\001-\50]\0/) { # Windows ICO icon
    $bbi->{FileFormat}='ICO';
    # An .ico file may contain multiple icons (hence [\001-50]); we report the
    # properties of the very first one. Code based on ImageMagick.
    # Imp: WinXP True color icons
    ($dummy,$bbi->{URX},$bbi->{URY},$bbi->{'Info.colors'},$bbi->{'Info.reserved'},
     $bbi->{'Info.num_planes'},$bbi->{BitsPerSample})=unpack("A6CCCCvv", $head);
    # more precisely: BitsPerSample is bits per pixel;
    # Dat: Info.reserved, BitsPerSample and Info.num_planes are often 0
  } elsif (substr($head,0,4)eq"8BPS") { # PSD image data (Adobe Photoshop bitmap)
    # based on PHP 4.2 image.c; untested
    $bbi->{FileFormat}='PSD';
    ($dummy,$bbi->{URY},$bbi->{URX})=unpack("A14NN",$head);
  } elsif (substr($head,0,8) eq "\%bitmap\0") { # Fuzzy Bitmap (FBM) image; untested
    $bbi->{FileFormat}='FBM';
    @L=unpack("A8A8A8A8A8A8A12A12A12A12A80A80",$head); # <=256 chars OK
    for (@L) { s@\0.*@@s } # make strings null-terminated
    $bbi->{"Info.credits"}=pop(@L); # string
    $bbi->{"Info.title"}=pop(@L); # string
    goto SYerr if !defined ($bbi->{aspect}=c_numval(pop(@L)));
    shift(@L); # magic
    for my $item (@L) { goto SYerr if !defined($item=c_intval($item)) }
    ( $bbi->{URX},$bbi->{URY},$bbi->{"Info.num_planes"},$bbi->{"Info.bits"},
      $bbi->{"Info.physbits"},$bbi->{"Info.rowlen"},$bbi->{"Info.plnlen"},
      $bbi->{"Info.clrlen"})=@L;
    #    char    cols[8];                /* Width in pixels */
    #    char    rows[8];                /* Height in pixels */
    #    char    planes[8];              /* Depth (1 for B+W, 3 for RGB) */
    #    char    bits[8];                /* Bits per pixel */
    #    char    physbits[8];            /* Bits to store each pixel */
    #    char    rowlen[12];             /* Length of a row in bytes */
    #    char    plnlen[12];             /* Length of a plane in bytes */
    #    char    clrlen[12];             /* Length of colormap in bytes */
    #    char    aspect[12];             /* ratio of Y to X of one pixel */
  } elsif (substr($head,0,4)eq"\x59\xa6\x6a\x95") { # Sun raster images; untested
    $bbi->{FileFormat}='SunRaster';
    ($dummy,$bbi->{URX},$bbi->{URY})=unpack("NNN",$head);
    #0		belong		0x59a66a95	Sun raster image data
    #>4		belong		>0		\b, %d x
    #>8		belong		>0		%d,
    #>12	belong		>0		%d-bit,
    ##>16	belong		>0		%d bytes long,
    #>20	belong		0		old format,
    ##>20	belong		1		standard,
    #>20	belong		2		compressed,
    #>20	belong		3		RGB,
    #>20	belong		4		TIFF,
    #>20	belong		5		IFF,
    #>20	belong		0xffff		reserved for testing,
    #>24	belong		0		no colormap
    #>24	belong		1		RGB colormap
    #>24	belong		2		raw colormap
    #>28	belong		>0		colormap is %d bytes long
  } elsif (substr($head,0,4)eq"\xf1\x00\40\xbb") {
    $bbi->{FileFormat}='CMUWM'; # from xloadimage; untested
    ($dummy,$bbi->{URX},$bbi->{URY},$bbi->{"Info.depth"})=unpack("NNNn",$head);
  } elsif (substr($head,0,4) eq "\361\0\100\273") { # CMU window manager raster image data
    # from xvl untested
    $bbi->{FileFormat}='CMUWM';
    ($dummy,$bbi->{URX},$bbi->{URY},$bbi->{'Info.num_bits'})=unpack("VVVV",$head);
  } elsif (substr($head,0,2)eq"\x52\xCC") { # Utah Raster Toolkit RLE images; untested
    $bbi->{FileFormat}='RLE'; # from xloadimage
    ($dummy,$bbi->{URX},$bbi->{URY},$bbi->{LLX},$bbi->{LLY})=unpack("A6vvvv",$head);
    $bbi->{BitsPerSample}=vec($head,12,8)/vec($head,11,8);
    $bbi->{SamplesPerPixel}=vec($head,11,8);
    #0		leshort		0xcc52		RLE image data,
    #>6		leshort		x		%d x
    #>8		leshort		x		%d
    #>2		leshort		>0		\b, lower left corner: %d
    #>4		leshort		>0		\b, lower right corner: %d
    #>10	byte&0x1	=0x1		\b, clear first
    #>10	byte&0x2	=0x2		\b, no background
    #>10	byte&0x4	=0x4		\b, alpha channel
    #>10	byte&0x8	=0x8		\b, comment
    #>11	byte		>0		\b, %d color channels
    #>12	byte		>0		\b, %d bits per pixel
    #>13	byte		>0		\b, %d color map channels
  } elsif (substr($head,0,32)eq"\377\377\377\377\377\377\377\377\377\377\377\377\377\377\377\377\377\377\377\377\377\377\377\377\377\377\377\377\377\377\377\377") { # Kodak Photograph on CD Image
    # derived from xloadimage; untested
    $dummy=3587-length($head);
    goto IOerr if $dummy=read $F, $head, $dummy, length($head);
    goto SYerr if substr($head,2048,7) ne "PCD_IPI";
    $bbi->{FileFormat}='PCD';
    # vvv funny: an image format with fixed (hard-wired) image size
    if ((vec($head,3586,8)&1)!=0) { ($bbi->{URY},$bbi->{URX})=(768,512) }
                             else { ($bbi->{UXY},$bbi->{URY})=(768,512) }
  } elsif ($head=~/\A\0\0..\0\0\0[\001-\50]\0\0\0[\0-\002]\0\0\0([\001-\77])/s) {
    $bbi->{FileFormat}='XWD';
    $bbi->{SubFormat}='MSBfirst';
    $bbi->{'Info.depth'}=ord($1);
    ($dummy,$bbi->{URX},$bbi->{URY})=unpack("A16NN",$head);
  } elsif ($head=~/\A..\0\0[\001-\50]\0\0\0[\0-\002]\0\0\0([\001-\77])\0\0\0/s) {
    $bbi->{FileFormat}='XWD';
    $bbi->{SubFormat}='LSBfirst';
    $bbi->{'Info.depth'}=ord($1);
    ($dummy,$bbi->{URX},$bbi->{URY})=unpack("A16VV",$head);
  } elsif ($head=~/\A\0\001\0[\010-\377](?:\0.|\001\0)\0.....(?:[\001-\37].|\0[^\0]|\40\0){2}/s) { # GEM Bit image
    # from xloadimage; untested
    $bbi->{FileFormat}='GEM';
    ($dummy,$bbi->{'Info.hlen'},$bbi->{'Info.colors'},$bbi->{'Info.patlen'},
     $bbi->{URX},$bbi->{URY},$bbi->{'Info.llen'},$bbi->{'Info.lines'})=unpack("nnnnnnnn",$head);
  } elsif ($head=~/\A....\0\0\0\004....\0\0[\0-\001].\0\0[\0-\003]./s) { # McIDAS areafile
    # from xloadimage; untested
    $bbi->{FileFormat}='McIDAS';
    $bbi->{SubFormat}='MSBfirst';
    ($dummy,$bbi->{URY},$bbi->{URX})=unpack("A32NN",$head);
  } elsif ($head=~/\A....\004\0\0\0.....[\0-\001]\0\0.[\0-\003]\0\0/s) { # McIDAS areafile
    # from xloadimage; untested
    $bbi->{FileFormat}='McIDAS';
    $bbi->{SubFormat}='LSBfirst';
    ($dummy,$bbi->{URY},$bbi->{URX})=unpack("A32VV",$head);
  } elsif ($head=~/\AVIEW/) {
    # from xv; untested
    $dummy="NNNNNN"; $bbi->{SubFormat}='MSBfirst';
   do_PM:
    $bbi->{FileFormat}='PM';
    ($dummy,$bbi->{'Info.num_planes'},$bbi->{URX},$bbi->{URY},
     $bbi->{'Info.num_bands'}, $bbi->{'Info.pixel_format'})=unpack($dummy,$head);
  } elsif ($head=~/\AWEIV/) {
    $dummy="VVVVVV"; $bbi->{SubFormat}='LSBfirst';
    goto do_PM;
  } elsif ($head=~/\A\001\332/) { # SGI 'rgb' image data
    $bbi->{SubFormat}='MSBfirst'; $dummy="nCCnnnn";
   do_SGI:
    $bbi->{FileFormat}='SGI'; # from xv IRIS; untested
    ($dummy,$bbi->{'Info.compression'},$bbi->{'Info.precision'},$bbi->{'Info.dimension'},
     $bbi->{URX},$bbi->{URY},$bbi->{SamplesPerPixel})=unpack($dummy,$head);
       if ($bbi->{'Info.compression'}==0) { $bbi->{'Info.compression'}='None' }
    elsif ($bbi->{'Info.compression'}==1) { $bbi->{'Info.compression'}='RLE' }
    $dummy=substr($head,80);
    $bbi->{'Info.comment'}=$1 if $dummy=~m@\A([^\0])\0@s;
    # Dat: Info.dimension is 2 or 3
    ## See http://reality.sgi.com/grafica/sgiimage.html
  } elsif ($head=~/\A\332\001/) { # SGI 'rgb' image data
    $bbi->{SubFormat}='MSBfirst'; $dummy="vCCvvvvv";
    goto do_SGI;
  } elsif (substr($head,0,9) eq "SIMPLE  =") {
    $bbi->{FileFormat}='FITS';
    while ($head!~/\bEND/) {
      goto IOerr if 1>read $F, $head, 1024, length($head);
    }
    $bbi->{'Info.bits_per_pixel'}=$1 if $head=~/\bBITPIX\s*=\s*(\d+)/;
    $bbi->{'Info.num_axis'}=$1 if $head=~/\bNAXIS\s*=\s*(\d+)/;
    $bbi->{URX}=$1 if $head=~/\bNAXIS1\s*=\s*(\d+)/;
    $bbi->{URY}=$1 if $head=~/\bNAXIS2\s*=\s*(\d+)/;
    $bbi->{'Info.depth'}=$1 if $head=~/\bNAXIS3\s*=\s*(\d+)/;
    $bbi->{'Info.data_max'}=$1 if $head=~/\bDATAMAX\s*=\s*(\d+)/;
    $bbi->{'Info.data_min'}=$1 if $head=~/\bDATAMIN\s*=\s*(\d+)/;
    # Dat: it would be quite hard to extract the dimensions...
    ## FITS is the Flexible Image Transport System, the de facto standard for
    ## data and image transfer, storage, etc., for the astronomical community.
    ## (FITS floating point formats are big-endian.)
    #0	string	SIMPLE\ \ =	FITS image data
    #>109	string	8		\b, 8-bit, character or unsigned binary integer
    #>108	string	16		\b, 16-bit, two's complement binary integer
    #>107	string	\ 32		\b, 32-bit, two's complement binary integer
    #>107	string	-32		\b, 32-bit, floating point, single precision
    #>107	string	-64		\b, 64-bit, floating point, double precision
  } elsif ($head=~/\A(?:NJPL1I|CCSD3Z|LBLSIZE=)/) {
    # from xv, imagemagick; untested
    $bbi->{FileFormat}='VICAR';
    while ($head!~/\bEND/) {
      goto IOerr if 1>read $F, $head, 1024, length($head);
    }
    $bbi->{URX}=$1 if $head=~/\b(?:IMAGE_LINES|LINES|NL)\s*=\s*(\d+)/;
    $bbi->{URY}=$1 if $head=~/\b(?:LINE_SAMPLES|NS)\s*=\s*(\d+)/;
    ##------------------------------------------------------------------------------
    ## vicar:  file(1) magic for VICAR files.
    ##
    ## From: Ossama Othman <othman@astrosun.tn.cornell.edu
    ## VICAR is JPL's in-house spacecraft image processing program
    ## VICAR image
    #0	string	LBLSIZE=	VICAR image data
    #>32	string	BYTE		\b, 8 bits  = VAX byte
    #>32	string	HALF		\b, 16 bits = VAX word     = Fortran INTEGER*2
    #>32	string	FULL		\b, 32 bits = VAX longword = Fortran INTEGER*4
    #>32	string	REAL		\b, 32 bits = VAX longword = Fortran REAL*4
    #>32	string	DOUB		\b, 64 bits = VAX quadword = Fortran REAL*8
    #>32	string	COMPLEX		\b, 64 bits = VAX quadword = Fortran COMPLEX*8
    ## VICAR label file
    #43	string	SFDU_LABEL	VICAR label file
  } elsif (substr($head,0,4) eq "IT01" or substr($head,0,4) eq "IT02") { # untested
    $bbi->{FileFormat}='FIT'; # do not cunfuse FIT and FITS
    ($dummy,$bbi->{URX},$bbi->{URY},$bbi->{'Info.num_bits'})=unpack("NNNN",$head);
  } elsif (substr($head,0,4) eq "#FIG") {
    $bbi->{FileFormat}='FIG';
    $bbi->{SubFormat}=$1 if $head=~/\A....[ \t]+(\S+)/s;
    ## FIG (Facility for Interactive Generation of figures), an object-based format
    ## (as handled by xfig). There is no size information, fig2dev saves bounding
    ## box as EPS
    #0	string		#FIG		FIG image text
    #>5	string		x		\b, version %.3s

## These file formats below are known to the Debian potato file(1) command,
## but the magic(5) file doesn't tell us how to extract size information
##
## NITF is defined by United States MIL-STD-2500A
#0	string	NITF	National Imagery Transmission Format
#>25	string	>\0	dated %.14s
#
## NIFF (Navy Interchange File Format, a modification of TIFF) images
#0	string		IIN1		NIFF image data
## ITC (CMU WM) raster files.  It is essentially a byte-reversed Sun raster,
## 1 plane, no encoding.
## Artisan
#0	long		1123028772	Artisan image data
#>4	long		1		\b, rectangular 24-bit
#>4	long		2		\b, rectangular 8-bit with colormap
#>4	long		3		\b, rectangular 32-bit (24-bit with matte)
#
#
## PHIGS
#0	string		ARF_BEGARF		PHIGS clear text archive
#0	string		@(#)SunPHIGS		SunPHIGS
## version number follows, in the form m.n
##>40	string		SunBin			binary
##>32	string		archive			archive
##
## GKS (Graphics Kernel System)
#0	string		GKSM		GKS Metafile
#>24	string		SunGKS		\b, SunGKS
#
## CGM image files
#0	string		BEGMF		clear text Computer Graphics Metafile
## XXX - questionable magic
#0	beshort&0xffe0	0x0020		binary Computer Graphics Metafile
#0	beshort		0x3020		character Computer Graphics Metafile
#
## MGR bitmaps  (Michael Haardt, u31b3hs@pool.informatik.rwth-aachen.de)
#0	string	yz	MGR bitmap, modern format, 8-bit aligned
#0	string	zz	MGR bitmap, old format, 1-bit deep, 16-bit aligned
#0	string	xz	MGR bitmap, old format, 1-bit deep, 32-bit aligned
#0	string	yx	MGR bitmap, modern format, squeezed
#
## image file format (Robert Potter, potter@cs.rochester.edu)
#0	string		Imagefile\ version-	iff image data
## this adds the whole header (inc. version number), informative but longish
#>10	string		>\0		%s
#
## other images
#0	string	This\ is\ a\ BitMap\ file	Lisp Machine bit-array-file
#0	string		\!\!		Bennet Yee's "face" format
#
## From SunOS 5.5.1 "/etc/magic" - appeared right before Sun raster image
## stuff.
##
#0	beshort		0x1010		PEX Binary Archive
#
## Visio drawings
#03000	string	Visio\ (TM)\ Drawing			%s
#
#0	string		IC		PC icon data
#0	string		PI		PC pointer image data
#0	string		CI		PC color icon data
#0	string		CP		PC color pointer image data

  } elsif (substr($head,0,2) eq "\37\x9d") {
    # .Z compress(1)ed file; may be an image (i.e pbm.Z)
    $bbi->{FileFormat}='compress'; $bbi->{SubFormat}='compress';
  } elsif (substr($head,0,2) eq "\37\x8b") {
    $bbi->{FileFormat}='compress'; $bbi->{SubFormat}='gzip';
  } elsif (substr($head,0,2) eq "\37\x36") {
    $bbi->{FileFormat}='compress'; $bbi->{SubFormat}='pack';
  } elsif ($head=~/\A(?:\377\037|\037\377)/) {
    $bbi->{FileFormat}='compress'; $bbi->{SubFormat}='compact';
  } elsif (substr($head,0,3) eq "BZh") {
    $bbi->{FileFormat}='compress'; $bbi->{SubFormat}='bzip2';
  } elsif (substr($head,0,2) eq "BZ") { # check must be after bzip
    $bbi->{FileFormat}='compress'; $bbi->{SubFormat}='bzip1';
  } elsif (substr($head,0,2) eq "\x76\xff") {
    $bbi->{FileFormat}='compress'; $bbi->{SubFormat}='squeeze';
  } elsif (substr($head,0,2) eq "\x76\xfe") {
    $bbi->{FileFormat}='compress'; $bbi->{SubFormat}='crunch';
  } elsif (substr($head,0,2) eq "\x76\xfd") {
    $bbi->{FileFormat}='compress'; $bbi->{SubFormat}='LZH';
  } elsif (substr($head,0,2) eq "\037\237") {
    $bbi->{FileFormat}='compress'; $bbi->{SubFormat}='freeze2';
  } elsif (substr($head,0,2) eq "\037\236") {
    $bbi->{FileFormat}='compress'; $bbi->{SubFormat}='freeze1';
  } elsif (substr($head,0,2) eq "\037\240") {
    $bbi->{FileFormat}='compress'; $bbi->{SubFormat}='SCO.LZH';
  } elsif (substr($head,0,9) eq "\x89\x4c\x5a\x4f\x00\x0d\x0a\x1a\x0a") {
    $bbi->{FileFormat}='compress'; $bbi->{SubFormat}='lzop';

  } elsif (substr($head,0,2) eq "\x60\xEA") {
    $bbi->{FileFormat}='archive'; $bbi->{SubFormat}='ARJ';
  } elsif ($head=~/\A..-l[hz]/s) {
    $bbi->{FileFormat}='archive'; $bbi->{SubFormat}='LHA';
  } elsif (substr($head,0,4) eq "Rar!") {
    $bbi->{FileFormat}='archive'; $bbi->{SubFormat}='RAR';
  } elsif (substr($head,0,4) eq "UC2\x1A") {
    $bbi->{FileFormat}='archive'; $bbi->{SubFormat}='UC2';
  } elsif (substr($head,0,4) eq "PK\003\004") {
    $bbi->{FileFormat}='archive'; $bbi->{SubFormat}='ZIP';
  } elsif (substr($head,0,4) eq "\xDC\xA7\xC4\xFD") {
    $bbi->{FileFormat}='archive'; $bbi->{SubFormat}='ZOO';

  } elsif ($head=~/\A.PC Research, Inc/s) {
    $bbi->{FileFormat}='G3';
    $bbi->{SubFormat}='Digifax';
    # Dat: determining $bbi->{URX} and $bbi->{URY} would require a complex
    #      and full parsing of the G3 facsimile data
  } elsif ($head=~/\A\367[\002-\005]/) {
    # Dat: \005 is rather arbitrary here
    goto FF__DVI;
  } elsif ($head=~/\A[\36-\77](?:\001[\001\11]|\0[\002\12\003\13])\0\0/ and
    vec($head, 1, 8)<=11 and (vec($head, 16, 8)<=8 or vec($head, 16, 8)==24)) { # potato magic
    my @types=(0,'Map','RGB','Gray',0,0,0,0,0,'Map.RLE','RGB.RLE','Gray.RLE');
    $bbi->{FileFormat}='TGA';
    $bbi->{SubFormat}=$types[vec($head,2,8)];
    ($dummy,$bbi->{LLX},$bbi->{LLY},$bbi->{URX},$bbi->{URY})=unpack("A8vvvv",$head);
    # Imp: verify LLX!=0 URX-LLX
  } elsif (30<=vec($head, 0, 8) and vec($head, 0, 8)<=63 and
    vec($head, 1, 8)<=11 and (vec($head, 16, 8)<=8 or vec($head, 16, 8)==24)) {
    # ^^^ Dat: TGA doesn't have a fixed-format header, so this detection is quite
    #     weak. That's why it is the last one we perform.
    $bbi->{FileFormat}='TGA';
    $bbi->{SubFormat}='fallback';
    ($dummy,$bbi->{LLX},$bbi->{LLY},$bbi->{URX},$bbi->{URY})=unpack("A8vvvv",$head);
    # Imp: verify LLX!=0 URX-LLX
  } elsif ($head=~/^PicData:\s*(\d+)\s*(\d+)\s*(\d+)/m) { # grayscale Faces Project imagegrayscale Faces Project image; untested
    # ^^^ Dat: regexp match is quite weak; perform check last
    $bbi->{FileFormat}='Faces'; # from xloadimage
    $bbi->{URX}=$1+0; $bbi->{URY}=$2+0; $bbi->{"Info.bitdepth"}=$3+0;
  } elsif ($head=~/\A\001\0/s) { # really weak
    $bbi->{FileFormat}='G3';
    $bbi->{SubFormat}='MSBfirst.bytepad';
  } elsif ($head=~/\A\0\001/s) { # really weak
    $bbi->{FileFormat}='G3';
    $bbi->{SubFormat}='LSBfirst.bytepad';
  } elsif ($head=~/\A\24\0/s) { # really weak
    $bbi->{FileFormat}='G3';
    $bbi->{SubFormat}='MSBfirst.raw';
  } elsif ($head=~/\A\0\24/s) { # really weak
    $bbi->{FileFormat}='G3';
    $bbi->{SubFormat}='LSBfirst.raw';
    # Dat: determining $bbi->{URX} and $bbi->{URY} would require a complex
    #      and full parsing of the G3 facsimile data
  } else {
    $bbi->{Error}='unrecognised FileFormat'
  }
 done:
  if ($have_paper and exists $bbi->{URX} and exists $bbi->{URY}) {
    ($bbi->{Paper},$bbi->{PaperWidth},$bbi->{PaperHeight})=@L[0,1,2] if
      @L=Htex::papers::valid_bp($bbi->{URX},$bbi->{URY},$bbi->{LLX},$bbi->{LLY});
  } else {
    delete $bbi->{LLX} if !exists $bbi->{URX};
    delete $bbi->{LLY} if !exists $bbi->{URY};
  }
  $bbi
}

sub import {
  no strict 'refs';
  my $package=(caller())[0];
  shift;
  ($have_paper,$have_pdf)=(1,1);
  for my $p (@_) {
    if ($p eq '-PDF') { $have_pdf=0 }
    elsif ($p eq '-paper') { $have_paper=0 }
    else { *{$package."::$p"}=\&{$p} }
  }
  if ($have_pdf) { require Htex::PDFread; import Htex::PDFread }
  if ($have_paper) { require Htex::papers; import Htex::papers }
}

just::end}

BEGIN{$ INC{'vars.pm'}='vars.pm'} {
package vars;
use just;
# by pts@fazekas.hu at Wed Jan 10 12:42:08 CET 2001
require 5.002;
sub import {
  my $callpack = caller;
  my ($sym, $ch, $sym0);
  shift;
  for $sym0 (@_) {
    die("Can't declare another package's variables") if $sym0 =~ /::/;
    ($ch, $sym) = unpack('a1a*', $sym0);
    *{"${callpack}::$sym"} =
    (  $ch eq "\$" ? \$   {"${callpack}::$sym"}
     : $ch eq "\@" ? \@   {"${callpack}::$sym"}
     : $ch eq "\%" ? \%   {"${callpack}::$sym"}
     : $ch eq "\*" ? \*   {"${callpack}::$sym"}
     : $ch eq "\&" ? \&   {"${callpack}::$sym"}
     : die("'$ch$sym' is not a valid variable name\n")
    );
  }
}
just::end}

BEGIN{$ INC{'Htex/PDFread.pm'}='Htex/PDFread.pm'} {
package Htex::PDFread;
# by pts@fazekas.hu at Sat Dec 21 21:28:09 CET 2002
use just;
use integer;
use strict;
use Pts::string;
use vars qw($pdf_last_ref0);

my @pdf_classify;
#** @param $_[0] a string in PDF source format
#** @return a rewritten string, or "" if $_[0] is truncated, or undef if
#**   there is a parse error
sub pdf_rewrite($;$) {
  my $explicit_term_p=$_[1];
  my $L=length($_[0]);
  return "" if $L==0;
  my $S="$_[0]\n>>  "; # add sentinel
  my $I=0;
  my $O;
  my $RET="";
  if (!@pdf_classify) {
    # Dat: PDF whitespace(0) is  [\000\011\012\014\015\040]
    # Dat: PDF separators(10) are < > { } [ ] ( ) / %
    # Dat: PDF regular(40) character is any of [\000-\377] which is not whitespace or separator
    @pdf_classify=(40)x256;
    @pdf_classify[ord('<'),ord('>'),ord('{'),ord('}'),ord('['),ord(']'),
      ord('('),ord(')'),ord('/'),ord('%')]=(10,11,12,13,14,15,16,17,18,19);
    @pdf_classify[000,011,012,014,015,040]=(0,0,0,0,0,0);
  }
  while ($I<$L) {
    $O=$pdf_classify[vec($S,$I,8)];
    if ($O==0) { # whitespace
    } elsif (12<=$O and $O<=15) { # one-char token
      $RET.=" ".substr($S,$I,1);
    } elsif ($O==18 or $O==40) { # name or /name
      my $P=0;
      if ($O==18) { $I++; $RET.=" /" } else { $RET.=" "; $P=1 }
      my $T="";
      $T.=chr($O) while $pdf_classify[$O=vec($S,$I++,8)]==40;
      $I--;
      ## die $I;
      $T=~s@([^A-Za-z0-9_.-])@sprintf"#%02x",ord$1@ge; # make name safe
      $RET.=$T;
      return $RET if $P and ($T eq "stream" or $T eq "endobj" or $T eq "startxref");
      next
    } elsif ($O==11) { # `>'
      return "" if ++$I==$L; # only `>' has arrived
      return undef if vec($S,$I,8)!=62; # err(">> expected");
      $RET.=" >>";
    } elsif ($O==16) { # string
      my $T="";
      my $depth=1; $I++;
      while ($I<$L) {
        $O=vec($S,$I++,8); bcont:
        ## print chr($O),":$depth\n";
        if ($O==40) { $depth++ }
        elsif ($O==41) { last unless --$depth }
        elsif ($O==92) { # a backslash
          $O=vec($S,$I++,8);
          if (48<=$O && $O<=55) {
            my $P=$O-48; $O=vec($S,$I++,8);
            if (48<=$O && $O<=55) {
              my $Q=$O-48; $O=vec($S,$I++,8);
              if (48<=$O && $O<=55) { $T.=chr(255&($P<<6|$Q<<3|($O-48))) }
                               else { $T.=chr($P<<3|$Q); goto bcont }
            } else { $T.=chr($P); goto bcont }
          } elsif ($O==110) { $O=10 }
          elsif ($O==114) { $O=13 }
          elsif ($O==116) { $O=9 }
          elsif ($O== 98) { $O=8 }
          elsif ($O==102) { $O=12 }
        }
        $T.=chr($O)
      } # WHILE
      return "" if $depth; # err("unterminated string")
      $T=~s@([^A-Za-z0-9_.-])@sprintf"\\%03o",ord$1@ge; # make string safe
      $RET.=" ($T)"; next
    } elsif ($O==10) { # hex string
      $O=vec($S,++$I,8);
      if ($O==60) { $RET.=" <<"; $I++; next }
      # parse hexadecimal string
      my $half=0x100;
      my $T="";
      while (1) {
        1 until $pdf_classify[$O=vec($S,$I++,8)]; # skip whitespace
        if ($O==62) { $T.=chr($half&0xFF) if $half&0x1000; last } # '>'
        return undef if $pdf_classify[$O]!=40; # err("unexpected token in hex")
        if (65<=$O and $O<=70) { $half+=$O-55 }
        elsif (97<=$O and $O<=102) { $half+=$O-87 }
        elsif (48<=$O and $O<=57) { $half+=$O-48 }
        else { return undef } # err("illegal hex digit")
        if ($half&0x1000) { $T.=chr($half&0xFF); $half=0x100 }
                     else { $half<<=4 }
      }
      $T=~s@([^A-Za-z0-9_.-])@sprintf"\\%03o",ord$1@ge; # make string safe
      $RET.=" ($T)"; next
    } elsif ($O==19) { # single-line comment
      $I++ while ($O=vec($S,$I,8))!=13 && $O!=10;
      ## print STDERR "I=$I L=$L\n";
      next
    } else { return undef } # err("token expected") # $O==11, $O==17
    $I++
  } ## WHILE
  ## print STDERR "XI=$I L=$L\n";
  # die $explicit_term_p;
  return "" if $explicit_term_p;
  ($I>$L) ? "" : $RET
}

# Unit test:
#die unless pdf_rewrite("hello \n\t world\n\t") eq " hello world";
#die unless pdf_rewrite('(hel\)lo\n\bw(or)ld)') eq ' (hel\051lo\012\010w\050or\051ld)';
#die unless pdf_rewrite('(hel\)lo\n\bw(orld)') eq '';
#die unless pdf_rewrite('[ (hel\)lo\n\bw(or)ld)>>') eq ' [ (hel\051lo\012\010w\050or\051ld) >>';
#die unless pdf_rewrite('>') eq "";
#die unless pdf_rewrite('<') eq "";
#die unless pdf_rewrite('< ') eq "";
#die unless !defined pdf_rewrite('< <');
#die unless !defined pdf_rewrite('> >');
#die unless pdf_rewrite('[ (hel\)lo\n\bw(or)ld) <') eq "";
#die unless pdf_rewrite("<\n3\t1\r4f5C5 >]") eq ' (1O\134P) ]';
#die unless pdf_rewrite("<\n3\t1\r4f5C5") eq "";
#die unless !defined pdf_rewrite("<\n3\t1\r4f5C5]>");
#die unless pdf_rewrite("% he te\n<\n3\t1\r4f5C5 >]endobj<<") eq ' (1O\134P) ] endobj';
#die unless pdf_rewrite("") eq "";
#die unless pdf_rewrite("<<") eq " <<";
#die unless pdf_rewrite('%hello') eq '';
#die unless pdf_rewrite("alma\n%korte\n42") eq ' alma 42';
#die unless pdf_rewrite('/Size 42') eq ' /Size 42';
#die "OK";

#** Reads a single PDF indirect object (without its stream) from a PDF file.
#** Does some trivial transformations on it to make later regexp matching
#** easier. Stops at `stream', `endobj' and `startxref'.
#** @param $_[0] a filehandle (e.g \*STDIN), correctly positioned in the PDF
#**   file to the beginning of the object data (i.e just before `5 0 obj')
#** @return string containing PDF source code, or undef on error
sub pdf_read_obj($) {
  my $F=$_[0];  my $L=1024;  my $M;  my $S="";  my $RET;
  while (1) { # read as much data as necessary
    return undef if 0>($M=read $F, $S, $L, length($S));
    $RET=pdf_rewrite($S,1);
    ## print "($S)\n";
    return undef if !defined $RET; # parse error
    return $RET if length $RET; # OK, found object
    return undef if $M==0; # cannot read more, reached EOF
    $L<<=1;
  }
  #$S=~m@[\000\011\012\014\015\040]*(
  #  %[^\r\n]*[\r\n]|
  #  /?[^\000\011\012\014\015\040<>{}\[\]()/%]*(?=[\000\011\012\014\015\040<>{}\[\]()/%])| # unterminated
  #  <<|>>|\{|}|\[|]|
  #  <[a-fA-F0-9\000\011\012\014\015\040]*>| # hex string
  #  \((?:[^\\()]+|\\[\000-\377])*\)| # literal string, the easy way
  #  \( # an unfinished string, needs special care
  #)@gx
}

#** @param $_[0] a filehandle (e.g \*STDIN), containing a PDF file, positioned
#**  just before an `xref' table
#** @param $_[1] an xref table: $_[1][4][56] is the file offset of object 56
#**   from generation 4; will be extended
#** @return the `trailer' section after the `xref'; or undef
sub pdf_read_xref($$) {
  # made much faster at Wed Dec 18 09:50:23 CET 2002
  my $T;
  my $E;
  my $F=$_[0];
  my $XREF=$_[1];
  return undef if 8>read $F, $T, 1024;
  return undef unless $T=~s@\A\s*xref\s+(\d+)\s+(\d+)\s+(?=\S)@@;
  my ($first,$len,$flen);
  while (1) {
    ($first,$len)=($1+0,$2+0);
    ## print " $first + $len\n";
    $flen=($len*=20)-length($T)+20;
    return undef unless $flen<1 or $flen==read $F, $T, $flen, length($T);
    for (my $I=0;$I<$len;$I+=20, $first++) {
      $E=substr($T, $I, 20);
      return undef unless $E=~/\A(\d{10})\s(\d{5})\s([nf])\s\s/;
      ## print "($1 $2 $3)\n";
      $XREF->[$2+0][$first]=$1+0 if $3 eq 'n';
    }
    $E=substr($T, $len);
    last if $E!~s@\A\s*(\d+)\s*(\d+)\s+(?=\S)@@; # next section
    $T=$E;
  }
  
  # die(-length($T)+$len);
  ## die tell($F);
  return undef if length($T)!=$len and !seek $F, -length($T)+$len, 1;
  ## die tell($F);
  return undef unless defined($T=pdf_read_obj($F));
  $XREF->[0][0]=undef if defined $XREF->[0];
  $XREF->[0][0]=$1+0 if $T=~m@ /Prev (\d+)@; # remember /Prev xref table
  return undef unless $T=~m@\A trailer( .*) startxref\Z(?!\n)@s;
  $1
}

$pdf_last_ref0=0;
#** @param $_[0] a filehandle (e.g \*STDIN), containing a PDF file
#** @param $_[1] an xref table: $_[1][4][56] is the file offset of object 56
#**   from generation 4
#** @param $_[2] an object number
#** @param $_[3] a generation number
#** @return PDF source code of the reference, or undef
sub pdf_ref($$$$) {
  my $F=$_[0]; my $XREF=$_[1]; my $ON=$_[2]+0; my $GN=$_[3]+0;
  my $T;
  $pdf_last_ref0=$ON if $GN==0;
  ## print "REF $ON $GN;\n";
  until (ref $XREF->[$GN] and defined ($T=$XREF->[$GN][$ON])) {
    return undef if !ref $XREF->[0] or !defined $XREF->[0][0]; # no /Prev entry, `$ON $GN R' not found
    return undef unless seek $F, $XREF->[0][0], 0;
    return undef if !defined pdf_read_xref($F,$XREF);
  }
  ## print "REF at $T;\n";
  return undef unless seek $F, $T, 0;
  return undef unless defined($T=pdf_read_obj($F));
  ## print "REF=($T);\n";
  return undef unless $T=~s@\A (\d+) (\d+) obj\b(.*) (endobj|stream)\Z(?!\n)@$3@s;
  $T
}

#** Gets a key from a direct dict, and resolves it if it is an indirect object
#** @param $_[0] a filehandle (e.g \*STDIN), containing a PDF file
#** @param $_[1] an xref table: $_[1][4][56] is the file offset of object 56
#**   from generation 4
#** @param $_[2] a PDF source dict (`<< ... >>') or array
#** @param $_[3] a key (`/...')
sub pdf_get($$$$) {
  my $F=$_[0]; my $XREF=$_[1]; my $S=$_[2]; my $KEY=$_[3]; my $POS=0;
  my $DEPTH=0; my $IS_DICT; my $C=0; my $N=0;
  ## print "\n";
  while ($S=~/\G (\S+)/g) {
    $C=vec($1,0,8);  $POS=pos($S);
    ## print "($1) $DEPTH $N\n";
    if ($1 eq '>>' or $1 eq ']') {
      return undef if 0==$DEPTH--;
      last if !$DEPTH;
      $N++ if 1==$DEPTH;
    }
    elsif ($DEPTH==1 and !$IS_DICT and $KEY==$N) { $POS=pos($S)-=length($1)+1; goto do_ret }
    elsif ($1 eq '<<') { $IS_DICT=1 if 0==$DEPTH++ }
    elsif ($1 eq '[') {
      if (0==$DEPTH++) {
        $IS_DICT=0;
        return undef if $KEY!~/\A(\d+)\Z(?!\n)/; # err("non-numeric key in array")
      }
    }
    elsif (0==$DEPTH) { return undef } # not in a composite object
    elsif (1!=$DEPTH) { next }
    elsif (!$IS_DICT) { $N++ }
    elsif ($C==40) { $N++ } # `(': string or bare name
    elsif ($C>=47 and $C<=57) { # '/': /name 0..9: number
      ## print "TRY ($1) KEY=$KEY.\n";
      next if ($N++&1)==1 or $1 ne $KEY;
     do_ret:
      ## print substr($S,pos($S)),";;\n";
      return pdf_ref $F, $XREF, $1, $2 if $S=~/\G (\d+) (\d+) R\b/gc;
      ## print substr($S,pos($S)),"::\n";
      $DEPTH=0;
      while ($S=~/\G( \S+)/g) {
        if ($1 eq ' <<' or $1 eq ' [') { $DEPTH++ }
        elsif ($1 eq ' >>' or $1 eq ' ]') {
          ## die "($1)\n";
          return undef if 0==$DEPTH--; # err("nesting")
          return substr($S,$POS,pos($S)-$POS) if 0==$DEPTH;
        } elsif ($DEPTH==0) { return $1 }
      }
    } else { $N++ } # bare name
  }
  return undef if $POS!=length($S); # err("invalid source dict");
  "" # not found
}

# Unit test:
#die unless pdf_get(\*STDIN, 0, ' [ al makorte 42 ]', 0) eq ' al';
#die unless pdf_get(\*STDIN, 0, ' [ al makorte 42 ]', 1) eq ' makorte';
#die unless pdf_get(\*STDIN, 0, ' [ al makorte 42 ]', 2) eq ' 42';
#die unless pdf_get(\*STDIN, 0, ' [ al makorte 42 ]', 3) eq '';
#die unless pdf_get(\*STDIN, 0, ' [ << >> ]', 0) eq ' << >>';
#die unless pdf_get(\*STDIN, 0, ' [ << >> ]', 1) eq '';
#die unless pdf_get(\*STDIN, 0, ' [ << >> [ al makorte 42 ] ]', 1) eq ' [ al makorte 42 ]';
#die unless pdf_get(\*STDIN, 0, ' << /Alma [ 1 2 ] /Korte [ 3 4 ] >>', '/Korte') eq ' [ 3 4 ]';
#die unless !defined pdf_get(\*STDIN, 0, ' [ al makorte 42 ]', '/Name');
#die unless !defined pdf_get(\*STDIN, 0, ' << al makorte 42 >>', 42);
#die unless pdf_get(\*STDIN, 0, ' << al makorte 42 137 >>', 42) eq ' 137';
#die unless pdf_get(\*STDIN, 0, ' << al makorte >>', 'al') eq "";
#die "OK";

#** Reported boxes: /MediaBox /CropBox /BleedBox /TrimBox /ArtBox
#** @param $_[0] a filehandle (e.g \*STDIN), containing a PDF file
#** @param $_[1] an xref table: $_[1][4][56] is the file offset of object 56
#**   from generation 4
#** @param $_[2] a PDF source dict (`<< ... >>') of /Type/Catalog
#**   /Type/Pages or /Type/Page
#** @param $_[3] hashref to update. $_[3]{BleedBox}[2] will be the URX corner
#**   of the BleedBox
sub pdf_get_boxes($$$$) {
  my $F=$_[0]; my $XREF=$_[1]; my $S=$_[2]; my $bbi=$_[3];
  return if !defined $S;
  for my $name (qw{MediaBox CropBox BleedBox TrimBox ArtBox}) {
    my $box=pdf_get($F, $XREF, $S, "/$name");
    next if !defined $box or !length $box
         or $box!~m@ \[ ([0-9eE.-]+) ([0-9eE.-]+) ([0-9eE.-]+) ([0-9eE.-]+) \]\Z(?!\n)@
         or !defined c_numval($1) or !defined c_numval($2) or !defined c_numval($3) or !defined c_numval($4);
    ($bbi->{LLX},$bbi->{LLY},$bbi->{URX},$bbi->{URY})=($1+0,$2+0,$3+0,$4+0) if $name eq 'MediaBox';
    my $name2="Info.$name";
    ($bbi->{$name2}[0],$bbi->{$name2}[1],$bbi->{$name2}[2],$bbi->{$name2}[3])=($1+0,$2+0,$3+0,$4+0);
  }
}

sub import {
  no strict 'refs';
  my $package=(caller())[0];
  shift;
  for my $p (@_ ? @_ : qw{pdf_get_boxes pdf_get pdf_read_xref pdf_read_obj
    pdf_rewrite pdf_ref}) { *{$package."::$p"}=\&{$p} }
}

just::end}

BEGIN{$ INC{'Htex/papers.pm'}='Htex/papers.pm'} {
package Htex::papers;
# contains paper size information
# by pts@fazekas.hu at Sun Dec 22 00:30:58 CET 2002
use just;
use integer;
use strict;
use Htex::dimen;

my @papers=(
#
# paper.txt
# by pts@fazekas.hu at Tue Jan 16 18:21:59 CET 2001
# by pts@fazekas.hu at Tue Jan 16 19:13:16 CET 2001
#
# Examined: dvips, gs, libpaperg
#
# all units are measured in Big Points (bp)
# 72 bp == 1 in
# 2.54 cm == 1 in
#
# papername	width	height
qw{Comm10	297	684},
qw{Monarch	279	540},
qw{halfexecutive 378	522},

qw{Legal	612	1008},
qw{Statement	396	612},
qw{Tabloid	792	1224},
qw{Ledger	1224	792},
qw{Folio	612	936},
qw{Quarto	610	780},
qw{7x9		504	648},
qw{9x11		648	792},
qw{9x12		648	864},
qw{10x13	720	936},
qw{10x14	720	1008},
qw{Executive	540	720},

qw{ISOB0	2835	4008},
qw{ISOB1	2004	2835},
qw{ISOB2	1417	2004},
qw{ISOB3	1001	1417},
qw{ISOB4	 709	1001},
qw{ISOB5	 499	 709},
qw{ISOB6	 354	 499},
qw{ISOB7	 249	 354},
qw{ISOB8	 176	 249},
qw{ISOB9	 125	 176},
qw{ISOB10	 88	 125},
qw{jisb0	2916	4128},
qw{jisb1	2064	2916},
qw{jisb2	1458	2064},
qw{jisb3	1032	1458},
qw{jisb4	 729	1032},
qw{jisb5	 516	 729},
qw{jisb6	 363	 516},

qw{C7		230	323},
qw{DL		312	624},

qw{a3		842	1190},	# defined by Adobe
qw{a4		595	842},	# defined by Adobe; must precede a4small

# a4small should be a4 with an ImagingBBox of [25 25 570 817].},
qw{a4small	595	842},
qw{letter	612	792},	# must precede lettersmall
# lettersmall should be letter with an ImagingBBox of [25 25 587 767].
qw{lettersmall	612	792},
# note should be letter (or some other size) with the ImagingBBox
# shrunk by 25 units on all 4 sides.
qw{note		612	792},
qw{letterLand	792	612},
# End of Adobe-defined page sizes

qw{a0		2380	3368},
qw{a1		1684	2380},
qw{a2		1190	1684},
qw{a5		421	595},
qw{a6		297	421},
qw{a7		210	297},
qw{a8		148	210},
qw{a9		105	148},
qw{a10		74	105},
qw{b0		2836	4008},
qw{b1		2004	2836},
qw{b2		1418	2004},
qw{b3		1002	1418},
qw{b4		709	1002},
qw{b5		501	709}, # defined by Adobe

qw{a0Land	3368	2380},
qw{a1Land	2380	1684},
qw{a2Land	1684	1190},
qw{a3Land	1190	842},
qw{a4Land	842	595},
qw{a5Land	595	421},
qw{a6Land	421	297},
qw{a7Land	297	210},
qw{a8Land	210	148},
qw{a9Land	148	105},
qw{a10Land	105	74},
qw{b0Land	4008	2836},
qw{b1Land	2836	2004},
qw{b2Land	2004	1418},
qw{b3Land	1418	1002},
qw{b4Land	1002	709},
qw{b5Land	709	501},

qw{c0		2600	3677},
qw{c1		1837	2600},
qw{c2		1298	1837},
qw{c3		918	1298},
qw{c4		649	918},
qw{c5		459	649},
qw{c6		323	459},

# vvv U.S. CAD standard paper sizes
qw{archE	2592	3456},
qw{archD	1728	2592},
qw{archC	1296	1728},
qw{archB	864	1296},
qw{archA	648	864},

qw{flsa		612	936},	# U.S. foolscap
qw{flse		612	936},	# European foolscap
qw{halfletter	396	612},
qw{csheet	1224	1584},	# ANSI C 17x22
qw{dsheet	1584	2448},	# ANSI D 22x34
qw{esheet	2448	3168},	# ANSI E 34x44
qw{17x22	1224	1584},	# ANSI C 17x22
qw{22x34	1584	2448},	# ANSI D 22x34
qw{34x44	2448	3168},	# ANSI E 34x44
);

#** Converts a numeric paper size to a well-defined paper name. Tolerance is
#** 8.5bp
#** @param $_[0] width, in bp
#** @param $_[1] height, in bp
#** @return () or ("papername", ret.paper.width.bp, ret.paper.height.bp)
sub valid_bp($$;$$) {
  no integer;
  my ($W1,$H1)=(defined$_[2]?$_[2]:0,defined$_[3]?$_[3]:0);
  my ($WW,$HH)=(Htex::dimen::dimen2bp($_[0])-$W1, Htex::dimen::dimen2bp($_[1])-$H1);
  # Dat: 1mm == 720/254bp; 3mm =~ 8.5bp
  no integer;
  for (my $I=0; $I<@papers; $I+=3) {
    return @papers[$I,$I+1,$I+2] if abs($papers[$I+1]-$WW)<=8.5 and abs($papers[$I+2]-$HH)<=8.5;
  }
  ()
}

#** @param $_[0] (width width_unit "," height height_unit)
#** @return () or ("papername", width.bp, height.bp)
sub valid($) { # valid_papersize
  my $S=lc$_[0];
  $S=~/^\s*(\d+(\.\d+)?)\s*([a-z][a-z0-9]+)\s*,\s*(\d+(\.\d+)?)\s*([a-z][a-z0-9]+)\s*\Z(?!\n)/ ?
    valid_bp("$1$3","$4$6") : ();
}

#** @param $_[0] (width width_unit? ("," || "x") height height_unit?) || (papername)
#** @return () or ("papername"?, width.bp, height.bp)
sub any($) {
  my $S=lc$_[0];
  if ($S=~/\A[a-z]\w+\Z(?!\n)/) {
    for (my $I=0; $I<@papers; $I+=3) {
      return @papers[$I,$I+1,$I+2] if lc($papers[$I]) eq $S;
    }
  }
  return () if $S!~/^\s*(\d+(\.\d+)?)\s*((?:[a-z][a-z0-9]+)?)\s*[,x]\s*(\d+(\.\d+)?)\s*((?:[a-z][a-z0-9]+)?)\s*\Z(?!\n)/;
  my($w,$h)=($1.$3, $4.$6);
  my @L=valid_bp($w,$h);
  @L ? @L : (undef,Htex::dimen::dimen2bp($w),Htex::dimen::dimen2bp($h))
}

just::end}

BEGIN{$  INC{'Htex/img_bbox.pm'}='Htex/img_bbox.pm'}

package Htex::img_bbox;
# img_bbox.pa -- detect file format and media parameters
# This file contains embedded perldoc(1) POD documentation.
# by pts@fazekas.hu at Sat Dec  7 21:31:01 CET 2002
# JustLib2 at Sat Dec 21 21:29:21 CET 2002
#
# img_bbox.pl is a standalone Perl script that can extract file format,
# width, height, bounding box and
# other meta-information from image files. Supported vector formats are:
# PDF, Flash SWF, EPS, PS, DVI and FIG. Supported raster image formats are:
# GIF, JPEG, PNG, TIFF, XPM, XBM1, XBM, PNM, PBM, PGM, PPM, PCX, LBM, other
# IFF, Windows and OS/2 BMP, MIFF, Gimp XCF, Windows ICO, Adobe PSD, FBM,
# SunRaster, CMUWM, Utah RLE, Photo CD PCD, XWD, GEM, McIDAS, PM, SGI IRIS,
# FITS, VICAR, PDS, FIT, Fax G3, Targa TGA and Faces.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# Extracting the image size is not supported for: other IFF, FIG.
#
#
use just 1;
use integer; # important
use strict; # not so important
# use Htex::ImgBBox qw(calc -PDF -paper);
use Htex::ImgBBox qw(calc);

sub delete0($$) {
  delete $_[0]{$_[1]};
  ""
}

#** @param $_[0] $bbi hashref
#** @return a multiline dump of all key--value pairs, sorted by key
sub all($) {
  my $bbi=$_[0];
  my $RET="";
  for my $key (sort keys %$bbi) { if (1<length $key) {
    my $val=$bbi->{$key};
    $RET.="  $key = ".(ref($val)eq'ARRAY' ? "[ @$val ]\n" : "$val\n");
  } }
  $RET
}

my %texq;
#** @param $_[0] arbitrary binary string
#** @return the string quoted, so it can be safely placed inside TeX
#**   \message{...} or \special{...}
sub texq($) {
  if (!keys %texq) {
    $texq{' '}='\iftrue\space\fi '; # won't collapse two spaces into one
   $texq{'\\'}='\expandafter\@secondoftwo\string\\\\';
    $texq{'{'}='\expandafter\@secondoftwo\string\{';
    $texq{'}'}='\expandafter\@secondoftwo\string\}';
    $texq{'%'}='\expandafter\@secondoftwo\string\%';
    $texq{'#'}='\expandafter\@secondoftwo\string\#';
    $texq{'^'}='\expandafter\@secondoftwo\string\^'; # no danger of ^^
    $texq{'~'}='\expandafter\@secondoftwo\string\~';
    $texq{'`'}='\expandafter\@secondoftwo\string\`';
    $texq{'"'}='\expandafter\@secondoftwo\string\"';
    # vvv will work only if the token is expanded only once
    #$texq{'~'}='\noexpand~';
    #$texq{'`'}='\noexpand`';
    #$texq{'"'}='\noexpand"';
  }
  my $S=$_[0];
  $S=~s@(\W)@exists$texq{$1}?$texq{$1}:$1@ge;
  $S=~s~([\000-\037\177-\377])~sprintf"\\expandafter\\\@secondoftwo\\string\\^^%02x",ord$1~ge;
  $S
}

sub aq($$) {
  $_[0] eq ":t" ? texq($_[1]) : $_[1]
}

my $t_short="%{FileName} %{FileFormat:-??} %{LLX:-??} %{LLY:-??} %{URX:-??} %{URY:-??}%{Paper?+ %{Paper}}%{Error?+ error:%{Error}}\n";
my $t_long="%{FileName}%{FileName?0}\n%{all}";
# my $t_tex='\graphicPmeta{%{FileName:t}%{c}{%{FileFormat:-?}%{c}{%{LLX:-?}%{c}{%{LLY:-?}%{c}{%{URX:-?}%{c}{%{URY:-?}%{c}%{n}';
my $t_tex='\graphicPmeta{%{FileName:t}%{c}{%{FileFormat:-?}%{SubFormat?+.%{SubFormat}}%{c}{%{LLX:-?}%{c}{%{LLY:-?}%{c}{%{URX:-?}%{c}{%{URY:-?}%{c}%{n}';

sub compile_template($) {
  my $template=$_[0];
  # convert $template to Perl code
  $template=~s@([\\'])@\\$1@g;
  $template=~s@([}])|[%][{]([\w.-]+)(:t)?(:-|[?][+0-]|)@
    defined($1) ? "').'" :
    $4 eq "" && $2 eq "all" ? "'.(all(\$bbi).'" :
    $4 eq "" ? "'.(!defined\$bbi->{'$2'}?'':aq('".($3||"")."',\$bbi->{'$2'}).'" :
    $4 eq "?+" ? "'.(!defined\$bbi->{'$2'}?'':'" :
    $4 eq "?-" ? "'.(defined\$bbi->{'$2'}?'':'" :
    $4 eq ":-" ? "'.(defined\$bbi->{'$2'}?aq('".($3||"")."',\$bbi->{'$2'}):'" :
    $4 eq "?0" ? "'.(delete0(\$bbi,'$2').'" :
    "[$1]($2)($4)" # should never happen
  @ge;
  my $sub=eval "sub { my \$bbi=\$_[0]; '$template' }";
  die "$0: template syntax error: $@" if $@ or ref($sub) ne 'CODE';
  $sub
}

sub work($$) {
  my($sub,$filename)=@_;
  my $bbi;
  # die "$0: $filename: $!\n" unless open F, "< $filename";
  if (open F, "< $filename") {
    ## print STDERR "$filename\n";
    $bbi=calc(\*F);
  } else {
    $bbi->{Error}="open: $!"
  }
  $bbi->{FileName}=$filename;
  $bbi->{n}="\n";
  $bbi->{p}="%";
  $bbi->{c}="}";
  print $sub->($bbi);
}

sub usage() {
  die "This is img_bbox.pl by pts\@fazekas.hu
This program is free software, licensed under the GNU GPL.
This software comes with absolutely NO WARRANTY. Use at your own risk!

Usage: $0 [<template>] <filename.image> [...]
Template is one of: --  --short  --long  --tex  --template <t>

I can detect file format, width, height, bounding box and other
meta-information from image files. Run this to get more docs:
	pod2man '$0' | man -l -\n"
# ^^^ pod2man is better than perldoc(1), because perldoc(1) is not installed
#     on some Debian systems.
}

just::main;

usage if !@ARGV;

my $template=$t_short;
if ($ARGV[0] eq '--' or $ARGV[0] eq '--short') { }
elsif ($ARGV[0] eq '--long') { $template=$t_long; shift @ARGV }
elsif ($ARGV[0] eq '--tex') { $template=$t_tex; shift @ARGV }
elsif ($ARGV[0] eq '--template') { usage if @ARGV<2; $template=$ARGV[1]; splice @ARGV, 0, 2 }
elsif ($ARGV[0]=~/\A--/) { usage }

my $sub=compile_template($template);
for my $filename (@ARGV) { work $sub, $filename }

__END__

=begin man

.ds pts-dev \*[.T]
.do if '\*[.T]'ascii'  .ds pts-dev tty
.do if '\*[.T]'ascii8' .ds pts-dev tty
.do if '\*[.T]'latin1' .ds pts-dev tty
.do if '\*[.T]'nippon' .ds pts-dev tty
.do if '\*[.T]'utf8'   .ds pts-dev tty
.do if '\*[.T]'cp1047' .ds pts-dev tty
.do if '\*[pts-dev]'tty' \{\
.ll 79
.pl 33333v
.nr IN 2n
.\}
.ad n

=end man

=head1 NAME

img_bbox.pl - detect file format and media parameters

=head1 SYNOPSIS

C<B<img_bbox.pl>>
 S<[ C<--> | C<--short>>
 S<| C<--long>>
 S<| C<--tex>>
 S<| C<--template> I<template> ]>
 S<I<filename.image>> S<[ ... ]>

=head1 DESCRIPTION

img_bbox.pl is a standalone Perl script that can detect file format,
width, height, bounding box and
other meta-information from image files. Supported vector formats are:
PDF, Flash SWF, EPS, PS, DVI and FIG. Supported raster image formats are:
GIF, JPEG, PNG, TIFF, XPM, XBM1, XBM, PNM, PBM, PGM, PPM, PCX, LBM, other
IFF, Windows and OS/2 BMP, MIFF, Gimp XCF, Windows ICO, Adobe PSD, FBM,
SunRaster, CMUWM, Utah RLE, Photo CD PCD, XWD, GEM, McIDAS, PM, SGI IRIS,
FITS, VICAR, PDS, FIT, Fax G3, Targa TGA and Faces.

img_bbox.pl writes the detected information to STDOUT, in a format
determined by the template specified on the command line. The default
template is C<--short>. Templates are:

=over 10

=item C<--short>

writes the file name, file format and the four
bounding box coordinates (lower left x, lower left y, upper right x, upper
right y), separated by spaces.

=item C<--long>

writes a multi-line entry for each file containing all key--value pairs
that img_bbox.pl was able to detect.

=item C<--tex>

writes output suitable for C<\input> in TeX. The file name, file format and
bounding box is dumped

=item C<--pat>

lets the user specify an individual pattern, see later.

=back

=head1 PATTERNS

Individual patterns can be specified after C<--pat>. Built-in patterns are:

 --short: %{FileName} %{FileFormat:-??} %{LLX:-??} %{LLY:-??} %{URX:-??} %{URY:-??}%{Paper?+ %{Paper}}%{Error?+ error:%{Error}}%{n}
 --long : %{FileName}%{FileName?0}%{n}%{all}
 --tex  : \graphicPmeta{%{FileName:t}%{c}{%{FileFormat:-?}%{c}{%{LLX:-?}%{c}{%{LLY:-?}%{c}{%{URX:-?}%{c}{%{URY:-?}%{c}%{n}

Expressions of the form
 C<%{> I<key> [ I<quoting> ] I<method> I<body> C<}>
 are substituted.

I<key>s of interest will be enumerated later in this subsection.

I<quoting> is one of

=over 7

=item (none)

The string is inserted as-is.

=item C<:t>

Quotes all TeX and LaTeX control characters.

=back

The interpretation of I<body> depends on I<method>. The default action is to
append the contents of I<body> verbatim after the substitution. I<body> is
an empty string most of the time.

I<method> is one of

=over 7

=item (none)

Expands to the value of I<key>, or an empty string. I<body> must be empty.

=item C<:->

Expands to the value of I<key>, or I<body>.

=item C<?0>

Deletes I<key>, and expands to I<body>.

=item C<?+>

Expands to I<body> if I<key> exists, or an empty string.

=item C<?->

Expands to I<body> if I<key> is missing, or an empty string.

=back

I<key>s of interest are:

=over 20

=item n

a newline

=item p

a percent sign

=item c

a close brace

=item all

A detailed, multi-line key--value listing of all information detected, as
output by the C<--long> template.

=item FileName

=item FileFormat

=item SubFormat

=item LLX

Zero for most file formats.

=item LLY

Zero for most file formats.

=item URX

The width for most file formats.

=item URY

The height for most file formats.

=item SamplesPerPixel

=item BitsPerSample

=item ColorSpace

Gray, RGB, YCbCr, CMYK, YCCK, Indexed etc.

=item Error

the first I/O or other error

=item Info.

various file format specific keys begin with C<Info.>

=item Val.

various key--value pairs read from the file, beginning with C<Val.>

=item Info.MediaBox

PDF only

=item Info.CropBox

PDF only

=item Info.BleedBox

PDF only

=item Info.TrimBox

PDF only

=item Info.ArtBox

PDF only

=item Info.Compression

TIFF only

=item Info.NewSubfileType

TIFF only

=item Info.PhotometricInterpretation

TIFF only

=item Info.Thresholding

TIFF only

=item Info.CellWidth

TIFF only

=item Info.CellLength

TIFF only

=item Info.FillOrder

TIFF only

=item Info.Orientation

TIFF only

=item Info.RowsPerStrip

TIFF only

=item Info.MinSampleValue

TIFF only

=item Info.MaxSampleValue

TIFF only

=item Info.PlanarConfiguration

TIFF only

=item Info.GrayResponseUnit

TIFF only

=item Info.ResolutionUnit

TIFF only

=item Info.ExtraSamples

TIFF only

=item Info.hvs

JPEG only

=item Info.id_rgb

JPEG only

=item Info.had_jfif

JPEG only

=item Info.ColorTransform

JPEG only

=item Info.binary

Clean7Bit, Clean8Bit or Binary. PDF and PS only

=item Info.linearized

PDF only

=item Info.denominator

DVI only

=item Info.nominator

DVI only

=item Info.version_id

DVI only


=item Info.maginification

DVI only


=item Info.jobname

DVI only

=item Info.page1_nr

DVI only

=item Info.special

DVI only

=item Info.colors

ICO only

=item Info.reserved

ICO only


=item Info.num_planes

ICO only


=item Info.credits

FBM only

=item Info.title

FBM only

=item Info.num_planes

FBM only

=item Info.bits

FBM only

=item Info.rowlen

FBM only

=item Info.plnlen

FBM only

=item Info.clrlen

FBM only

=item Info.hlen

GEM only

=item Info.colors

GEM only

=item Info.patlen

GEM only

=item Info.llen

GEM only

=item Info.lines

GEM only

=item Info.num_planes

PM only

=item Info.num_bands

PM only

=item Info.pixel_format

PM only

=item Info.compression

SGI only

=item Info.comment

SGI only

=item Info.bits_per_pixel

FITS only

=item Info.num_axis

FITS only

=item Info.depth

FITS only

=item Info.data_max

FITS only

=item Info.data_min

FITS only

=back

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

=head1 AUTHOR

PE<0xE9>ter SzabE<0xF3> <F<pts@fazekas.hu>>

=head1 SEE ALSO

file(1)
