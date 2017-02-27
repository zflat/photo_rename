#!/usr/bin/perl
#
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

# NOTES:
# For further inspiration: http://www.brayebrookobservatory.org/BrayObsWebSite/HOMEPAGE/PHOTO_EXP_CALC_HIST.html
# Math symbols: http://sites.psu.edu/symbolcodes/accents/math/mathchart/
        
use constant VERSION => "0.1.0";
use 5.022;
use strict;
use Math::Complex;

sub strLabelNode {
    my ($val, $degrees, $radius, $radius_max, $style, $cY) = @_;
    my $str = '';
    my $tr_radius = $radius_max - $radius;
    $cY = $cY ? $cY : 0;
    $str = $str."<text x='0' y='20'\n";
    $str = $str."\ttext-anchor='middle' \n";
    $str = $str."\tdominant-baseline='central'\n";
    $str = $str."\tstyle='font-family: Times New Roman; font-size: 14px; fill: #000000; ".$style."'\n";
    $str = $str."\ttransform='translate(0 $cY) rotate(".$degrees." ".$radius_max." ".$radius_max.") translate(".$radius_max." ".$tr_radius.")'\n";
    $str = $str.">\n";
    $str = $str.$val."\n";
    $str = $str."</text>\n";

    return $str;
}

sub strRadialLine {
    my ($width, $height, $degrees, $radius, $radius_max, $fill, $cY) = @_;
    
    my $str = '';
    my $xCorner = $radius_max-int($width/2);
    $cY = $cY ? $cY : 0;

    my $tr_radius = $radius_max - $radius;
    return "<rect fill='".$fill."' width='".$width."' height='".$height."' x='".$xCorner."' y='".$tr_radius."' transform='translate(0 $cY) rotate(".$degrees." ".$radius_max." ".$radius_max.")'></rect>";
}

sub delta2ratio {
    my ($delta) = @_;
    my $ratio = 2**($delta);
    # rounded to nearest 1/2
    return int($ratio*2)/2;
}

sub strStop {
    my $av = sprintf("%.3f", @_);
    my %nominal = (
        "0.000" => "1.0",
        "0.333" => "1.1",
        "0.500" => "1.2",
        "0.667" => "1.2",
        "1.000" => "1.4",
        "1.333" => "1.6",
        "1.500" => "1.7",
        "1.667" => "1.8",
        "2.000" => "2",
        "2.333" => "2.2",
        "2.500" => "2.4",
        "2.667" => "2.5",
        "3.000" => "2.8",
        "3.333" => "3.2",
        "3.500" => "3.3",
        "3.667" => "3.5",
        "4.000" => "4",
        "4.333" => "4.5",
        "4.500" => "4.8",
        "4.667" => "5.0",
        "5.000" => "5.6",
        "5.333" => "6.3",
        "5.500" => "6.7",
        "5.667" => "7.1",
        "6.000" => "8",
        "6.333" => "9",
        "6.500" => "9.5",
        "6.667" => "10",
        "7.000" => "11",
        "7.333" => "13",
        "7.500" => "13",
        "7.667" => "14",
        "8.000" => "16",
        "8.333" => "18",
        "8.500" => "19",
        "8.667" => "20",
        "9.000" => "22",
        "9.333" => "25",
        "9.500" => "27",
        "9.667" => "29",
        "10.000" => "32",
        "10.333" => "36",
        "10.500" => "38",
        "10.667" => "40",
        "11.000" => "45",
        "11.333" => "51",
        "11.500" => "54",
        "11.667" => "57",
        );

    return %nominal{$av};
}

my $outName = "output.svg";
my $svgFile;

# circle radius and center
my $r = 200;
my $pX = $r;
my $pY = $r;


my $inc_denom = 3;
my $n_increments = (10*$inc_denom)+1;
my $deg_inc = 360.0/$n_increments;

my $n_wDeltas = 3;
my $n_wIncrements = 2*$n_wDeltas;
my $inc_wDeg = 360.0/$n_wIncrements;


open $svgFile, ">", $outName or die $!;
print $svgFile "<!DOCTYPE svg PUBLIC '-//W3C//DTD SVG 1.1//EN' 'http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd'>", "\n";
print $svgFile "<svg xmlns='http://www.w3.org/2000/svg' width='".(2*$r)."' height='".(4*$r)."'>", "\n";
print $svgFile "<rect fill='#FFFFFF' width='".(2*$r)."' height='".(4*$r)."'></rect>","\n";

##############
# Outer circle

print $svgFile "<circle stroke='#AAAAAA' 
        stroke-width='2' 
        fill='#FFFFFF' 
        cx='$pX'  
        cy='$pY' 
        r='".($r-3)."'>
</circle>","\n";

# print $svgFile strLabelNode("Lighting Ratios", 0, -20, $r);
# print $svgFile strLabelNode("Slide Chart", 0, -36, $r);

print $svgFile "<circle fill='#333333' cx='$pX'  cy='$pY' r='3'></circle>","\n";

# Drawing an arc:
# rx, ry, x-axis-rotation, large-arc-flag, sweep-flag, x, y
# Or just draw in incscape and copy here
my $pathArg = 0;

if($r == 250) {
    $pathArg = "M 237.45137,14.604132 C 212.25902,14.455823 209.04815,35.830797 187.49383,44.859271";    
}

if($r == 200) {
    $pathArg = "M 186.86501,17.002872 C 172.1705,16.899086 174.19659,34.924751 157.42138,40.948117";
}

if($pathArg) {
    print $svgFile "<path
     d='".$pathArg."'
     style='fill:none;fill-rule:evenodd;stroke:#AAAAAA;stroke-width:2px;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1' />", "\n";
}


for(my $wDelta=0; $wDelta < $n_wDeltas*2; $wDelta++) {
    my $degBase = $inc_wDeg*$wDelta;
    my $deg33 = $degBase+(1/3)*$inc_wDeg;
    my $deg50 = $degBase+(1/2)*$inc_wDeg;
    my $deg66 = $degBase+(2/3)*$inc_wDeg;

    my $val00 = strStop($wDelta);
    my $val33 = strStop($wDelta+(1/3));
    my $val50 = strStop($wDelta+(1/2));
    my $val66 = strStop($wDelta+(2/3));

    # print $svgFile strRadialLine(2, 30, $degBase, 200, $r, '#AAAAAA');
    # print $svgFile strRadialLine(2, 30, $deg33, 200, $r, '#AAAAAA');
    # print $svgFile strRadialLine(2, 30, $deg50, 200, $r, '#AAAAAA');
    # print $svgFile strRadialLine(2, 30, $deg66, 200, $r, '#AAAAAA');

    print $svgFile strLabelNode("ƒ/".$val00, $degBase, $r-20, $r), "\n";
    if($val33 != $val50) {
        print $svgFile strLabelNode($val33, $deg33, $r-20, $r), "\n";
    }
    print $svgFile strLabelNode($val50, $deg50, $r-20, $r), "\n";
    if($val66 != $val50) {
        print $svgFile strLabelNode($val66, $deg66, $r-20, $r), "\n";
    }

    my $val00D = strStop($wDelta+2*$n_wDeltas);
    if($val00D < 33) {
        print $svgFile strLabelNode("ƒ/".$val00D, $degBase, $r, $r), "\n";
    }

    if($val00D < 32) {
        my $val33D = strStop($wDelta+(1/3)+2*$n_wDeltas);
        my $val50D = strStop($wDelta+(1/2)+2*$n_wDeltas);
        my $val66D = strStop($wDelta+(2/3)+2*$n_wDeltas);
        
        if($val33D != $val50D) {
            print $svgFile strLabelNode($val33D, $deg33, $r, $r), "\n";
        }
        print $svgFile strLabelNode($val50D, $deg50, $r, $r), "\n";
        if($val66D != $val50D) {
            print $svgFile strLabelNode($val66D, $deg66, $r, $r), "\n";
        }
    }
}


##############
# Inner circle

$pY = 3*$r;
my $r_inner = $r-50;

print $svgFile "<circle stroke='#AAAAAA' 
        stroke-width='2' 
        fill='#FFFFFF' 
        cx='$pX'  
        cy='$pY' 
        r='".($r_inner)."'>
</circle>","\n";
print $svgFile "<circle fill='#333333' cx='$pX'  cy='$pY' r='3'></circle>","\n";


print $svgFile "<path d='M 0 20 L 18 20 L 9 0 z' 
      fill='#333333' 
      transform='translate(".($r-9)." ".(2*$r+54).")' 
      />", "\n";


my $title_offset = -10;
print $svgFile strLabelNode("Lighting Ratios", 0, $title_offset, $r, '', 2*$r);
print $svgFile strLabelNode("Slide Chart", 0, $title_offset-18, $r, '', 2*$r);

for (my $wDelta=0; $wDelta <= $n_wDeltas; $wDelta++) {
    my $degBase = $inc_wDeg*$wDelta;
    my $deg33 = $degBase+(1/3)*$inc_wDeg;
    my $deg50 = $degBase+(1/2)*$inc_wDeg;
    my $deg66 = $degBase+(2/3)*$inc_wDeg;

    for(my $mirror=1; $mirror>=0; $mirror--) {
        my $degSign = ($mirror%2) ? 1 : -1;

        if($wDelta == 0) {
            print $svgFile strRadialLine(3, 25, $degSign*$degBase, $r_inner-10, $r, '#333333', 2*$r), "\n";
        } else {
            print $svgFile strLabelNode("Δ".$wDelta, $degSign*$degBase, $r_inner-7, $r, 'font-weight:900;', 2*$r), "\n"; 
            print $svgFile strRadialLine(2, 15, $degSign*$degBase, $r_inner-2, $r, '#333333', 2*$r);
            print $svgFile strRadialLine(2, 15, $degSign*$degBase, $r_inner-35, $r, '#333333', 2*$r);
        }


        my $ratio = 2**$wDelta;
        if(!($wDelta == 0 && $degSign<0)) {
            my $ratioVal = ($degSign>0) 
                ? $ratio.":1"
                : "1:".$ratio; 
            print $svgFile strLabelNode($ratioVal, $degSign*$degBase, $r_inner-40, $r,'font-weight:700;', 2*$r), "\n";
        }

        if($wDelta == $n_wDeltas) {last;}

        my $lblPrefix = ($wDelta ? $wDelta : "");
        print $svgFile strRadialLine(2, 15, $degSign*$deg33, $r_inner-10, $r, '#333333', 2*$r);
        print $svgFile strRadialLine(2, 25, $degSign*$deg50, $r_inner-10, $r, '#333333', 2*$r);
        print $svgFile strRadialLine(2, 15, $degSign*$deg66, $r_inner-10, $r, '#333333', 2*$r);
        # print $svgFile strLabelNode("Δ".$lblPrefix."⅓", $degSign*$deg33, '190', '250', ''), "\n"; 
        # print $svgFile strLabelNode("Δ".$lblPrefix."½", $degSign*$deg50, '200', '250', ''), "\n"; 
        # print $svgFile strLabelNode("Δ".$lblPrefix."⅔", $degSign*$deg66, '190', '250', ''), "\n"; 

        my $incRatio33 = delta2ratio($wDelta+1/3);
        if(($incRatio33 - $ratio) > 0) {
            my $ratioVal = ($degSign>0) 
                ? $incRatio33.":1"
                : "1:".$incRatio33; 
            print $svgFile strLabelNode($ratioVal, $degSign*$deg33, $r_inner-15, $r,'font-weight:500;', 2*$r), "\n";
        }
        my $incRatio50 = delta2ratio($wDelta+1/2);
        if(($incRatio50 - $ratio) > 0
           && ($incRatio50 - $incRatio33) > 0.5) {
            my $ratioVal = ($degSign>0) 
                ? $incRatio50.":1"
                : "1:".$incRatio50; 
            print $svgFile strLabelNode($ratioVal.":1", $degSign*$deg50, $r_inner-40, $r,'font-weight:500;', 2*$r), "\n";
        }
        my $incRatio66 = delta2ratio($wDelta+2/3);
        if(($incRatio66 - $ratio ) > 0
           && ($incRatio66 - $incRatio33) > 0
           && ($incRatio66 - $incRatio50) > 0) {
            my $ratioVal = ($degSign>0) 
                ? $incRatio66.":1"
                : "1:".$incRatio66; 
            print $svgFile strLabelNode($ratioVal, $degSign*$deg66, $r_inner-15, $r,'font-weight:500;', 2*$r), "\n";
        }

    }
}

print $svgFile "</svg>", "\n";
