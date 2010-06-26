#!/usr/bin/env perl
# Everything moved into one file, does things the right way
use strict;
use warnings;
use Getopt::Long;
use IPC::Open2;

# parse the input options
my $markdown_bin;
my $outputdir;
my $toc;
GetOptions(
    "markdown=s" => \$markdown_bin,
    "output=s"   => \$outputdir,
    "toc=s"      => \$toc
);

die "You need to specify an output directory for a table of contents!\n"
  if ( $toc && !defined($outputdir) );

warn "--toc doesn't do anything yet!\n" if $toc;

# grab comments out of incoming text
sub docker {
    my $input  = shift;
    my @output = ();
    my $line;
    while ( $input =~ m{\*\*(?:.|[\r\n])*?\*/}g ) {
        $line = $&;
        $line =~ s{(\*\/|\/\*\*)}{}g;
        $line =~ s{([\r\n]+)\s{1}}{$1}g;
        push( @output, "\r$line\r" );
    }
    return join( "", @output );
}

# put a nice header on the html output
sub html_head {
    my $input = shift;

    #my $title = shift;
    my $title  = "Jo JavaScript Application Framework for HTML5";
    my $output = qq(
    <!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">

    <html lang="en">
    <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <title>$title</title>
    <meta name="generator" content="joDoc">
    <link rel="stylesheet" type="text/css" href="docbody.css">
    <link rel="stylesheet" type="text/css" href="doc.css">
    <meta name="viewport" content="initial-scale=1.0, maximum-scale=1.0, user-scalable=no, width=device-width">
    <meta name="format-detection" content="false">
    </head>
    <body>
    <cite>Jo<cite>JavaScript App Framework</cite></cite>

    $input

    <br>
    <cite><cite>Jo</cite></cite>
    </body>
    </html>);
    return $output;
}

# link together all the html output, make an index at the bottom
sub autolink {
    my $input    = shift;
    my @keywords = ();
    # find all the h1 tags, make them link to each other
    while ( $input =~ m{\<h1\>([^\<]+)\<\/h1\>}g ) {
        unshift( @keywords, $1 );
    }
    # prepare for the regex
    my $keys = join( "|", @keywords );
    # make anything refing a keywork link to it
    $input =~ s{(\W+)($keys)(?!\<\/a|\w+)}{$1\<a href=\"\#$2\"\>$2\<\/a\>}g;
    # make a #tag for the keyword h1 tag
    $input =~ s{\<h1\>\<a href=\"\#}{\<h1\>\<a name=\"}g;
    # put an external css class on outbound links
    $input =~
s{(\<a)\s+(href=\"http|href=\"mailto|href=\"ftp)}{$1 class=\"external\" $2}g;
    my $index      = qq(\n\n<hr>\n\n<h1>Index</h1>\n<div id="index">\n);
    my $lastletter = "ZZ";

    # Make an alphasorted index
    for my $i ( sort { lc($a) cmp lc($b) } @keywords ) {
        my $letter = uc( substr( $i, 0, 1 ) );
        if ( $letter ne $lastletter ) {
            if ( $lastletter ne "ZZ" ) {
                $index .= "</ul>\n";
            }
            $index .= "\n<h2>$letter</h2>\n";
            $index .= "\n<ul>\n";
            $lastletter = $letter;
        }
        $index .= qq(<li><a href=#$i>$i</a></li>\n);
    }
    $index .= "</ul></div>\n\n";
    return ( $input, $index );
}

# Pipe stuff through markdown for parsing
sub markdown_pipe {
    my $in  = shift;
    my @out = ();

    # Use pipes instead of temp files
    # The magic here is what you expect open(HANDLE, "| $markdown_bin |") to do.
    my $pid = open2( my $chld_out, my $chld_in, $markdown_bin ) or die $!;
    print $chld_in $in;
    close $chld_in;
    while (<$chld_out>) {
        push( @out, $_ );
    }
    close $chld_out;
    return join( "", @out );
}

# If not specified, find a markdown parser in the path
chomp( $markdown_bin = qx(command -v markdown) ) unless $markdown_bin;

# We can't do anything if we can't call markdown
die "Markdown parser not found!\n" unless ( -x $markdown_bin );

# Slurp all the files and process them
my %processed = ();
for my $file (@ARGV) {
    unless ( -f $file ) {
        warn "File $file doesn't exist or isn't a file!\n";
        next;
    }
    my $content;
    open( my $fh, '<', $file ) or die $!;
    {
        local $/;
        $content = <$fh>;
    }
    close $fh or die $!;

    # javascript and css files get "cleaned"
    if ( $file =~ m{\.(js|css)$} ) {
        $content = docker($content);
    }
    # pure htmlfiles don't have markdown applied
    unless ( $file =~ m{\.html$} ) {
        $content = markdown_pipe($content);
    }
    $processed{$file} = $content;
}

# TODO: make a proper hierarchy of files, for now just print out one html file
my $outstring = join( "\n", ( values %processed ) );
$outstring = join( "", autolink($outstring) );
$outstring = html_head($outstring);
if ($outputdir) {
    mkdir $outputdir;
    open( my $fh, '>', $outputdir . "/index.html" ) or die $!;
    print $fh $outstring;
    close $fh or die $!;
}
else {
    print $outstring;
}

=head1
JoDoc documenation maker

=head2
Takes in files and passes them through markdown in a consistent manner

JoDoc opetions:

=over

=item --toc, print out a table of contents into a specified file in --output

=item --output, a folder to put the output into

=item --markdown, specify a markdown processor

=back

=cut
