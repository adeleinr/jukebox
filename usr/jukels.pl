#!/usr/bin/perl

#Adelein Rodriguez

use Getopt::Std;
use lib "/home/jukebox/lib";
use DataInventory;
  
#Get the shell args
#-h: help, duh
#-d DISKNAME: disk number in label
getopts("hd:s:l");

###############GLOBAL VARIABLES#################

$DISKID;
$SIDE="noside";




if( !$opt_d && !($opt_d && $opt_l)){
	
	&help_msg;

}
if($opt_h){

	&help_msg;
}

#this is required
if($opt_d){
	
	$DISKID = $opt_d;
	
}

if($opt_s){

	$SIDE = $opt_s;

}
if($opt_l){

	if($SIDE ne "noside"){
		&retrieveDetailedFileList($DISKID,$SIDE);
	}
	else{
	
		&retrieveDetailedFileList($DISKID,a);
		&retrieveDetailedFileList($DISKID,b);

	}	
		

}
else{

	if($SIDE ne "noside"){
		&retrieveFileList($DISKID,$SIDE);
	}
	else{
	
		&retrieveFileList($DISKID,a);
		&retrieveFileList($DISKID,b);

	}

}

######################SUBS################################
sub help_msg{
	print STDERR "Use one of the following options combinations\n\n";
	print STDERR "1.\n";
        print STDERR "	-d: disk to be written\n";
	print STDERR "2.\n";
	print STDERR "	-d: disk to be written\n";
	print STDERR "	-l print content of folders as well\n";
	exit(0);
}





