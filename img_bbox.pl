#! /bin/sh
eval '(exit $?0)' && eval 'PERL_BADLANG=x;PATH="$PATH:.";export PERL_BADLANG\
;exec perl -x -S -- "$0" ${1+"$@"};#'if 0;eval 'setenv PERL_BADLANG x\
;setenv PATH "$PATH":.;exec perl -x -S -- "$0" $argv:q;#'.q
#!perl -w
+push@INC,'.';$0=~/(.*)/s;do(index($1,"/")<0?"./$1":$1);die$@if$@__END__+if 0
;#Don't touch/remove lines 1--7: https://pts.github.io/Magic.Perl.Header

#
# img_bbox.pl -- extract file format and bbox (dimension) information from
#   image files
# by pts@fazekas.hu at Sat Dec  7 21:31:01 CET 2002
#
# Dat: we know most of xloadimage-1.16, most of of file(1)-debian-potato,
#   all of sam2p-0.40, all of xv-3.10
# Dat: only in xloadimage: g3Ident,        g3Load,        "G3 FAX Image", (hard to identify file format)
# Dat: only in xloadimage: macIdent,       macLoad,       "MacPaint Image", (stupid, black-white)
#
use integer; # important
use strict; # not so important
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

# --- PDF helpers

#** @param $_[0] an arbirary binary string
#** @param $_[1] string containing [^\w.-] chars as octal
#sub pdf_safe_string($) {
#  my $S=$_[0];
#  $S=~s@([^A-Za-z0-9_.-])@sprintf"\\%03o",ord$1@ge;
#  $S
#}

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
      return undef if vec($S,++$I,8)!=62; # err(">> expected");
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
#die unless !defined pdf_rewrite('>');
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

#die pdf_rewrite('
#alma
#0000012341 00000 n
#0000026989 00000 n
#trailer
#<<
#/Size 38131
#/Info 37444 0 R
#/Root 37550 0 R
#/Prev 7020615
#/ID[<16576b7a7b963d75f7a70b3c3d78455c><16576b7a7b963d75f7a70b3c3d78455c>]
#>>
#startxref',0);

#** Reads a single PDF indirect object (without its stream) from a PDF file.
#** Does some trivial transformations on it to make later regexp matching
#** easier. Stops at `stream', `endobj' and `startxref'.
#** @param $_[0] a filehandle (e.g \*STDIN), correctly positioned in the PDF
#**   file to the beginning of the object data (i.e just before `5 0 obj')
#** @return string containing PDF source code, or undef on error
sub pdf_read_obj($) {
  my $F=$_[0];  my $L=1;  my $M;  my $S="";  my $RET; # !!
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

#** @param $_[0] a filehandle (e.g \*STDIN), containing a PDF file
#** @param $_[1] an xref table: $_[1][4][56] is the file offset of object 56
#**   from generation 4
#** @param $_[2] a PDF source string (rewritten by pdf_rewrite()), possibly
#**   containing indirect object references (e.g `56 4 R')
#** @return a rewritten PDF source string, with references resolved, or undef
sub pdf_resolve($$$) {
  my $F=$_[0];
  my $XREF=$_[1];
  my $S=$_[2];
  my $T;
  my $P;
  # Imp: disallow `stream' in most cases
  # 1 while # one iteration only
  $S=~s` (\d+) (\d+) R\b`
    return undef unless ref $XREF->[$2+0] and defined ($P=$XREF->[$2+0][$1+0]);
    return undef unless seek $F, $P, 0;
    return undef unless defined($T=pdf_read_obj($F));
    return undef unless $T=~s@\A (\d+) (\d+) obj\b(.*) (endobj|stream)\Z(?!\n)@$3@s;
#    die $T;
#    return undef unless $T=~s@\A (\d+) (\d+) obj\b(.*) (endobj|stream)@$3@s;
#    die $T;
    $T
  `ge;
  # die defined $S;
  $S
}

#** @param $_[0] a filehandle (e.g \*STDIN), containing a PDF file, positioned
#**  just before an `xref' table
#** @param $_[1] an xref table: $_[1][4][56] is the file offset of object 56
#**   from generation 4; will be extended
#** @return the `trailer' section after the `xref'; or undef
sub pdf_read_xref($$) {
  my $T;
  my $F=$_[0];
  my $XREF=$_[1];
  return undef unless defined($T=pdf_read_obj($F));
  return undef unless $T=~s@\A xref (\d+) (\d+)@@;
  my($first,$len)=($1+0,$2+0);
  return undef unless $T=~s@ trailer( .*) startxref\Z(?!\n)@@s;
  my $RET=$1;
  my $lasT=0;
  while ($T=~/\G (\d+) (\d+) ([nf])/gm) {
    ## print "Z $first\n";
    $XREF->[$2+0][$first]=$1+0 if $3 eq 'n';
    $lasT=pos($T); $first++;
  }
  # Imp: check len
  return undef unless $lasT==length($T); # read full xref table
  $RET
}

# die pdf_read_obj \*STDIN;

# ---

#** May moves the file offset, but only relatively (SEEK_CUR).
#** @param $_[0] \*FILE
#** @return BBoxInfo
sub img_bbox($) {
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
  } elsif ($head=~m@\AP([1-6])[\s#]@) { # PNM
    $bbi->{FileFormat}='PNM';
    my @subformats=qw{- PBM.text PGM.text PPM.text PBM.raw PGM.raw PPM.raw};
    $bbi->{SubFormat}=$subformats[0+$1];
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
      } elsif (0xC1<=$tag and $tag<=0xCF and $tag!=0xC4 and $tag!=0xC8) { # SOFn
        $bbi->{Subformat}="SOF".($tag-0xC0);
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
    ($dummy,$bbi->{URX},$bbi->{URY})=unpack("A16NN",$head);
  } elsif (substr($head,0,5) eq "%PDF-") {
    $bbi->{FileFormat}='PDF'; # Adobe Portable Document Format
    # Dat: this routine cannot read encrypted PDF files
    $bbi->{SubFormat}=$1 if $head=~/\A%PDF-([\d.]+)/;
    $bbi->{'Info.binary'}=($head=~/\A[^\r\n]+[\r\n]+[ -~]*[^\n\r -~]/) ? 'Binary' : 'Clean7Bit';
    # if ($head=~m@\A(?:%[^\r\n]*[\r\n])*.{0,40}/Linearized@s and $head=~m@\A(?:%[^\r\n]*[\r\n])*.{0,200}/O\s+(\d+)@s) {
    $head=pdf_rewrite($head,1);
    my $page1obj;
    if (defined $head and $head=~m@ /Linearized @ and $head=~m@ /O (\d+)@) {
      $bbi->{'Info.linearized'}=1;
      # $page1obj=$bbi->{'Info.page1obj'}=$1+0; ## !! uncomment this
    } else { $bbi->{'Info.linearized'}=0 }
    # 1. We seek to EOF and find the beginning of the xref table
    goto IOerr if !seek $F, -1024, 2;
    goto IOerr if 1>read $F, $head, 1024;
    goto SYerr if $head!~/startxref\s+(\d+)\s+%%EOF\s+\Z(?!\n)/;
    my $xref_ofs=$1+0;
    goto IOerr if !seek $F, $xref_ofs, 0;
    # die pdf_read_obj($F);
    my $xref=[];
    my $trailer=pdf_read_xref($F,$xref);
    goto SYerr if !defined $trailer;
    my $rootR;
    if (!defined $page1obj) { # ...
      goto SYerr if $trailer!~m@ /Root( \d+ \d+ R) @;
      $rootR=$1;
      
      # Read the whole, large xref table
      while ($trailer=~m@ /Prev (\d+) @) {
        ## print "prev=$1\n";
        goto IOerr if !seek $F, $1, 0;
        goto SYerr if !defined($trailer=pdf_read_xref($F,$xref));
      }

      my $root=pdf_resolve($F, $xref, $rootR);
      die $root;
      # Imp: /Pages
      # Imp: /Kids list etc.
      # Imp: pdf_resolve_val
      ## die $xref->[0][37550];
      ## die $trailer; # /Root
      
    }
    my $page1=pdf_resolve($F, $xref, " $page1obj 0 R");
    goto IOerr if!defined $page1;
    # my $MediaBox=pdf_resolve_val($F, $xref, $page1, ' /MediaBox ');
    # die $MediaBox;
    # Imp: indirect object MediaBox
    # Imp: CropBox
    if ($page1=~m@ /MediaBox \[ ([0-9eE.-]+) ([0-9eE.-]+) ([0-9eE.-]+) ([0-9eE.-]+) \]@) {
      no integer;
      ($bbi->{LLX},$bbi->{LLY},$bbi->{URX},$bbi->{URY})=($1+0,$2+0,$3+0,$4+0);
    }    
    # die $page1;
    # print Dumper $xref;
    # Imp: ...
  } elsif (substr($head,0,5) eq "%!PS-") {
    # Dat: the user should not trust Val.languagelevel blindly. There are far
    #      too many PS files hanging around that do not conform to any standard.
    $bbi->{FileFormat}=($head=~/\A[^\n\r]*?\bEPSF-/) ? "EPS" : "PS";
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
              $bbi->{URX}=dimen2bp($L[0]);
              $bbi->{URY}=dimen2bp($L[1]);
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
  delete $bbi->{'LLX'} if !exists $bbi->{'URX'};
  delete $bbi->{'LLY'} if !exists $bbi->{'URY'};
  $bbi
}

# ---

# my $filename="examples/xman.xpm";
# my $filename="/home/guests/pts/prg/pshack/jpeg2pdf/sam2p-0.39/examples/pts2.pbm";
# my $filename="/home/guests/pts/prg/pshack/jpeg2pdf/sam2p-0.39/examples/sziget_al.ppm";
# my $filename="/home/guests/pts/prg/pshack/jpeg2pdf/sam2p-0.39/examples/ptsbanner.gif";
# my $filename="/home/guests/pts/prg/pshack/jpeg2pdf/sam2p-0.39/examples/ptsbanner2.jpg";
# my $filename="examples/firstrun.swf";
# my $filename="examples/at-logo.lbm";
# my $filename="examples/t.miff";
# my $filename="examples/t.tga";
# my $filename="/home/guests/pts/prg/pshack/jpeg2pdf/sam2p-0.39/examples/fusi.png";
# my $filename="/home/guests/pts/prg/pshack/jpeg2pdf/sam2p-0.39/examples/mixing1.pcx";
# my $filename="examples/t.xbm1";
# my $filename="examples/uparrow.xbm";
# my $filename="examples/uparrow.xbm";
# my $filename="examples/ptsbanner.bmp";
# my $filename="/home/guests/pts/prg/pshack/jpeg2pdf/sam2p-0.40/examples/fisht.tiff";
# my $filename="/home/guests/pts/prg/pshack/jpeg2pdf/sam2p-0.40/examples/fusi.tiff";
# my $filename="examples/chopok.dvi";
# my $filename="examples/chopok.dvi";
# my $filename="examples/a.jpg";
# my $filename="examples/ptsbanner2a.jpg";
# my $filename="examples/ptsbannerg.jpg";
# my $filename="examples/13x7.xcf";
# my $filename="examples/Far.ico";
# my $filename="examples/boomlink.psd";
# my $filename="examples/ptsbanner.xwd";
# my $filename="examples/t.g3";
# my $filename="examples/t.gz";
# my $filename="examples/t.fits";
# my $filename="examples/t.zip";
# my $filename="examples/t.sgi";
# my $filename="examples/test.ps";
# my $filename="examples/test_atend.eps";
# my $filename="examples/test.pdf";
# my $filename="/tmp/PLRM.pdf";
# my $filename="/tmp/PDFRef.pdf";
# my $filename="/tmp/fsproto.pdf";
# my $filename="examples/a-gth-1.pdf";
# my $filename="examples/hello.pdf";
# my $filename="/home/guests/pts/eg/bssz/szamelmszig_tetelsorA_kidolgozott.php.pdf";
# my $filename="/home/guests/pts/eg/ele/elovizsga2001.pdf";
# my $filename="/home/guests/pts/eg/th/lm2.pdf";
# my $filename="/tmp/PLRM.pdf";

sub work(@) {
  my $filename=$_[0];
  die "$0: $filename: $!\n" unless open F, "< $filename";
  print STDERR "$filename\n";
  my $bbi=img_bbox(\*F);
  # print "$filename: ", Dumper($bbi);
  my $LLX=defined $bbi->{LLX} ? $bbi->{LLX} : "??";
  my $LLY=defined $bbi->{LLY} ? $bbi->{LLY} : "??";
  my $URX=defined $bbi->{URX} ? $bbi->{URX} : "??";
  my $URY=defined $bbi->{URY} ? $bbi->{URY} : "??";
  my $Error=defined $bbi->{Error} ? " error:$bbi->{Error}" : "";
  print "$filename $LLX $LLY $URX $URY$Error\n";
}

if (@ARGV) { for my $filename (@ARGV) { work $filename } }
      else { work $filename }
__END__
