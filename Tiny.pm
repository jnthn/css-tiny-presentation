class CSS::Tiny:ver<1.19>;

BEGIN {
	require 5.004;
	$CSS::Tiny::errstr  = '';
}

# Create an empty object
sub new { bless {}, shift }

# Create an object from a file
sub read {
	my $class = shift;

	# Check the file
	my $file = shift or return $class->_error( 'You did not specify a file name' );
	return $class->_error( "The file '$file' does not exist" )          unless -e $file;
	return $class->_error( "'$file' is a directory, not a file" )       unless -f _;
	return $class->_error( "Insufficient permissions to read '$file'" ) unless -r _;

	# Read the file
	local $/ = undef;
	open( CSS, $file ) or return $class->_error( "Failed to open file '$file': $!" );
	my $contents = <CSS>;
	close( CSS );

	$class->read_string( $contents )
}

# Create an object from a string
sub read_string {
	my $self = ref $_[0] ? shift : bless {}, shift;

	# Flatten whitespace and remove /* comment */ style comments
	my $string = shift;
	$string =~ tr/\n\t/  /;
	$string =~ s!/\*.*?\*\/!!g;

	# Split into styles
	foreach ( grep { /\S/ } split /(?<=\})/, $string ) {
		unless ( /^\s*([^{]+?)\s*\{(.*)\}\s*$/ ) {
			return $self->_error( "Invalid or unexpected style data '$_'" );
		}

		# Split in such a way as to support grouped styles
		my $style      = $1;
		my $properties = $2;
		$style =~ s/\s{2,}/ /g;
		my @styles = grep { s/\s+/ /g; 1; } grep { /\S/ } split /\s*,\s*/, $style;
		foreach ( @styles ) { $self->{$_} ||= {} }

		# Split into properties
		foreach ( grep { /\S/ } split /\;/, $properties ) {
			unless ( /^\s*([\w._-]+)\s*:\s*(.*?)\s*$/ ) {
				return $self->_error( "Invalid or unexpected property '$_' in style '$style'" );
			}
			foreach ( @styles ) { $self->{$_}->{lc $1} = $2 }
		}
	}

	$self
}

# Copy an object, using Clone.pm if available
BEGIN { local $@; eval "use Clone 'clone';"; eval <<'END_PERL' if $@; }
sub clone {
	my $self = shift;
	my $copy = ref($self)->new;
	foreach my $key ( keys %$self ) {
		my $section = $self->{$key};
		$copy->{$key} = {};
		foreach ( keys %$section ) {
			$copy->{$key}->{$_} = $section->{$_};
		}
	}
	$copy;
}
END_PERL

# Save an object to a file
sub write {
	my $self = shift;
	my $file = shift or return $self->_error( 'No file name provided' );

	# Write the file
	open( CSS, '>'. $file ) or return $self->_error( "Failed to open file '$file' for writing: $!" );
	print CSS $self->write_string;
	close( CSS );
}

# Save an object to a string
sub write_string {
	my $self = shift;

	# Iterate over the styles
	# Note: We use 'reverse' in the sort to avoid a special case related
	# to A:hover even though the file ends up backwards and looks funny.
	# See http://www.w3.org/TR/CSS2/selector.html#dynamic-pseudo-classes
	my $contents = '';
	foreach my $style ( reverse sort keys %$self ) {
		$contents .= "$style {\n";
		foreach ( sort keys %{ $self->{$style} } ) {
			$contents .= "\t" . lc($_) . ": $self->{$style}->{$_};\n";
		}
		$contents .= "}\n";
	}

	return $contents;
}

# Generate a HTML fragment for the CSS
sub html {
	my $css = $_[0]->write_string or return '';
	return "<style type=\"text/css\">\n<!--\n${css}-->\n</style>";
}

# Generate an xhtml fragment for the CSS
sub xhtml {
	my $css = $_[0]->write_string or return '';
	return "<style type=\"text/css\">\n/* <![CDATA[ */\n${css}/* ]]> */\n</style>";
}

# Error handling
sub errstr { $CSS::Tiny::errstr }
sub _error { $CSS::Tiny::errstr = $_[1]; undef }

1;
