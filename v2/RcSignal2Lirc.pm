#!/usr/bin/perl -w

package RcSignal2Lirc;

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
print Dumper(@_);

	my ($self, $info, $_descr) = @_;

	#return _globalcache_data2pronto_raw($info->{id}, $info->{key1_repeat}, $info->{freq}, $info->{key1_frame_main_pause_cycles}, $info->{key1_frame_start}, $info->{key1_frame_main}) if (defined $info->{key1_frame_start});
#	return _globalcache_data2pronto_raw($info->{id}, $info->{key1_repeat}, $info->{freq}, $info->{key1_frame_main_pause_cycles}, $info->{key1_frame_start}, $info->{key1_frame_main});
#	return _globalcache_data2pronto_raw($info->{id}, $info->{key1_repeat}, $info->{freq}, $info->{key1_frame_main_pause_cycles}, $info->{key1_frame_main});
}

sub _globalcache_data2arrpause {
        my ($data, $pause) = @_;

        return () if (!defined $data);

        my @arr = split (/ /, $data);
        return @arr;

        my $len = scalar @arr;
        if ($len & 0x01) {
                push @arr, $pause;
        } else {
                $arr[$#arr] += $pause;
        }

        return @arr;
}

sub _globalcache_data2pronto_raw {
        my ($id, $count, $freq, $pause, $data_once, $data_repeat) = @_;
        my $out = "";

	if (defined $data_repeat && $data_once eq $data_repeat) {
                $data_once = ();
	}

        if (!defined $data_repeat) {
                $data_repeat = $data_once;
                $data_once = ();
        }

        my @arr_once = _globalcache_data2arrpause($data_once, $pause);
        my @arr_repeat = _globalcache_data2arrpause($data_repeat, $pause);
#        my @arr_once = split / /, $data_once;
#        my @arr_repeat = split / /, $data_repeat;

        $out = "sendir,";
        $out .= "1:1,";
        $out .= $id.",";

	my $f = (int(($freq+500)/1000))*1000;
        $out .= $f.",";

	$out .= $count.",";

	my $offset = 1;
	if ($#arr_once > 0 && $#arr_repeat > 0) {
		$offset = $#arr_once + 2;
	}
	$out .= $offset.",";

	if ($#arr_once > 0 && $#arr_repeat > 0) {
		$out .= join ",", @arr_once;
		$out .= ",";
	}
	$out .= join (",", @arr_repeat);

        return $out;
}
1;
