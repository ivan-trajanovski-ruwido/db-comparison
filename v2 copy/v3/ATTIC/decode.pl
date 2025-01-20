#!/usr/bin/perl

use warnings;
use strict;
use utf8;
use Data::Dumper;

use RcSignalDecode;

use constant USE_SYMBOL_COUNT => 0;	# 0 ... use time
#use constant IR_DEVIATION => 0.18;
use constant IR_DEVIATION => 0.10;
#use constant IR_DEVIATION => 0.07;

my $decode = new RcSignalDecode();
$decode->decode_signal($ARGV[0]);
$decode->output();

