#!/usr/bin/perl

use strict;
use warnings;

while (<>) {
    s/\b0x//gi;
    s/([\d\w]{2})\B/$1:/g;
    print;
}
