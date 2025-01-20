#!/usr/bin/perl -w

package MetaEDID;

use strict;
use MIME::Base64;
#use Digest::SHA qw(sha256_hex);
use Digest::MD5 qw(md5_base64);

binmode(STDIN);	#NOTE: this is critical for correctly handling the transmitted binary data

sub new {
	my ($class) = @_;

	my $self = {};

	bless $self, $class;

	return $self;
}

sub _parse_descr
{
	my ($self, $raw) = @_;

	my @eedid_info = ('v', 'C', 'C', 'C', 'a13');
	my ($v1, $zero1, $v2, $zero2, $data) = unpack(join('', map { $_ } @eedid_info), $raw);

	# Monitor Name
	if ($v1 == 0x00 && $v2 == 0xfc) {
		$self->{emonitor_name} = $data;
		$self->{emonitor_name} =~ s/\n.*$//;
	}

	# Monitor serial number (text)
	elsif ($v1 == 0x00 && $v2 == 0xff) {
		$self->{emonitor_serial} = $data;
		$self->{emonitor_serial} =~ s/\n.*$//;
	}
}

sub parse
{
	my ($self, $edid_raw) = @_;
	my %edid = ();

	return undef if (length($edid_raw) % 128);	#check if edid data is a multiple of 128byte blocks

	my ($main_edid, @eedid_blocks) = unpack("a128" x (length($edid_raw) / 128), $edid_raw);

	my @edid_info = ('a8', 'n', 'v', 'V', 'C', 'C', 'C', 'C');
	my @vals = unpack(join('', map { $_ } @edid_info), $main_edid);

	$self->{raw} = $edid_raw;
	$self->{_header} = $vals[0];
	$self->{manufacturer_id} = $vals[1];
	$self->{manufacturer_name} =
		chr((($vals[1] >> 10) & 0x1f) + ord('A') - 1) .
		chr((($vals[1] >>  5) & 0x1f) + ord('A') - 1) .
		chr((($vals[1] >>  0) & 0x1f) + ord('A') - 1);
	$self->{product_code} = $vals[2];
	$self->{serial_number} = $vals[3];
	$self->{week} = $vals[4];
	$self->{year} = $vals[5] + 1990;
	$self->{edid_version} = $vals[6];
	$self->{edid_revision} = $vals[7];

	$self->_parse_descr(substr $self->{raw}, 54);
	$self->_parse_descr(substr $self->{raw}, 72);
	$self->_parse_descr(substr $self->{raw}, 90);
	$self->_parse_descr(substr $self->{raw}, 108);

	return $self;
}

sub fingerprint
{
	my ($self) = @_;

	my @vals = split(//, $self->{raw});
	$vals[8] = $vals[9] = 0;	# manufacturer
	$vals[16] = $vals[17] = 0;	# production
	$vals[12] = $vals[13] = $vals[14] = $vals[15] = 0;	# serial
	$vals[127] = 0;			# checksum

	#return sha256_hex(join("", @vals));
	return md5_base64(join("", @vals));
}

1;
