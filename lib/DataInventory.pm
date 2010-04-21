package DataInventory; 
require Exporter;
#use Juke;

use Fcntl qw(:DEFAULT :flock);

our @ISA = qw(Exporter);
our @EXPORT = qw($DATA recordEntry retrieveFileList retrieveDetailedFileList deleteEntries);


$DATA="/home/jukebox/share/data";


   
#params: Filename, diskid, side, list of files inside tar
#returns: nothing
sub recordEntry{

	
	if(! -e "$DATA/$_[1]/$_[2]"){#if folder does not exist create it plus create side folder
	
		`mkdir -p $DATA/$_[1]/$_[2]/`; #/home/jukebox/data/diskid/side/
	
	}
	
	open FILE,">> $DATA/$_[1]/$_[2]/$_[0]" or die " could not create file: $!";
	print FILE "$_[3]";
	close FILE;
	
}

#params: diskid, side
sub deleteEntries{

	`rm -rf $DATA/$_[0]/$_[1]/*`;

}
#params: diskid, side
#returns: nothing
sub retrieveFileList{

	print "Side $_[1]\n"; 
	if(! -e "$DATA/$_[0]/$_[1]"){
	
		
	
	}
	else{
		
		@list=`ls $DATA/$_[0]/$_[1]`;
		foreach $file (@list){ 
			print "$file";
				
		}
		
	}
	


}

#params: diskid, tarfilename
#returns: nothing
sub retrieveDetailedFileList{


	print "Side $_[1]\n"; 
	if(! -e "$DATA/$_[0]/$_[1]"){		
	
	}
	else{

		@list=`ls $DATA/$_[0]/$_[1]`;
		foreach $file (@list){ 
			print "$file";
			$filetree = `cat $DATA/$_[0]/$_[1]/$file`;
			print ".........................\n$filetree\n";
				
		}
		
	}
	

}

1; 