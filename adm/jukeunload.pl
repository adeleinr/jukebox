#!/usr/bin/perl
#jukeread
#Adelein Rodriguez

use Getopt::Std;
use DBI;

$db_handle = DBI->connect("dbi:mysql:database=jukebox-db;host=leopard.cs.fiu.edu:3306;user=jukebox;password=d1llw33d5")
   or die "oops...Couldn't connect to database..maybe you are an idiot?Maybe I am the idiot: $DBI::errstr\n";

#Get the shell args
#[-h]: help, duh
#-d DISKNAME: disk number in label
#-s SLOTID: slot where disk must be unloded from


getopts('h:d:s:');


###############GLOBAL VARIABLES#################
$DISKID=0;
$SLOTID=0;
my @data;

if(!($opt_d && $opt_s) && !$opt_s){&help_msg;}

if($opt_d){

	
	$DISKID = "$opt_d";
	print "Disk number: $DISKID\n";
	
	my $sth = $db_handle->prepare('SELECT sid FROM disks WHERE did = ?')
         or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($DISKID)           # Execute the query
         or die "Couldn't execute statement: " . $sth->errstr;

	if (@data = $sth->fetchrow_array()) {
            
     		$SLOTID = $data[0];
     		print "fetching from slot $SLOTID\n";
	}
	if ($sth->rows == 0) {
            	print "No such disk loaded\n\n";
		exit(-1);
	}
	
	

}
if($opt_s){


	$SLOTID="$opt_s";
	print "Slotid number: $SLOTID\n";
	
	
	my $sth = $db_handle->prepare('SELECT did FROM slots WHERE sid = ?')
         or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($SLOTID)           # Execute the query
         or die "Couldn't execute statement: " . $sth->errstr;

	if (@data = $sth->fetchrow_array()) {
            
     		$DISKID = $data[0];
		
		if($DISKID == 0){
		
			print "No disk loaded into slot\n";
		}
     		print "Diskid: $DISKID\n";
	}
	if ($sth->rows == 0) {
            	print "No such slotid\n\n";
		exit(-1);
	}




}


#give the user help if they request, if they dont, help them anyway =)
if ($opt_h) {
        &help_msg;
} else {
       #&help_msg;
}


######################MAIN PROCESSING##################
print"Processing...............\n";

#1. unload disk into slot

&unloadDiskFromJukeBox;

#2. update slots and disks tables


my $sth = $db_handle->prepare('UPDATE slots SET did=0 WHERE did=?')
         or die "Couldn't prepare statement: " . $dbh->errstr;
$sth->execute($DISKID)            # Execute the query
         or die "Couldn't execute statement: " . $sth->errstr;
	  


my $sth = $db_handle->prepare('UPDATE disks SET sid=0 WHERE did=?')
         or die "Couldn't prepare statement: " . $dbh->errstr;
$sth->execute($DISKID)            # Execute the query
          or die "Couldn't execute statement: " . $sth->errstr;



$sth->finish;
######################SUBS################################
sub help_msg{
	
	print STDERR "\nUse one of the following combinations\n";
	print STDERR "1. \n";
        print STDERR "	-s SLOTID: unload disk from this slot id\n";
	print STDERR "	-d DISKID: disk to be unloaded\n\n";
	print STDERR "2. \n";
	print STDERR "	-s SLOTID: unload disk from this slot id\n";
	exit(0);
}


sub unloadDiskFromJukeBox{


	`/usr/sbin/mtx -f /dev/sg5 transfer $SLOTID 259`;
	$commanderror=`echo $?`;
	if($commanderror==256){
	
		print "There was an error, quitting now\n";
		exit(-1);
		
	}



}





