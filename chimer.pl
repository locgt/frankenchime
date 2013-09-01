#!/usr/bin/perl
#Chimer app to play 5 different music files depending on the input from the arduino
#The arduino will feed the serial port with a letter a-e for which sound file : number (1-1024) that represents the strength of the hit.
#This app will take the feedback and play the sound files a fast as possible to simulate a realtime event.  We are leveraging paplay to allow for
#simultaneous files being played and volume control on each stream.
#Ben Miller @vmfoo

use strict;

#Settings
my $sounddir="/home/pi/chimer/sounds/";
my $player = "/usr/bin/sox";
my $writelog = 0;
my $logname = "/tmp/chimer.log";
my $cooldown = "750"; #miliseconds
my %sounds = (A=>'chime1a.wav', B=>'chime2a.wav', C=>'chime3a.wav', D=>'chime4a.wav', E=> 'chime5a.wav');
my $serialport="/dev/ttyAMA0";
my $baud="19200";
my $stty="/bin/stty";


#Set the environment variable for sox to point to alsa
$ENV{AUDIODRIVER}="alsa";

#do some setup
startup();

#Start the main loop
main();

sub startup {
	Log("Initializing chimer");
	srand();  #seed the randomizer

	#set baud rate
	system("$stty -F $serialport $baud");

	#Sound check
	foreach my $key ( keys(%sounds) ) {
		Log("Playing: $sounddir$sounds{$key}");
		#sox chime1a.wav -d -q
		system("$player $sounddir$sounds{$key} -d -q &");
	}
}


sub main {
	Log("Starting read loop");
	#go into read loop
	#while (<STDIN>) {  #Replace STDIN with a serial port for implentation
	open(IN, "<$serialport") or die "Can't open $serialport: $!\n";
	while(<IN>){
		my ($chime,$pwr) = split(':',$_,2);  #pwr should be between 1-1024
		chomp $pwr;
		#error check input
		if (! exists $sounds{$chime} ) {
			#Z exists for testing
			
			#bad chime value
			Log("Bad chime value received: $chime") unless $chime eq 'Z';
			next unless $chime eq 'Z'; #skip this whole loop
		}
		if ($pwr < 0 or $pwr > 1024 ){
			#Bad pwr value
			Log("Bad power value recieved: $pwr");
			$pwr=1024; #set to max just for fun
		}
		strike($chime, $pwr, 0);  #delay is 0 on the first strike
	}	
}

sub strike {
	my($chime, $pwr, $delay) = @_;
	#my $vol = (40*$pwr)+20000;
	my $vol = sprintf("%.2f", nummap($pwr,1,1024,-20,10));
	#gain needs to be between -20 and +20.  Power is 1-1024 so . ..
	Log("Volume of strike $pwr is $vol at delay $delay");
	if ($chime eq 'Z') {  #this creates a 1 sec delay  #testing loop
		sleep 1;
		return;
	}
	system("sleep $delay; $player $sounddir$sounds{$chime} -d -q gain $vol &");
	#pwr is 1-1024 where 1 is the lowest audible strike and 1024 is the most powerful.
	# 1 is the first level above the strike threshold and should be audible
	#for each strike there is a chance that a neighboring chime will be struck.
	#probability is proportional to the diference in pwr and max pwr 1024-pwr
	#lets run the probabilities here and recurse through the function
	my $dif = 1025-$pwr; 
	#do a 1-1025 random roll.  If $rnd > $diff then another chime is hit with $pwr * .75
	my $rnd=int(rand(1024))+1;
	Log("Random roll for another hit: $rnd witch a dif of $dif");
	if ($rnd *3 > $dif) {
		$rnd=int(rand(4))+65; #Generate a random other chime
		while($chime eq chr($rnd)) {  #don't re-hit the same chime
			$rnd=int(rand(4))+65;	
		}
		$chime=chr($rnd);
		$pwr=int($pwr*.75);
		#delay needs to be small, but real so, random to the rescue
		$delay = sprintf("%.2f", rand(1)/2);
		Log("Another chime is hit: $chime at $pwr");
		strike($chime, $pwr, $delay);
	}
	
}

sub nummap(long x, long in_min, long in_max, long out_min, long out_max)
{
	my ($x, $in_min, $in_max, $out_min, $out_max)=@_;
	my $answer= ($x - $in_min) * ($out_max - $out_min) / ($in_max - $in_min) + $out_min;
	return $answer;
}

sub Log {
	my ($message) = shift;
	print now().":  $message\n";
	if ($writelog > 0) {
		open (OUT, ">>$logname");
		print OUT now().":  $message\n";
		close OUT;
	}
}

sub now{
	my ($logsec,$logmin,$loghour,$logmday,$logmon,$logyear,$logwday,$logyday,$logisdst)=localtime(time);
	my $logtimestamp = sprintf("%02d-%02d-%4d %02d:%02d:%02d",$logmon+1,$logmday,$logyear+1900,$loghour,$logmin,$logsec);
	return $logtimestamp;
}


