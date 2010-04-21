#!/usr/bin/perl

#Adelein Rodriguez
use lib "/home/jukebox/lib";
use Getopt::Std;
use Juke;
getopts("hag:");


###############GLOBAL VARIABLES#################
$GROUPNAME="";
my @data;

##############OPTIONS##########################

if(!$opt_g && !$opt_a){
	&help_msg
}

if($opt_g){

	$GROUPNAME = $opt_g;
	print "Group name: $GROUPNAME\n";
	my $sth = $db_handle->prepare('SELECT did,sid FROM disks where gid=? and not sid=0')
         or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($GROUPNAME)         # Execute the query
         or die "Couldn't execute statement: " . $sth->errstr;

	while (@data = $sth->fetchrow_array()) {
                 		
     		print "Diskid: $data[0] Slotid: $data[1]\n";
		
	}
	
}
if($opt_a){


	my $sth = $db_handle->prepare('SELECT did,gid,sid FROM disks where not sid=0')
         or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute         # Execute the query
         or die "Couldn't execute statement: " . $sth->errstr;

	while (@data = $sth->fetchrow_array()) {
                 		
     		print "Diskid: $data[0] Groupid: $data[1] Slotid: $data[2]\n";
		
	}

}

#give the user help if they request, if they dont, help them anyway =)
if ($opt_h) {
        &help_msg;
} 



######################SUBS################################
sub help_msg{

	print STDERR "\nUse one of the following combination of options\n\n";
	print STDERR "1.\n";
        print STDERR "	-g GROUPNAME: show database entries relavent to GROUPNAME\n\n";
	print STDERR "2.\n";
	print STDERR "	-a Show all entries in the database\n";
	print STDERR "3. \n";
	print STDERR "	-h Show help\n";
	exit(0);
}





