sub MAIN(
        $template = 'presentation/template.html',
        $output   = 'presentation/index.html') {
    my @pieces = slurp($template).split('<!--STORY-->');
    die "Template file missing magical <!--STORY-->"
        unless @pieces == 2;

    my @commits     = parse_log();
    my $slides_html = make_html(@commits);

    spurt $output, "@pieces[0]$slides_html@pieces[1]";
}

grammar CommitLog {
    token TOP {
        <commit>*
        [ $ || { die "Failed to parse commit log at $/.CURSOR.target.substr($/.CURSOR.pos, 20)..." } ]
    }

    token commit {
        'commit'  \s+ $<sha1>=[<.xdigit>+] \n
        'Author:' \s+ $<author>=[\N+]      \n
        'Date:'   \s+ $<date>=[\N+]        \n
        \n
        <title=commit_line>
        \N* \n
        $<description>=[<.commit_line>*]
        \s*
        <diff>*
        \s*
    }

    token commit_line {
        \s**4 <( \N+ )> \n
    }
    
    token diff {
        'diff --git a/' $<file>=[\S+] \N+ \n
        [ \w \N+ \n ]*
        '---' \s \N+ \n
        '+++' \s \N+ \n
        <diff_line>+
    }

    token diff_line {
        <!before '+++' | '---'>
        <[\ @+-]> \N* \n
    }
}

class Commit {
    has $.sha1;
    has $.title;
    has $.description;
    has %.file_diffs;
}

class CommitBuilder {
    method TOP($/) {
        make (.made for @<commit>);
    }

    method commit($/) {
        make Commit.new(
            sha1        => ~$<sha1>,
            title       => ~$<title>,
            description => ~$<description>,
            file_diffs  => hash(@<diff>.map(-> $/ { ~$<file> => (.Str for @<diff_line>) }))
        );
    }
}

sub parse_log() {
    my $log = qx{git log --reverse -p --grep="^[^[][^m][^e]"};
    return CommitLog.parse($log, :actions(CommitBuilder)).made;
}

sub make_html(@commits) {
    my @slides;

    sub escape($text) {
        constant ESCAPES = hash('<' => '&lt;', '>' => '&gt;', '&' => '&amp;');
        $text.subst(/<[<>&]>/, -> $/ { ESCAPES{$/} }, :g)
    }
    sub md($text) {
        escape($text).subst(/ '`' (.+?) '`' /, -> $/ { "<code>" ~ $0 ~ "</code>" }, :g)
    }
    sub detab($text) {
        $text.subst("\t", "    ", :g)
    }
    
    for @commits -> $commit {
        state $prev_commit = '';
        next unless $prev_commit;
        LEAVE $prev_commit = $commit.sha1;
        
        my @diff_lines;
        for $commit.file_diffs.kv -> $file, @lines {
            @diff_lines.push("<strong>" ~ $file ~ "</strong>\n");
            
            constant COLORS = hash('@' => 'teal', '+' => 'green', '-' => 'red');
            for @lines {
                my $color = COLORS{.substr(0, 1)} // 'black';
                @diff_lines.push(qq{<span style="color: $color">} ~ escape(detab($_)) ~ "</span>");
            }
        }
        
        @slides.push: qq:to/SLIDE/;
            <section>
                <h2> &md($commit.title) </h2>
                <p> &md($commit.description) </p>
                <pre style="text-align: left">@diff_lines.join() </pre>
            </section>
        SLIDE
    }
    
    return @slides.join;
}
