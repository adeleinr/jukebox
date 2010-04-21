package Juke; 
require Exporter;
use DBI;


our @ISA = qw(Exporter);
our @EXPORT = qw(checkIfDiskExits 
		fetchAvailableDisk 
		saveDiskState 
		$MTX 
		transferDiskToSlot 
		umountDisk 
		@drives 
		@mountpoints
		$QUEUEDIR
		$SPOOLDIR
		$COUNTERFILE
		lockArm
		unlockArm
		isArmBusy
		$db_handle
		rollBack);


$db_handle = DBI->connect("dbi:mysql:database=jukebox-db;host=leopard.cs.fiu.edu:3306;user=jukebox;password=d1llw33d5")
   or die "oops...Couldn't connect to database..maybe you are an idiot?Maybe I am the idiot: $DBI::errstr\n";


#my @diskState;
$QUEUEDIR= "/home/jukebox/share/queue";
$SPOOLDIR="/home/jukebox/share/spool";
$COUNTERFILE="/home/jukebox/share/counterfile";
$MTX ="/usr/sbin/mtx -f /dev/sg5";
@drives=("sda","sdb","sdc","sdd","sde");
@mountpoints=("sd1","sd2","sd3","sd4","sd5");


#params: diskid
#returns: 0 if disk doesnt exit, 1 otherwise
sub checkIfDiskExits{

	my $sth = $db_handle->prepare('SELECT * FROM disks WHERE did = ?')
         or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($_[0])           # Execute the query
         or die "Couldn't execute statement: " . $sth->errstr;

	if (@data = $sth->fetchrow_array()) {
     		
     		print "Diskid $_[0] found\n";
		$sth->finish;
		return 1;
	}
	elsif ($sth->rows == 0) {
            	print "There isnt such a Diskid\n";
		$sth->finish;
		return 0;
	}
	
}

#params: groupid, filesize
#returns: disknumber or 0 if no disk available
sub fetchAvailableDisk{
	
	#Select an available slot

	my $sth = $db_handle->prepare('SELECT did FROM disks WHERE ( aformat > ? or bformat > ? or aformat < 0 or bformat < 0) and gid = ? limit 1')
         or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($_[1],$_[1],$_[0])           # Execute the query
         or die "Couldn't execute statement: " . $sth->errstr;

	if (@data = $sth->fetchrow_array()) {
            
     		print "available disk $data[0]\n";
		#$sth->finish;
		return $data[0];
     		
	}
	elsif ($sth->rows == 0) {
            	print "No disks are empty for group $GROUPNAME\n\n";
		$sth->finish;
		return 0;
	}

	
}
# #params: diskid
# #returns: diskState array with all the initial values from the disk table
# #that belong to this disk, this will be used for rolling back writes
# #diskstate array description:
# #[0] aformat
# #[1] bformat
# #[2] a
# #[3] b
# #[4] drive
# sub saveDiskState{
# 
# 	
# 	my $sth = $db_handle->prepare("SELECT aformat,bformat,a,b,drive FROM disks WHERE did = ? ")
#          or die "Couldn't prepare statement: " . $dbh->errstr;
# 	$sth->execute($_[0])           # Execute the query
#          or die "Couldn't execute statement: " . $sth->errstr;
# 
# 	if (@data = $sth->fetchrow_array()) {
#             
#      			
# 		@diskState=@data;
# 				
#      			
# 	}
# 	if ($sth->rows == 0) {
#             	print "Jobid: $JOBID Couldnt find such disk\n\n";
# 		$sth->finish;
# 		exit(-1);
# 	}
# 	
# 		
# 	
# 	return @diskState;
# 
# 
# }

# #params: diskid,waiting flag(to know whether the process never got to reset the waiting
# # flag or not, arm flag
# #return: nothing
# #state list has:
# #[0] aformat
# #[1] bformat
# #[2] a
# #[3] b
# #[4] drive
# #[5] drive to remove disk from
# sub rollBack{
# 
# 	my $sth = $db_handle->prepare("SELECT drive,waiting,sid from disks WHERE did=?")
# 	or die "Couldn't prepare statement: " . $dbh->errstr;
# 	$sth->execute($_[0])	
# 	or die "Couldn't execute statement: " . $sth->errstr;
# 	if (@data = $sth->fetchrow_array()) {
#             
#      		$waiting =$data[1];
# 		print "Initial state: $diskState[0],$diskState[1],$diskState[2],$diskState[3],$diskState[4], waiting = $waiting \n";
# 		if($_[1] == 1 ){#if process never reset the waiting flag 
# 	
# 		
# 			$waiting=$waiting - 1;
# 	
# 		}
# 		if($data[0] > 0 && ($data[1] == 0)){#if it is in drive but not waiting 
# 	
# 		
# 			&umountDisk($data[0]);
# 			&transferDiskToSlot($_[0],$_[5],$data[2]);
# 	
# 		}
# 	}	
# 	if ($sth->rows == 0) {
#             	print "No such disk loaded\n\n";
# 		exit(-1);
# 	}
# 	
# 
# 	my $sth = $db_handle->prepare("UPDATE disks SET aformat=?,bformat=?,a=?,b=?,drive=?,inuse=0, waiting=? WHERE did=?")
# 	or die "Couldn't prepare statement: " . $dbh->errstr;
# 	$sth->execute($diskState[0],$diskState[1],$diskState[2],$diskState[3],$diskState[4],$waiting,$_[0])            
# 	or die "Couldn't execute statement: " . $sth->errstr;
# 	$sth->finish;
# 
# 
# 
# }


#params: diskid
#returns: diskState array with all the initial values from the disk table
#that belong to this disk, this will be used for rolling back writes
#diskstate array description:
#[0] aformat
#[1] bformat
#[2] a
#[3] b
#[4] drive
#[5]inuse
#[6]waiting
sub saveDiskState{

	print"Saving state\n";
	my $sth = $db_handle->prepare("SELECT aformat,bformat,a,b,drive,inuse,waiting FROM disks WHERE did = ? ")
         or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($_[0])           # Execute the query
         or die "Couldn't execute statement: " . $sth->errstr;

	if (@data = $sth->fetchrow_array()) {
            
     			
		@diskState=@data;
				
     			
	}
	if ($sth->rows == 0) {
            	print "Jobid: $JOBID Couldnt find such disk\n\n";
		$sth->finish;
		exit(-1);
	}
		
	return @diskState;


}
#params: diskid,waiting flag(to know whether the process never got to reset the waiting
# flag or not, isarminuse flag, @savedstate
#return: nothing

sub rollBack{

	#retrieve saved state
	print "Rolling back state\n";
	($diskid,$waiting,$isarminuse,@savedstate)=@_;
	print "Received state:\n diskid:$diskid, waiting:$waiting,is arm in use:$isarminuse\n
	Previously saved stated:\n
	[0] aformat:$savedstate[0]\n
	[1] bformat:$savedstate[1]\n
	[2] a:$savedstate[2]\n
	[3] b:$savedstate[3]\n
	[4] drive:$savedstate[4]\n
	[5] inuse:$savedstate[5]\n
	[6] waiting:$savedstate[6]\n";
	
	#retrieve info needed of current state, not all
	my $sth = $db_handle->prepare("SELECT drive,waiting,sid from disks WHERE did=?")
	or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($_[0])	
	or die "Couldn't execute statement: " . $sth->errstr;
	if (@data = $sth->fetchrow_array()) {
            
		$drive=$data[1];
     		$currentwaiting =$data[1];
		$sid=$data[2];
		
		
		if($waiting == 1 ){#if process never reset the waiting flag 
			
			$currentwaiting=$currentwaiting - 1;	
		}
		if($drive > 0 && ($currentwaiting == 0)){#if it is in drive but no one waiting for disk, put it back 
	
		
			&umountDisk($data[0]);
			&transferDiskToSlot($diskid,$savedstate[4],$sid[2]);
	
		}
	}	
	elsif ($sth->rows == 0) {
            	print "No such disk loaded\n\n";
		exit(-1);
	}
	

	my $sth = $db_handle->prepare("UPDATE disks SET aformat=?,bformat=?,a=?,b=?,drive=?,inuse=0, waiting=? WHERE did=?")
	or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($savedstate[0],$savedstate[1],$savestate[2],$savestate[3],$savestate[4],$currentwaiting,$diskid)            
	or die "Couldn't execute statement: " . $sth->errstr;
	$sth->finish;
	exit(-1);


}


#param: mount point
#return: nothing
sub umountDisk{
	
	$ls = `ls $_[0]`;
	print "$ls";
	`sync`;
	`umount $_[0]`;
	
}

#param: diskid, drive where the disk is at, slotid
sub transferDiskToSlot{

	while(&isArmBusy == 1){sleep(10);}#wait while arm is busy
	&lockArm($DISKID);

	`$MTX unload $_[2] $_[1]`;
		
	my $sth = $db_handle->prepare('UPDATE disks SET drive=0 WHERE did=?')
        or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($_[0])            # Execute the query
        or die "Couldn't execute statement: " . $sth->errstr;
	
	
	my $sth = $db_handle->prepare('UPDATE drives SET did=0 WHERE drid=?')
        or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($_[1])            # Execute the query
        or die "Couldn't execute statement: " . $sth->errstr;
	$sth->finish;
	unlockArm;
}



#param: diskid
#returns: nothing
#description: this function sets the flag to the diskid for driver # 6 (jukebox's arm) in the DB
sub lockArm{
	

	my $sth = $db_handle->prepare('UPDATE drives SET did=? WHERE drid=6')
        or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($_[0])            # Execute the query
        or die "Couldn't execute statement: " . $sth->errstr;	
	$sth->finish;




}

#param: nothing
#returns: nothing
#description: this function sets the flag to 0 for driver # 6 (jukebox's arm) in the DB
sub unlockArm{


	my $sth = $db_handle->prepare('UPDATE drives SET did=0 WHERE drid=6')
        or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute          # Execute the query
        or die "Couldn't execute statement: " . $sth->errstr;	
	$sth->finish;




}
#param: nothing
#returns : 0 if arm busy, 1 otherwise
sub isArmBusy{

	my $sth = $db_handle->prepare('SELECT * FROM drives WHERE drid=6 AND did=0 ')
        or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute            # Execute the query
        or die "Couldn't execute statement: " . $sth->errstr;	
	if (@data = $sth->fetchrow_array()) {
	
            	$sth->finish;
		return 0;#arm is not busy
     		
	}
	elsif ($sth->rows == 0) {
	
		$sth->finish;
            	return 1;#arm is busy
	}
	


}


1;              
