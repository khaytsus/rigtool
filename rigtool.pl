#!/usr/bin/perl

# Perl script to control a radio using HamLib

use Hamlib;
use Term::ReadKey;
use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin;

our $VERSION = '1.1';

# Todo - Remote tuning
# Interesting thing
# RIG_FLAG_TUNER RIG_FUNC_LOCK RIG_FUNC_TUNER send_morse

# Use our rigtool.pm module and get all of our settings out of it
use rigtool;

my $hamliburl          = $rigtool::hamliburl;
my $country            = $rigtool::country;
my $license            = $rigtool::license;
my $cw_passband        = $rigtool::cw_passband;
my $data_passband      = $rigtool::data_passband;
my $ssb_passband       = $rigtool::ssb_passband;
my $am_passband        = $rigtool::am_passband;
my $fm_passband        = $rigtool::fm_passband;
my $tune_bottom        = $rigtool::tune_bottom;
my $tune_top           = $rigtool::tune_top;
my $enforce_tune_limit = $rigtool::enforce_tune_limit;
my $cwoffset           = $rigtool::cwoffset;
my $fautomodeset       = $rigtool::fautomodeset;
my $bypassdatamode     = $rigtool::bypassdatamode;
my $allmodeset         = $rigtool::allmodeset;
my $avgsignal          = $rigtool::avgsignal;
my $avgsamples         = $rigtool::avgsamples;
my $showtuneinfo       = $rigtool::showtuneinfo;
my $showbandinfo       = $rigtool::showbandinfo;
my $locked             = $rigtool::locked;
my $rigopenmax         = $rigtool::rigopenmax;
my $hzstep             = $rigtool::hzstep;
my $khzstep            = $rigtool::khzstep;
my $fivekhzstep        = $rigtool::fivekhzstep;
my $largestep          = $rigtool::largestep;
my $hzupkey            = $rigtool::hzupkey;
my $hzdownkey          = $rigtool::hzdownkey;
my $khzupkey           = $rigtool::khzupkey;
my $khzdownkey         = $rigtool::khzdownkey;
my $fivekhzupkey       = $rigtool::fivekhzupkey;
my $fivekhzdownkey     = $rigtool::fivekhzdownkey;
my $largeupkey         = $rigtool::largeupkey;
my $largedownkey       = $rigtool::largedownkey;
my $scanstep           = $rigtool::scanstep;
my $scandelay          = $rigtool::scandelay;
my $scanupkey          = $rigtool::scanupkey;
my $scandownkey        = $rigtool::scandownkey;
my $coloroutput        = $rigtool::coloroutput;
my $lightterm          = $rigtool::lightterm;
my @sixtymfreqs        = @rigtool::sixtymfreqs;
my %tuneinfo           = %rigtool::tuneinfo;
my %freqnames          = %rigtool::freqnames;
my %bandnames          = %rigtool::bandnames;
my $notefile           = $rigtool::notefile;
my $powerdivider       = $rigtool::powerdivider;

# Comment out to enable hamlib debugging (very noisy)
Hamlib::rig_set_debug($Hamlib::RIG_DEBUG_NONE);

# Change to your rig type, port, etc
my $rig = Hamlib::Rig->new($Hamlib::RIG_MODEL_NETRIGCTL);
$rig->set_conf( '', $hamliburl );

# Don't touch below here unless modifying %tuneinfo
# if you want to modify that

# Define our cw and ssb freqs and get them defined based on license
# The data is pulled from the get_bandplan sub in our module
my ( $cwfreqsref, $datafreqsref, $ssbfreqsref )
    = &rigtool::get_bandplan( $country, $license );
my @cwfreqs   = @$cwfreqsref;
my @datafreqs = @$datafreqsref;
my @ssbfreqs  = @$ssbfreqsref;

# Auto mode flag to use in various places
my $automode = '0';

# Scan mode flag
my $scanmode = '0';

# Keep track of average
my @signalarray;
my $avgtimes = '0';
my $lastavg  = '-99';

# Track what mode we were in last so we don't switch to the same mode
my $lastmode = '';

# Keep track of last vfo used so we can use it again
my $lastvfo = '';

# Keep track of our last input so we can use a repeat command later
my $lastinput = '';

# Keep track of our last channel so we can rotate through them
my $lastchannel = '';

# Check to see if we have the Term::ANSIColor module so it's not a hard requirement
my $ansi = eval {
    require Term::ANSIColor;
    Term::ANSIColor->import(':constants');
    1;
};

# Set up colors and other ANSI codes
my ( $r, $c_r, $c_g, $c_c, $c_m, $c_b, $c_y, $cl,
    $clearrestscreen, $clearscreen, $topleft );

# Set up our color tags
color_tags();

# Keep track of how many times we had to open the connection for info
my $rigopens = '0';

rigopen();

# Loop vars defined so we can control exiting better
my $whileloop = '1';
my $autoloop  = '0';

# Frequency divider to get to khz
my $freqdiv = '1000';

# Variables so we can flip/flop frequencies or return to the last one easy
my $quickfreq = $rig->get_freq() / $freqdiv;
my $quickmode = 'u';
my $lastfreq  = $quickfreq * $freqdiv;

# If auto is the first parameter, go straight to auto mode

my $arg = '';

if ( scalar(@ARGV) ) {
    $arg = $ARGV[0];
}

if ( $arg eq 'auto' ) {
    $autoloop = '1';
    auto_mode();
}

# Start manual loop
manual_mode();

print "Exiting script\n";

rigclose();

exit;

sub manual_mode {

    # Loop through our prompt while we're running
    while ($whileloop) {
        my ( $prompt, $tunertext, $extratext, $bandtext, $chantext )
            = create_prompt();

        if ( $tunertext ne '' ) {
            print $tunertext . ' ' . $bandtext . $chantext . "\n";
        }
        print $prompt . ': ';
        my $input = <STDIN>;
        chomp $input;
        $input = ($input);
        parse_input($input);

        # Return to our locked freq/mode if locked
        if ($locked) {
            parse_f($quickfreq);
            parse_mode($quickmode);
        }
    }
    return;
}

# Clean up
sub freq_text {

    my ($passedfreq) = @_;

    my $cwmatch   = '0';
    my $datamatch = '0';
    my $ssbmatch  = '0';
    my $matched   = '';
    my $tunertext = '';
    my $bandtext  = '';
    my $chantext  = '';
    my $testfreq  = '1000';
    my $f         = $testfreq;

    # If we were passed a frequency, find the info for it, not the tuned one
    if ( defined($passedfreq) ) {
        $f = $passedfreq;
    }
    else {
        $f = $rig->get_freq();
    }

    # Sometimes we seem to get nonsense, try to cycle the connection
    if ( $f =~ /NaN/ || $f < $testfreq ) {
        rigclose();
        rigopen();
        my %returnhash = (
            'pretty_freq' => 0,
            'cwmatch'     => 0,
            'datamatch'   => 0,
            'ssbmatch'    => 0,
            'outofband'   => 0,
            'tunertext'   => '',
            'bandtext'    => '',
            'chantext'    => ''
        );
        return %returnhash;
    }
    else {
        # Reset our rigopens counter if we got a good value
        $rigopens = 0;
    }

    foreach my $item (@cwfreqs) {

        # Test if we have a range
        if ( $item =~ /-/xms ) {
            my ( $low, $high ) = split( /-/xms, $item );
            if ( $f >= $low && $f < $high ) {
                $cwmatch = '1';
            }
        }
        else

            # Single frequency; ie:  60M
        {
            if ( $f == $item ) {
                $cwmatch = '1';
            }
        }
    }

    foreach my $item (@datafreqs) {

        # Test if we have a range
        if ( $item =~ /-/xms ) {
            my ( $low, $high ) = split( /-/xms, $item );
            if ( $f >= $low && $f < $high ) {
                $datamatch = '1';
            }
        }
        else

            # Single frequency; ie:  60M
        {
            if ( $f == $item ) {
                $datamatch = '1';
            }
        }
    }

    foreach my $item (@ssbfreqs) {

        # Test if we have a range
        if ( $item =~ /-/xms ) {
            my ( $low, $high ) = split( /-/xms, $item );
            if ( $f >= $low && $f < $high ) {
                $ssbmatch = '1';
            }
        }
        else

            # Single frequency; ie:  60M
        {
            if ( $f == $item ) {
                $ssbmatch = '1';
            }
        }
    }

    # If set, add tuner info to prompt text
    if ($showtuneinfo) {
        for my $key ( keys %tuneinfo ) {
            my $value = $tuneinfo{$key};

            my ( $low, $high ) = split( /-/xms, $key );
            if ( $f >= $low && $f <= $high ) {
                $tunertext = '(' . $value . ')';
            }
        }
    }

    # If set, add band info to prompt text
    if ($showbandinfo) {
        for my $key ( keys %bandnames ) {
            my $value = $bandnames{$key};

            my ( $low, $high ) = split( /-/xms, $key );
            if ( $f >= $low && $f < $high ) {
                $bandtext = '(' . $value . ')';
            }
        }
    }

    if ( $cwmatch || $datamatch || $ssbmatch ) { $matched = '1'; }

    # Pad the frequency to make it look nicer
    my $pretty_freq = $f / $freqdiv;
    my ( $khz, $hz );
    if ( $pretty_freq =~ /\./xms ) {
        ( $khz, $hz ) = split( /\./xms, $pretty_freq );
        $hz .= '0' x ( 2 - length $hz );
        $pretty_freq = $khz . '.' . $hz;
    }
    else {
        $pretty_freq = $pretty_freq . '.00';
    }
    my $outofband = '0';
    unless ( $matched || !defined($license) ) { $outofband = '1'; }

    # If we know this frequency, add it to the prompt
    my $freqname = name_from_freq($f);
    if ( defined($freqname) && $freqname ne '' ) {
        $chantext .= ' (' . $c_c . $freqname . $r . ') ';
    }

# Create a hash to return so it makes it easier to extend and only use what we need
    my %returnhash = (
        'pretty_freq' => $pretty_freq,
        'cwmatch'     => $cwmatch,
        'datamatch'   => $datamatch,
        'ssbmatch'    => $ssbmatch,
        'outofband'   => $outofband,
        'tunertext'   => $tunertext,
        'bandtext'    => $bandtext,
        'chantext'    => $chantext
    );

    return %returnhash;
}

sub parse_input {
    my ($orig_input) = @_;

    # Lowercase our input for most tests
    my $input = lc($orig_input);

    my $storelastinput = '0';
    my $skip           = '0';

    # Get current info so we can switch back to these if we change with 'r'
    my $f = $rig->get_freq();
    my ( $mode, $width ) = $rig->get_mode();
    my ( $textmode, @rest ) = split( //xms, Hamlib::rig_strrmode($mode) );

    # Repeat last command

    if ( $input eq '!' ) {
        $input = $lastinput;
        print 'Repeating command:  ' . $lastinput . "\n";
    }

    # Help
    if ( $input =~ /\?+/xms ) {
        usage($input);
    }

    # Automatic mode
    if ( $input =~ /auto/xms ) {
        $autoloop = '1';
        auto_mode();
        $input = '';
        $skip++;
    }

    # Lock to current freq/mode
    if ( $input =~ /^lock/xms ) {
        print "Locking\n";
        $locked    = '1';
        $quickfreq = $f / $freqdiv;
        $quickmode = $textmode;
        $input     = '';
        $skip++;
    }

    # Unlock
    if ( $input =~ /^unlock/xms ) {
        print "Unlocking\n";
        $locked = '0';
        $input  = '';
        $skip++;
    }

    if ( $input =~ /q/xms ) {
        $whileloop = '0';
        return;
    }

    if ( $input =~ /set/xms ) {
        my ( undef, $data )    = split( /\ /xms, $input );
        my ( $var,  $setting ) = split( /=/xms,  $data );
        change_setting( $var, $setting );
        return;
    }

    # Change radio power
    if ( $input =~ /^power/xms ) {
        my ( undef, $data ) = split( /\ /xms, $input );
        if ( defined($data) ) {
            $data =~ s/[wW]//g;
            if ( $data =~ /^\d+$/xms && $data > 0 && $data <= 1500 ) {
                my $outputpower = int(
                    (         $rig->get_level_f($Hamlib::RIG_LEVEL_RFPOWER)
                            * $powerdivider
                    ) + .5
                );
                print 'Setting power from '
                    . $outputpower . ' to '
                    . $data
                    . " watts\n";

                my $adjustedpower = $data / $powerdivider;
                $rig->set_level( $Hamlib::RIG_LEVEL_RFPOWER, $adjustedpower );
            }
            else {
                print 'Invalid power value, must be between 0 and 1500'
                    . "\n";
            }
        }
        else {
            print 'No power value, must be between 0 and 1500' . "\n";
        }
        return;
    }

    if ( $input =~ /note/xms ) {
        my ( undef, @note ) = split( /\ /xms, $orig_input );
        my $notestring = join( ' ', @note );
        save_note($notestring);
        return;
    }

    # Do nothing if we're locked
    if ($locked) { return; }

    if ( $input =~ /chan/xms ) {
        my ( $command, @channel ) = split( /\ /xms, $input );
        my $channel = join( " ", @channel );
        my ( $freq, $chanmode ) = freq_from_name($channel);
        if ( defined($freq) && $freq != 0 ) {
            parse_f($freq);
            if ( $chanmode ne "" ) {
                parse_mode($chanmode);
            }
            $storelastinput++;
        }
        $skip++;
    }

# Skip our other tokens if we've done something that might execute more commands
    if ( !$skip ) {

        # Revert to previous mode
        if ( $input =~ /r/xms ) {

            # Switch modes
            parse_f($quickfreq);
            parse_mode($quickmode);
        }

        # Change to VFO A
        if ( $input =~ /a/xms && $input !~ /am/xms ) {
            unless ( $automode || $scanmode ) {
                print "Switching to VFO A\n";
            }

            # If we specify vfo, make sure we honor it
            $lastvfo = 'A';
            $rig->set_vfo($Hamlib::RIG_VFO_VFO);
            $rig->set_vfo($Hamlib::RIG_VFO_A);
        }

        # Change to VFO B
        if ( $input =~ /b/xms ) {
            unless ( $automode || $scanmode ) {
                print "Switching to VFO B\n";
            }

            # If we specify vfo, make sure we honor it
            $lastvfo = 'B';
            $rig->set_vfo($Hamlib::RIG_VFO_VFO);
            $rig->set_vfo($Hamlib::RIG_VFO_B);
        }

        # Parse and change frequency
        if ( ( $input =~ /f/xms && $input !~ /fm/xms )
            || $input =~ /^[0-9\.,]+$/xms )
        {
            parse_f($input);
            $storelastinput++;
        }

        # Parse and change mode
        if (   $input =~ /u/xms
            || $input =~ /l/xms
            || $input =~ /c/xms
            || $input =~ /am/xms
            || $input =~ /fm/xms
            || $input =~ /d/xms )
        {
            parse_mode($input);
        }

        # Scan up
        if ( $input =~ /sup/xms ) {
            scan( $f / $freqdiv, 0, 'up' );
            $storelastinput++;
        }

        # Scan down
        if ( $input =~ /sdown/xms ) {
            scan( $f / $freqdiv, 0, 'down' );
            $storelastinput++;
        }

        # Scan range
        if ( $input =~ /s\ *\d+\-\d+/xms ) {
            my ( $bottom, $top ) = split( /-/xms, $input );
            $bottom =~ s/s//gx;
            if (   $bottom =~ /\d+/xms
                && $top =~ /\d+/xms
                && ( $top > $bottom ) )
            {

                # Trim any whitespace out
                $bottom =~ s/^\s+|\s+$//gx;
                $top =~ s/^\s+|\s+$//gx;
                scan( $bottom, $top, '' );
                $storelastinput++;
            }
            else {
                print "Invalid scan range.  Example:  s7200-7300\n";
            }
        }

        # If empty enter key, see if we changed frequency
        if ( $input =~ /^$/xms ) {
            if ( $f != $lastfreq ) {
                my $freqname = name_from_freq($f);

                my %freqtext = freq_text();

                if (   $freqtext{pretty_freq} !~ /NaN/
                    && $freqtext{pretty_freq} != 0 )
                {
                    print 'Switched to ' . $freqtext{pretty_freq} . ' kHz';
                    if ( defined($freqname) && $freqname ne '' ) {
                        print ' (' . $c_c . $freqname . $r . ')';
                    }
                    print "\n";
                }
                $lastfreq = $f;
            }
            return;
        }
    }

    # Store our quick settings to switch back to later
    unless ($locked) {
        $quickfreq = $f / $freqdiv;
        $quickmode = $textmode;
    }

# Store our last command for our ! repeat command if we passed a valid command
    if ($storelastinput) {
        $lastinput = $input;
    }

    return;
}

# Change mode based on current frequency
sub auto_mode {

    $automode = '1';
    ReadMode('cbreak');

    print $clearscreen;

    while ($autoloop) {
        my $extra = '';

        ReadMode('cbreak');
        my $char = ReadKey(-1);

        # We need this defined, so if it's not, make it so
        if ( !defined($char) ) {
            $char = '';
        }

        my $f = $rig->get_freq();
        my ( $mode, $width ) = $rig->get_mode();

        # If we know this frequency, add it to the prompt
        my $freqname = name_from_freq($f);
        if ( defined($freqname) && $freqname ne '' ) {
            $extra = '(' . $c_c . $freqname . $r . ') ';
        }

        $extra .= $r . '(Auto Mode)';
        my ( $prompt, $tunertext, $extratext, $bandtext )
            = create_prompt($extra);

        my %freqtext = freq_text();

        my $textmode = Hamlib::rig_strrmode($mode);

       # If the mode matches the bypassdatamode expression, don't switch modes
        unless ( defined($bypassdatamode)
            && $bypassdatamode ne ""
            && $textmode =~ /$bypassdatamode/xms )
        {
            auto_mode_set( $f, $textmode, $freqtext{cwmatch},
                $freqtext{datamatch}, $freqtext{ssbmatch} );
        }

        print $topleft . $cl . $tunertext . "\n";

        print $cl . $extratext . "\n";

        print $cl . $prompt;

        print $clearrestscreen;

        # Exit auto mode
        if ( $char eq 'q' ) { $autoloop = '0'; }

        # Exit script completely
        if ( $char eq 'Q' ) {
            $autoloop  = '0';
            $whileloop = '0';
        }

        # Enable lock mode
        if ( $char eq 'l' ) {

            # Lock to current freq/mode
            $locked    = '1';
            $quickfreq = $f / $freqdiv;
            $quickmode = $textmode;
        }

        # Disable lock mode
        if ( $char eq 'u' ) {
            $locked = '0';
        }

        # Process arrow keys, dunno why I can't seem to read the whole input
        # so just look for what the ANSI code has in it
        my $tmpf = $f / $freqdiv;

        # Up 10hz
        if ( $char =~ /$hzupkey/xms ) {
            $tmpf += $hzstep;
            parse_f($tmpf);
        }

        # Down 10hz
        if ( $char =~ /$hzdownkey/xms ) {
            $tmpf -= $hzstep;
            parse_f($tmpf);
        }

        # Up 1khz
        if ( $char =~ /$khzupkey/xms ) {
            $tmpf += $khzstep;
            parse_f($tmpf);
        }

        # Down 1khz
        if ( $char =~ /$khzdownkey/xms ) {
            $tmpf -= $khzstep;
            parse_f($tmpf);
        }

        # Up 5khz
        if ( $char =~ /$fivekhzupkey/xms ) {
            $tmpf += $fivekhzstep;
            parse_f($tmpf);
        }

        # Down 5hz
        if ( $char =~ /$fivekhzdownkey/xms ) {
            $tmpf -= $fivekhzstep;
            parse_f($tmpf);
        }

        # Up 10khz
        if ( $char =~ /$largeupkey/xms ) {
            $tmpf += $largestep;
            parse_f($tmpf);
        }

        # Down 10khz
        if ( $char =~ /$largedownkey/xms ) {
            $tmpf -= $largestep;
            parse_f($tmpf);
        }

        # Scan up
        if ( $char =~ /$scanupkey/xms ) {
            scan( $tmpf, 0, 'up' );
        }

        # Scan down
        if ( $char =~ /$scandownkey/xms ) {
            scan( $tmpf, 0, 'down' );
        }

        # Return to our locked freq/mode if locked
        if ($locked) {
            parse_f($quickfreq);
            parse_mode($quickmode);
        }

        # Set lastfreq to our last known frequency
        $lastfreq = $f;

        # If the character buffer is empty, sleep a little before looping
        if ( !$char ) {

           # Sleep can only do integers, this pattern can do sub-second sleeps
            select( undef, undef, undef, .25 );
        }

    }
    print "\nExiting back to normal mode\n";
    ReadMode('normal');
    $automode = '0';

    return;
}

# Scan the band.  If we're in auto mode when we start, we'll do a band scan
# if we started in band, otherwise we scan until stopped.  In manual mode,
# we scan the range specified
sub scan {
    my ( $f, $top, $direction ) = @_;
    my $scanchar = '';
    my $loops    = '0';
    my $bottom;

    # If we start scanning out of band, don't attempt to band scan
    my $scanstart      = '1';
    my $startoutofband = '0';

    $scanmode = '1';

    # If we're in range scan mode, scan up from the bottom
    if ($top) {
        $direction = 'up';

        # If we're range scanning, set radio to bottom
        $bottom = $f;
        parse_f($bottom);
    }

    print $clearscreen;
    while ( defined($scanchar) && $scanchar eq "" ) {

        # If we're in range scan mode, check boundaries
        if ($top) {
            my $ftmp = $rig->get_freq();
            if ( ( $ftmp / $freqdiv ) >= $top ) {
                if ( $direction eq 'up' ) { $direction = 'down'; }
            }

            if ( ( $ftmp / $freqdiv ) <= $bottom ) {
                if ( $direction eq 'down' ) { $direction = 'up'; }
            }
        }

        # If we were in Auto mode, do a band scan.  If we started out of band,
        # just keep going.
        if ($automode) {
            my %freqtext = freq_text();
            if ( $scanstart == 1 ) {
                $scanstart = '0';
                if ( $freqtext{outofband} ) {
                    $startoutofband = '1';
                }
            }

            if ( $freqtext{outofband} && $startoutofband == 0 ) {
                if    ( $direction eq 'up' )   { $direction = 'down'; }
                elsif ( $direction eq 'down' ) { $direction = 'up'; }
            }
        }

        ReadMode('cbreak');
        $scanchar = ReadKey(-1);

        # We need this defined, so if it's not, make it so
        if ( !defined($scanchar) ) {
            $scanchar = '';
        }

        # We need about 3 loops before we flush the char buffer
        if ( $loops < 3 ) { $scanchar = ''; }
        if ( $direction eq 'up' ) { $f += $scanstep; }
        if ( $direction eq 'down' ) { $f -= $scanstep; }
        parse_f($f);
        $loops++;

        # Every 10 loops, update the prompt
        if ( $loops % 10 ) {
            my ( $prompt, $tunertext, $extratext, $bandtext )
                = create_prompt();

            print $topleft;
            print $cl . $tunertext . ' ' . $extratext . "\n";
            print $cl . $prompt . "\r";
        }

        # If defined, pause a short period between frequencies
        if ( $scandelay > 0 ) {
            select( undef, undef, undef, $scandelay );
        }
    }
    ReadMode('normal');

    print $clearscreen . $topleft;
    $scanmode = '0';

    # Last our last known frequency; where we finished scanning
    $lastfreq = $f * $freqdiv;

    return;
}

sub create_prompt {
    my ($extra) = @_;

    # If we got nothing passed in, set $extra to blank
    if ( !defined($extra) ) {
        $extra = '';
    }

    my $freqcolor = $c_c;

    my %freqtext    = freq_text();
    my $pretty_freq = $freqtext{pretty_freq};

    my ( $mode, $width ) = $rig->get_mode();
    my $textmode = Hamlib::rig_strrmode($mode);
    my $vfo      = $rig->get_vfo();
    my $textvfo  = Hamlib::rig_strvfo($vfo);
    $textvfo =~ s/MEM/M/;
    $textvfo =~ tr/ABM\.//cd;
    $lastvfo = $textvfo;

# Sometimes we seem to get nonsense, set pretty_freq to 0 to avoid ugly errors
    if ( $pretty_freq eq '' || $pretty_freq =~ /NaN/ ) {
        $pretty_freq = 0;
    }

    # Only store A/B, don't store M
    if ( $textvfo ne 'M' ) { $lastvfo = $textvfo; }
    my $lockstatus = $c_g . 'U';
    if ($locked) { $lockstatus = $c_r . 'L'; }

    if ($scanmode) {
        $extra = '(Scanning) ' . $extra;
    }

    if ( $freqtext{bandtext} ne '' ) {
        $extra = $extra . ' ' . $freqtext{bandtext};
    }

    if ( $freqtext{outofband} ) {
        $freqcolor = $c_r;
        $extra = $r . $c_r . $cl . 'Warning -- Out of Band ' . $r . $extra;
    }

    # Retrieve the output power of the rig and round up
    my $outputpower
        = int(
        ( $rig->get_level_f($Hamlib::RIG_LEVEL_RFPOWER) * $powerdivider )
        + .5 );

    my $signal = $rig->get_level_i($Hamlib::RIG_LEVEL_STRENGTH);

    if ( $avgsignal && $automode ) {
        push( @signalarray, $signal );
        splice( @signalarray, 0, -$avgsamples );
        $signal = average( $signal, @signalarray );
    }

    # Pad some stuff
    $pretty_freq = sprintf( '%8s', $pretty_freq );
    $textmode    = sprintf( '%3s', $textmode );
    $signal      = sprintf( '%3s', $signal );

    my $prompt = '';

    if ( $pretty_freq < 1000 ) {
        $prompt = '(' . $c_r . 'Unknown; hamlib issue?' . $r . ')';
    }
    else {
        $prompt
            = '('
            . $freqcolor
            . $pretty_freq
            . $r . '/'
            . $c_y
            . $signal
            . $r . '/'
            . $c_g
            . $textmode
            . $r . '/'
            . $c_y
            . $outputpower . 'w'
            . $r . '/'
            . $c_m
            . $textvfo
            . $r . '/'
            . $lockstatus
            . $r . ')';
    }
    return $prompt, $freqtext{tunertext}, $extra, $freqtext{bandtext},
        $freqtext{chantext};
}

# Set the mode based on the frequency we're on when in auto mode
sub auto_mode_set {
    my ( $f, $textmode, $cwmatch, $datamatch, $ssbmatch ) = @_;

    my $modefreq = '10000000';

    # Only SSB
    if ($ssbmatch) {
        if ( $lastmode eq 'c' ) {

            # Kludge to keep us on the same frequency we just tuned to
            my $freq = $rig->get_freq();
            $freq += $cwoffset;
            my $vfo = $rig->get_vfo();
            if ( $vfo == 1 ) {
                $rig->set_freq( $Hamlib::RIG_VFO_A, $freq );
            }
            if ( $vfo == 2 ) {
                $rig->set_freq( $Hamlib::RIG_VFO_B, $freq );
            }
        }

        # Handle 60m; it's always USB for SSB
        if ( grep( /$f/xms, @sixtymfreqs ) ) {
            if ( $textmode ne 'USB' ) {
                parse_mode('u');
            }
        }
        elsif ( $f < $modefreq && $textmode ne 'LSB' ) {
            parse_mode('l');
        }
        elsif ( $f > $modefreq && $textmode ne 'USB' && $textmode ne 'FM' ) {
            parse_mode('u');
        }

        $lastmode = '';
    }

    # Skip the rest if we're not auto changing modes
    if ($allmodeset) {

        # Only CW
        if ( $cwmatch && !$ssbmatch ) {
            unless ( $textmode eq 'CW' ) {

                # Kludge to keep us on the same frequency we just tuned to
                my $freq = $rig->get_freq();
                $freq -= $cwoffset;
                my $vfo = $rig->get_vfo();
                if ( $vfo == 1 ) {
                    $rig->set_freq( $Hamlib::RIG_VFO_A, $freq );
                }
                if ( $vfo == 2 ) {
                    $rig->set_freq( $Hamlib::RIG_VFO_B, $freq );
                }

                parse_mode('c');
                $lastmode = 'c';
            }
        }

        # Only Data
        if ( !$ssbmatch && !$cwmatch && $datamatch ) {
            unless ( $textmode eq 'DATA' ) {
                parse_mode('d');
            }
        }
    }

    return;
}

sub parse_mode {
    my ($input) = @_;
    $input = lc($input);

    my ( $mode, $width ) = $rig->get_mode();
    my $textmode = Hamlib::rig_strrmode($mode);

    my $output = '';

    if ( $input =~ /u/xms ) {
        $output = 'USB';
        if ( $textmode eq $output ) { return; }
        $rig->set_mode( $Hamlib::RIG_MODE_USB, $ssb_passband );
    }
    if ( $input =~ /l/xms ) {
        $output = 'LSB';
        if ( $textmode eq $output ) { return; }
        $rig->set_mode( $Hamlib::RIG_MODE_LSB, $ssb_passband );
    }
    if ( $input =~ /c/xms ) {
        $output = 'CW';
        if ( $textmode eq $output ) { return; }
        $rig->set_mode( $Hamlib::RIG_MODE_CW, $cw_passband );
    }
    if ( $input =~ /d/xms ) {
        $output = 'DATA';
        if ( $textmode eq $output ) { return; }
        $rig->set_mode( $Hamlib::RIG_MODE_PKTUSB, $data_passband );
    }
    if ( $input =~ /du/xms ) {
        $output = 'DATA';
        if ( $textmode eq $output ) { return; }
        $rig->set_mode( $Hamlib::RIG_MODE_PKTUSB, $data_passband );
    }
    if ( $input =~ /dl/xms ) {
        $output = 'DATA';
        if ( $textmode eq $output ) { return; }
        $rig->set_mode( $Hamlib::RIG_MODE_PKTLSB, $data_passband );
    }
    if ( $input =~ /am/xms ) {
        $output = 'AM';
        if ( $textmode eq $output ) { return; }
        $rig->set_mode( $Hamlib::RIG_MODE_AM, $am_passband );
    }
    if ( $input =~ /fm/xms ) {
        $output = 'FM';
        if ( $textmode eq $output ) { return; }
        $rig->set_mode( $Hamlib::RIG_MODE_FM, $fm_passband );
    }

    unless ( $automode || $scanmode || $locked ) {
        print "Switching to $output mode\n";
    }

    return;
}

sub parse_f {
    my ($freq) = @_;

    my $f = $rig->get_freq();

    my $cleanfreq = clean_freq($freq);

    if ( $f == $cleanfreq || $cleanfreq == 0 ) { return; }

    my $freqname = name_from_freq($cleanfreq);

    if ( $cleanfreq > 0 ) {

        # Auto set mode if manually changing frequency
        # We need to pass it the frequency here so it doesn't use the one
        # on the radio since we're not setting it until later.
        # TODO: Make sure this is sane.
        if ($fautomodeset) {
            my %freqtext = freq_text($cleanfreq);

            my ( $mode, $width ) = $rig->get_mode();
            my $textmode = Hamlib::rig_strrmode($mode);

            # Pass our new freq and invalid mode so we switch properly
            auto_mode_set( $cleanfreq, 'X', $freqtext{cwmatch},
                $freqtext{datamatch}, $freqtext{ssbmatch} );
        }

        my $prettyfreq = $cleanfreq / $freqdiv;
        unless ( $locked || $automode || $scanmode ) {
            print 'Switching to ' . $prettyfreq . ' kHz';
            if ( defined($freqname) && $freqname ne '' ) {
                print ' (' . $c_c . $freqname . $r . ')';
            }
            print "\n";
        }

        # We're changing frequency, update our $lastfreq before we do
        $lastfreq = $cleanfreq * $freqdiv;
        my $vfo     = $rig->get_vfo();
        my $textvfo = Hamlib::rig_strvfo($vfo);
        if ( $vfo == 1 ) {
            $rig->set_freq( $Hamlib::RIG_VFO_A, $cleanfreq );
        }
        if ( $vfo == 2 ) {
            $rig->set_freq( $Hamlib::RIG_VFO_B, $cleanfreq );
        }

        # If in Memory mode, switch to our last known VFO first
        if ( $textvfo eq 'MEM' ) {
            $rig->set_vfo($Hamlib::RIG_VFO_VFO);

            # If we were last in memory mode, default to VFO A
            if ( $lastvfo && ( $lastvfo eq 'A' || $lastvfo eq 'M' ) ) {
                $rig->set_vfo($Hamlib::RIG_VFO_A);
                $rig->set_freq( $Hamlib::RIG_VFO_A, $cleanfreq );
            }
            if ( $lastvfo && $lastvfo eq 'B' ) {
                $rig->set_vfo($Hamlib::RIG_VFO_B);
                $rig->set_freq( $Hamlib::RIG_VFO_B, $cleanfreq );
            }
        }
    }
    else {
        print "Invalid or blank frequency\n";
    }

    return;
}

# Clean up, figure out what's frequency is probably wanted and return in hz
sub clean_freq {
    my ($freq) = @_;

    # Strip out anything but numbers and separators
    $freq =~ tr/0-9\.,//cd;

    # Normalize , separator to .
    $freq =~ s/,/\./xsm;

    # Bail out if we find multiple separators
    if ( $freq =~ /^\d+\.\d+\.\d+$/xsm ) {
        print "Multiple separators found; invalid input\n";
        return 0;
    }

    # ##.### looks like megahertz
    if ( $freq =~ /^\d{1,2}\.\d+$/xsm ) {
        $freq *= $freqdiv * $freqdiv;
    }

    # Otherwise, we assume input in Kilohertz
    else {
        $freq *= $freqdiv;
    }

    # Check to see if we're outside of tuning range
    if (   ( defined($tune_bottom) && defined($tune_top) )
        && ( $freq < $tune_bottom || $freq > $tune_top ) )
    {
        print 'Invalid input, outside of radio limits: ' . $freq . "hz\n";
        if ($enforce_tune_limit) { return 0; }
    }

    return $freq;
}

# Change a setting (TODO; not used yet)
sub change_setting {
    my ( $var, $setting ) = @_;
    print "[$var] [$setting]\n";

    #$var  =~ s/(\$\w+)/$1/eeg;
    my $newvar = \$var;
    print "scandelay: $scandelay\n";
    print '['
        . $var
        . '] is currently set to ['
        . $newvar . ' ' . ' '
        . $$newvar . ']' . "\n";
    $$var = $setting;
    print "scandelay: $scandelay\n";
    return 0;
}

# Give back a name if this frequency is known
sub name_from_freq {
    my ($freq) = @_;

    # If set, add frequency name to status text
    for my $key ( keys %freqnames ) {
        my $value = $freqnames{$key};
        my ( $keyvalue, undef ) = split( '\|', $key );
        if ( $freq eq $keyvalue ) {
            return $value;
        }
    }

    return;
}

# Give back a frequency if the channel name is known
sub freq_from_name {
    my ($channel)     = @_;
    my @channelarray  = ();
    my $channelsfound = 0;

    # Iterate through our freqnames hash looking for matching channels
    # and store them in @chanmatch
    for my $key ( keys %freqnames ) {
        my $value = $freqnames{$key};
        $value   = lc($value);
        $channel = lc($channel);

        if ( $value =~ /\Q$channel/xms ) {
            push( @channelarray, $value );
        }

        # Sort the array for humans
        @channelarray = sort(@channelarray);

        # Find out how many channel matches we found
        $channelsfound = @channelarray;
    }

    # If we matched at least one channel, figure out the next best channel
    # to switch to.
    if ($channelsfound) {
        my $preindex            = 0;
        my $currentchannelindex = -1;
        my $channelmatched      = 0;
        my $index               = 0;
        my $newchannel          = '';

        # First, find out where we are in our array
        foreach (@channelarray) {
            my $preindexfoundchannel = $_;

            if ( $preindexfoundchannel eq $lastchannel ) {
                $currentchannelindex = $preindex;
            }
            else {
                $preindex++;
            }
        }

        # Now that we know where our current channel is in the array, interate
        # through the array until we reach the next channel
        foreach (@channelarray) {
            my $foundchannel = $_;

            unless ($channelmatched) {

               # If the array index is above the current channel, switch to it
                if ( $index > $currentchannelindex ) {
                    $newchannel = $foundchannel;
                    $channelmatched++;
                }
                else {
                    $index++;
                }

                # If we're at the end of the array, change to the first match
                if ( $index >= $channelsfound ) {
                    $newchannel = $channelarray[0];
                    $channelmatched++;
                }
            }

            # Change to the channel we identified to go to
            for my $key ( keys %freqnames ) {
                my $value = $freqnames{$key};
                $value   = lc($value);
                $channel = lc($channel);
                my $mode = '';

                if ( $value =~ /\Q$newchannel/xms ) {
                    $lastchannel = $value;

                    # If a specific mode has been specified, split it out
                    if ( $key =~ /\|/xms ) {
                        ( $key, $mode ) = split( '\|', $key );
                    }
                    my $returnfreq = $key / $freqdiv;
                    return ( $returnfreq, $mode );
                }
            }
        }
    }
    else {
        if ( $channel ne "" ) {
            print 'Unknown channel:  ' . $channel . "\n";
        }
    }

    # If no channel passed, print our known channels
    if ( $channel eq "" ) {
        for my $key ( keys %freqnames ) {
            my $value = $freqnames{$key};
            $value   = lc($value);
            $channel = lc($channel);
            print $value . "\n";
        }
    }

    return;
}

# Save a note about this frequency
sub save_note {
    my ($note) = @_;
    if ( defined($notefile) && length($note) > 0 ) {
        open 'NOTEFILE', '>>', $notefile or do {
            print 'Can\'t write to ' . $notefile . "\n";
            return;
        };
        my $timestamp   = logtimestamp();
        my $f           = $rig->get_freq();
        my $pretty_freq = $f / $freqdiv;
        my ( $mode, $width ) = $rig->get_mode();
        my $textmode = Hamlib::rig_strrmode($mode);
        print NOTEFILE $timestamp . ' - '
            . $pretty_freq . ' ['
            . $textmode . '] '
            . $note . "\n";
        close('NOTEFILE');

        return;
    }
}

# Get a pretty timestamp for our logfile
sub logtimestamp {
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst )
        = localtime(time);
    my $nice_timestamp = sprintf(
        '%04d' . '-' . '%02d' . '-' . '%02d' . ' ' . '%02d' . ':' . '%02d'
            . ':' . '%02d',
        $year + 1900,
        $mon + 1, $mday, $hour, $min, $sec
    );

    return $nice_timestamp;
}

sub usage {
    my ($exted) = @_;

    if ( $exted eq '?' ) {
        my $helptext = <<'END';
Manual mode commands

auto - Switch to autotune mode
   f - Switch to frequency in kHz
   u - Switch to Upper Side Band
   l - Switch to Lower Side Band
   c - Switch to CW
  am - Switch to AM
  fm - Switch to FM
   d - Switch to USB Data Mode
  dl - Switch to LSB Data mode
   a - Switch to VFO A
   b - Switch to VFO B
   r - Revert to last freq/mode
   q - Exit autotune mode or exit
   ! - Repeat last command
   ? - Help
  ?? - Auto mode help
lock - Lock to current freq/mode
unlock - Unlock
chan name - Switch to frequency of named channel
note - Capture a note about the current frequency
f7188lb - Move to 7188kHz LSB on VFO B
28450 - Move to 28450kHz (assumes input in kilohertz)
28203.5 or 28.2035 - Move to 28203.5kHz (only way to input sub-khz frequencies)
s7200-7300 - Scan 7200 to 7300

(freq/sig/mode/lockstatus)
END
        print $helptext;
    }

    if ( $exted eq '??' ) {
        my $morehelptext = <<'END';
Auto mode commands

q - Exit auto mode
Q - Exit script
l - Lock frequency/mode
u - Unlock
Cursor up/down - +/- 1khz
Cursor right/left - +/- 10hz
Page up/down - +/- 10khz
Home up/down - Scan up/down
END
        print $morehelptext;
    }

    return;
}

# Set up our color tags
sub color_tags {

    # If we're colorizing, set our bold default
    if ( $coloroutput && $ansi ) {
        $r = RESET();

        # Don't use bright colors on a light terminal theme
        if ($lightterm) {
            $c_r = RED();
            $c_g = GREEN();
            $c_c = CYAN();
            $c_m = MAGENTA();
            $c_b = BLUE();
            $c_y = YELLOW();
        }
        else {
            $c_r = BRIGHT_RED();
            $c_g = BRIGHT_GREEN();
            $c_c = BRIGHT_CYAN();
            $c_m = BRIGHT_MAGENTA();
            $c_b = BRIGHT_BLUE();
            $c_y = BRIGHT_YELLOW();
        }
    }

    # Go to start of line, clear entire line
    $cl = "\r\033[2K";

    # Clear from cursor to the end of the screen
    $clearrestscreen = "\033[J\r";

    # Clear the entire screen
    $clearscreen = "\033[2J";

    # Move cursor to the 0,0 position
    $topleft = "\033[0;0H";

    return;
}

# Average a passed-in array
sub average {
    my ( $signal, @array ) = @_;
    my $intval = '0.5';

    my $arraycount = @array;
    unless ($arraycount) { return $signal; }

    # First time through, set to the first signal we see
    if ( $lastavg == -99 ) { $lastavg = $signal; }

    if ( $avgtimes >= $avgsamples ) {
        my $sum;
        foreach my $item (@array) {
            $sum += $item;
        }
        $avgtimes = '0';
        $signal   = int( $sum / @array + .5 );
        if ( $signal < 0 ) { $intval *= -1; }
        $lastavg = $signal;
    }
    else {
        $avgtimes++;
        $signal = $lastavg;
    }

    return $signal;
}

# Open the hamlib connection
sub rigopen {
    if ( $rigopens > 25 ) {
        $autoloop = '0';
    }
    $rigopens++;
    $rig->open();

    return;
}

# Close the hamlib connection
sub rigclose {
    $rig->close();

    return;
}
