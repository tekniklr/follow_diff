#!/opt/local/bin/perl -w

use strict;
use Net::Twitter;
use Data::Dumper;

# twitter user this will operate on
my $username = "tekniklr";

# will run noisily if this is >= 1
my $debug = 1;

# initialize twitter
my $twitter = Net::Twitter->new(legacy => 0);

# file to save followers found from the previous run
my $follower_cache = "/tmp/${username}_followers.txt";

# get follower (ids) as of this moment
my (@new_followers, $now_followers);
$now_followers = $twitter->followers({screen_name=>$username});
($debug > 1) and print Dumper($now_followers);
foreach (@{$now_followers}) {
	push @new_followers, $_->{screen_name};
}
($debug > 1) and print Dumper(\@new_followers);

# if this is the first run, the follower cache won't exist. create it and exit
if (!-e $follower_cache) {
	$debug and print "Creating cache file: $follower_cache\n";
	write_cache();
	exit;
}

# read follower (handles) from the previous run
open(FOLLOWERS,  "$follower_cache") or die ("Could not open follower cache file: $!\n");
my @cached_followers = <FOLLOWERS>;
chomp @cached_followers;
close FOLLOWERS;
my %old_followers;
@old_followers{@cached_followers} = undef;
($debug > 1) and print Dumper(\%old_followers);

# compare old followers to new followers, save the new additions
my @additions;
foreach (@new_followers) {
	if (!exists $old_followers{$_}) {
		push @additions, $_;
		$debug and print "New addition: $_\n";
	}
}
$debug and print @additions." total additions.\n";

# go through the additions,
my @noteworthy_additions;
foreach (@additions) {
	my $handle = $_;
	$debug and print "Checking out how interesting $handle is!\n";
	my $interesting = 0;
	# they are interesting if...
	
	# if they have followers in common with us
	my $their_followers = $twitter->followers({screen_name=>$handle});
	foreach (@{$their_followers}) {
		if (exists $old_followers{$_}) {
			$debug and print "\t$handle has follower $_ in common with $username\n";
			$interesting++;
		}
	}
	
	# or if they have more followers than following
	my $theyre_following = $twitter->following({screen_name=>$handle});
	if (@{$their_followers} > @{$theyre_following}) {
		$debug and print "\t$handle has more people following them (".@{$their_followers}.") than they follow (".@{$theyre_following}.")\n";
		$interesting++;
	}
	elsif ($debug) {
		print "\t$handle has less people following them (".@{$their_followers}.") than they follow (".@{$theyre_following}.")\n";
	}
	
	if ($interesting) {
		$debug and print "\t$handle is interesting!\n";
		push @noteworthy_additions, $handle;
	}
	elsif ($debug) {
		print "\t$handle is not interesting.\n";
	}
}

# get and mail the userinfo for the interesting new additions
my $result_text;
if (@noteworthy_additions) {
	$debug and print @noteworthy_additions." new noteworthy additions!\n";
	$result_text = "The following interesting users have started following you:\n\n";
	foreach (@noteworthy_additions) {
		$result_text .= "\t<a href='http://twitter.com/${_}'>\@${_}</a>\n\n";
	}
	$result_text .= "Woot!\n";
	print $result_text;
}
elsif ($debug) {
	print "No new noteworthy additions.\n"
}

$debug and print "Updating cache file: $follower_cache\n";
write_cache();

# write current followers to follower cache file
sub write_cache {
	open(FOLLOWERS,  ">$follower_cache") or die ("Could not open follower cache file: $!\n");
	foreach (@new_followers) {
		print FOLLOWERS "$_\n";
	}
	close FOLLOWERS;
	exit;
}