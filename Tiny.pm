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

    my grammar SimpleCSS {
        token TOP {
            <style>* [ $ || { die "Failed to parse CSS" } ]
        }
        token style {
            \s* (<style_name>+ %% [\s* ',' \s* ]) \s* '{'
                \s* (<property>+ %% [\s* ';' \s* ]) \s*
            '}' \s*
        }
        token style_name { [ <-[\s,{]>+ ]+ % [\s+] }
        token property {
            (<[\w.-]>+) \s* ':' \s* (<-[\s;]>+)
        }
    }

	# Flatten whitespace and remove /* comment */ style comments
	$string ~~ s:g/ \s ** 2..* | '/*' .+? '*/' / /;

	# Split into styles
	for SimpleCSS.parse($string)<style>.list -> $s {
		# Split in such a way as to support grouped styles
		my $style      = $s[0];
		my $properties = ~$s[1];
		my @styles     = $style<style_name>.map(~*);
		for @styles { $self{$_} //= {} }

		# Split into properties
		for $properties.split(';').grep(/\S/) {
			unless /^ \s* (<[\w._-]>+) \s* ':' \s* (.*?) \s* $/ {
				fail "Invalid or unexpected property '$_' in style '$style'";
			}
			for @styles { $self{$_}{lc $0} = ~$1 }
		}
	}

	$self
}

# Copy an object
method clone {
    my %styles_copy;
    for %!styles.kv -> $style, %properties {
        %styles_copy{$style} = { %properties };
    }
    self.new(styles => %styles_copy)
}

# Save an object to a file
method write($file) {
	try { spurt($file, self.write_string) } orelse fail $!;
}

# Save an object to a string
method write_string {

	# Iterate over the styles
	# Note: We use 'reverse' in the sort to avoid a special case related
	# to A:hover even though the file ends up backwards and looks funny.
	# See http://www.w3.org/TR/CSS2/selector.html#dynamic-pseudo-classes
	my $contents = '';
	for self.keys.sort.reverse -> $style {
		$contents ~= "$style \{\n";
		for self{$style}.keys.sort {
			$contents ~= "\t" ~ lc($_) ~ ": {self{$style}{$_}};\n";
		}
		$contents ~= "}\n";
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
