#!/usr/bin/perl

use strict;
#use warnings;

use Getopt::Std;
use Data::Dumper;

sub usage() {
    print "Usage:   zonecfggen.pl -f <filename>\n\tfilename is a full path to file, contains zone aliases, separated by spaces\n";
}


sub main() {

    my $in_alias;
    my $fh;
    my %opts;
    
    getopts("f:",\%opts);
    
    usage() unless $in_alias = $opts{'f'};

    open($fh, "< $in_alias");

    while ( <$fh> ) {
        my @aliases = split /\s/;
        my $s_alias = shift @aliases;
        
        my @z_elem = ();
        
        foreach ( @aliases )  {
            push @z_elem, split /_|-/;
        }
        my %seen = ();
        my @uniq = grep { ! $seen{$_}++ } @z_elem;    
        my $dst_zname = join('_', @uniq);
        my $dst_aliases = join(';',@aliases); 
        
        print "zonecreate $s_alias"."___"."$dst_zname".",\""."$s_alias;$dst_aliases"."\"\n";
    }
}

main();
