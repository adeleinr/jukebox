#!/usr/bin/perl
 
#Loads disks into the jukebox, and adds the 
#corresponding jukedb entry
#Author: Adelein Rodriguez

############NOTES###########################################

# - Slot 259 is the top slot where disks are loaded 
# into before going to the slots inside the jukebox

# - In the case when a disk has been unloaded, the 
# entry in the disks table for that disk remains, the 
# only change is that the slot id is 0. This is done so 
# that when a disk is loaded again into the jukebox, 
# there is a record of it already.

# - If one wishes to load a disk again, but as part of 
# a new group, then use option -c to
# specify the new group. A new group will be added
# and the entry of the disk will be updated to be under
# the new group and have the next available slot id. If
# one wishes to load a disk again, but as part of 
# a different existing group, then use option -g to
# specify the other group. 

# - When a new disk is loaded, a new disk entry is created for it.
# Its disk id is obtained from the "insertid" that the mysql
# database returns when it has inserted a new record. This is
# an autoincrement number, be aware that if you remove an entry
# from the database manually, the number will not reused. So
# do NOT remove a disk entry from the database.

#-All disks are loaded by default on side a. So make sure you load the disk
# with side a facing up.

##########################################################
use Getopt::Std;
use lib "/home/jukebox/lib";
use Juke;
use DataInventory;

#Get the shell args
#-h: help, duh
#-g GROUPID: name of group the disk belongs to
#-d DISKNAME: disk number in label
#-n NEW DISK: this is a new disk, assign the next id available
#-c GROUPID: create new group and load disk as part of it
getopts('hng:d:c:');

###############GLOBAL VARIABLES#################
$GROUPID="";
$DISKID=0;
$NEWDISKID=0;#0 if not new, 1 if new
my @data;

####################OPTIONS####################

if((!$opt_g && !$opt_n) && (!$opt_c && !$opt_n) && 
	(!$opt_c && !$opt_d) && (!$opt_g && !$opt_d) && !$opt_d){
	&help_msg;
}
if($opt_c){
	
	&createNewGroup($opt_c);
	$GROUPID=$opt_c;	

}

if($opt_g){

	$GROUPID = $opt_g;
	print "Group name: $GROUPID\n";
}

#either this or the n option
if($opt_d){

	
	$DISKID = "$opt_d";
	print "Disk number: $DISKID\n";
	&checkIfDiskExits;
	#check if a disk with this id is already loaded
	my $sth = $db_handle->prepare('SELECT sid FROM disks WHERE did = ? and not sid = 0')
         or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($DISKID)           # Execute the query
         or die "Couldn't execute statement: " . $sth->errstr;

	if (@data = $sth->fetchrow_array()) {
            
     		$slot = $data[0];
     		print "Disk $DISKID seems to be already loaded into slot $slot\n";
		exit(-1);
	}
	

}
if($opt_n){

	$NEWDISK=1;

}

if(!$opt_n && !$opt_g){
	#set GROUPID to the group the disk was using before it was unloadee
	&getExistingGroup;
}

#give the user help if they request, if they dont, help them anyway =)
if ($opt_h) {
        &help_msg;
} 


######################MAIN PROCESSING##################
print"Processing...............\n";
#1. fetch empty slot

&fetchEmptySlot;

#2. load disk into slot

&loadDiskInJukeBox;

#3. update slots and disks tables


if($NEWDISK == 1){
	print "this is a new disk\n";
	my $sth = $db_handle->prepare('INSERT into disks (gid,sid,a,b,aformat,bformat) values (\'nogroup\',0,0,0,-1,-1)')
        or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute            # Execute the query
        or die "Couldn't execute statement: " . $sth->errstr;
	$DISKID=$db_handle->{'insertid'};		
	print "Disk number: $DISKID\n"; 
}
	
	

my $sth = $db_handle->prepare('UPDATE slots SET did=? WHERE sid=?')
         or die "Couldn't prepare statement: " . $dbh->errstr;
$sth->execute($DISKID,$emptyslotid)            # Execute the query
         or die "Couldn't execute statement: " . $sth->errstr;
	  


my $sth = $db_handle->prepare('UPDATE disks SET sid=?,gid=?,a=1 WHERE did=?')
         or die "Couldn't prepare statement: " . $dbh->errstr;
$sth->execute($emptyslotid,$GROUPID, $DISKID)            # Execute the query
          or die "Couldn't execute statement: " . $sth->errstr;

$sth->finish;
######################SUBS################################
#params: nothing
#return: nothing
sub fetchEmptySlot{
	
	#Select an available slot

	my $sth = $db_handle->prepare('SELECT sid FROM slots WHERE did = 0 and gid = ?
	limit 1')
         or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($GROUPID)           # Execute the query
         or die "Couldn't execute statement: " . $sth->errstr;

	while (@data = $sth->fetchrow_array()) {
            
     		$emptyslotid = $data[0];
     		print "empty slot $emptyslotid\n";
	}
	if ($sth->rows == 0) {
            	print "No slots are empty for group $GROUPID,
		maybe the GROUP you specified doesnt exist?\n\n";
		exit(-1);
	}

	
}
#params: groupid
#return: nothing
sub createNewGroup{

	
	my $sth = $db_handle->prepare('SELECT sid FROM slots WHERE did = 0 and gid = \'nogroup\'')
         or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute           # Execute the query
         or die "Couldn't execute statement: " . $sth->errstr;

	if (@data = $sth->fetchrow_array()) {
            
     		$slotid = $data[0];
     		print "empty slot $emptyslotid\n";
		my $sth = $db_handle->prepare('UPDATE slots set gid=? WHERE sid=?')
         	or die "Couldn't prepare statement: " . $dbh->errstr;
		$sth->execute($_[0],$slotid)            # Execute the query
         	or die "Couldn't execute statement: " . $sth->errstr;

	}
	if ($sth->rows == 0) {
            	print "No slots are empty to create new group: $_[0]\n\n";
		exit(-1);
	}


}

#params: nothing
#return: nothing
sub getExistingGroup{

	my $sth = $db_handle->prepare('SELECT gid FROM disks WHERE did = ?')
         or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($DISKID)           # Execute the query
         or die "Couldn't execute statement: " . $sth->errstr;

	if (@data = $sth->fetchrow_array()) {
            
     		$GROUPID=$data[0];
     		
	}
	if ($sth->rows == 0) {
            	print "There isnt such a Diskid, try with option -n to create new disk entry\n";
		exit(-1);
	}



}
#params: nothing
#return: nothing
sub checkIfDiskExits{

	my $sth = $db_handle->prepare('SELECT * FROM disks WHERE did = ?')
         or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($DISKID)           # Execute the query
         or die "Couldn't execute statement: " . $sth->errstr;

	if (@data = $sth->fetchrow_array()) {
            
     		
     		print "Diskid found\n";
	}
	if ($sth->rows == 0) {
            	print "There isnt such a Diskid, try with option -n to create new disk entry\n";
		exit(-1);
	}

}

#params: nothing
#return: nothing
sub loadDiskInJukeBox{

	`/usr/sbin/mtx -f /dev/sg5 transfer 259 $emptyslotid`;
	$commanderror=`echo $?`;	
	if($commanderror == 256){
	
		print "There was an error, quitting now\n";
		exit(-1);
		
	}

}

#params: nothing
#return: nothing
sub help_msg{
      
	print STDERR "Use one of the following combination of options\n\n";
	print STDERR "1.\n";
        print STDERR "	-g GROUPID: load disk as part of this group\n";
	print STDERR "	-n: disk is new, assign next available id to disk\n\n";
	print STDERR "2.\n";
	print STDERR "	-c GROUPID: create new group and load disk as part of it\n";
	print STDERR "	-n: disk is new, assign next available id to disk\n\n";
	print STDERR "3.\n";
	print STDERR "	-c GROUPID: create new group and load disk as part of it\n";
	print STDERR "	-d DISKID: id assigned previously to disk\n";
	print STDERR "4.\n";	
	print STDERR "	-g GROUPID: load disk again in jukebox, if you want to load disk 
	under a different group just specify another group\n";
	print STDERR "	-d DISKID: id assigned previously to disk\n";
	print STDERR "5.\n";
	print STDERR "	-d DISKID: id assigned previously to disk (keeps the disk under the same GROUPID)\n";
	print STDERR "6. \n";
	print STDERR "	-h Show help\n";
	
        exit(0);
}


