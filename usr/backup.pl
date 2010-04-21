#!/usr/bin/perl

#Adelein Rodriguez


use Getopt::Std;
use Fcntl qw(F_SETLK);
getopts('hd:s:g:f:');



##########GLOBAL VARIABLES#######################################################
$DISKID = 0;
$SIDE = "noside";
$GROUPID = "nogroup";
$FILEPATH;	 	#input from the user
$STATICPATH;	 	#this is the actual spelled out path, so instead pf '.' you have
		 	#'/home/jukebox' or whatever is your current directory
$FILETOCOMPRESS;
$COMPRESSEDFILE;  	#this is the final compressed file that
		 	#will be saved in the spoole directory
$FILELISTING; 		#list of files inside the tar

my $fh;
$QUEUEDIR= "/home/jukebox/share/queue";
$SPOOLDIR="/home/jukebox/share/spool";
$COUNTERFILE="/home/jukebox/share/counterfile";
$UNIQUEJOBID;

#################################################################################

if(! $opt_f || (! $opt_d && ! $opt_g) || ($opt_s && ! $opt_d)){

	&help_msg;
}


if($opt_d){

	$DISKID=$opt_d;
	print "diskid: $DISKID\n";
		
}

if($opt_s){
	
	$SIDE="$opt_s";
	print "side: $SIDE\n";
	if( $SIDE  ne "a" && $SIDE ne "b" ){

		&help_msg;
	}

}
if($opt_g){ $GROUPID = $opt_g; }
if($opt_f){ 

	$FILEPATH=$opt_f; 
	if(! -e "$FILEPATH"){
			
			print "File $FILEPATH does not exists \n";
			exit(-1);
	}
	elsif(-l "$FILEPATH"){
			
			print "File $FILEPATH is a symbolic link\n";
			exit(-1);	
	
	}

}

######################MAIN##############################

&parseFileName;

if ( -d $STATICPATH){
	
	&tarFile;		
}
&queueWrite;

######################SUBS##############################

sub parseFileName{

	`cd $FILEPATH`;
	$STATICPATH=`cd $FILEPATH  ; /bin/pwd`;
	chomp($STATICPATH); #get rid of new line
	print "This is the relative path: $FILEPATH \n";
	print "This is the whole path of the directory: $STATICPATH \n";
	

}
sub tarFile{

	eval{
		
		($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime;
		$mon=$mon+1;
		$year=1900+$year;
		$FILETOCOMPRESS= `basename $STATICPATH`;
		chomp($FILETOCOMPRESS);
		$FILETOCOMPRESS=$FILETOCOMPRESS . $mon . '-' . $mday . '-' . $year .'-'. $hour. '.'.$min.'.'.$sec.'.' . tar.'.'.gz;
		$UNIQUEJOBID=$mon . '-' . $mday . '-' . $year .'-'. $hour. '.'.$min.'.'.$sec;
		print "Unique job id: $UNIQUEJOBID\n";
		print "taredfilename : $FILETOCOMPRESS\n";
		`tar czvf $SPOOLDIR/$FILETOCOMPRESS $STATICPATH`;
		$maxsize=(-s "$SPOOLDIR/$FILETOCOMPRESS")/1024;
		if( $maxsize > 2587590){
			
			print "This file is too big, go save it in your home hd\n";
			`rm -rf $SPOOLDIR/$FILETOCOMPRESS`;
			exit(-1);
		
		} 
		$COMPRESSEDFILE=$FILETOCOMPRESS;				
	};
	print $@;	

}

sub queueWrite{

	eval{
		
		$try=0;
		while(!open (FILE, "+< $COUNTERFILE")){#, wait until file is unlocked, dont try more than 10 times
			
			print "waiting to open counter file\n";
			$try++;
			if($try eq 11){ last;}
			sleep(1);
		}
		
		if( $try le 10){
			
			#lock file
			#fcntl(FILE, F_SETLK, $returnedbuffer) or die "can't fcntl F_SETLK: $!";
			#flock(FILE,2) or die "cannot lock file: $!" ;
			defined(my $line = <FILE>) or die "premature eof";
			chomp($line);
			my $counter=$line;
			$counter ++;
			print "Jobnumber: $counter \n";			
			open JOBFILE, ">> $QUEUEDIR/$counter" or die "Cant create file: $!\n";
			print JOBFILE "WRITE\n$COMPRESSEDFILE\n$GROUPID\n$DISKID\n$SIDE\n";
			#update number of jobs counter
			`echo $counter > $COUNTERFILE`;
			
			close(JOBFILE);
			close(FILE) ;
		}
		else{
			die "Cannot open $COUNTERFILE: $!" ;
				
		}
	
	};
	
	print $@;

}

sub help_msg{
        print STDERR "Use one of the following options combinations\n\n";
	print STDERR "1.\n";
        print STDERR "	-d: disk to be written\n";
	print STDERR "	-s: side to be written\n";
	print STDERR "	-g: group\n";
	print STDERR "	-f: source file to be backed up\n";
	print STDERR "2.\n";
	print STDERR "	-d: disk to be written\n";
	print STDERR "	-s: side to be written\n";
	print STDERR "	-f: source file to be backed up\n";
	print STDERR "3.\n";
	print STDERR "	-g: group\n";
	print STDERR "	-f: source file to be backed up\n";
	print STDERR "4.\n";
	print STDERR "	-d: disk to be written\n";
	print STDERR "	-f: source file to be backed up\n";
        exit(0);
}

