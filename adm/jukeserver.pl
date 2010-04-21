#!/usr/bin/perl
#jukeread
#Adelein Rodriguez
use lib "/home/jukebox/lib";
use Juke;


#########GLOBALS####################

$TAREDFILE;
$DISKID=0;
$SIDE="noside";
$GROUPID="nogroup";
$ACTION; #read or write
@queue;
my $fh;
####################################


while(1){

	
	eval{
		@queue=`ls $QUEUEDIR`;
		foreach $file (@queue){
			chomp($file);
			print "jobnumber: $file \n";
			&readInstruction("$file");
			print "action: $ACTION \n";
			print "file to write: $TAREDFILE\n";
			print "group: $GROUPID\n";
			print "diskid :$DISKID\n";
			print "side if any: $SIDE\n";
			
		
			#send job to jukewrite
			if (($pid = fork) == 0)
       			{
				exec( "./jukewrite.pl -d $DISKID -s $SIDE -g $GROUPID -f $TAREDFILE -j $file");	
				exit (1);
       			}
       			elsif ($pid > 0){
         			
       			}
       			else
       			{
        			 print ("Could not fork: errno is $!\n");
       			}
		
			$try=0;
			while(!open (COUNTER, "+< $COUNTERFILE")){#wait until file is unlocked, dont try more than 10 times
				print "waiting\n";
				$try++;
				if($try eq 11){ last;}
				sleep(10);
			}
		
			if( $try le 10){
			
				#lock file
				flock(COUNTER,2) or die "cannot lock file: $!" ;
				defined(my $line = <COUNTER>) or die "premature eof";
				chomp($line);
				my $counter=$line;
				$counter --;
				#update counter
				`echo $counter > $COUNTERFILE`;
				 close(COUNTER) ;
			}
			else{ die "Cannot open $COUNTERFILE: $!" ;}
		
			`rm -rf $QUEUEDIR/$file`;
			
			$commanderror=`echo $?`;
			if($commanderror==256){
	
				print "There was an error, quitting now\n";
				exit(-1);
		
			}
			print "Removed job $file from queue\n";
			sleep(5);
	
		}#end foreach
	
	};
	print $@;

	sleep(10);

}

sub readInstruction{

		local($file)=$_[0];
		chomp($file);
		open (FILE, "+< $QUEUEDIR/$file") or die "could not open file";
		defined(my $line = <FILE>) or die "premature eof";
		chomp($line);
		$ACTION=$line;
		defined(my $line = <FILE>) or die "premature eof";
		chomp($line);
		$TAREDFILE=$line;
		defined(my $line = <FILE>) ;
		chomp($line);
		$GROUPID=$line;
		defined(my $line = <FILE>) or die "premature eof";
		chomp($line);
		$DISKID=$line;
		defined(my $line = <FILE>) ;
		chomp($line);
		$SIDE=$line;
			
		close(FILE);

}
