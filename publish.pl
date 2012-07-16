#!/usr/bin/perl -w

######################################################################
#
# Master script to handle all journal publication tasks:
# - Converting original input text files to monthly XML files
#   (the document of record);
# - Generating HTML for web browser viewing;
# - Generating PDFs for printing.
#
# Command line format:
#   publish.pl [options...] [specs...] <month-range>
#   publish.pl [options...] pdf-calendar <date-range> <outfile>
#
# Options:
#   -g   Debug mode: produces additional output
#   -h   Print help menu
#
# Specs:
# 
#   Any combination of the following output specifiers, indicating
#   which publication phases should be run.  If none of these are
#   listed on the command line, all phases are run.
#     xml - process all input files into the monthly XML files (the
#       documents of record)
#     html - generate monthly and yearly HTML files for browsing
#     pdf - generate monthly and yearly PDF files for printing
#
#   The special specifier "pdf-calendar" may be used to generate a
#   PDF calendar covering an arbitrary date range.  This feature is
#   there to support keeping a continuous calendar that new pages
#   can be added to over time without interrupting the content flow.
#
# Range:
#
#   The date range to process.  May be a single month (M/YY), a
#   range of months (M/YY-M/YY), or "all" to process all available
#   dates.
#
#   For "pdf-calendar" mode only, must be a date range given as
#   M/D/YY-M/D/YY.  The XML must have been generated for the months
#   in that range already.  The output file must also be specified
#   on the command line.
#
# Command line examples:
#
#   publish.pl 1/01
#   publish.pl 1/01-7/10
#   publish.pl pdf 1/01
#   publish.pl xml html 2/01
#   publish.pl all
#   publish.pl html all
#
#   publish.pl pdf-calendar 1/5/06-8/13/09
#
######################################################################

BEGIN {
    our $JOURNAL_BASE = '/Users/mferber/Documents/Journal';
    our $LIB_DIR = "$JOURNAL_BASE/etc/lib";
    our $CONF_DIR = "$JOURNAL_BASE/etc/conf";
    our $FOP_DIR = "$JOURNAL_BASE/etc/fop-1.0";
    our $XML_DIR = "$JOURNAL_BASE/published/xml";
    our $HTML_DIR = "$JOURNAL_BASE/published/html";
    our $PDF_DIR = "$JOURNAL_BASE/published/pdf";
    our $TMP_DIR = "$JOURNAL_BASE/etc/tmp";
}
use lib "$LIB_DIR/perl";

use File::Basename;
use File::Copy;
use File::Path 'make_path';
use File::Spec::Functions;
use Getopt::Std;
use IO::File;
use IO::String;
use Time::Local;
use Text::SmartyPants;
use XML::Twig;
use XML::Writer;

# allow UTF-8 chars within this perl source file (see smartypants())
use utf8;

our %MON2NUM = qw(
    jan 1  feb 2  mar 3  apr 4  may 5  jun 6
    jul 7  aug 8  sep 9  oct 10 nov 11 dec 12
);
our @MONTHNAMES = qw(January February March April May June July August
    September October November December);
our %DOW2NUM = qw(sun 0 mon 1 tue 2 wed 3 thu 4 fri 5 sat 6);
our @WEEKDAYNAMES = qw(Sunday Monday Tuesday Wednesday Thursday Friday
    Saturday);

# Java options for the FOP processor: beef up memory so we don't crash
# while caching fonts; prefer Saxon as the XSLT processor (so we can
# use XSLT 2.0); run in headless mode (don't start up an AWT GUI app)
our $FOP_OPTS = '-Xmx1024m '
        . '-Djavax.xml.transform.TransformerFactory='
            . 'net.sf.saxon.TransformerFactoryImpl '
        . '-Djava.awt.headless=true';
        


our ($from_mo, $from_yr, $to_mo, $to_yr);
our ($pdf_calendar_start, $pdf_calendar_end, $pdf_calendar_outfile);
our %phases;
our %opts;

getopt('', \%opts);

print_help_and_exit() if $opts{h};
our $debug = $opts{g};

# Determine what phases to run
while (@ARGV and $ARGV[0] =~ /^(xml|html|pdf|pdf-calendar)$/) {
    $phases{$ARGV[0]} = 1;
    shift;
}
if ( !(keys(%phases)) ) {       # no specified phases = use all
    $phases{xml} = 1;
    $phases{html} = 1;
    $phases{pdf} = 1;
}
if ($phases{'pdf-calendar'} and scalar(keys(%phases)) != 1) {
    die "'pdf-calendar' phase cannot be used with other phases.\n\n";
    print_help_and_exit();
}

# Get time range to process
if ($phases{'pdf-calendar'}) {
    ($pdf_calendar_start, $pdf_calendar_end) =
        get_pdf_calendar_dates($ARGV[0]);
    $pdf_calendar_outfile = $ARGV[1];
    unless ( defined($pdf_calendar_start) ) {
        print "Error: PDF calendar date range missing or incomplete.\n\n";
        print_help_and_exit();
    }
    unless ( defined($pdf_calendar_outfile) ) {
        print "Error: PDF calendar output file path missing.\n\n";
        print_help_and_exit();
    }
}
else {
    # "normal" phases: get range of months
    ($from_mo, $from_yr, $to_mo, $to_yr) = get_month_range($ARGV[0]);
    unless (defined($from_mo)) {
        print "Error: range of months missing.\n\n";
        print_help_and_exit();
    }
    
    # Validate and normalize dates
    if ($from_mo < 1 || $from_mo > 12) {
        die "Invalid starting month";
    }
    if ($to_mo < 1 || $to_mo > 12) {
        die "Invalid ending month";
    }
    $from_yr += 2000 if $from_yr < 100;
    $to_yr += 2000 if $to_yr < 100;
}

if ($phases{'pdf-calendar'}) {
    process_arbitrary_pdf_calendar($pdf_calendar_start,
        $pdf_calendar_end, $pdf_calendar_outfile);
}
else {
    process_months(\%phases, $from_mo, $from_yr, $to_mo, $to_yr);
}
print "Done.\n";




#
# Get the month/year range from the command line argument (for all
# phases except pdf-calendar
#
sub get_month_range
{
    my $arg = shift;
    defined($arg) or return (undef, undef, undef, undef);
    
    my ($from_mo, $from_yr, $to_mo, $to_yr);
    if ($arg eq 'all') {
        ($from_mo, $from_yr, $to_mo, $to_yr) =
            get_all_months_range();
        if ( defined($from_mo) ) {
            print "Processing complete range: ",
                "$from_mo/$from_yr-$to_mo/$to_yr\n"
        }
    }
    else {
        if ($arg =~
            m|
                ^                               # starting month...
                (\d{1,2})/(\d{2}(?:\d{2})?)     #   M/YY or M/YYYY
                (?:                             # ending month...
                    -
                    (\d{1,2})/(\d{2}(?:\d{2})?) # M/YY or M/YYYY
                )?                              # ending month is optional
                $
            |x
        ) {
            ($from_mo, $from_yr) = ($1, $2);
            if (defined($3)) {
                ($to_mo, $to_yr) = ($3, $4);
            }
            else {
                ($to_mo, $to_yr) = ($from_mo, $from_yr);
            }
        }
    }
    return ($from_mo, $from_yr, $to_mo, $to_yr);
}


#
# Get the month/year range when the user specified "all"
# returns (from_mo, from_yr, to_mo, to_yr)
#
sub get_all_months_range
{
    my $pat = catfile($JOURNAL_BASE, 'journal.????-??-??.txt');
    my @entries = sort(glob($pat));
    @entries or return (undef, undef, undef, undef);
    
    my ($from_mo, $from_yr, $to_mo, $to_yr); 
    for (my $i = 0; $i < @entries; $i++) {
        if ( $entries[$i] =~ m{/journal.(\d{4})-(\d{2})-(\d{2})\.txt$} ) {
            ($from_yr, $from_mo) = ($1, $2);
            last;
        }
    }
    for (my $i = @entries - 1; $i >= 0; $i--) {
        if ( $entries[$i] =~ m{/journal.(\d{4})-(\d{2})-(\d{2})\.txt$} ) {
            ($to_yr, $to_mo) = ($1, $2);
            last;
        }
    }
    return
        defined($from_mo) && defined($from_yr) && defined($to_mo) &&
            defined($to_yr)
        ? ($from_mo, $from_yr, $to_mo, $to_yr)
        : (undef, undef, undef, undef);
}


#
# Get the date range for arbitrary PDF calendar generation
#
sub get_pdf_calendar_dates
{
    my $arg = shift;
    if ($arg =~
        m|
            ^
            (\d{1,2})/(\d{1,2})/(\d{2}(?:\d{2})?)   # M/D/YY or M/D/YYYY
            -
            (\d{1,2})/(\d{1,2})/(\d{2}(?:\d{2})?)   # same
            $
        |x
    ) {
        my $y0 = (length($3) > 2 ? $3 : 2000 + $3);
        my $y1 = (length($6) > 2 ? $6 : 2000 + $6);
        my $start = sprintf("%04d-%02d-%02d", $y0, $1, $2);
        my $end = sprintf("%04d-%02d-%02d", $y1, $4, $5);
        return ($start, $end);
    }
    return (undef, undef);
}


#
# Process months
#
sub process_months
{
    my ($hr_phases, $from_mo, $from_yr, $to_mo, $to_year) = @_;

    for (my $yr = $from_yr; $yr <= $to_yr; ++$yr) {
        my $mo0 = ($yr == $from_yr ? $from_mo : 1);
        my $mo1 = ($yr == $to_yr ? $to_mo : 12);
        if ($mo0 <= $mo1) {
            for (my $mo = $mo0; $mo <= $mo1; ++$mo) {
                process_month($hr_phases, $mo, $yr);
            }
            process_year($hr_phases, $yr);
        }
    }
}


#
# Process a single month
#
sub process_month
{
    my ($hr_phases, $mo, $yr) = @_;
    
    if ($hr_phases->{'xml'}) {
        collect_month_xml($mo, $yr);
    }
    if ($hr_phases->{'html'}) {
        process_month_to_html($mo, $yr);
    }
    if ($hr_phases->{'pdf'}) {
        process_month_to_pdf($mo, $yr);
    }
}


#
# Process year-level stuff for a given year
#
sub process_year
{
    my ($hr_phases, $yr) = @_;
    
    if ($phases{'html'}) {
        process_year_to_html($yr);
    }
    if ($phases{'pdf'}) {
        process_year_to_pdf($yr);
    }
}


#
# Process a month of text to XML; returns the number of entries
# found
#
sub collect_month_xml
{
    my ($mo, $yr) = @_;
    
    my $pat = catfile($JOURNAL_BASE,
        "journal.$yr-" . sprintf("%02d", $mo) . '-??.txt');
    my @entries = sort(glob($pat));

    print "Collecting XML for $mo/$yr... found ",
      scalar(@entries), ' entr', (@entries == 1 ? 'y' : 'ies'), "\n";
    
    @entries or return 0;
    
    my $xmlwpath = "$XML_DIR/" . sprintf("%04d-%02d", $yr, $mo) . ".xml";
    
    make_path(dirname($xmlwpath));
    
    my $xml;
    my $xmls = IO::String->new($xml);
    my $xmlw = XML::Writer->new(
        OUTPUT => $xmls,
        ENCODING => 'UTF-8',
    );
    
    $xmlw->xmlDecl();
    $xmlw->startTag('journal', 'year' => sprintf('%04d', $yr),
        'month' => sprintf('%02d', $mo));
    my $entry;
    eval {
        for (@entries) {
            $entry = $_;
            convert_entry_to_xml($_, $xmlw);
        }
    };
    if ($@) {
        die "Error processing $entry: $@";
    }
    $xmlw->endTag('journal');
    $xmlw->end();
    
        
    # reparse the XML using XML::Twig, just because it has good
    # pretty-printing facilities and XML::Writer doesn't
    my $twig = XML::Twig->new(
        output_encoding => 'utf-8',
        pretty_print => 'indented',
    );
    $twig->parse($xml);
    
    my $xmlwpathnew = "$xmlwpath.new";
    (my $xmlwfile = IO::File->new($xmlwpathnew, 'w'))
        or die "Can't open $xmlwpath for writing: $!";
    $twig->print($xmlwfile);
    $xmlwfile->close();
    
    # when finished successfully, move the new file over the old
    # one (if any)
    move($xmlwpathnew, $xmlwpath);
    
    return scalar(@entries);
}



#
# Convert an entry to XML
#
sub convert_entry_to_xml
{
    my ($filepath, $xmlw) = @_;

    if (open(ENTRY, '<:utf8', $filepath)) {
        my @lines = <ENTRY>;
        close(ENTRY);
        chomp(@lines);
        
        # parse components from the entry
        my ($dateline, $summary, $text);
        shift(@lines) until !@lines or $lines[0] !~ /^\s*$/;
        if (@lines and $lines[0] =~ /^\*/) {
            $dateline = shift(@lines);
            shift(@lines) until $lines[0] !~ /^\s*$/;
        }
        if (@lines and $lines[0] =~ /^\!/) {
            $summary = shift(@lines);
            shift(@lines) until !@lines or $lines[0] !~ /^\s*$/;
        }
        $text = join("\n", @lines);
        
        $summary =~ s/^\!\s*//;
        my @paras = grep(/\S/, split(/\n{2,}/, $text));
        
        $summary = smartypants($summary);
        $_ = smartypants($_) for @paras;
        
        my $date = get_validated_date(basename($filepath), $dateline);
        my ($sec, $min, $hr, $mday, $pmon, $pyr, $dow) = localtime($date);
        my $datestamp = sprintf('%04d-%02d-%02d', 1900 + $pyr, $pmon + 1, $mday);
        
        $xmlw->startTag('entry', 'date' => $datestamp,
            'weekday' => $WEEKDAYNAMES[$dow]);
        if ($summary =~ /\S/) {
            $xmlw->startTag('summary');
            write_with_tagged_italics($summary, $xmlw);
            $xmlw->endTag('summary');
        }
        if (@paras) {
            $xmlw->startTag('text');
            for (@paras) {
                if (/\S/) {
                    $xmlw->startTag('p');
                    write_with_tagged_italics($_, $xmlw);
                    $xmlw->endTag('p');
                }
            }
            $xmlw->endTag('text');
        }
        $xmlw->endTag('entry');
    }
    else {
        warn "Error opening $filepath: $!";
    }
}


#
# Tag italicized sections marked with *
# (this might be a good feature to replace with Markdown or MultiMarkdown)
#
sub write_with_tagged_italics {
    my ($text, $xmlw) = @_;
    
    # Replace *this* with <i>this</i>, at word/punctuation boundaries
    my @parts = split(/\*((?:\b|\W)[^\*]+(?:\b|\W))\*/i, $text);
    while (@parts) {
        #warn $parts[0];
        $xmlw->characters(shift(@parts));
        #warn "<$parts[0]>" if @parts;
        $xmlw->dataElement('i', shift(@parts)) if @parts;
    }
}


#
# Process a month from XML to HTML
#
sub process_month_to_html
{
    my ($mo, $yr) = @_;
    
    my $moyrfile = sprintf("%04d-%02d", $yr, $mo);
    my $xmlfile = "$XML_DIR/$moyrfile.xml";
    unless (-f $xmlfile and -r $xmlfile) {
        print "Nothing to render to HTML for $mo/$yr\n";
        return;
    }
    
    print "Rendering $mo/$yr full text to HTML...\n";
    my @cmd = ('java',
        '-classpath', "$LIB_DIR/java/saxon9he",
        'net.sf.saxon.Transform',
        "-s:$xmlfile",
        "-o:$HTML_DIR/$moyrfile.html",
        "-xsl:$LIB_DIR/xslt/month2html.xsl",
    );
    
    print "\n", join(' ', @cmd), "\n\n" if $debug;
    
    system(@cmd);
}


#
# Process year-level calendar to HTML
#
sub process_year_to_html
{
    my $yr = shift;
    
    my $exists = 0;
    for (my $mo = 1; $mo <= 12; $mo++) {
        my $moyrfile = sprintf("$yr-%02d", $mo);
        my $xmlfile = "$XML_DIR/$moyrfile.xml";
        ($exists = 1, last) if (-f $xmlfile and -r $xmlfile);
    }
    unless ($exists) {
        print "Nothing to render to HTML for year $yr\n";
        return;
    }
    
    print "Rendering $yr calendar to HTML...\n";
    my @cmd = ('java',
        '-classpath', "$LIB_DIR/java/saxon9he",
        'net.sf.saxon.Transform',
        "-o:$HTML_DIR/${yr}-calendar.html",
        "-xsl:$LIB_DIR/xslt/year2html.xsl",
        '-it:main',
        "input-base-uri=file:$XML_DIR/",
        "year=$yr",
    );
    
    print "\n", join(' ', @cmd), "\n\n" if $debug;
    
    system(@cmd);
}


#
# Process month to PDF
#
sub process_month_to_pdf
{
    my ($mo, $yr) = @_;
    
    my $moyrfile = sprintf("%04d-%02d", $yr, $mo);
    my $xmlfile = "$XML_DIR/$moyrfile.xml";
    unless (-f $xmlfile and -r $xmlfile) {
        print "Nothing to render to PDF for $mo/$yr\n";
        return;
    }
    
    print "Rendering $mo/$yr full text to PDF...\n";
    my @cmd = ("$FOP_DIR/fop",
        '-c', "$CONF_DIR/fop.xconf",
        '-xml', $xmlfile,
        '-xsl', "$LIB_DIR/xslt/month2fo.xsl",
        '-pdf', "$PDF_DIR/$moyrfile.pdf",
    );
    
    print "\n", join(' ', @cmd), "\n\n" if $debug;
    
    $ENV{'FOP_OPTS'} = $FOP_OPTS;
    system(@cmd);
}


#
# Process year to PDF
#
sub process_year_to_pdf
{
    my $yr = shift;
    
    my $exists = 0;
    for (my $mo = 1; $mo <= 12; $mo++) {
        my $moyrfile = sprintf("$yr-%02d", $mo);
        my $xmlfile = "$XML_DIR/$moyrfile.xml";
        ($exists = 1, last) if (-f $xmlfile and -r $xmlfile);
    }
    unless ($exists) {
        print "Nothing to render to PDF for year $yr\n";
        return;
    }
    
    print "Rendering $yr calendar to PDF...\n";
    
    my @cmd = ("$FOP_DIR/fop",
        '-c', "$CONF_DIR/fop.xconf",
        '-xml', "$LIB_DIR/xslt/null.xml",
        '-xsl', "$LIB_DIR/xslt/year2fo.xsl",
        '-pdf', "$PDF_DIR/${yr}-calendar.pdf",
        '-param', 'input-base-uri', "file:$XML_DIR/",
        '-param', 'year', $yr
    );
    
    print "\n", join(' ', @cmd), "\n\n" if $debug;
    
    $ENV{'FOP_OPTS'} = $FOP_OPTS;
    system(@cmd);
}


#
# Generate the PDF calendar for an arbitrary date range.  Pass in dates
# formatted as YYYY-MM-DD.
#
sub process_arbitrary_pdf_calendar
{
    my ($startdate, $enddate, $outfile) = @_;
    
    print "Rendering calendar range to PDF...\n";
    
    my @cmd = ("$FOP_DIR/fop",
        '-c', "$CONF_DIR/fop.xconf",
        '-xml', "$LIB_DIR/xslt/null.xml",
        '-xsl', "$LIB_DIR/xslt/year2fo.xsl",
        '-pdf', $outfile,
        '-param', 'input-base-uri', "file:$XML_DIR/",
        '-param', 'start', $startdate,
        '-param', 'end', $enddate
    );
    
    print "\n", join(' ', @cmd), "\n\n" if $debug;
    
    $ENV{'FOP_OPTS'} = $FOP_OPTS;
    system(@cmd);
}


#
# Parse the entry date from the filename, and if provided with
# a dateline, check that they match and emit a warning if not; return the
# entry date as a perl date
#
sub get_validated_date
{
    my ($filename, $dateline) = @_;
    
    my ($realyr, $realmo, $realday) = ($filename =~
        /^journal.(\d{4})-(\d{2})-(\d{2}).txt$/);
    if (!defined($realyr) or !defined($realmo) or !defined($realday)) {
        die "Fatal: can't parse date out of filename $filename";
    }
    my $realdate = timelocal(0, 0, 0, $realday, $realmo-1, $realyr-1900);
    
    # Validate the dateline from the file against the filename date
    if (!defined($dateline)) {
        warn "Warning: no date to validate in $filename";
    }
    else {
        my ($docdow, $docmostr, $docday, $docyr) = ($dateline =~
            /^\*\s+([a-z]+),\s*([a-z]+)\s+(\d+),\s*(\d+)$/i);
        if (!defined($docyr)) {
            warn "Warning: in $filename, can't parse dateline \"$dateline\"";
        }
        else {
            $ismatch = ($realyr == $docyr and $realday == $docday);
            if ($ismatch) {
                my $docmo = $MON2NUM{lc(substr($docmostr, 0, 3))};
                $ismatch = ($docmo == $realmo);
            }
            if (!$ismatch) {
                warn "Warning: in $filename, dateline \"$dateline\" doesn't match";
            }
            else {
                # check day of week
                my $docdownum = $DOW2NUM{lc(substr($docdow, 0, 3))};
                my $realdow = (localtime($realdate))[6];
                if ($realdow != $docdownum) {
                    warn "Warning: in $filename, day of week ($docdow) ",
                        "doesn't match expected ", $WEEKDAYNAMES[$realdow];
                }
            }
        }
    }
    
    return $realdate;
}


# Run SmartyPants algorithm to smartify quotes and dashes, but
# then transform entities back to the actual UTF-8 character, since
# SmartyPants doesn't do that natively
sub smartypants
{
    my $in = shift;
    my $tmp = Text::SmartyPants::process($in, 'qd');  # qd = quotes & dashes only
    $tmp =~ s/&#8216;/‘/g;
    $tmp =~ s/&#8217;/’/g;
    $tmp =~ s/&#8220;/“/g;
    $tmp =~ s/&#8221;/”/g;
    $tmp =~ s/&#8212;/—/g;  # em dash
    return $tmp;
}


# Print help and exit
sub print_help_and_exit
{
    my $scriptname = basename($0);
    print << "END_USAGE";
HELP TEXT HERE
END_USAGE
    exit 0;
}