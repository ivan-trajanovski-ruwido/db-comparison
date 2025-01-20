#!/usr/bin/perl -w

use strict;
use CGI;
use DBI;
use MIME::Base64;
use Data::Dumper;
use String::CRC32;

use DataBase;
use MetaEDID;
use RuwidoSignalList;
use RuwidoEDID;

$CGI::POST_MAX = 1024 * 1024;

my $q = CGI->new;
my %param = $q->Vars;

my $filter = new RuwidoEDID();

my $db = new DataBase();
my $dbh = $db->connect();

my $signalList = new RuwidoSignalList($db, $dbh);

binmode(STDIN);	#NOTE: this is critical for correctly handling the transmitted binary data

my %edid;

use constant TYPE_NO_IR => -1;
use constant TYPE_ANY   => 0;
use constant TYPE_TV    => 1;
use constant TYPE_AMP   => 9;
use constant TYPE_PROJ  => 13;

########################################
$param{edid} =~ s/\ /\+/g;	# TM 20160817 dirty hack
print STDERR "edid=$param{edid}";

$param{edid} = decode_base64($param{edid}) if ($param{edid});
$param{brand} =~ s/^\ +// if ($param{brand});
$param{brand} =~ s/\ +$// if ($param{brand});
$param{model} =~ s/^\ +// if ($param{model});
$param{model} =~ s/\ +$// if ($param{model});

foreach my $item (("key", "fkt", "output", "codes", "revision_id", "project_id", "type_id")) {
	$param{$item} = $q->url_param($item) if (!defined $param{$item});
}

$db->cleanupParam(\%param);

if ($db->{__permission}) {
	my $meta = new MetaEDID();
	my $edid = $meta->parse($param{edid});

	if (!defined $edid) {
		$db->print_error ($q, 200, "Failed to parse EDID information ");
		goto END;
	}

	$edid->{emonitor_name} = '' if (!defined $edid->{emonitor_name});	# TM 20180705
	$edid->{emonitor_name} =~ s/\*//;					# TM 20180718

	########################################

	 my ($brands, $models, $remotes);
        ($param{type_id}, $param{model_name}) = $filter->filter($edid);

	delete $param{model_name} if (defined $param{model_name} && $param{model_name} eq "");

	$param{model_name} = undef if ($edid->{manufacturer_name} eq "SEK");
	$param{brand} = $filter->{brand} if (defined $filter->{brand});

	my @types = ();
	if ($param{type_id} != TYPE_NO_IR) {
		#($brands, $remotes) = get_entries($edid->{manufacturer_id}) unless (defined $brands);
		($brands, $remotes) = get_entries($edid->{manufacturer_name}) unless (defined $brands);

		my @type_tmp = split(/,/, $param{type_id});
		foreach (@type_tmp) {
			push @types, {id => $_, short => "TV"} if ($_ == TYPE_TV || $_ == 0);
			push @types, {id => $_, short => "AMP"} if ($_ == TYPE_AMP);
			push @types, {id => $_, short => "PROJ"} if ($_ == TYPE_PROJ);
		}
	}

	if (defined $remotes) {
		print STDERR "types=" . $param{type_id} . " result=" . $brands->{item}[0]->{name} if (defined $brands && defined $brands->{item});
		$db->print($q, $signalList->{total}, {brands => $brands, types => {item => \@types}, remotes => {total => $signalList->{total}, num => $signalList->{num}, remote => $remotes}}, {-vary => "Accept",
                        -access_control_allow_origin => '*',
                        -access_control_allow_headers => 'content-type,X-Requested-With',
                        -access_control_allow_methods => 'GET,POST,OPTIONS',
                        -access_control_allow_credentials => 'true'
                });
	} else {
		$db->print($q, 0, {remotes => {total => 0, num => 0}}, {-vary => "Accept"});
	}
} else {
	$db->print_error($q, 401, "Unauthorized");
}

END:
$db->disconnect();
exit 0;

sub get_signals
{
        my ($brand_id) = @_;

        my %pa;
        $pa{key} = $param{key};
        $pa{limit} = 3;
        $pa{type_id} = TYPE_TV;
        $pa{type_id} = $param{type_id} if (defined $param{type_id});

        $pa{brand_id} = $brand_id;
        $pa{model_name} = $db->createSearch($param{model_name}) if (defined $param{model_name});

        $pa{fkt} = $param{fkt};

       if ($edid->{year} > 2000 && $edid->{year} <= 2018) {
                if (!defined $pa{model_name}) {
                        $pa{year} = $edid->{year};
                }
        } elsif ($edid->{year} == 0) {
        } else {
                $pa{age} = $pa{type_id} == TYPE_TV ? 7 : 15;
        }

        $pa{compress} = 2;      #$param{compress};

        $signalList->get_signal($q, \%pa);

	# FALLBACK: retry
        if ($signalList->{total} == 0) {
                delete $pa{model_name};
                $signalList->get_signal($q, \%pa);
        }

	if ($signalList->{total} != 0) {
		output_to_base64($signalList) if (!defined $param{output} || $param{output} eq "base64_blob");
	}

        return $signalList->{remote};
}

sub get_pnp
{
	my ($pnp_id) = @_;
	my $sth;

	if ($param{brand}) {
		$sth = $dbh->prepare("SELECT brand.id, brand.name FROM brand WHERE brand.name = ?");
		$sth->execute($param{brand});
	} else {
		$sth = $dbh->prepare("SELECT brand.id, brand.name FROM brand JOIN pnp_to_brand USING brand.id = brand_id AND pnp_to_brand.id = ?");
		$sth->execute($pnp_id);
	}

	my $row = $sth->fetchrow_hashref();
	return ($row->{id}, $row->{name});
}

sub get_entries
{
	my ($pnp_id) = @_;

	my ($brand_id, $brand_name) = get_pnp($pnp_id);

	my $items_brand = { item => [{ name => $brand_name, id => $brand_id }]};
	my $items_signal = undef;

	if ($brand_id) {
		$items_signal = get_signals($brand_id);
	}

	return ($items_brand, $items_signal);
}

sub output_to_base64
{
	my ($signalList) = @_;

	my $txt = "";
	return if (!defined $signalList->{remote});

	foreach my $id (keys $signalList->{remote}) {
		$txt .= pack("C", 0x01);	# version
		$txt .= pack("C", scalar keys $signalList->{remote}[$id]->{signal});	# number of entries
		foreach my $foo (keys $signalList->{remote}[$id]->{signal}) {
			my @arr = split (/,/, $signalList->{remote}[$id]->{signal}[$foo]->{content});
			my $fkt = pack("S", $signalList->{remote}[$id]->{signal}[$foo]->{id});
			my $len_sig = pack("C", scalar @arr);
			my $sig = pack("H*", join "", @arr);

			if ($param{key} eq "4f5f6683e2ed" ||    #hotwire
			    $param{key} eq "b16e7704eafc"       #telus hostpitality
			) {
				if ($param{type_id} == 9) {
					$fkt |= 1 << 12;
				}
			}
			elsif (defined $param{type_id} && $param{output} eq "base64_blob_layer") {
				$fkt |= ($param{type_id} & 0x1f) << 11;
			}

			$txt .= $fkt . $len_sig . $sig;
		}
		delete $signalList->{remote}[$id];
		$txt .= pack("L", crc32($txt));
		$txt = encode_base64($txt);
		$txt =~ s/[\r\n "]+//g;
		$signalList->{remote}[$id]->{base64}->{content} = $txt;
		$txt = "";
	}
}
