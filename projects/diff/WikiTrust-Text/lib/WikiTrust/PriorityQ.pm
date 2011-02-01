package WikiTrust::PriorityQ;

use 5.006;
use strict;
use warnings;
use vars qw($VERSION);

$VERSION = '0.02';


# Constructor. Enables Inheritance
sub new {
	my $this = shift;
	my $class = ref($this) || $this;
	my $self = {};
	bless $self, $class;
	$self->{priorities} = [];
	return $self;
}

sub findPriorityPoint {
    my ($self, $val) = @_;

    my $min = 0;
    my $max = @{ $self->{priorities} } - 1;
    my $mid = $min;
    while ($min <= $max) {
	$mid = $min + int( ($max - $min) / 2 );
	my $found = $self->{priorities}->[$mid]->[0];
	my $cmp = $val <=> $found;
	if ($cmp > 0) {
	    $min = $mid + 1;
	} elsif ($cmp < 0) {
	    $max = $mid - 1;
	} else {
	    # exact match, so we're done.
	    return $mid;
	}
    }
    # we always want to splice in $val at location $min
    splice( @{ $self->{priorities} }, $min, 0, [$val, []] );
    return $min;
}

# Insert an element into the list
# Duplicates are not allowed - might be optional if needed in the future
sub insert {
	# Arguments check
	return 'List::Priority - Expected 3 arguements!' if (scalar(@_) != 3);
	
	# Argument assignment
	my $self = shift;
	my $priority = shift;
	my $object = shift;
	
	my $pos = $self->findPriorityPoint($priority);
	die "Bad priority" if $self->{priorities}->[$pos]->[0] != $priority;
	# Insert
	push(@{ $self->{priorities}->[$pos]->[1] }, $object);
	return 1;
}

sub pop {
    my $self = shift;
    return undef if @{ $self->{priorities} } == 0;
    my $item = pop( @{ $self->{priorities}->[-1]->[1] });
    pop(@{ $self->{priorities} }) if @{ $self->{priorities}->[-1]->[1] } == 0;
    return $item;
}

1;
