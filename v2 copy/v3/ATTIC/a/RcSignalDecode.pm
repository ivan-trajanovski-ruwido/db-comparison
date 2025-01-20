#!/usr/bin/perl -w

package RcSignalDecode;

use warnings;
use strict;
use utf8;
use POSIX;

use constant USE_HEX => 1;

use constant OFF_START2 => 3;
use constant OFF_FLAGS => 4;
use constant OFF_PERIOD => 6;
use constant OFF_PULSE => 7;
use constant OFF_REPEAT => 8;

use constant {
	L_CONTINOUS	=> 0x0001,
	L_SINGLESHOT	=> 0x0002,
	L_REPEATCNT	=> 0x0004,
	L_HF_MODE	=> 0x0008,
	L_LONG_FLASH	=> 0x0010,
	L_REPEATFRAME	=> 0x0020,
	L_STARTFRAME	=> 0x0040,
	L_STOPFRAME	=> 0x0080,
	L_CHANGEFRAME	=> 0x0100,
	L_SEC_STARTFRAME => 0x0200,
	L_EXTCHANGEFRAME => 0x0400,
};

sub new {
        my ($class) = @_;

        my $self = {
		result	=> {},
		ptr	=> 0,
		use_debug	=> 0,
        };

        bless $self, $class;

        return $self;
}

sub _decode_bits
{
	my ($self, $ref_arr, $end, $ref_index, $num) = @_;
	my @arr = @{$ref_arr};
	my @len = @{$ref_index};
	my @bits = ();

	return @bits if ($self->{ptr} >= scalar @arr);

	my $bitlen = $arr[$self->{ptr}++];

	my $compression = 0;
	my $mask = 0;
	if ($num <= 2) {
		$compression = 1;
		$mask = 0x01;
	} elsif ($num <= 4) {
		$compression = 2;
		$mask = 0x03;
	} elsif ($num <= 16) {
		$compression = 4;
		$mask = 0x0F;
	} else {
		$compression = 8;
		$mask = 0xFF;
	}

	my $bits_left = 0;
	my $bits_buf;
	for (; $bitlen; $bitlen--) {
		if ($bits_left <= 0) {
			return @bits if ($self->{ptr} >= scalar @arr);

			$bits_buf = $arr[$self->{ptr}++];
			$bits_left = 8;
		}

		$bits_left -= $compression;
		push @bits, $len[($bits_buf >> $bits_left) & $mask];
	}

	return @bits;
}

sub decode_frames
{
	my ($self, $ref_arr, $end, $prefix) = @_;
	my @arr = @{$ref_arr};

	my $flags = $arr[$self->{ptr}++] | $arr[$self->{ptr}++] << 8;
#	$self->{result}->{$prefix."_flags"} = sprintf("0x%02x", $flags);

#	$self->{result}->{$prefix."_flags"} .= "CONTINOUS," if ($flags & L_CONTINOUS);
	$self->{result}->{$prefix."_flags"} .= "SINGLESHOT," if ($flags & L_SINGLESHOT);
	$self->{result}->{$prefix."_flags"} .= "REPEATCNT," if ($flags & L_REPEATCNT);
	$self->{result}->{$prefix."_flags"} .= "HF_MODE," if ($flags & L_HF_MODE);
	$self->{result}->{$prefix."_flags"} .= "LONG_FLASH," if ($flags & L_LONG_FLASH);
#	$self->{result}->{$prefix."_flags"} .= "REPEATFRAME," if ($flags & L_REPEATFRAME);
	$self->{result}->{$prefix."_flags"} .= "STARTFRAME," if ($flags & L_STARTFRAME);
	$self->{result}->{$prefix."_flags"} .= "STOPFRAME," if ($flags & L_STOPFRAME);
	$self->{result}->{$prefix."_flags"} .= "CHANGEFRAME," if ($flags & L_CHANGEFRAME);
#	$self->{result}->{$prefix."_flags"} .= "SEC_STARTFRAME," if ($flags & L_SEC_STARTFRAME);	#unused
#	$self->{result}->{$prefix."_flags"} .= "EXTCHANGEFRAME," if ($flags & L_EXTCHANGEFRAME);	#unused
	$self->{result}->{$prefix."_flags"} =~ s/,$// if (exists $self->{result}->{$prefix."_flags"});

	my @prefix2_str;
	my $prefix2_str_index = 0;

	$prefix2_str[$prefix2_str_index++] = "_frame_start" if ($flags & L_STARTFRAME);
	$prefix2_str[$prefix2_str_index++] = "_frame_main";
	$prefix2_str[$prefix2_str_index++] = "_frame_main2" if ($flags & L_CHANGEFRAME);
	$prefix2_str[$prefix2_str_index++] = "_frame_stop" if ($flags & L_STOPFRAME);
	$prefix2_str[$prefix2_str_index++] = "_frame_ERR1";
	$prefix2_str[$prefix2_str_index++] = "_frame_ERR2";
	$prefix2_str[$prefix2_str_index++] = "_frame_ERR3";
	$prefix2_str[$prefix2_str_index++] = "_frame_ERR4";

	my $period = $arr[$self->{ptr}++];
	$period = 1 if ($period == 0);
	my $pulse = $arr[$self->{ptr}++];
	$pulse = 1 if ($pulse == 0);

	if ($flags & L_HF_MODE) {
		my $hf_period = $arr[$self->{ptr}++];
		$self->{result}->{$prefix."_period_hf_pause"} = $hf_period;
	}

$period++;
	my $freq = 4000/$period;
	$self->{result}->{"freq"} = $freq * 1000;			#in Hz
	$self->{result}->{"duty_cycle"} = int($period*4/($pulse) + .5);	#NOTE: .5 for rounding
	$self->{result}->{$prefix."_repeat"} = $arr[$self->{ptr}++];

	my $num = $arr[$self->{ptr}++];
	my $min = 0xffff;
	my @len;
	for (my $i = 0; $i < $num; $i++) {
		$len[$i] = int($arr[$self->{ptr}+1])<<8 | int($arr[$self->{ptr}]) - 1;	#FIXME: -1 to correct the incorrect frame-values
#		$len[$i] = int($arr[$self->{ptr}+1])<<8 | int($arr[$self->{ptr}]);
		$self->{ptr} += 2;
	}

	my $a = 0;
	my $prefix2;
	do {
		my @bits = $self->_decode_bits(\@arr, $end, \@len, $num);
		return if (!@bits);

		my $pause_time = (0xFFFF - ($arr[$self->{ptr}++] | $arr[$self->{ptr}++] << 8))*32000/1000000;
		my $pause_cycles = int($pause_time * $freq + 0.5); 

		my $signal_cycles = (eval join '+', @bits);
		my $signal_time = $signal_cycles*1/$freq;
		my $interval_time = int($pause_time + $signal_time + 0.5);
		my $interval_cycles = $interval_time*$freq;
		my $pause_cycles_recalc = int($interval_cycles - $signal_cycles + 0.5);

#		push @bits, ((pop @bits) + $pause_cycles_recalc);

### just for calculation in ms
#@bits = map {int(1000/$freq*$_)} @bits;

		$prefix2 = $prefix2_str[$a];
		if (0 && $prefix2 eq "_frame_main2") {
#			$self->{result}->{$prefix."_frame_main"} .= ",".join (',', @bits);
			$self->{result}->{$prefix."_frame_main"} .= ",".join (' ', @bits);
		} else {
			$self->{result}->{$prefix.$prefix2."_interval"} = $interval_time * 1000;
#			$self->{result}->{$prefix.$prefix2} = join (',', @bits);
			$self->{result}->{$prefix.$prefix2} = join (' ', @bits);
		}

		$a++;
	} while ($self->{ptr} < $end);

}

# hex with commas
#sub decode_signal
#{
#	my ($self, $str) = @_;
#	my @arr = split /,/, $str;
#
#	return if (scalar @arr < 10);
#
#	@arr = map { hex "0x".$_ } @arr if (USE_HEX);
#	$self->{result} = ();
#
#	my $start2 = $arr[OFF_START2];
#	my $frame_end = scalar @arr;
#
#	$frame_end = $start2 if ($start2 > 4);
#
#	$self->{ptr} = 4;
#	$self->decode_frames(\@arr, $frame_end, "key1");
#
#	if ($start2 > 4) {
#		$self->{ptr} = $start2;
#		$frame_end = scalar @arr;
#		$self->decode_frames(\@arr, $frame_end, "key2");
#	}
#}

# hex without commas
#sub decode_hex
#{
#	my ($self, $str) = @_;
#
#	$str =~ s/(.{2})/$1,/g;
#	return $self->decode_signal($str);
#}

# binary
sub decode_binary
{
	my ($self, $str) = @_;

	my @arr = unpack ('H2' x length($str), $str);

	return if (scalar @arr < 10);

	@arr = map { hex "0x".$_ } @arr if (USE_HEX);
	$self->{result} = ();

	my $start2 = $arr[OFF_START2];
	my $frame_end = scalar @arr;

	$frame_end = $start2 if ($start2 > 4);

	$self->{ptr} = 4;
	$self->decode_frames(\@arr, $frame_end, "key1");

	if ($start2 > 4) {
		$self->{ptr} = $start2;
		$frame_end = scalar @arr;
		$self->decode_frames(\@arr, $frame_end, "key2");
	}
}

sub output
{
	my ($self) = @_;

	foreach my $key (sort keys $self->{result}) {
		print "$key: " . $self->{result}->{$key} . " | ";
	}

	print "\n";
}

1;
