#!/usr/bin/perl

use warnings;
use strict;
use utf8;
use CGI;
use DBI;
use Data::Dumper;

use DataBase;
use RcSignalDecode;
use RuwidoSignalList;

my $db = new DataBase();
my $dbh = $db->connect();

my $signalList = new RuwidoSignalList($db, $dbh);

use constant USE_SYMBOL_COUNT => 0;	# 0 ... use time
#use constant IR_DEVIATION => 0.18;
use constant IR_DEVIATION => 0.10;
#use constant IR_DEVIATION => 0.07;

my $q = CGI->new;
my %param = $q->Vars;

sub match_signals 
{
	my ($sig1, $sig2) = @_;

	my @arr1 = @$sig1;
	my @arr2 = @$sig2;

	my $len_orig = (scalar @arr2) - 1;
	my $len_cmd = (scalar @arr1) - 1;

#print "LEN " . $len_orig . " "  . $len_cmd . "\n";
	return 0 if (abs($len_orig - $len_cmd) > 2);

	my $deviation = IR_DEVIATION;
	$deviation = $param{deviation} if (defined $param{deviation});

	for (my $i=0; $i<$len_orig; $i++) {
#	for (my $i=2; $i<$len_orig; $i++) {
#print " == " . ($sig1->[$i]) . " > " . ($sig2->[$i]*(1.0 - IR_DEVIATION)) . " && " . $sig1->[$i] . " < " . ($sig2->[$i]*(1.0 + IR_DEVIATION)) . "\n";
		return 0 if ($sig1->[$i] < $sig2->[$i]*(1.0 - $deviation) || $sig1->[$i] > $sig2->[$i]*(1.0 + $deviation));
	}

	return 1;
}

my @arr;
sub check_signals
{
	my ($signal, $decode) = @_;

	if (exists $decode->{result}->{key1_frame_main}) {
		@arr = map { int($_*1000000/$decode->{result}->{freq}) } split /,/, $decode->{result}->{key1_frame_main};
		return 1 if (match_signals(\@arr, $signal));
	}
	if (exists $decode->{result}->{key1}) {
		@arr = map { int($_*1000000/$decode->{result}->{freq}) } split /,/, $decode->{result}->{key1};
		return 1 if (match_signals(\@arr, $signal));
	}
	if (exists $decode->{result}->{key1_frame_start}) {
		@arr = map { int($_*1000000/$decode->{result}->{freq}) } split /,/, $decode->{result}->{key1_frame_start};
		return 1 if (match_signals(\@arr, $signal));
	}
	if (exists $decode->{result}->{key1_frame_main2}) {
		@arr = map { int($_*1000000/$decode->{result}->{freq}) } split /,/, $decode->{result}->{key1_frame_main2};
		return 1 if (match_signals(\@arr, $signal));
	}
	if (exists $decode->{result}->{key2_frame_main}) {
		@arr = map { int($_*1000000/$decode->{result}->{freq}) } split /,/, $decode->{result}->{key2_frame_main};
		return 1 if (match_signals(\@arr, $signal));
	}

	return 0;
}

sub check_cycles
{
	my ($signal, $decode) = @_;

	if (exists $decode->{result}->{key1_frame_main}) {
		@arr = split /,/, $decode->{result}->{key1_frame_main};
		return 1 if (match_signals(\@arr, $signal));
	}
	if (exists $decode->{result}->{key1}) {
		@arr = split /,/, $decode->{result}->{key1};
		return 1 if (match_signals(\@arr, $signal));
	}
	if (exists $decode->{result}->{key1_frame_start}) {
		@arr = split /,/, $decode->{result}->{key1_frame_start};
		return 1 if (match_signals(\@arr, $signal));
	}
	if (exists $decode->{result}->{key1_frame_main2}) {
		@arr = split /,/, $decode->{result}->{key1_frame_main2};
		return 1 if (match_signals(\@arr, $signal));
	}
	if (exists $decode->{result}->{key2_frame_main}) {
		@arr = split /,/, $decode->{result}->{key2_frame_main};
		return 1 if (match_signals(\@arr, $signal));
	}

	return 0;
}

sub select_code
{
	my ($q, $param) = @_;

	my $sth;
	my $sql;
	my @bind_values = ();

	my $total = 0;
	my $num = 0;
	my $virtual_remote = [];

	my $decode = new RcSignalDecode();
	my $func_ids = $signalList->db_get_func($param);
	$func_ids = "0" if ($func_ids eq "");

#FIXME: get only the remotes where signal_X is defined...

	my $sth = $signalList->db_get_signal($q, $param);

	my %skip_oem;
	my %items = ();

	while(my $row = $sth->fetchrow_hashref()) {
		next if ($skip_oem{$row->{oem_id}});
		goto next_round if ($row->{content} eq "");

		$decode->decode_signal($row->{content});

		if (exists $param->{"signal_".$row->{id}}) {
			my @signal = split /,/, $param->{"signal_".$row->{id}};
			goto next_round if (!check_signals(\@signal, $decode));
		}
		elsif (exists $param->{"signal_".$row->{name}}) {
			my @signal = split /,/, $param->{"signal_".$row->{name}};
			goto next_round if (!check_signals(\@signal, $decode));
		}
		elsif (exists $param->{"signal"}) {	# compare with any
			my @signal = split /,/, $param->{"signal"};
			goto next_round if (!check_signals(\@signal, $decode));
		}
		elsif (exists $param->{"cycle_".$row->{id}}) {
			my @signal = split /,/, $param->{"cycle_".$row->{id}};
			goto next_round if (!check_cycles(\@signal, $decode));
		}
		elsif (exists $param->{"cycle_".$row->{name}}) {
			my @signal = split /,/, $param->{"cycle_".$row->{name}};
			goto next_round if (!check_cycles(\@signal, $decode));
		}
		elsif (exists $param->{"cycle"}) {	# compare with any
			my @signal = split /,/, $param->{"cycle"};
			goto next_round if (!check_cycles(\@signal, $decode));
		} else {
#			@arr = map { int($_*1000000/$decode->{result}->{freq}) } split /,/, $decode->{result}->{key1_frame_main};
		}

#		$row->{content} = join (",", @arr);

### from $signalList->get_signal
		# add debug data
		if ($param->{debug} & 0x04) {
			$decode->decode_signal($row->{content});

			foreach my $key (sort keys $decode->{result}) {
				$row->{$key} = $decode->{result}->{$key};
			}
		}
		my $oem_id = $row->{oem_id};
		$items{$oem_id}{num} = $row->{oem_num};
		$items{$oem_id}{weight} = $row->{weight};

#		delete $row->{oem_id};
		delete $row->{oem_num};
                delete $row->{weight};

		$items{$oem_id}{$row->{id}} = $row;	# add function
		next;

next_round:
		$skip_oem{$row->{oem_id}} = 1;;
		delete $items{$row->{oem_id}};	# if (defined $row->{oem_id});
	}
	$sth->finish();

	%items = %{$signalList->do_compress(\%items, $param)} unless (defined $param->{compress} && $param->{compress} == 0);

	##### filter only items containing the required functions
	foreach my $key (split (',',$param->{fkt_required})) {
		foreach my $oem_id (keys %items) {
			my $found = 0;
			foreach my $fkt_id (keys $items{$oem_id}) {
				next unless ($signalList->isint($fkt_id));
				if ($items{$oem_id}{$fkt_id}{name} eq $key) {
					$found = 1;
					last;
				}
			}

			if ($found == 1) {
				$total++;
				$num += $items{$oem_id}{num};
			} else {
				delete $items{$oem_id};
			}
		}
	}

	$signalList->db_create_output($param, \%items);
	$db->print($q, $total, {remotes => {total => $total, num => $num, remote => $signalList->{remote}}}, {-vary => "Accept"});
}

$param{model_id} = '' if (defined $param{model_id} && $param{model_id} eq "true");		# HACK for jquery
$param{model_name} = '' if (defined $param{model_name} && $param{model_name} eq "true");	# HACK for jquery
$param{debug} = 0 if (!$db->checkAccessDebug(\%param));

delete $param{brand_id} if ($param{brand_id} eq '');
delete $param{brand_name} if ($param{brand_name} eq '');

$param{fkt_required} = $signalList->_func_expand($param{fkt_required}) if (defined $param{fkt_required});

my @arr_fkt_required;
@arr_fkt_required = split /,/, $param{fkt_required} if (defined $param{fkt_required});
foreach my $key (keys %param) {
	my ($a) = ($key =~ /^signal_(.*)$/);
	push (@arr_fkt_required, $a) if (defined $a);
}
foreach my $key (keys %param) {
	my ($a) = ($key =~ /^cycle_(.*)$/);
	push (@arr_fkt_required, $a) if (defined $a);
}
$param{fkt_required} = join (',', @arr_fkt_required) if (scalar @arr_fkt_required);
if (!exists $param{fkt}) {
        $param{fkt} = $param{fkt_required};
} elsif ($param{fkt_required} && $param{fkt} ne "") {
        $param{fkt} .= "," . $param{fkt_required};
}

#$db->print_error($q, 401, "Unauthorized") if (exists $param->{"cycle_"});

if ($db->checkAccess(\%param)) {
	select_code($q, \%param);
} else {
	$db->print_error($q, 401, "Unauthorized");
}

$db->disconnect();
exit 0;
