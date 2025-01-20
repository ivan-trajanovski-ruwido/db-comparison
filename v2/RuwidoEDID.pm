#!/usr/bin/perl -w

package RuwidoEDID;

use constant TYPE_NO_IR	=> -1;
use constant TYPE_ANY	=> 0;
use constant TYPE_TV	=> 1;
use constant TYPE_AMP	=> 9;
use constant TYPE_PROJ	=> 13;

sub new {
        my ($class) = @_;

        my $self = {
                edid => undef,
		brand => undef
        };

        bless $self, $class;

        return $self;
}

sub _filter
{
	my ($self, $edid) = @_;

	$param{brand} = "Bang Olufsen" if ($edid->{manufacturer_name} eq "BNO");
        $param{brand} = "Grundig" if ($edid->{manufacturer_name} eq "GRU");

	if (
		$edid->{manufacturer_name} eq 'AAA' ||
		$edid->{manufacturer_name} eq 'XXX' ||
		$edid->{manufacturer_name} eq '___' ||
		0
		) {
		return (-2, undef);
	}

	if ($edid->{manufacturer_name} eq 'SAM') {
#		return (TYPE_NO_IR, $edid->{emonitor_name}) if ($edid->{product_code} == 2314);	# SMS27B750V
#		return (TYPE_NO_IR, $edid->{emonitor_name}) if ($edid->{product_code} == 2610);	# S22C350
##		return (TYPE_NO_IR, $edid->{emonitor_name}) if ($edid->{product_code} == 2636);	# S24C550
##		return (TYPE_NO_IR, $edid->{emonitor_name}) if ($edid->{product_code} == 2879);	# S22D300
#		return (TYPE_NO_IR, $edid->{emonitor_name}) if ($edid->{product_code} == 2917);	# S24D390
#		return (TYPE_NO_IR, $edid->{emonitor_name}) if ($edid->{product_code} == 2919);	# S27D390
##		return (TYPE_NO_IR, $edid->{emonitor_name}) if ($edid->{product_code} == 3150);	# U28E590
#		return (TYPE_NO_IR, $edid->{emonitor_name}) if ($edid->{product_code} == 0x0c5c);	# S27E590
#		return (TYPE_NO_IR, $edid->{emonitor_name}) if ($edid->{product_code} == 0x0d22);	# S27F350
#		return (TYPE_NO_IR, $edid->{emonitor_name}) if ($edid->{product_code} == 0x0d24);	# S32F351
#		return (TYPE_NO_IR, $edid->{emonitor_name}) if ($edid->{product_code} == 0x0c4c);	# U28E590

#		return (TYPE_NO_IR, $edid->{emonitor_name}) if ($edid->{product_code} == 0x0b3f);	# S22D300
#		return (TYPE_NO_IR, $edid->{emonitor_name}) if ($edid->{product_code} == 0x0c4e);	# U28E590
#		return (TYPE_NO_IR, $edid->{emonitor_name}) if ($edid->{product_code} == 0x0a4c);	# S24C550

		return (TYPE_NO_IR, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ "^[SU][23]");	# S24C550


#		return (TYPE_TV, "SyncMaster") if ($edid->{product_code} == 0x070a);		# SMB2030HD	IR ok
#		return (TYPE_TV, "SyncMaster") if ($edid->{product_code} == 0x0710);		# SMB2330HD
#		return (TYPE_TV, "SyncMaster") if ($edid->{product_code} == 0x0712);		# SMB2430HD
#		return (TYPE_TV, "SyncMaster") if ($edid->{product_code} == 0x0713);		# SMB2430HD
#		return (TYPE_TV, "SyncMaster") if ($edid->{product_code} == 0x074a);		# SMFX2490HD	IR ok
##		return (TYPE_TV, "SyncMaster") if ($edid->{product_code} == 0x07ad);		# SMT24A350
#		return (TYPE_TV, "SyncMaster") if ($edid->{product_code} == 0x07a7);		# SMT22A350
#		return (TYPE_TV, "SyncMaster") if ($edid->{product_code} == 0x080e);		# SMT27A950
#		return (TYPE_TV, "SyncMaster") if ($edid->{product_code} == 0x087a);		# SMT27A300
#		return (TYPE_TV, "SyncMaster") if ($edid->{product_code} == 0x087b);		# SMT22A300
		return (TYPE_TV, "SyncMaster") if ($edid->{emonitor_name} =~ "^SM");	# S24C550

#		return (TYPE_TV, "SyncMaster") if ($edid->{product_code} == 0x0b71);		# T27D390
#		return (TYPE_TV, "SyncMaster") if ($edid->{product_code} == 0x0c20);		# T24E390
		return (TYPE_TV, "SyncMaster") if ($edid->{emonitor_name} =~ "^T[23]");	# S24C550

#		return (TYPE_TV, "UE75F6370SSXZG") if ($edid->{product_code} == 0x0a7e);	# 16199
#		return (TYPE_TV, "KE55S9CSLXZG")   if ($edid->{product_code} == 0x0a7d);	# 16199
#		return (TYPE_TV, "UE32H4000AWX")   if ($edid->{product_code} == 0x0b32);	# 17548
#		return (TYPE_TV, "UE40H6410SSXZG") if ($edid->{product_code} == 0x0b60);	# 18186
#		return (TYPE_TV, "UE32H4580SSXZG") if ($edid->{product_code} == 0x0b54);	# 18169
#		return (TYPE_TV, "UE55HU8580QXZG") if ($edid->{product_code} == 0x0b92);	# 18186
#		return (TYPE_TV, "UE55HU7580TXZG") if ($edid->{product_code} == 0x0b92);	# 18186
#		return (TYPE_TV, "UE55HU6900SXZG") if ($edid->{product_code} == 0x0bb4);	# 16199

		my %hash = (
			0x0002 => "LE32R74BD",
			0x0009 => "UE32EH4000",
			0x0209 => "UE32EH5000",
#			0x0209 => "UE22ES5410",
			0x0b09 => "UE40ES8000",
			0xc007 => "UE32D5000",
#			0xc007 => "UE32D5520",
			0x1111 => "LE32B530",
			0x1202 => "PS42E7HD",
			0x2109 => "PS43E450",
			0x5906 => "LE32C530",
			0x600b => "UE32H6500",
			0x6906 => "UE32C6000",
			0x6906 => "LE32C650",
#			0x6906 => "UE32C6510",
			0x7806 => "UE32C4000",
			0x7a0a => "UE22F5000",
#			0x7a0a => "UE32F5000",
			0x7c06 => "LE32C450",
#			0x7c06 => "PS50C550",
			0x7c0a => "UE28F4000",
			0x7e06 => "PS50C450",
			0x9209 => "UE32EH6030",
			0x9d02 => "LE26S86BD",
			0x9d02 => "LE26R87BD",
#			0x9f02 => "LE40M87BD",
			0xa402 => "LE26S86BD",
			0xbc03 => "LE40A558",
			0xc007 => "LE37D580",
			0xc507 => "UE40D8000",
#			0xc507 => "UE32D6100",
			0xd007 => "UE32D4000",
#			0xd007 => "LE32D400",
			0xfb04 => "LE32B530P7WXXC",
			0xfd04 => "UE22C4000",
		);
		return (TYPE_TV, $hash{$edid->{product_code}}) if (defined $hash{$edid->{product_code}});

		return (TYPE_AMP, undef) if ($edid->{emonitor_name} =~ 'AVR');
		return (TYPE_AMP, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ 'AV');
		return (TYPE_AMP, undef) if ($edid->{product_code} == 1987);

		return (TYPE_TV, undef) if ($edid->{emonitor_name} =~ '^SAMSUNG');

		#return (undef, undef);
		return (TYPE_TV, undef);
	}

	if ($edid->{manufacturer_name} eq 'ACI') {	# per default Asus does not have IR
		$edid->{emonitor_name} =~ s/^ASUS //;
		return (TYPE_NO_IR, $edid->{emonitor_name});
	}

	if ($edid->{manufacturer_name} eq 'ACR') {
		$self->{brand} = "Acer";
		$edid->{emonitor_name} =~ s/^Acer //;

		return (TYPE_PROJ, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ "^P");
		return (TYPE_TV, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ "^AT");
		return (TYPE_NO_IR, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ "^[GHK]");

		return (undef, undef);
	}

	if ($edid->{manufacturer_name} eq 'ANE') {
		$self->{brand} = "anthem";
		return (TYPE_AMP, $edid->{emonitor_name});
	}

	if ($edid->{manufacturer_name} eq 'AOC') {	# per default AOC does not have IR
		$self->{brand} = "aoc";
		return (TYPE_NO_IR, $edid->{emonitor_name});
	}

	if ($edid->{manufacturer_name} eq 'AUS') {	# per default AOC does not have IR
		$self->{brand} = "asus";
		$edid->{emonitor_name} =~ s/^ASUS //;
		return (TYPE_NO_IR, $edid->{emonitor_name});
	}

	if ($edid->{manufacturer_name} eq 'BBY') {
		if ($edid->{emonitor_name} =~ '^DX') {
			$self->{brand} = "dynex";
			return (TYPE_TV, $edid->{emonitor_name});	# TV
		}
		if ($edid->{emonitor_name} =~ '^NS') {
			$self->{brand} = "insignia";
			return (TYPE_TV, $edid->{emonitor_name});	# TV
		}
		if ($edid->{emonitor_name} =~ 'DR') {
			$self->{brand} = "insignia";
			return (TYPE_TV, $edid->{emonitor_name});	# TV
		}
		return (TYPE_TV, undef);
	}

	if ($edid->{manufacturer_name} eq 'BLS') {
		$self->{brand} = "Blusens";
		return (TYPE_TV, undef);
	}

	if ($edid->{manufacturer_name} eq 'BNO') {
		return (TYPE_TV, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ 'Vision');	# infrared only
		return (TYPE_AMP, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ 'Play');	# infrared only
		return (undef, undef);
	}

	if ($edid->{manufacturer_name} eq 'BOE') {
		if ($edid->{emonitor_name} =~ '^BRLED' ||	
		    $edid->{emonitor_name} =~ '^BSLED' ||	
		    $edid->{emonitor_name} =~ '^BTC' ||	
		    $edid->{emonitor_name} =~ 'RLDED' ||	
		    $edid->{emonitor_name} =~ 'RLED' ||	
		    $edid->{emonitor_name} =~ '^RT' ||	
		    $edid->{emonitor_name} =~ '^TR') {
			$self->{brand} = 'RCA';
#			return (TYPE_TV, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ 'LED');
#			return (TYPE_TV, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ 'LDED');
			return (TYPE_TV, $edid->{emonitor_name});
		}

		$self->{brand} = "proscan" if ($edid->{emonitor_name} =~ '^DS');
		$self->{brand} = "proscan" if ($edid->{emonitor_name} =~ '^PL');
		$self->{brand} = "sylvania" if ($edid->{emonitor_name} =~ '^SLED');

		return (undef, $edid->{emonitor_name});
	}

	if ($edid->{manufacturer_name} eq 'BSE') {	# bose
		$edid->{emonitor_name} =~ s/^Bose //i;
		return (TYPE_AMP, $edid->{emonitor_name});	# AMP
	}

	if ($edid->{manufacturer_name} eq 'BW@') {	# ???
		$self->{brand} = "bowers&wilkins";
		return (TYPE_AMP, undef);
	}

	if ($edid->{manufacturer_name} eq 'COB') {
		$self->{brand} = "coby";
		return (TYPE_TV, undef);
	}

	if ($edid->{manufacturer_name} eq 'CVT') {
		if ($edid->{product_code} == 0x8010) {		# sky
			$self->{brand} = "daewoo";
			return (TYPE_TV, "TL1952BDTP");
		}

		$self->{brand} = "CVT";
		return (TYPE_TV, undef);
	}

	if ($edid->{manufacturer_name} eq 'DAI') {
		$self->{brand} = "daytek";
		return (TYPE_TV, undef);
	}

	if ($edid->{manufacturer_name} eq 'DPC') {	# ???
		$self->{brand} = "infocus";
		$edid->{emonitor_name} =~ s/^InFocus //;
		return (TYPE_NO_IR, $edid->{emonitor_name});
	}

	if ($edid->{manufacturer_name} eq 'DEL') {
		$edid->{emonitor_name} =~ s/^DELL //;

#		return (TYPE_PROJ, $edid->{emonitor_name}) if ($edid->{product_code} == 24656);	# DELL M110
#		return (TYPE_PROJ, $edid->{emonitor_name}) if ($edid->{product_code} == 24635);	# DELL M210X
		return (TYPE_PROJ, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ "^M");

#		return (TYPE_NO_IR, $edid->{emonitor_name}) if ($edid->{product_code} == 0x4099);	# P2314H
#		return (TYPE_NO_IR, $edid->{emonitor_name}) if ($edid->{product_code} == 0x40f7);	# P2717H
#		return (TYPE_NO_IR, $edid->{emonitor_name}) if ($edid->{product_code} == 0xa06e);	# P2411H
#		return (TYPE_NO_IR, $edid->{emonitor_name}) if ($edid->{product_code} == 0xa098);	# P2214H
#		return (TYPE_NO_IR, $edid->{emonitor_name}) if ($edid->{product_code} == 0xd086);	# P4317Q
#		return (TYPE_NO_IR, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ "^P");

#		return (TYPE_NO_IR, $edid->{emonitor_name}) if ($edid->{product_code} == 0x4084);	# S2340T
#		return (TYPE_NO_IR, $edid->{emonitor_name}) if ($edid->{product_code} == 0xa086);	# ST2420L
#		return (TYPE_NO_IR, $edid->{emonitor_name}) if ($edid->{product_code} == 0xd058);	# S2340L
#		return (TYPE_NO_IR, $edid->{emonitor_name}) if ($edid->{product_code} == 0xd082);	# SE2416H
#		return (TYPE_NO_IR, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ "^S");

#		return (TYPE_NO_IR, $edid->{emonitor_name}) if ($edid->{product_code} == 41146);	# U2415
#		return (TYPE_NO_IR, $edid->{emonitor_name}) if ($edid->{product_code} == 41105);	# U2713H
#		return (TYPE_NO_IR, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ "^U");
#		return (TYPE_NO_IR, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ "^W");

		return (TYPE_TV, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ "^W");
		return (TYPE_NO_IR, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ "^[PSUW]");

		return (undef, undef);
	}

	if ($edid->{manufacturer_name} eq 'DON') {
		return (TYPE_AMP, "avr-2807") if ($edid->{product_code} == 0x0005);		# 18040

#		return (TYPE_AMP, undef) if ($edid->{emonitor_name} =~ 'AVR');
#		return (TYPE_AMP, undef) if ($edid->{emonitor_name} =~ 'AVAMP');
		return (TYPE_AMP, undef);
	}

	if ($edid->{manufacturer_name} eq 'ELE') {
		$self->{brand} = "Element Electronics";
		return (TYPE_TV, $edid->{emonitor_name});
	}

	if ($edid->{manufacturer_name} eq 'FLU') {
		$self->{brand} = "fluid";
		return (TYPE_TV, undef);
	}

	if ($edid->{manufacturer_name} eq 'FNI') {	# funai
		#return (TYPE_TV, "LT19DA1BJ") if ($edid->{product_code} == 0x0000);		# 18040
		return (TYPE_TV, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ "^FW");

		return (TYPE_TV, undef);
	}

	if ($edid->{manufacturer_name} eq 'GSM') {
		return (TYPE_PROJ, undef) if ($edid->{emonitor_name} eq "LG PROJECTOR");

		# ignore 0x0000, 0x0001, 0x0100
		my %hash = (
			0x6156 => "26LC55",
			0x7275 => "42PC5D",
			0x029d => "42PQ6000",
			0x429d => "32LH4000",
			0x7275 => "47LG6000",
			0xa876 => "37LF7700",
		);
		return (TYPE_TV, $hash{$edid->{product_code}}) if (defined $hash{$edid->{product_code}});

#		return (TYPE_TV, "37LF7700") if ($edid->{product_code} eq 0xa876 && $edid->{emonitor_name} eq "37LF7700");	# sky
		return (TYPE_TV, $edid->{emonitor_name}) if ($edid->{product_code} == 0xa876);	# sky
#		return (TYPE_TV, "42PC5D") if ($edid->{product_code} eq 0x7275 && $edid->{emonitor_name} eq "42PC5D-ZB");	# sky
#		return (TYPE_TV, "47LG6000") if ($edid->{product_code} eq 0x7275 && $edid->{emonitor_name} eq "47LF65-ZC");	# sky
		return (TYPE_TV, $edid->{emonitor_name} =~ s/-*$//) if ($edid->{product_code} == 0x7275);	# sky

		return (TYPE_TV, undef) if ($edid->{emonitor_name} =~ "LG TV");
		
		return (TYPE_TV, $edid->{emonitor_name});
	}

	if ($edid->{manufacturer_name} eq 'HAI') {
# technika
		return (TYPE_TV, "LCD32M3") if ($edid->{product_code} == 0x118);	# sky
		if ($edid->{product_code} == 0x010b) {
			if ($edid->{emonitor_name} == "LET32A300") {
				return (TYPE_TV, "LCD32M3") if ($edid->{product_code} == 0x118);	# sky
			}
			if ($edid->{emonitor_name} == "LY19RECW") {
				$self->{brand} = "technika";
				return (TYPE_TV, "LCD32M3") if ($edid->{product_code} == 0x118);	# sky
			}
		}
		return (undef, undef);
	}

	if ($edid->{manufacturer_name} eq 'HUA') {	# ???
		$self->{brand} = "teufel";
		return (TYPE_AMP, $edid->{emonitor_name});
	}

	if ($edid->{manufacturer_name} eq 'HEC') {	# hisense
		return (TYPE_TV, undef) if ($edid->{emonitor_name} eq "HISENSE");
		return (TYPE_TV, undef) if ($edid->{emonitor_name} eq "HDMI");
		return (TYPE_TV, undef) if ($edid->{emonitor_name} =~ "^UNKNOWN");

		return (TYPE_TV, $edid->{emonitor_name});
	}

	if ($edid->{manufacturer_name} eq 'HKC') {
		$self->{brand} = "HKC";
		return (TYPE_TV, undef);
	}

	if ($edid->{manufacturer_name} eq 'HRE') {	# haier
		return (TYPE_TV, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ "U[A-Z]");
		return (TYPE_TV, undef);
	}

	if ($edid->{manufacturer_name} eq 'HRG') {	# haier for bush
		$self->{brand} = "haier";
		return (TYPE_TV, $edid->{emonitor_name});
	}

	if ($edid->{manufacturer_name} eq 'HTC') {	# hitachi
		return (TYPE_TV, "P42H01") if ($edid->{product_code} == 0x008c);	# sky
		return (TYPE_TV, "40H6L03U") if ($edid->{product_code} == 0x0037);	# sky
		return (TYPE_TV, "32LD8700") if ($edid->{product_code} == 0x4c00);	# sky

		return (TYPE_TV, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ "^LE");
		return (TYPE_TV, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ "HDM");

		return (undef, undef);
	}

	if ($edid->{manufacturer_name} eq 'IFS') {
		$self->{brand} = "infocus";
		$edid->{emonitor_name} =~ s/^InFocus //;
		return (TYPE_NO_IR, $edid->{emonitor_name});
	}

	if ($edid->{manufacturer_name} eq 'ITE') {
		$self->{brand} = "BenQ";

		$edid->{emonitor_name} =~ s/^ITE\. //;
		return (TYPE_NO_IR, $edid->{emonitor_name});
	}

	if ($edid->{manufacturer_name} eq 'IVM') {
		return (TYPE_NO_IR, undef);	# infrared only
	}

	if ($edid->{manufacturer_name} eq 'JBL') {
		$self->{brand} = "JBL";
		return (TYPE_AMP, undef);
	}

	if ($edid->{manufacturer_name} eq 'JVC') {
		return (TYPE_TV, "LT-32P80BU") if ($edid->{product_code} == 8645);	# FPDEUFL5	chasiss FL5
		return (TYPE_TV, "LT-32A80ZU") if ($edid->{product_code} == 8646);	# FPDEUFL5	chasiss FL5
		return (TYPE_TV, "LT-32A80ZU") if ($edid->{product_code} == 8638);	# FPDEUFT3	chasiss FT3
		return (TYPE_TV, "LT-32R10BU") if ($edid->{product_code} == 8689);	# FPDEUFT4	chasiss FT4
		return (TYPE_TV, "LT-37DV1BJ") if ($edid->{product_code} == 8735);	# FPDEUFY2	chasiss FY2

		return (TYPE_TV, "LT32DP9") if ($edid->{product_code} == 0xdf21);	# sky
		return (TYPE_TV, "LT26DA8") if ($edid->{product_code} == 0xbe21);	# sky

#		return (TYPE_TV, $edid->{emonitor_name}) if ($edid->{product_code} == 0xef21);	# sky: "LT-26Dx9"
		return (TYPE_TV, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ "^LT-");
		return (undef, undef);
	}

	if ($edid->{manufacturer_name} eq 'KDI') {
		$self->{brand} = "Seiki";
		return (TYPE_TV, $edid->{emonitor_name});
	}

	if ($edid->{manufacturer_name} eq 'KTC') {
		$self->{brand} = "KTC";
		return (TYPE_TV, undef);
	}

	if ($edid->{manufacturer_name} eq 'LEN') {
		$self->{brand} = "lenovo";
		return (TYPE_NO_IR, undef);
	}

	if ($edid->{manufacturer_name} eq 'LOE') {
		return (TYPE_TV, "individual 42") if ($edid->{product_code} == 0x0118);
		return (TYPE_TV, "individual 42") if ($edid->{product_code} == 0x0418);
		return (TYPE_TV, "connect 22") if ($edid->{product_code} == 0x1009);	# sky
		return (undef, undef);
	}

	if ($edid->{manufacturer_name} eq 'MEI') {
		my %hash = (
			0x11c1 => "TX32LXD60",
			0x2bc1 => "TX32LZD81F",
			0x35c1 => "TXL32S10",
#			0x35c1 => "TXL37G15",
#			0x35c1 => "TXL32G10",
			0xa6a0 => "TXP42G20B",
			0xa9a0 => "TXP42X20",
			0xc9a0 => "TXP42GT30",
			0xcfa0 => "TXP42C3",
			0x7da0 => "TH42PD81B",
			0x96a2 => "TXP42GT50",
			0x28c3 => "TXL42DT50",
			0x29c3 => "TXP42E5BTS",
			0x34c3 => "TXL32C5B",
			0x36c1 => "TXL32X10",
			0x96a2 => "TX19XM6B",
#			0x96a2 => "TX32A400B",
#			0x96a2 => "TX32AS501BTS",
#			0x96a2 => "TX39AS740BTS",
#			0x96a2 => "TXL42DT60BTS",
#			0x96a2 => "TXL42X60BT",
#			0x96a2 => "TXL32ET60BTS",

#			0xa296 => "TX32ASW504",	# 16252
		);
		return (TYPE_TV, $hash{$edid->{product_code}}) if (defined $hash{$edid->{product_code}});
		return (TYPE_AMP, "BTT590") if ($edid->{emonitor_name} eq "11SP_HTIB");	# Panasonic	"11SP_HTIB-1"
		return (TYPE_TV, undef);
	}

	if ($edid->{manufacturer_name} eq 'MSH') {
		$self->{brand} = "Microsoft";
		return (undef, undef);
	}

	if ($edid->{manufacturer_name} eq 'MST') {
		$self->{brand} = "Mstar";
		return (undef, undef);
	}

	if ($edid->{manufacturer_name} eq 'MTC') {
		$self->{brand} = "Mitac";
		return (TYPE_TV, undef);
	}

	if ($edid->{manufacturer_name} eq 'ORN') {
		my %hash = (
			0x0412 => "TV37094",
		);
		return (TYPE_TV, $hash{$edid->{product_code}}) if (defined $hash{$edid->{product_code}});
		return (undef, undef);
	}

	if ($edid->{manufacturer_name} eq 'ONK') {	# onkyo
		return (TYPE_AMP, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ "^TX-");
		return (TYPE_AMP, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ "^HT-");
		return (undef, undef);
	}

	if ($edid->{manufacturer_name} eq 'ONN') {	# onn == seiki
		$self->{brand} = "Seiki";
		return (TYPE_TV, $edid->{emonitor_name});
	}

	if ($edid->{manufacturer_name} eq 'OPP') {	# oppo
		return (TYPE_TV, $edid->{emonitor_name});
	}

	if ($edid->{manufacturer_name} eq 'PIO') {
		my %hash = (
			0x6200 => "PDP506XDE",
			0x9300 => "PDP508XD",
		);
		return (TYPE_TV, $hash{$edid->{product_code}}) if (defined $hash{$edid->{product_code}});

		return (TYPE_TV, undef) if ($edid->{emonitor_name} =~ '^PDP');
		return (TYPE_TV, undef) if ($edid->{emonitor_name} =~ '^PIONEER_PDP');

		return (TYPE_AMP, undef) if ($edid->{emonitor_name} =~ '^AV Receiver');
		return (TYPE_AMP, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ '^AV');
		return (TYPE_AMP, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ '^VSX');
		return (TYPE_AMP, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ '^BD-HTS');
		return (TYPE_AMP, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ '^SC-');
		return (TYPE_AMP, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ '^HTP-');

		return (undef, undef);
	}

	# is ok. or silva schneider
#		if ($edid->{manufacturer_name} eq 'VES' && $edid->{product_code} == 0x3700) {
#			$edid->{manufacturer_name} = "+OK"
#			$self->{brand} = "ok";
#			$edid->{predefined} = 1;
#			return (TYPE_TV, "individual 42");
#		}

	if ($edid->{manufacturer_name} eq 'PHL') {
		return (TYPE_TV, "32PF996810") if ($edid->{product_code} == 0x1); # 14013
		return (TYPE_TV, "42PUS780912") if ($edid->{product_code} == 0x304); # 16269/16269.1

		$edid->{emonitor_name} =~ s/^PHL //;
		return (TYPE_TV, $edid->{emonitor_name}) if ($edid->{product_code} == 0xc0a8); # PHL 241TE5

		$edid->{emonitor_name} =~ s/^Philips //;
		$edid->{emonitor_name} =~ s/^PHI([0-9])/$1/;
		return (TYPE_TV, $edid->{emonitor_name}) if ($edid->{product_code} == 0xc040); # Philips 201T
		return (TYPE_TV, $edid->{emonitor_name}) if ($edid->{product_code} == 0xc062); # Philips 221TE
		return (TYPE_TV, $edid->{emonitor_name}) if ($edid->{product_code} == 0xc049); # Philips 223E
		return (TYPE_TV, $edid->{emonitor_name}) if ($edid->{product_code} == 0xc046); # Philips 231T
		return (TYPE_TV, $edid->{emonitor_name}) if ($edid->{product_code} == 0xc036); # Philips 244E

#		return (TYPE_TV, "32PFL7605H") if ($edid->{product_code} == 0x0000);		# sky
#		return (TYPE_TV, "32PFL9632D") if ($edid->{product_code} == 0x0000);		# sky
#		return (TYPE_TV, "32PFL7603D") if ($edid->{product_code} == 0x0000);		# sky
#		return (TYPE_TV, "32PFL5403D") if ($edid->{product_code} == 0x0000);		# sky

		return (TYPE_TV, undef) if ($edid->{product_code} == 0x0000);		# sky
		my %hash = (
			0xca14 => "26PFL5522D",
			0x5046 => "32PF5521D",
			0x5046 => "26PF5520D",
		);
		return (TYPE_TV, $hash{$edid->{product_code}}) if (defined $hash{$edid->{product_code}});

		return (TYPE_TV, undef) if ($edid->{emonitor_name} =~ 'PHILIPS');
		return (TYPE_TV, undef) if ($edid->{emonitor_name} eq '');

		return (TYPE_TV, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ 'PFL');
		return (TYPE_TV, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ 'TE');

	    	return (TYPE_AMP, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ '^PHL CS');
	    	return (TYPE_AMP, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ 'Fidelio');

		return (undef, undef);
	}

	if ($edid->{manufacturer_name} eq 'PRI') {      # Prima
		return (TYPE_TV, undef);
	}

	if ($edid->{manufacturer_name} eq 'RCA') {
		return (TYPE_TV, $edid->{emonitor_name});
	}

	if ($edid->{manufacturer_name} eq 'RKU') {	# hisense roku smart tv
		$self->{brand} = "hisense";
		return (TYPE_NO_IR, undef);
	}

	if ($edid->{manufacturer_name} eq 'SNY') {
		my %hash = (
			0x0096 => "KDL32S2000E",
			0x0108 => "KDL32S3000",
#			0x0108 => "KDL26T3000",
			0x0186 => "KDL19L4000",
			0x01a4 => "KDL32W5810",
			0x01ba => "KDL32Z5500",
			0x01ee => "KDL40NX703",
#			0x01ee => "KDL32EX43B",
			0x0230 => "KDL32CX523",
			0x0244 => "KDL32BX320",
			0x027a => "KDL22EX553",
			0x027f => "KDL32EX343",
			0x02dc => "KDL32W655A",
#			0x02dc => "KDL32W653",
			0x0315 => "KDL32R423A",
			0x034b => "KDL32W705",
			0x0358 => "KDL32R433B",

			0x1400 => "MFM-HT75W",
			0x4203 => "KD65X9005B",
			0x5703 => "KDL40R485B",
			0x4803 => "KDL42W815B",
			0x4b03 => "KDL42W705B",

			0xf903 => "KD49X8000E",	# from astro/pesi
		);
		return (TYPE_TV, $hash{$edid->{product_code}}) if (defined $hash{$edid->{product_code}});
#		return (TYPE_TV, $edid->{product_code}) if ($edid->{product_code} =~ '^KD');
#		return (TYPE_TV, $edid->{product_code}) if ($edid->{product_code} =~ '^MFM');
	    	return (TYPE_TV, undef) if ($edid->{emonitor_name} =~ 'SONY TV');

	    	return (TYPE_AMP, undef) if ($edid->{emonitor_name} =~ 'AVAMP');
	    	return (TYPE_AMP, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ 'AV');

		# NOTE: sony amps seems to have the models of the connected devices in the model field
		# these seem to be receivers, showing sony as a brand but a model being a different brand...
		my %hash_amp = (
			0x0200 => 1,
			0x0264 => 1,
			0x0408 => 1,
			0x0409 => 1,
			0x040b => 1,
			0x0459 => 1,
			0x045a => 1,
			0x045b => 1,
			0x045c => 1,
			0x050a => 1,
#			0x1400 => 1,	# MFM-HT75W
			0x2203 => 1,
			0x2303 => 1,
			0x2801 => 1,
			0x2803 => 1,
			0x4003 => 1,
#			0x4203 => 1,
			0x4904 => 1,
			0x5103 => 1,
#PJ			0x5503 => 1,
			0x5504 => 1,
			0x5b00 => 1,
			0x6003 => 1,
#PJ 			0x6203 => 1,
#VPL			0x66f3 => 1,
			0x6b03 => 1,
			0x6c03 => 1,
			0x7403 => 1,
#VPL			0x8bf3 => 1,
			0x9e02 => 1,
			0xa602 => 1,
#VPL			0xaa03 => 1,
			0xad03 => 1,
			0xae03 => 1,
			0xaf03 => 1,
			0xb403 => 1,
			0xb603 => 1,
			0xd802 => 1,
		);
		return (TYPE_AMP, undef) if (defined $hash_amp{$edid->{product_code}});

	    	return (TYPE_PROJ, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ 'VPL');
	    	return (TYPE_PROJ, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ 'SONY PJ');

#		return (undef, undef);
		return (TYPE_TV, undef);
	}

	if ($edid->{manufacturer_name} eq 'SHP') {
		return (TYPE_TV, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ '^LC');
		return (TYPE_TV, $edid->{emonitor_name}) if ($edid->{emonitor_name} =~ '^LE');

		#return (undef, undef);
		return (TYPE_TV, undef);
	}

	if ($edid->{manufacturer_name} eq 'SRD') {
		$self->{brand} = "Haier";
		return (TYPE_TV, undef);
	}

	if ($edid->{manufacturer_name} eq 'TSB') {
		return (TYPE_TV, undef) if ($edid->{emonitor_name} eq 'TOSHIBA-TV');

		my %hash = (
			0x0201 => "32WLT68",	#"STASIA32WLT58",
			0x0401 => "26WLT66",
			0x0501 => "32C3000",	#"32C3000D",
			0x0512 => "26DV665D",	#"26DV665DG",
			0x0612 => "32DV713",
			0x0801 => "32AV833",
			0x0901 => "32RV753",
#			0x0901 => "40WL753",
			0x0a01 => "40VL758",
			0x0b01 => "32RL853",
#			0x0b01 => "32TL868",
#			0x0b01 => "42VL863",
#			0x0b01 => "32RL858",
			0x1001 => "32L4353",
			0x1201 => "32L6453DG",
		);
		return (TYPE_TV, $hash{$edid->{product_code}}) if (defined $hash{$edid->{product_code}});

		return (undef, undef);
	}

	if ($edid->{manufacturer_name} eq 'TV@') {	# philco || electrolux
		$self->{brand} = "Philco";
		$edid->{year} = 0;	# make sure we have all philco's in the results
		return (TYPE_TV, undef) if ($edid->{emonitor_name} eq "PHILCO");
	}

	if ($edid->{manufacturer_name} eq 'UMC') {
		$self->{brand} = "Sharp";
		return (TYPE_TV, undef);
	}

	if ($edid->{manufacturer_name} eq 'VDC') {	# videocon
		return (TYPE_TV, "VU193LD") if ($edid->{product_code} == 0x5303);		# sky
		return (TYPE_TV, "VU326LD") if ($edid->{product_code} == 0x5303);		# sky
		return (undef, undef);
	}

#dent

	if ($edid->{manufacturer_name} eq 'ONK') {	# onkyo
		return (TYPE_AMP, undef) if ($edid->{emonitor_name} =~ 'AV Receiver');

		#$edid->{manufacturer_name} = "+IA" if ($edid->{emonitor_name} =~ '^DTR');	# insignia
		$self->{brand} = "integra" if ($edid->{emonitor_name} =~ '^DTR');	# insignia
		return (TYPE_AMP, $edid->{emonitor_name});	# AMP
	}

	if ($edid->{manufacturer_name} eq 'MJI') {	# marantz
		return (TYPE_AMP, undef) if ($edid->{emonitor_name} =~ 'AVR');

		$edid->{emonitor_name} =~ s/HDMI*$//;
		return (TYPE_AMP, $edid->{emonitor_name});	# AMP
	}

	########################################	
	# PROJ
	########################################	
	if ($edid->{manufacturer_name} eq 'BNQ') {	# benq
		$edid->{emonitor_name} =~ s/^BenQ //;

		return (TYPE_PROJ, undef) if ($edid->{emonitor_name} =~ "BenQ PJ");

		return (TYPE_PROJ, $edid->{emonitor_name});	# PROJ
	}

	if ($edid->{manufacturer_name} eq 'OTM') {	# optoma
		$edid->{emonitor_name} =~ s/^Optoma //;

#		$edid->{emonitor_name} = "UHD60";	# FIXME: just picked one entry as default
#		return (TYPE_PROJ, "UHD60");	# PROJ
		return (TYPE_PROJ, $edid->{emonitor_name});
	}

	########################################	
	if ($edid->{manufacturer_name} eq 'TCL') {
                return (TYPE_TV, undef) if ($edid->{emonitor_name} =~ "DTV");
                return (TYPE_TV, $edid->{emonitor_name});       
        }

	if (
		$edid->{manufacturer_name} eq 'AKA' ||
		$edid->{manufacturer_name} eq 'TCL' ||
		$edid->{manufacturer_name} eq 'VIS' ||
		$edid->{manufacturer_name} eq 'VSC' 	# viewsonic
	) {
		return (TYPE_TV, $edid->{emonitor_name});	# TV
	}

	if ( $edid->{manufacturer_name} eq 'HCG' ||	# 
	    $edid->{manufacturer_name} eq 'LGE' ||	# LG audio
	    $edid->{manufacturer_name} eq 'AGC' ||	# 
	    $edid->{manufacturer_name} eq 'ATM' ||	# anthem
	    $edid->{manufacturer_name} eq 'ANE' ||	# anthem
	    $edid->{manufacturer_name} eq 'CAM') {	# cambridge audio

		return (TYPE_AMP, $edid->{emonitor_name});	# AMP
	}

	########################################	
	# HDMI switch
	########################################	
	if ($edid->{manufacturer_name} eq 'MIT') {
		$self->{brand} = "???";
		return (20, undef);
	}

#	if ($edid->{manufacturer_name} eq 'TTE') {
#		$self->{brand} = "Zoran";
#		return (20, undef);
#	}

	if ($edid->{manufacturer_name} eq 'ZRN') {
		$self->{brand} = "Zoran";
		return (20, undef);
	}

	########################################	
	# HDMI extender
	########################################	
	if ($edid->{manufacturer_name} eq 'SCT') {
		$self->{brand} = "SCT";
		return (TYPE_NO_IR, undef);
	}

	return (undef, undef);
}

sub filter
{
	my ($self, $edid) = @_;

	my @ret = $self->_filter($edid);
	if (defined $ret[1]) {
		$edid->{predefined} = 1;
		return @ret;
	}

	if (defined $ret[0]) {
		return @ret;
	}

	########################################	
	# fallback
	########################################	
	if ($edid->{emonitor_name} =~ 'TV' ||
		$edid->{emonitor_name} =~ 'LCD' ||
		$edid->{emonitor_name} =~ 'WXGA' ||
		$edid->{emonitor_name} =~ 'WUXGA' ||
		$edid->{emonitor_name} =~ 'VIDEO' ||
		$edid->{emonitor_name} =~ 'HDMI') {
		return (TYPE_TV, undef);	# TV
	}

	if ($edid->{emonitor_name} =~ /Sound/i ||
		$edid->{emonitor_name} =~ 'AV' ||
		$edid->{emonitor_name} =~ 'AVR' ||
		$edid->{emonitor_name} =~ 'AMP') {	# AMP
		return (TYPE_AMP, undef);
	}

	if ($edid->{emonitor_name} =~ 'DLP' ||	# 
		$edid->{emonitor_name} =~ 'PJ' ||	# 
		$edid->{emonitor_name} =~ 'PROJECTOR') {	# PROJ
		return (TYPE_PROJ, undef);
	}

	########################################	
	if ($edid->{emonitor_name} eq 'CHHWJT') {
		$self->{brand} = "ChangHong";
		return (TYPE_TV, undef);
	}

	if ($edid->{emonitor_name} eq 'RCA') {
		$self->{brand} = "RCA";
		return (TYPE_TV, undef);
	}

	########################################	
	return (TYPE_ANY, $edid->{emonitor_name});
}

1;
