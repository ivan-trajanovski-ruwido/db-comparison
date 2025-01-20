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
	my ($self, $info, $_descr) = @_;
	my @descr = split ' ', $_descr;
#print Dumper $_descr;
#print Dumper $info;

	return _pronto_data2pronto_raw($info->{freq}, $info->{key1_frame_main_pause_cycles}, $info->{key1_frame_start}, $info->{key1_frame_main}) if (defined $info->{key1_frame_start});
	return _pronto_data2pronto_raw($info->{freq}, $info->{key1_frame_main_pause_cycles}, $info->{key1_frame_main});
}

sub _pronto_data2arrpause {
        my ($data, $pause) = @_;

        return () if (!defined $data);

        my @arr = split / /, $data;

        my $len = scalar @arr;
        if ($len & 0x01) {
                push @arr, $pause;
        } else {
                $arr[$#arr] += $pause;
        }

        return @arr;
}

sub _pronto_data2pronto_raw {
        my ($freq, $pause, $data_once, $data_repeat) = @_;
        my $out = "";

	if (defined $data_repeat && $data_once eq $data_repeat) {
                $data_once = ();
	}

        if (!defined $data_repeat) {
                $data_repeat = $data_once;
                $data_once = ();
        }

        my @arr_once = _pronto_data2arrpause($data_once, $pause);
        my @arr_repeat = _pronto_data2arrpause($data_repeat, $pause);

        my %hdr = ();
        $hdr{wFmtId} = 0x00;                            # Format ID
        $hdr{wFrqDiv} = 4145146 / $freq;                # Carrier frequency divider
        $hdr{nOnceSeq} = scalar @arr_once / 2;          # Number of burst pairs at once sequence
        $hdr{nRepeatSeq} = scalar @arr_repeat / 2;      # Number of burst pairs at repeat sequence

        $out .= sprintf ("%04X %04X %04X %04X ", $hdr{wFmtId}, $hdr{wFrqDiv}, $hdr{nOnceSeq}, $hdr{nRepeatSeq});

        foreach (@arr_once) {
                $out .= sprintf ("%04X ", $_);
        }
        foreach (@arr_repeat) {
                $out .= sprintf ("%04X ", $_);
        }

        return $out;
}
1;
