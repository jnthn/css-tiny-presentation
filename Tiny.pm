use v6;

class CSS::Tiny:ver<1.19>;

has %!styles handles <at_key assign_key list pairs keys values kv>;

# Create an object from a file
method read($file) {
	# Check the file
    given $file.IO {
        fail "The file '$file' does not exist"          unless .e;
        fail "'$file' is a directory, not a file"       unless .f;
        fail "Insufficient permissions to read '$file'" unless .r;
    }

	# Read the file
    my $contents = try { slurp($file) } orelse fail $!;

	self.read_string($contents)
}

# Create an object from a string
method read_string($string is copy) {
	my $self = self // self.new;

	# Flatten whitespace and remove /* comment */ style comments
	$string ~~ s:g/ \s ** 2..* | '/*' .+? '*/' / /;

	# Split into styles
	for $string.split(/<?after '}'>/).grep(/\S/) {
		unless /^ \s* (<-[{]>+?) \s* '{' (.*) '}' \s* $/ {
			fail "Invalid or unexpected style data '$_'";
		}

		# Split in such a way as to support grouped styles
		my $style      = ~$0;
		my $properties = ~$1;
		$style ~~ s:g/\s ** 2..*/ /;
		my @styles = $style.split(/\s* ',' \s*/).grep(/\S/).map({ s:g/\s+/ / });
		for @styles { $self{$_} //= {} }

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
method write($file) {
	try { spurt($file, self.write_string) } orelse fail $!;
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
method html {
	my $css = self.write_string or return '';
	return "<style type=\"text/css\">\n<!--\n{$css}-->\n</style>";
}

# Generate an xhtml fragment for the CSS
method xhtml {
	my $css = self.write_string or return '';
	return "<style type=\"text/css\">\n/* <![CDATA[ */\n{$css}/* ]]> */\n</style>";
}

1;
