#!/usr/bin/perl

use strict;
use utf8;

use DataBase;

my $db = new DataBase();

my $q = CGI->new;
my %param = $q->Vars;

#my ($ir1, $ir2, $ir3, $ir4, $ir5, $rep, $junk) = split(/ /, $param{descr});
my @_descr = split(/ /, $param{descr});
my $descr = join(' ', @_descr[0..4]);
my $rep = $_descr[5] || 0;

my $signal = `./ruwido-IRDB-ubuntu_150811 $descr 0 db`;

$db->print($q, 1, {signal => {description => $param{descr}, content => rewrite_signal($signal, $rep)}}, {
	-vary => "Accept",
	-access_control_allow_origin => '*',
	-access_control_allow_headers => 'content-type,X-Requested-With',
	-access_control_allow_methods => 'GET,POST,OPTIONS',
	-access_control_allow_credentials => 'true'
});

exit;

use constant {
        L_CONTINOUS     => 0x0001,
        L_SINGLESHOT    => 0x0002,
        L_REPEATCNT     => 0x0004,
        L_HF_MODE       => 0x0008,
        L_LONG_FLASH    => 0x0010,
        L_REPEATFRAME   => 0x0020,
        L_STARTFRAME    => 0x0040,
        L_STOPFRAME     => 0x0080,
        L_CHANGEFRAME   => 0x0100,
        L_SEC_STARTFRAME => 0x0200,
        L_EXTCHANGEFRAME => 0x0400,
};

use constant {
        I_FLAGS         => 0x0001,
        I_PERIOD        => 0x0002,
        I_PULSEWIDTH    => 0x0004,
        I_REPEAT        => 0x0008,
};

sub get
{
        my ($index, $start, @sig) = @_;

        if ($index == I_FLAGS) {
                return $sig[$start] << 0 | $sig[$start+1] << 8;
        }
        if ($index == I_PERIOD) {
                return $sig[$start+2];
        }
        if ($index == I_PULSEWIDTH) {
                return $sig[$start+3];
        }
        if ($index == I_REPEAT) {
                if (get(I_FLAGS, $start, @sig) & L_HF_MODE) {
                        return $sig[$start+5];
                } else {
                        return $sig[$start+4];
                }
        }

        return 0;
}

sub set
{
        my ($index, $val, $start, $sig) = @_;

        if ($index == I_FLAGS) {
                $sig->[$start] = ($val >> 8) & 0xff;
                $sig->[$start+1] = ($val >> 0) & 0xff;
        }
        elsif ($index == I_REPEAT) {
                if (get(I_FLAGS, $start, @$sig) & L_HF_MODE) {
                        $sig->[$start+5] = $val;
                } else {
                        $sig->[$start+4] = $val;
                }
        }
        elsif ($index == I_PERIOD) {
                $sig->[$start+2] = $val;
        }
        elsif ($index == I_PULSEWIDTH) {
                $sig->[$start+3] = $val;
        }

        return 0;
}

sub rewrite_key
{
        my ($sig, $start, $end, $rep) = @_;

        my $flags = get(I_FLAGS, $start, @$sig);

#      return if ($flags & L_SINGLESHOT);      # ignore singleshot
#      return if ($flags & L_REPEATCNT);       # ignore when flag repeatcnt is set

### change from continuous to singlshot
#       if ($flags & L_CONTINOUS) {
		@$sig[$start] |= L_CONTINOUS;
		@$sig[$start] ^= L_SINGLESHOT;
#		@$sig[$start] |= L_SINGLESHOT;
		@$sig[$start] |= L_REPEATCNT;

		@$sig[$start] = 0x25;
#		$flags ^= L_CONTINOUS;
#		$flags |= L_SINGLESHOT;;
#		$flags |= L_REPEATCNT;;
#		set(I_FLAGS, $start, $sig);
#       }

### change repeat counter
        set(I_REPEAT, $rep, $start, $sig);               #repeat_counter
}

sub rewrite_signal
{
        my ($signal, $min_repeat) = @_;

	return $signal if ($min_repeat == 0);
        return undef if ($signal eq "");

        my @sig = map { hex "0x".$_ } split (/,/, $signal);

        my $key2 = $sig[3];
        my $end;

        $end = ($key2 > 4) ? $key2 : scalar @sig;
        rewrite_key(\@sig, 4, $end, $min_repeat);

        if ($key2 != 4) {
                $end = scalar @sig;
                rewrite_key(\@sig, $key2, $end, $min_repeat);
        }

        return join ",", map { sprintf "%02X", $_ } @sig;
}
