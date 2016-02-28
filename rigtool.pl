#!/usr/bin/perl

# Perl script to control a radio using HamLib

use Hamlib;
use Term::ReadKey;
use strict;
use warnings;

our $VERSION = 1.1;

# Comment out to enable hamlib debugging (very noisy)
Hamlib::rig_set_debug($Hamlib::RIG_DEBUG_NONE);

# Change to your rig type, port, etc
my $rig = new Hamlib::Rig($Hamlib::RIG_MODEL_NETRIGCTL);
$rig->set_conf( '', 'localhost:4532' );

# Your call priviledges (sorry, US-only for now, blank this out for elsewhere)
my $country = 'usa';
my $license = 'advanced';

# Pass band widths
my $cw_passband   = '1000';
my $data_passband = '3000';
my $ssb_passband  = '3000';
my $am_passband   = '6000';

# Radio tuning limits
my $tune_bottom        = '30000';
my $tune_top           = '56000000';
my $enforce_tune_limit = '0';

# If your radio offsets when it switches between CW and SSB, you can set that here
# or set it to 0 if you don't want the script twiddling this on CW/SSB transitions
my $cwoffset = '700';

# If set to 1, execute auto_mode_set on manual frequency change.  cw/ssb switch
# depends on $allmodeset setting
my $fautomodeset = '1';

# If set to 0, do not switch between cw and ssb, but still sets lsb/usb
# 1 executes auto_mode_set and switches beween cw and ssb as well as sets lsb/usb
# and in the future perhaps data modes as well
my $allmodeset = '0';

# Average the last N signals or not
my $avgsignal = '1';

# How many samples to average
my $avgsamples = '5';

# Determine if we show tuneinfo or not.  If you have an autotuner or do not need to
# manually tune you can just set this to 0.  If you do want this information, you
# will need to modify the %tuneinfo variable in the get_bandplan function
my $showtuneinfo = '1';

# How many times can we fail opening the port before we give up?
my $rigopenmax = '25';

# Step sizes for cursor keys in auto mode
my $hzstep    = '0.1';
my $khzstep   = '1.0';
my $largestep = '10';

# Step size for can mode
my $scanstep = '2.0';

# Don't touch below here unless modifying %tuneinfo
# if you want to modify that

# Define our cw and ssb freqs and get them defined based on license
my ( @cwfreqs, @datafreqs, @ssbfreqs );

# Define our tuner info
my %tuneinfo = ();

# Define our frequency names
my %freqnames = ();

get_bandplan( $country, $license );

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

# Check to see if we have the Term::ANSIColor module so it's not a hard requirement
my $ansi = eval {
    require Term::ANSIColor;
    Term::ANSIColor->import(':constants');
    1;
};

# Set up colors
my ( $r, $c_r, $c_g, $c_c, $c_m, $c_b, $c_y, $cl );

# Use color output
my $coloroutput = '1';

# Dark terminal background, set light = 0
my $light = '0';
color_tags();

# Lock the mode (set it back if it's changed on the radio)
# Really only works in auto mode (?)
my $locked = '0';

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

# If auto is the first parameter, go straight to auto mode

my $arg = '';

if ( scalar(@ARGV) ) {
    $arg = $ARGV[0];
}

if ( $arg eq 'auto' ) {
    $autoloop = '1';
    auto_mode();
}

# Loop through our prompt while we're running
while ($whileloop) {
    my ( $prompt, $tunertext, $extratext ) = create_prompt();
    print $prompt . ' ' . $tunertext . ': ';
    my $input = <STDIN>;
    chomp $input;
    $input = lc($input);
    parse_input($input);

    # Return to our locked freq/mode if locked
    if ($locked) {
        parse_f($quickfreq);
        parse_mode($quickmode);
    }
}

rigclose();

# We only expect to open the connection once, any more is something buggy
if ( $rigopens > $rigopenmax ) {
    print "Something wrong with rigctld?  Tried to cycle $rigopens times\n";
}
elsif ( $rigopens > 1 ) {
    print "We opened the hamlib connection $rigopens times\n";
}

# Clean up
sub freq_text {
    my $cwmatch   = '0';
    my $datamatch = '0';
    my $ssbmatch  = '0';
    my $matched   = '';
    my $tunertext = '';
    my $testfreq  = '1000';

    my $f = $rig->get_freq();

    # Sometimes we seem to get nonsense, try to cycle the connection
    if ( $f < $testfreq ) {
        rigclose();
        rigopen();
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
    my $outofband = 0;
    unless ( $matched || !defined($license) ) { $outofband = '1'; }

    return (
        $pretty_freq, $cwmatch,   $datamatch,
        $ssbmatch,    $outofband, $tunertext
    );
}

sub parse_input {
    my ($input) = @_;

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
        $autoloop = 1;
        auto_mode();
        $input = '';
        $skip++;
    }

    # Lock to current freq/mode
    if ( $input =~ /^lock/xms ) {
        print "Locking\n";
        $locked    = 1;
        $quickfreq = $f / $freqdiv;
        $quickmode = $textmode;
        $input     = '';
        $skip++;
    }

    # Unlock
    if ( $input =~ /^unlock/xms ) {
        print "Unlocking\n";
        $locked = 0;
        $input  = '';
        $skip++;
    }

    if ( $input =~ /q/xms ) {
        $whileloop = 0;
        return;
    }

    # Do nothing if we're locked
    if ($locked) { return; }

    if ( $input =~ /chan/xms ) {
        my ( $command, @channel ) = split( /\ /xms, $input );
        my $channel = join( " ", @channel );
        my $freq = freq_from_name($channel);
        if ( defined($freq) && $freq != 0 ) {
            parse_f($freq);
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
            $input = '';
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
        if ( $input =~ /f/xms || $input =~ /^[0-9\.,]+$/xms ) {
            parse_f($input);
            $storelastinput++;
        }

        # Parse and change mode
        if (   $input =~ /u/xms
            || $input =~ /l/xms
            || $input =~ /c/xms
            || $input =~ /am/xms
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
            my $quickfreqtest = $quickfreq * $freqdiv;
            if ( $f != $quickfreqtest ) {
                my $freqname = name_from_freq($f);
                my ($pretty_freq, $cwmatch,   $datamatch,
                    $ssbmatch,    $outofband, $tunertext
                ) = freq_text();
                print 'Switched to ' . $pretty_freq . ' kHz';
                if ( defined($freqname) && $freqname ne '' ) {
                    print ' (' . $c_c . $freqname . $r . ')';
                }
                print "\n";
            }
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
    $automode = 1;
    ReadMode('cbreak');

    # Clear screen and move to upper left corner
    print "\033[2J";

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

        $extra .= $r . '(Auto mode)';
        my ( $prompt, $tunertext, $extratext ) = create_prompt($extra);

   # TODO:  Fix tunertextextra so I'm not getting the same text back from both
        my ( $pretty_freq, $cwmatch, $datamatch,
            $ssbmatch, $outofband, $tunertextextra )
            = freq_text();
        my $textmode = Hamlib::rig_strrmode($mode);

        auto_mode_set( $f, $textmode, $cwmatch, $datamatch, $ssbmatch );

        # Move the cursor to 0,0
        print "\033[0;0H";
        print $cl . $tunertext . ' ' . $extratext;

        # Erase the rest of the line
        print "\033[K\n";
        print $cl . $prompt;

        # Clear from cursor to end of screen
        print "\033[J\r";

        # Exit auto mode
        if ( $char eq 'q' ) { $autoloop = 0; }

        # Enable lock mode
        if ( $char eq 'l' ) {

            # Lock to current freq/mode
            $locked    = 1;
            $quickfreq = $f / $freqdiv;
            $quickmode = $textmode;
        }

        # Disable lock mode
        if ( $char eq 'u' ) {
            $locked = 0;
        }

        # Process arrow keys, dunno why I can't seem to read the whole input
        # so just look for what the ANSI code has in it
        my $tmpf = $f / $freqdiv;

        # Right; Up 10hz
        if ( $char =~ /C/xms ) {
            $tmpf += $hzstep;
            parse_f($tmpf);
        }

        # Left; Down 10hz
        if ( $char =~ /D/xms ) {
            $tmpf -= $hzstep;
            parse_f($tmpf);
        }

        # Up; Up 1khz
        if ( $char =~ /A/xms ) {
            $tmpf += $khzstep;
            parse_f($tmpf);
        }

        # Down; Down 1khz
        if ( $char =~ /B/xms ) {
            $tmpf -= $khzstep;
            parse_f($tmpf);
        }

        # Page Up; up 10khz
        if ( $char =~ /5/xms ) {
            $tmpf += $largestep;
            parse_f($tmpf);
        }

        # Page Down; down 10khz
        if ( $char =~ /6/xms ) {
            $tmpf -= $largestep;
            parse_f($tmpf);
        }

        # Home; scan up.    I see 1 in screen, 7 outside, no idea why
        if ( $char =~ /1/xms || $char =~ /7/xms ) {
            scan( $tmpf, 0, 'up' );
        }

        # End; scan down.  I see 4 in screen, 8 outside, no idea why
        if ( $char =~ /4/xms || $char =~ /8/xms ) {
            scan( $tmpf, 0, 'down' );
        }

        # Return to our locked freq/mode if locked
        if ($locked) {
            parse_f($quickfreq);
            parse_mode($quickmode);
        }

        # If the character buffer is empty, sleep a little before looping
        if ( !$char ) {

           # Sleep can only do integers, this pattern can do sub-second sleeps
            select( undef, undef, undef, .25 );
        }

    }
    print "\nExiting back to normal mode\n";
    ReadMode('normal');
    $automode = 0;

    return;
}

# Scan the band.  If we're in auto mode when we start, we'll do a band scan
# if we started in band, otherwise we scan until stopped.  In manual mode,
# we scan the range specified
sub scan {
    my ( $f, $top, $direction ) = @_;
    my $scanchar = '';
    my $loops    = 0;
    my $bottom;

    # If we start scanning out of band, don't attempt to band scan
    my $scanstart      = 1;
    my $startoutofband = 0;

    $scanmode = 1;

    # If we're in range scan mode, scan up from the bottom
    if ($top) {
        $direction = 'up';

        # If we're range scanning, set radio to bottom
        $bottom = $f;
        parse_f($bottom);
    }

    print "\033[2J";
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
            my ($pretty_freq, $cwmatch,   $datamatch,
                $ssbmatch,    $outofband, $tunertext
            ) = freq_text();
            if ( $scanstart == 1 ) {
                $scanstart = 0;
                if ($outofband) {
                    $startoutofband = 1;
                }
            }

            if ( $outofband && $startoutofband == 0 ) {
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
            my ( $prompt, $tunertext, $extratext ) = create_prompt();

            print "\033[0;0H";
            print "\n";
            print $cl . $tunertext . ' ' . $extratext . "\n";
            print $cl . $prompt . "\r";
        }
    }
    ReadMode('normal');

    print "\033[2J";
    $scanmode = 0;

    return;
}

sub create_prompt {
    my ($extra) = @_;

    # If we got nothing passed in, set $extra to blank
    if ( !defined($extra) ) {
        $extra = '';
    }

    my $freqcolor = $c_c;
    my ($pretty_freq, $cwmatch,   $datamatch,
        $ssbmatch,    $outofband, $tunertext
    ) = freq_text();
    my ( $mode, $width ) = $rig->get_mode();
    my $textmode = Hamlib::rig_strrmode($mode);
    my $vfo      = $rig->get_vfo();
    my $textvfo  = Hamlib::rig_strvfo($vfo);
    $textvfo =~ s/MEM/M/;
    $textvfo =~ tr/ABM\.//cd;
    $lastvfo = $textvfo;

    # Only store A/B, don't store M
    if ( $textvfo ne 'M' ) { $lastvfo = $textvfo; }
    my $lockstatus = $c_g . 'U';
    if ($locked) { $lockstatus = $c_r . 'L'; }

    if ($scanmode) {
        $extra = '(Scanning) ' . $extra;
    }

    if ($outofband) {
        $freqcolor = $c_r;
        $extra = $r . $c_r . $cl . 'Warning -- Out of Band ' . $r . $extra;
    }

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
    my $prompt
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
        . $c_m
        . $textvfo
        . $r . '/'
        . $lockstatus
        . $r . ')';
    return $prompt, $tunertext, $extra;
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
        if (   $f == '5330500'
            || $f == '5346500'
            || $f == '5357000'
            || $f == '5371500'
            || $f == '5403500' )
        {
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
        $rig->set_mode( $Hamlib::RIG_MODE_RTTY, $data_passband );
    }
    if ( $input =~ /am/xms ) {
        $output = 'AM';
        if ( $textmode eq $output ) { return; }
        $rig->set_mode( $Hamlib::RIG_MODE_AM, $am_passband );
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
        if ($fautomodeset) {
            my ($pretty_freq, $cwmatch,   $datamatch,
                $ssbmatch,    $outofband, $tunertext
            ) = freq_text();
            my ( $mode, $width ) = $rig->get_mode();
            my $textmode = Hamlib::rig_strrmode($mode);

            # Pass our new freq and invalid mode so we switch properly
            auto_mode_set( $cleanfreq, 'X', $cwmatch, $datamatch, $ssbmatch );
        }

        my $prettyfreq = $cleanfreq / $freqdiv;
        unless ( $locked || $automode || $scanmode ) {
            print 'Switching to ' . $prettyfreq . ' kHz';
            if ( defined($freqname) && $freqname ne '' ) {
                print ' (' . $freqname . ')';
            }
            print "\n";
        }
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

# Define our band plans
# Data isn't really used right now, but define it.  Multiple flags can be active
# as there is usage overlap such a data/cw, ssb/cw etc
sub get_bandplan {
    my ( $bandcountry, $bandlicense ) = @_;
    $bandcountry = lc($bandcountry);
    $bandlicense = lc($bandlicense);

    my $privs = 0;

    # Build up priviledges from the base of novice.  This is of course based
    # on the US band plan.  Other band plans should be easily added and put
    # in their own country section

    if ( $bandcountry eq 'usa' ) {
        if ( $bandlicense eq 'novice' )     { $privs = 1; }
        if ( $bandlicense eq 'technician' ) { $privs = 2; }
        if ( $bandlicense eq 'general' )    { $privs = 3; }
        if ( $bandlicense eq 'advanced' )   { $privs = 4; }
        if ( $bandlicense eq 'extra' )      { $privs = 5; }

        if ( $privs == 0 ) {
            print 'Unknown license ' . $bandlicense . "\n";
        }

        # Novice
        if ( $privs > 0 ) {
            my @newcwfreqs = (
                '3525000-3600000',      # 80m
                '7025000-7125000',      # 40m
                '21025000-21200000',    # 15m
                '28000000-28300000'     # 10m
            );

            my @newdatafreqs = ();

            my @newssbfreqs = (
                '28300000-28500000'     # 10m
            );

            push( @cwfreqs,   @newcwfreqs );
            push( @datafreqs, @newdatafreqs );
            push( @ssbfreqs,  @newssbfreqs );
        }

        # Technician
        if ( $privs > 1 ) {
            my @newcwfreqs = (
                '50000000-50100000'     # 6m
            );

            my @newdatafreqs = ();

            my @newssbfreqs = (
                '50100000-54000000'     # 6m
            );

            push( @cwfreqs,   @newcwfreqs );
            push( @datafreqs, @newdatafreqs );
            push( @ssbfreqs,  @newssbfreqs );
        }

        # General
        if ( $privs > 2 ) {
            my @newcwfreqs = (
                '1800000-2000000',      # 160m
                '3525000-3600000',      # 80m
                '5330500', '5346500', '5357000', '5371500', '5403500',   # 60m
                '7025000-7125000',                                       # 40m
                '10100000-10150000',                                     # 30m
                '14025000-14150000',                                     # 20m
                '18068000-18110000',                                     # 17m
                '21025000-21200000',                                     # 15m
                '24890000-24930000',                                     # 12m
                '28000000-28300000'                                      # 10m
            );

            my @newdatafreqs = (
                '1800000-2000000',    # 160m
                '3525000-3600000',    # 80m
                '5330500', '5346500', '5357000', '5371500', '5403500',   # 60m
                '7025000-7125000',                                       # 40m
                '10100000-10150000',                                     # 30m
                '14025000-14150000',                                     # 20m
                '18068000-18110000',                                     # 17m
                '21025000-21200000',                                     # 15m
                '24890000-24930000',                                     # 12m
                '28000000-28300000'                                      # 10m
            );

            my @newssbfreqs = (
                '1800000-2000000',    # 160m
                '3800000-4000000',    # 80m
                '5330500', '5346500', '5357000', '5371500', '5403500',   # 60m
                '7175000-7300000',                                       # 40m
                '10100000-10150000',                                     # 30m
                '14225000-14350000',                                     # 20m
                '18110000-18168000',                                     # 17m
                '21275000-21450000',                                     # 15m
                '24930000-24990000',                                     # 12m
                '28500000-29700000'                                      # 10m
            );

            push( @cwfreqs,   @newcwfreqs );
            push( @datafreqs, @newdatafreqs );
            push( @ssbfreqs,  @newssbfreqs );
        }

        # Advanced
        if ( $privs > 3 ) {
            my @newcwfreqs = ();

            my @newdatafreqs = ();

            my @newssbfreqs = (
                '3700000-3800000',      # 80m
                '7125000-7175000',      # 40m
                '14175000-14225000',    # 20m
                '21225000-21275000'     # 15m
            );

            push( @cwfreqs,   @newcwfreqs );
            push( @datafreqs, @newdatafreqs );
            push( @ssbfreqs,  @newssbfreqs );
        }

        # Extra
        if ( $privs > 4 ) {
            my @newcwfreqs = (
                '3500000-3525000',      # 80m
                '7000000-7025000',      # 40m
                '14000000-14025000',    # 20m
                '21000000-21025000'     # 15m
            );

            my @newdatafreqs = ();

            my @newssbfreqs = (
                '3600000-3700000',      # 80m
                '14150000-14175000',    # 20m
                '21200000-21225000'     # 15m
            );

            push( @cwfreqs,   @newcwfreqs );
            push( @datafreqs, @newdatafreqs );
            push( @ssbfreqs,  @newssbfreqs );
        }
    }

    # Define our tuner info
    %tuneinfo = (
        '1800000-1850000'   => 'A 6.0 4.9',    # 160m
        '1850000-1950000'   => 'A 5.0 5.0',    # 160m
        '1950000-2000000'   => 'A 3.9 5.1',    # 160m
        '3535000-3600000'   => 'L 3.8 4.5',    # 80m
        '3700000-3900000'   => 'ATU',          # 80m
        '3900000-4000000'   => 'L 3.0 4.0',    # 80m
        '5330500-5403500'   => 'K 2.9 1.0',    # 60m
        '7025000-7125000'   => 'I 1.2 5.0',    # 40m
        '7125000-7180000'   => 'I 2.2 4.9',    # 40m
        '7180000-7220000'   => 'I 2.1 4.2',    # 40m
        '7220000-7300000'   => 'I 2.1 4.0',    # 40m
        '10100000-10150000' => 'G 2.8 4.0',    # 30m
        '14025000-14350000' => 'ATU',          # 20m
        '18068000-18168000' => 'C 2.0 0.5',    # 17m
        '21025000-21450000' => 'ATU',          # 15m
        '24890000-24990000' => 'ATU',          # 12m
        '28000000-29700000' => 'Direct',       # 10m
        '50000000-51000000' => 'C 0.2 2.2',    # 6m
        '51000000-52000000' => 'B 3.0 2.2',    # 6m
        '52000000-53000000' => 'B 6.0 2.0',    # 6m
        '53000000-54000000' => 'UNKNOWN'       # 6m
    );

    # Define our frequency names
    %freqnames = (
        '5330500'  => '60M CH1',
        '5346500'  => '60M CH2',
        '5357000'  => '60M CH3/JT65',
        '5371500'  => '60M CH4',
        '5403500'  => '60M CH5',
        '1838000'  => '160M JT65',
        '3576000'  => '80M JT65',
        '7076000'  => '40M JT65',
        '10138000' => '30M JT65',
        '14076000' => '20M JT65',
        '18102000' => '17M JT65',
        '21076000' => '15M JT65',
        '24917000' => '12M JT65',
        '28076000' => '10M JT65',
        '14200000' => 'Analog SSTV',
        '14233000' => 'Digital SSTV',
        '7200000'  => '40M Lids',
    );

    return;
}

# Give back a name if this frequency is known
sub name_from_freq {
    my ($freq) = @_;

    # If set, add frequency name to status text
    for my $key ( keys %freqnames ) {
        my $value = $freqnames{$key};

        if ( $freq eq $key ) {
            return $value;
        }
    }

    return;
}

# Give back a frequency if the channel name is known
sub freq_from_name {
    my ($channel) = @_;
    for my $key ( keys %freqnames ) {
        my $value = $freqnames{$key};
        $value   = lc($value);
        $channel = lc($channel);

        # Allow a substring match
        if ( $value =~ /\Q$channel/xms ) {
            return $key / $freqdiv;
        }
    }

    print 'Unknown channel:  ' . $channel . "\n";
    return;
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

# Set up our color tags if we're set to use it
sub color_tags {

    # If we're colorizing, set our bold default
    if ( $coloroutput && $ansi ) {
        $r = RESET();

        # Don't use bright colors on a light terminal theme
        if ($light) {
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

    # Other tags to use
    $cl = "\r\033[2K";

    return;
}

# Average a passed-in array
sub average {
    my ( $signal, @array ) = @_;
    my $intval = 0.5;

    my $arraycount = @array;
    unless ($arraycount) { return $signal; }

    # First time through, set to the first signal we see
    if ( $lastavg == -99 ) { $lastavg = $signal; }

    if ( $avgtimes >= $avgsamples ) {
        my $sum;
        foreach my $item (@array) {
            $sum += $item;
        }
        $avgtimes = 0;
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

        #$whileloop = 0;
        $autoloop = 0;
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
