#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Std;
use Data::Dumper;

sub usage {
    print "Usage:   zonecfggen.pl -i <WWPNs list> -z <cfgshow>\n\tfilename is a full path to file, contains zone aliases, separated by spaces\n";
}

sub getcfgname {
    my $cfgshow_out = shift;
    my $fh;
    my @def_cfgs = ();
    my $eff_flag = 0;
    my $eff_cfg;
    my $result_cfg;
    my $cfg_name;

    open($fh, "< $cfgshow_out") or die $!;
    while ( <$fh> ) {
        if (/Effective configuration:/) {
            $eff_flag = 1;
            next;
        }
        if (/cfg:\s+?([\w\d_]+)\s/i) {
            $cfg_name=$1;
            if (defined $cfg_name) {
                if ( $eff_flag ) {
                    $eff_cfg = $cfg_name;
                    last;
                } 
                else {
                    push @def_cfgs, $cfg_name;
                }
            }
        }
    } 
    close $fh;

    unless ( defined $eff_cfg) {
        print "No effective config\n";
        exit 1;
    }
    
    if ( scalar @def_cfgs == 0 ) {
        print "No Defined config\n";
        exit 1;
    }

    if ( scalar @def_cfgs > 1 ) {
        print "There are more than one Defined configuration, please choose required name: ", join (' ',@def_cfgs),"\n";
        $result_cfg = <STDIN>;
    } 
    else {
        $result_cfg = $def_cfgs[0];
    }

    if ( $eff_cfg ne $def_cfgs[0] ) {
        print "Warning! Effective configuration name is differ than Defined configuration\n";
    }

    chomp ($result_cfg);
    return $result_cfg;
}

sub main() {

    my $in_alias;
    my $fh;
    my %opts;

    getopts("i:z:",\%opts);
    
    usage() unless $in_alias = $opts{'i'};

#    my $cfg_name = getcfgname($opts{'z'});
    my $cfg_name = "default";

    open($fh, "< $in_alias") or die $!;

    while ( <$fh> ) {
        chomp;
        s/[\s\t]+/ /;
        my @aliases = split /\s/;
        my $s_alias = shift @aliases;
        
        foreach ( @aliases )  {
            my $z_name = "$s_alias"."___"."$_";
            print "zonecreate $z_name".",\""."$s_alias;$_"."\"\n";
            print "cfgadd $cfg_name, $z_name\n";
        }
    }
    print "cfgsave\n";
    print "cfgenable $cfg_name\n";
    close $fh;
}

main();
