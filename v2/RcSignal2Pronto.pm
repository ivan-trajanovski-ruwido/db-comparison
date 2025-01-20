#!/usr/bin/perl -w

package RcSignal2Pronto;

use warnings;
use strict;
use utf8;
use POSIX;

use Data::Dumper;

sub new {
        my ($class) = @_;

        my $self = {
		result	=> {},
        };

        bless $self, $class;

        return $self;
}

sub convert
{
	my ($self, $info) = @_;

	return _pronto_data2pronto_raw($info->{freq}, $info->{key1_frame_start}, $info->{key1_frame_start_pause_cycles}, $info->{key1_frame_main}, $info->{key1_frame_main_pause_cycles}) if (defined $info->{key1_frame_start});
	return _pronto_data2pronto_raw($info->{freq}, $info->{key1_frame_main}, $info->{key1_frame_main_pause_cycles});
}

sub _pronto_data2arrpause {
        my ($data, $pause) = @_;

        return () if (!defined $data);

        my @arr = split / /, $data;

        my $len = scalar @arr;
        if ($len & 0x01) {
                push @arr, $pause;
        } elsif (defined $pause) {
                $arr[$#arr] += $pause;
        }

        return @arr;
}

sub _pronto_data2pronto_raw {
        my ($freq, $data_once, $pause, $data_repeat, $pause_repeat) = @_;
        my $out = "";

	if (defined $data_repeat && $data_once eq $data_repeat) {
                $data_once = ();
	}

        if (!defined $data_repeat) {
                $data_repeat = $data_once;
                $data_once = ();
        }

        my @arr_once = _pronto_data2arrpause($data_once, $pause);
        my @arr_repeat = _pronto_data2arrpause($data_repeat, $pause_repeat);

        my %hdr = ();
        $hdr{wFmtId} = 0x00;				# Format ID
        $hdr{wFrqDiv} = 4145146.0 / $freq + 0.5;	# Carrier frequency divider
        $hdr{nOnceSeq} = scalar @arr_once / 2;		# Number of burst pairs at once sequence
        $hdr{nRepeatSeq} = scalar @arr_repeat / 2;	# Number of burst pairs at repeat sequence

        $out .= sprintf ("%04X %04X %04X %04X ", $hdr{wFmtId}, $hdr{wFrqDiv}, $hdr{nOnceSeq}, $hdr{nRepeatSeq});

        foreach (@arr_once) {
                $out .= sprintf ("%04X ", $_);
        }
        foreach (@arr_repeat) {
		if (defined $_) {
                	$out .= sprintf ("%04X ", $_);
		}
        }

        return $out;
}

1;
