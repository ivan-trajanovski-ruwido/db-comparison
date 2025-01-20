#!/usr/bin/perl -w

package DataBaseConfig;

$CFG = {
	db		=> "DBI:mysql:ruwido_rc;host=master.cxvyjjpvca39.eu-central-1.rds.amazonaws.com",
	db_schema_rc	=> "DBI:mysql:ruwido_rc;host=master.cxvyjjpvca39.eu-central-1.rds.amazonaws.com",
	db_schema_meta	=> "DBI:mysql:ruwido_rc_meta;host=master.cxvyjjpvca39.eu-central-1.rds.amazonaws.com",
	db_schema_feedback	=> "DBI:mysql:ruwido_rc_feedback;host=master.cxvyjjpvca39.eu-central-1.rds.amazonaws.com",
	db_user		=> "ruwido_rc",
	db_pass		=> "9tzllxt9",
	dbh		=> undef,
	_default_limit	=> 50,
	_default_type_id=> 1,
};

1;
