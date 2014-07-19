#!/usr/bin/perl -w
#
# Nagios module to check Fiber Channel paths (Multipathing) status for Solaris v0.1
# Made by Pierre Mavro
# Last Modified : 17/04/2009
#
# This Nagios module is under GPLv2 License
#
########################################################################
#
# Installation (nagios client side) :
# - Copy the script in your nagios plugins directory (usualy /opt/csw/libexec/nagios-plugins)
# - Set good rights (755 for root:bin)
#
# Usage : check_multipath -d<device> -t<total_path> -w<warning_path_number> -c<critical_path_number>
#           -d device path (ex. /dev/rdsk/c4t600A0B8000492C630000038849DB2A3Ad0s2)
#           -t total paths (number of active path in non degraded state)
#           -w warning from path number lost (ex. warn if lost 1 path)
#           -c critical from path number remaining (ex. critical if stay only 1 active path)
#
# Example : check_multipath -d /dev/rdsk/c4t600A0B8000492C630000038849DB2A3Ad0s2 -t 4 -w 1 -c 2
#
########################################################################
#
# History :
#
# v0.1 :
# + First version
#
########################################################################


use strict;
use Getopt::Std;

# Args decalration
my %opts;
getopt('d:m:t:w:c:', \%opts);
my $device;
my $mmode;
my $total_paths;
my $warning=0;
my $critical=0;
my $path_ok=0;
my $path_fail=0;
my @errors;

# Help
sub help {
    print "Usage : check_multipath -d <device> -t <total_path> -w <warning_path_number> -c <critical_path_number>\n";
    print "\t-d device path (ex. /dev/rdsk/c4t600A0B8000492C630000038849DB2A3Ad0s2)\n";
    print "\t-t total paths (number of active path in non degraded state)\n";
    print "\t-w warning from path number lost (ex. warn if lost 1 path)\n";
    print "\t-c critical from path number remaining (ex. critical if stay only 1 active path)\n\n";
    print "Example : check_multipath -d /dev/rdsk/c4t600A0B8000492C630000038849DB2A3Ad0s2 -m AP -t 4 -w 1 -c 1\n";
    exit(1);
}

# Check defined arguments
sub check_args {
    if (defined($opts{d})) {
        if ($opts{d} =~ /\/\w+\/.+/) {
            $device=$opts{d};
        } else {
            print "-d error : Device should looks like : /dev/rdsk/c4t600A0B8000492C630000038849DB2A3Ad0s2\n";
            &help;
        }
    } else {
        &help;
    }
    if (defined($opts{t})) {
        if ($opts{t} =~ /\d+/) {
            $total_paths=$opts{t};
        } else {
            print "-t error : Please set a number value as total paths\n";
            &help;
        }
    } else {
        &help;
    }
    if (defined($opts{w})) {
        if ($opts{w} =~ /\d+/) {
            $warning=$opts{w};
        } else {
            print "-w error : Please set a number value as warning path lost\n";
            &help;
        }
    } else {
        &help;
    }
    if (defined($opts{c})) {
        if ($opts{c} =~ /\d+/) {
            $critical=$opts{c};
        } else {
            print "-c error : Please set a number value as critical path lost\n";
            &help;
        }
    } else {
        &help;
    }
}

# Get and stock result command
sub get_stock_result {
    my $number_of_path=0;
    my $port_group_number=0;
    my $access_state_status;
    open (MPATHSHOW, "mpathadm show lu $opts{d} |");
    while (<MPATHSHOW>) {
        chomp $_;
        # Get Path State
        if (/Path State:\s*(\w+)/i) {
            $number_of_path++;
            if ($1 =~ /OK/i) {
                $path_ok++;
            } else {
                $path_fail++;
            }
        # Get ID Group Number
        } elsif (/\s+ID:\s*(\d+)/) {
            $port_group_number=$1;
        # Get Access State
        } elsif (/Access State:\s*(\w+)/i) {
            $access_state_status=$1;
            if ($1 eq 'unavailable') {
                unshift @errors, "Lost port no. $port_group_number ";
            } elsif ($1 =~ /!(active|standby)/i) {
                unshift @errors, "Unknow state port no. $port_group_number (state: $access_state_status) ";
            }
        }
    }
    close (MPATHSHOW);
}

# Check possible error between request and active paths
sub check_nagerror {
    if ($path_ok != $opts{t}) {
        return 3;
    }
    return 0;
}

&check_args;
&get_stock_result;
unshift @errors, "[$path_ok/$opts{t} active paths]: ";

# Critical
if ($path_ok<=$opts{c}) {
    print "@errors\n";
    exit(2);
# Warning
} elsif ($path_fail>=$opts{w}) {
    print "@errors\n";
    exit(1);
# OK
} else {
    print "$path_ok/$opts{t} paths are active";
    if (&check_nagerror == 0) {
        print "\n";
        exit(0);
    } else {
        print " : you may have a Nagios configuration mismatch\n";
        exit(3);
    }
}

