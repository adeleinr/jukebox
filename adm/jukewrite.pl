#!/usr/bin/perl
#jukewrite
#Adelein Rodriguez

######################NOTES#########################################
                   
# - This command is meant to be used only by the jukeserver.
# Its use is as following: 

#	./jukewrite.pl -d $DISKID -s $SIDE -g $GROUPID -f $TAREDFILE -j $file

# The steps involved in writing are: 

# -Find out if disk is in use: If the disk is being used,
# this program will wait (busy waiting) until the "inuse"
# flag in the database is cleared by the process using the disk.
# The program will increase the number of waiting processes by
# 1 to account for this process. It does busy waiting.
	
# - If the users specified a side to be written, then check
# if that side has enough space, if it doesnt, notify the user
# so that he/she picks another side. If the user did not specify
# a side, then check if the current side has enough space. If not,
# try the other side. If at the end, no side with enough space has
# been found, exit with error.
# - Find an empty drive where disk could be sent to. If disk is
# already in a drive use it. Transfer disk to drive. Check if arm
# is not in use as set by the flag in the database, do busy waiting
# for it. Lock arm to let every other process know the arm is in use. 
# If the disk was already in a drive, but is not on the right side,
# unmount it and invert the disk. If the disk is not in drive and is
# on wrong side invert it before putting it in drive.
# - If the side's size is -1, it means the side has not been formatted.
# Format it, and create a file inside the disk specifying the
# disk id(This is called stamping the disk). Mount the disk then.
# -Write compressed file to disk, if when written the original file
# and the one on this are different, there will be an error output
# and the faulty file will be kept in disk but with a .error extension.
# The administrator will also be notified of this error.Then calculate
# the new space left and update it in database. 
# -Record entry and the compressed file's contents in the data folder
# so that the user can look at what each disk has without having to
# read the disk using jukels.

##########################ERROR NUMBERS################################


# 1 > File written to disk is different than original, possible corrupt
# file. File was kept in the disk but with a .error extension. User should
# try to backup file again. A 'cmp' was performed to find this out.

########################################################################

use Getopt::Std;
use Filesys::DiskSpace;
use lib "/home/jukebox/lib";
use Juke;
use DataInventory;

#Get the shell args
#-h: help, duh
#-d DISKNAME: disk number in label
#-s SLOTID: slot where disk must be unloded from
#-n : This could be use instead of -s this just finds a side with enough 
# space for the file
#-j : Job id
getopts('hd:s:g:f:j:');


#############################GLOBAL VARIABLES###########################
$debug=1;
$DISKID=0;
$SLOTID;
$GROUPID="nogroup";
$SIDE="noside"; 	#side that use wants to write on
$FILENAME="";
$FILESIZE=0;
$afreespace=0; 		#free space on disk a
$bfreespace=0; 		#free space on disk b
$SIDETOFORMAT=""; 	#side to be formatted
$INDRIVE=0;		#drive the disk is on, 0 if in no disk
$EMPTYDRIVE;
$DRIVEINUSE;		#by default DRIVEINUSE is equal to the empty drive
 			#unless the disk is already in a drive
$CURRENTSIDE; 		#side that disk in currently on
$needToStamp=0;		#if the disk has just been formatted it needs
			#to be "stamped"  (write a file with its id in the disk)
			#0 means it doesn't need to be stamped
$INUSE;			#0 if no one using disk, 1 otherwise
my @data;		#database statement variable
$MOUNTPOINT ="/mnt/$mountpoints[$DRIVEINUSE-1]";
$JOBID;
$WAITING;		#this flag is set to 1 if job is waiting 
##################################################


print ".............Processing options...........\n";

if($opt_j){ $JOBID=$opt_j; }
if($opt_s){
	
	$SIDE="$opt_s";
	print "Side: $SIDE\n";
	if( $SIDE  ne "a" && $SIDE ne "b" && $SIDE ne "noside"){

		&help_msg;

	}

}
if($opt_g){ $GROUPID=$opt_g; print "Jobid: $JOBID Groupid $GROUPID\n";}
if($opt_f){

	$FILENAME=$opt_f;
	if(! -e "$SPOOLDIR/$FILENAME"){
		
		print "Jobid: $JOBID File $FILENAME does not exists on the $SPOOLDIR\n";
		exit(-1);
	}
	print "Jobid: $JOBID Filename: $FILENAME\n";
	$FILESIZE=(-s "$SPOOLDIR/$FILENAME");
	print "Jobid: $JOBID File size: $FILESIZE bytes\n";
	$FILESIZE=$FILESIZE/1024; #convert to kilobytes
	print "Jobid: $JOBID File size: $FILESIZE kbytes\n";
	
}
if($opt_d){

	$DISKID="$opt_d";
	print "Jobid: $JOBID Diskid: $DISKID\n";	
	
}

else{
	#note that there could be the case thet later on
	#when the disk is about to be written you find
	#out that there is no space because other operation
	#already modified the state of the disk. So this is just 
	#temporarily. Another disk might be used late on.
	print "Jobid: $JOBID No disk specified, fetching a temporary diskid for now: Diskid $DISKID\n";
	if($DISKID == 0){

		$temp=&fetchAvailableDisk($GROUPID,$FILESIZE);
		if($temp > 0) {$DISKID=$temp;}
		else{
			print "Jobid: $JOBID No disk available for group $GROUPID\n";
			exit(-1);
		}
	}

}

#give the user help if they request it, if they dont, help them anyway =)
if ($opt_h) { &help_msg; } 


#################################################
#						#
#		Main Processing			#
#						#
#################################################

print ".......Starting main processing..........\n";

#################################################
#		Locking disk			#
#################################################

print "Step 0. Jobid: $JOBID Checking lock status\n";

#This is so that we dont increase the 
#waiting counter more than once
$WAITING=0;

#Busy waiting loop, wait if disk is being used
while(&diskInUse($DISKID) == 1 ){
	
	if($WAITING != 1){
		&increaseWaitingListCount($DISKID);
	}
	$WAITING=1;
	sleep(10);
	
}
#Mark it as in use
&markDiskInUse($DISKID);

#If it ever had to wait at all 
#decrement waiting counter, else nothing, 
#bz you never incremented the counter anyways
if($WAITING == 1){&decreaseWaitingListCount($DISKID)}; 
#Lets save the current state of the disk
#so that we can try recovering later one

##################################################
#	  Snapshot of disk state   		 #	
##################################################

@savedState=saveDiskState($DISKID);

print "Taking snapshot of state:\n
	[0] aformat:$savedState[0]\n
	[1] bformat:$savedState[1]\n
	[2] a:$savedState[2]\n
	[3] b:$savedState[3]\n
	[4] drive:$savedState[4]\n
	[5] inuse:$savedState[5]\n
	[6] waiting:$savedState[6]\n";							 
##################################################
#	  Fetching disk info from DB	  	 #	
##################################################

print"Step 1. Jobid: $JOBID Init process\n";

#1. Fetch info about the disk, increment jobs counter

&fetchInitInfo($DISKID);		
		
##################################################
#		Finding disk with space	  	 #	
##################################################

#1.5 Find side with enough space, give priority to the side 
#specified by the user if any.

print "Step 1.5 Jobid: $JOBID Finding side with enough space\n";
$SIDE=&findSideWithSpace ($SIDE);

#if after trying with the side that the user wanted, 
#and with the other side of the disk, error

if($SIDE eq "noside"){

	print "Jobid: $JOBID No disk available for writing for group $GROUPID\n";
	&rollBack($DISKID,0,$DRIVEINUSE,@savedState);
	exit(-1);
	
}


##################################################
# Finding drive for disk/Inverting disk 	#	
##################################################

#2. Find empty drive and transfer disk to it
if($INDRIVE == 0){

	print "Step 2. Jobid: $JOBID Finding empty available drive\n";
	&fetchEMPTYDRIVE;

	#3. Transfer disk to drive
	print "Step 3. Jobid: $JOBID Transfering disk to drive\n";
	&transferDiskToDrive;
		
}
else{

	$DRIVEINUSE=$INDRIVE;
	print "Jobid: $JOBID Disk is already in drive $DRIVEINUSE\n";
	print "$CURRENTSIDE $SIDE\n";
	if( $CURRENTSIDE ne $SIDE){
		
		$MOUNTPOINT ="/mnt/$mountpoints[$DRIVEINUSE-1]";
		&umountDisk($MOUNTPOINT);
		print "Jobid: $JOBID Inverting disk\n";
		&invertDisk;
	}

}

##################################################	
#		Formatting disk			 #
##################################################

#5. Format if necessary
if(${$SIDE . freespace}<0){
		$SIDETOFORMAT=$SIDE;
		print "Jobid: $JOBID Free space in side $SIDE ${$SIDE . freespace}\n";
				
}
print "Step 5. Jobid: $JOBID Formatting disk\n";

if($SIDETOFORMAT ne ""){

	print "Jobid: $JOBID Formatting disk $DISKID side $SIDE on drive $drives[$DRIVEINUSE-1]\n";
	$needToStamp=1; #the disk is new, needs to stamp it
	`mke2fs -F -m 0 -b 2048 -j /dev/$drives[$DRIVEINUSE-1]`;
	$commanderror=`echo $?`;
	if($commanderror == 256){
	
		print "There was an error, quitting now\n";
		&rollBack($DISKID,1,$DRIVEINUSE, @savedState);
		exit(-1);
		
	}
	
	$s=$SIDE . "format";
	my $sth = $db_handle->prepare("UPDATE disks SET $s=2587590 WHERE did=?")
	or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($DISKID)            # Execute the query
	or die "Couldn't execute statement: " . $sth->errstr;
	
	${$SIDE . freespace} = 2587590;
	
	print "Jobid: $JOBID Finish formatting disk\n";
	
	$sth->finish;
	&deleteEntries($DISKID,$SIDE);#Remove all the files for this disk/side
			            #that are in the data directory				

}
else{

	print "Jobid: $JOBID Disk already formatted\n";

}

##################################################	
#		Mounting disk			 #
##################################################
#6. Mount disk

$MOUNTPOINT ="/mnt/$mountpoints[$DRIVEINUSE-1]";
print "Step 6. Jobid: $JOBID Mounting disk\n";
&mountDisk;

##################################################	
#		Stamping disk			 #
##################################################
#7. Stamp if necessary

if( $needToStamp == 1){
	print "Step 7 Jobid: $JOBID Stamping disk\n";
	&stampDisk;
}

##################################################	
#		Writing disk			 #
##################################################
#8. Write file to disk

print "Step 8. Jobid: $JOBID Writing file to disk\n";
&writeFile;

##################################################	
#		Calculate Free Space		 #
##################################################
#9. Calculate free space
print "Step 9. Jobid: $JOBID Calculating freespace\n";
&calculateFreeSpace;

##################################################	
#     		Try to unmount disk		 #
##################################################
#10. Check number of jobs waiting for disk
$jobsWaitingForDisk=&jobsWaitingForDisk($DISKID);
print "Step 10. Jobid: $JOBID Number of jobs using disk: $jobsWaitingForDisk\n";

if($jobsWaitingForDisk == 0){

	#11. Unmounting disk
	print "Step 11. Jobid: $JOBID Unmounting disk\n";
	&umountDisk($MOUNTPOINT);
	
	#12. Transfer disk back to slot
	print "Step 12. Jobid: $JOBID Transfering disk to slot\n";
	&transferDiskToSlot($DISKID,$DRIVEINUSE,$SLOTID);
}

##################################################	
#     		Unlock disk			 #
##################################################
#13. Mark disk not in use
print "Srep 13. Jobid: $JOBID Decreasing job counter\n";
&markDiskNotInUSe($DISKID);

##################################################
#						 #
#		Subroutines			 #
#						 #
##################################################

sub help_msg{
        
        print STDERR "jukewrite.pl options:\n";
        print STDERR "-h: show this help file\n";
        print STDERR "-d: disk to be unloaded\n";
	print STDERR "-s | -n: side to be written or else let us choose any available side with enough space\n";
	print STDERR "-g: group\n";
	print STDERR "-f: source file to be backed up\n";
	print STDERR "-j: job number\n";
	print STDERR "./jukewrite.pl -d 0 -s noside -g sys -f jukebox1110233716.tar.gz  -j 3 \n";

        exit(0);
}


sub fetchInitInfo{

	my $sth = $db_handle->prepare("SELECT aformat,bformat,a,b,drive,sid FROM disks WHERE did = ? ")
         or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($_[0])           # Execute the query
         or die "Couldn't execute statement: " . $sth->errstr;

	if (@data = $sth->fetchrow_array()) {
            
     			
		$afreespace=$data[0];
		$bfreespace=$data[1];
			
		#determine which side the disk is on
		if($data[2] == 1){$CURRENTSIDE='a';}
		elsif($data[3] == 1){$CURRENTSIDE='b';}			
		$INDRIVE = $data[4];
		$SLOTID=$data[5];			
     			
	}
	if ($sth->rows == 0) {
            	print "Jobid: $JOBID Couldnt find such disk\n\n";
		exit(-1);
	}
		
	$sth->finish;

}

#params: SIDE, returns side with space
sub findSideWithSpace{
	
	#if the user input a side 
	if($_[0] ne "noside"){	
		if(${$SIDE . freespace} >= $FILESIZE || ${$SIDE . freespace} == -1){
		
			print "Jobid: $JOBID There is enough space the side you specified ($SIDE)\n";
			return $_[0];
		
		} 
		else{	
			print "Jobid: $JOBID There isnt enough space the side you specified ($SIDE)\n";
			return "noside";
			
			
		} 
			
	}else{#need to search for a side with space
	
		#try current side first
		if(${$CURRENTSIDE . freespace} >= $FILESIZE || ${$CURRENTSIDE . freespace} == -1){
		
			print "Jobid: $JOBID Found side $CURRENTSIDE with enough space\n";
			return $CURRENTSIDE;		
		
		}elsif( $CURRENTSIDE eq "a"){
		
			if($bfreespace >= $FILESIZE || ${$bfreespace . freespace} == -1){
				print "Jobid: $JOBID Found side b with enough space\n";
				return "b";			
			
			}
		
		}elsif( $CURRENTSIDE eq "b"){
		
		
			if($afreespace >= $FILESIZE || ${$afreespace . freespace} == -1){
				print "Jobid: $JOBID Found side a with enough space\n";
				return "a";			
			}
		
		}
		
		else {
		
		 print "Jobid: $JOBID Not enough space on any side\n";
		 return "noside";
		
		
		}	
	}
}
sub invertDisk{

	
	while(&isArmBusy== 1){sleep(10);}#wait while arm is busy
	&lockArm($DISKID);

	`$MTX unload 258 $SLOTID`;
	`$MTX invert load 258 $SLOTID`;
	$commanderror=`echo $?`;
	if($commanderror==256){
	
		print "There was an error, quitting now\n";
		&rollBack($DISKID,0,$DRIVEINUSE,@savedState);
		exit(-1);
		
	}
	
	$s1=$SIDE;
	my $sth = $db_handle->prepare("UPDATE disks SET $s1=1,$CURRENTSIDE=0 WHERE did=?")
	or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($DISKID)            # Execute the query
	or die "Couldn't execute statement: " . $sth->errstr;
	$CURRENTSIDE=$SIDE;
	$sth->finish;

	&unlockArm;

}
sub mountDisk{

	print "mount /dev/$drives[$DRIVEINUSE-1] $MOUNTPOINT\n";
	`mount /dev/$drives[$DRIVEINUSE-1] $MOUNTPOINT`;
	$commanderror=`echo $?`;
	
	if($commanderror==256){
	
		print "There was an error, quitting now\n";
		&rollBack($DISKID,0,$DRIVEINUSE,@savedState);
		exit(-1);
		
	}

}



sub stampDisk{

	`touch /mnt/$mountpoints[$DRIVEINUSE-1]/info`;
	`echo $DISKID > /mnt/$mountpoints[$DRIVEINUSE-1]/info`;
	print "echo $DISKID > /mnt/$mountpoints[$DRIVEINUSE-1]/info";
	`chmod a+r /mnt/$mountpoints[$DRIVEINUSE-1]/info`;

}

sub fetchEMPTYDRIVE{

	my $sth = $db_handle->prepare('SELECT drid FROM drives WHERE did = 0 limit 1')
         or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute           # Execute the query
         or die "Couldn't execute statement: " . $sth->errstr;

	while (@data = $sth->fetchrow_array()) {
            
     		$EMPTYDRIVE = $data[0];
		$DRIVEINUSE=$EMPTYDRIVE;
     		print "found empty drive $EMPTYDRIVE\n";
	}
	if ($sth->rows == 0) {
            	print "No empty drives available\n";
		exit(-1);
	}
	$sth->finish;	

}

sub transferDiskToDrive{
	
	while(&isArmBusy== 1){sleep(10);}#wait while arm is busy
	&lockArm($DISKID);
	eval{

		lockArm($DISKID);
		$DRIVEINUSE = $EMPTYDRIVE;
		if($CURRENTSIDE ne $SIDE){
	
				`$MTX invert load $SLOTID $EMPTYDRIVE`;
				$commanderror=`echo $?`;
				if($commanderror==256){
	
					print "There was an error, quitting now\n";
					&rollBack($DISKID,0,$DRIVEINUSE,@savedState);
					exit(-1);
		
				}
		
				#update side info in db
				if($SIDE eq "a"){
		
					my $sth = $db_handle->prepare('UPDATE disks SET a=1,b=0 WHERE did=?')
         				or die "Couldn't prepare statement: " . $dbh->errstr;
					$sth->execute($DISKID)            # Execute the query
         				or die "Couldn't execute statement: " . $sth->errstr;
			
		 		}
	 			elsif($SIDE eq "b"){
	 	
					my $sth = $db_handle->prepare('UPDATE disks SET a=0,b=1 WHERE did=?')
         				or die "Couldn't prepare statement: " . $dbh->errstr;
					$sth->execute($DISKID)            # Execute the query
         				or die "Couldn't execute statement: " . $sth->errstr;	 	
	 
	 			}
		}else{

			`$MTX load $SLOTID $EMPTYDRIVE`;
			 $commanderror=`echo $?`;
			if($commanderror==256){
	
				print "There was an error, quitting now\n";
				&rollBack($DISKID,0,$DRIVEINUSE,@savedState);
				exit(-1);
		
			}
					
		}
		unlockArm($DISKID);
	};
	print $@;
	
	my $sth = $db_handle->prepare('UPDATE drives SET did=? WHERE drid=?')
	or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($DISKID,$EMPTYDRIVE)            # Execute the query
	or die "Couldn't execute statement: " . $sth->errstr;

	my $sth = $db_handle->prepare('UPDATE disks SET drive=? WHERE did=?')
	or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($EMPTYDRIVE,$DISKID)            # Execute the query
	or die "Couldn't execute statement: " . $sth->errstr;
	$sth->finish;	
	&unlockArm;

}

sub writeFile{
 	
	 $filerecorded = $FILENAME; # this is the name of the file written in the disk, and
	 			    #could be different than the name of original file in case
				    #of error. e.g orig file (myfile), file written in disk after
				    #error (myfile.error)
				    	 
	 `cp $SPOOLDIR/$FILENAME $MOUNTPOINT`;
	 
	 $commanderror=`echo $?`;
	 if($commanderror==256){
	
		print "There was an error, quitting now\n";
		&rollBack($DISKID,0,$DRIVEINUSE,@savedState);
		exit(-1);
		
	}
	#compare original data with data copied to disk
	`cmp $SPOOLDIR/$FILENAME $MOUNTPOINT/$FILENAME`;
	$commanderror=`echo $?`;
	if($commanderror==256){
		
		print "There was an error, file written to disk seems to be different than original. File will be kept in disk but renamed to $FILENAME.error\n";
		$renamedfile="$MOUNTPOINT/$FILENAME" .".error";
		$filerecorded=$FILENAME.".error";
		`mv $MOUNTPOINT/$FILENAME $renamedfile`;
		`echo "There was an error, file written to disk $DISKID, side $SIDE seems to be different than original. File will be kept in disk but renamed to $FILENAME.error" | mail -s "[jukebox:1]Copy Error arodr059" arodr059\@cs.fiu.edu -c esj\@cs.fiu.edu`;
		
	}
	
	`rm -rf $SPOOLDIR/$FILENAME`;
	$listing=`tar ztvf $MOUNTPOINT/$filerecorded`;
	&recordEntry($filerecorded,$DISKID,$SIDE,$listing);	
	

}



sub calculateFreeSpace{


	($fs_type, $fs_desc, $used, $avail, $fused, $favail) = df $MOUNTPOINT;
	$s1=$SIDE . "format";
	print "side $s1 \n";
	my $sth = $db_handle->prepare("UPDATE disks SET $s1=? WHERE did=?")
	or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($avail,$DISKID)            # Execute the query
	or die "Couldn't execute statement: " . $sth->errstr;
	print "Free space now: $avail \n";
	$sth->finish;

}
#param: diskid
#returns 1 if in use 0 otherwise
sub diskInUse{

		
	my $sth = $db_handle->prepare("SELECT inuse FROM disks WHERE did = ? ")
         or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($_[0])           # Execute the query
         or die "Couldn't execute statement: " . $sth->errstr;

	if (@data = $sth->fetchrow_array()) {
            
     		
		if($data[0] == 1){return 1;}
		else{$sth->finish; return 0;}
		
	}
	if ($sth->rows == 0) {
            		print "Couldnt find such disk\n\n";
			exit(-1);
	}
	$sth->finish;
	
	

}
sub markDiskInUse{


	my $sth = $db_handle->prepare("UPDATE disks SET inuse=1 WHERE did=?")
	or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($_[0])            # Execute the query
	or die "Couldn't execute statement: " . $sth->errstr;
	print "Locked disk $DISKID\n";
	$sth->finish;
	#$temp=&fetchAvailableDisk($GROUPID,$FILESIZE);

}
sub markDiskNotInUSe{


	my $sth = $db_handle->prepare("UPDATE disks SET inuse=0 WHERE did=?")
	or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($_[0])            # Execute the query
	or die "Couldn't execute statement: " . $sth->errstr;
	print "Unlocked disk $DISKID\n";
	$sth->finish;


}
sub increaseWaitingListCount{

	my $sth = $db_handle->prepare("SELECT waiting FROM disks WHERE did = ? ")
         or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($_[0])           # Execute the query
         or die "Couldn't execute statement: " . $sth->errstr;

	if (@data = $sth->fetchrow_array()) {
            
     		
		$data[0] =$data[0]+1;
	}
	if ($sth->rows == 0) {
            		print "Couldnt find such disk\n\n";
			exit(-1);
	}
		
	my $sth = $db_handle->prepare("UPDATE disks SET waiting=? WHERE did=?")
	or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($data[0],$_[0])            # Execute the query
	or die "Couldn't execute statement: " . $sth->errstr;
	print "Increased num of waiting jobs to $data[0] for disk $DISKID\n";
	$sth->finish;
	return $data[0];
		

}
sub decreaseWaitingListCount{

	$WAITING = 0;
	my $sth = $db_handle->prepare("SELECT waiting FROM disks WHERE did = ? ")
         or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($_[0])           # Execute the query
         or die "Couldn't execute statement: " . $sth->errstr;

	if (@data = $sth->fetchrow_array()) {
            
     		
		$data[0] =$data[0]-1;
	}
	if ($sth->rows == 0) {
            		print "Couldnt find such disk\n\n";
			exit(-1);
	}$temp=&fetchAvailableDisk($GROUPID,$FILESIZE);

		
	my $sth = $db_handle->prepare("UPDATE disks SET waiting=? WHERE did=?")
	or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($data[0],$_[0])            # Execute the query
	or die "Couldn't execute statement: " . $sth->errstr;
	print "Decreased num of waiting jobs to $data[0] for disk $DISKID\n";
	$sth->finish;
	return $data[0];

}
sub jobsWaitingForDisk{


	my $sth = $db_handle->prepare("SELECT waiting FROM disks WHERE did = ? ")
         or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($_[0])           # Execute the query
         or die "Couldn't execute statement: " . $sth->errstr;

	if (@data = $sth->fetchrow_array()) {
            
     		
		return $data[0];
	}
	if ($sth->rows == 0) {
            		print "Couldnt find such disk\n\n";
			exit(-1);
	}

	$sth->finish;

}

