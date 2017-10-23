package rigtool;

# URL for Hamlib
our $hamliburl = "localhost:4532";

# Your call priviledges (sorry, US-only for now, blank this out for elsewhere)
our $country = 'USA';
our $license = 'Advanced';

# Note file to use
# Location of file which will pause scanning
my $home = $ENV{"HOME"};
our $notefile = $home . '/rigtoolnotes.txt';

# Pass band widths
our $cw_passband   = '1000';
our $data_passband = '3000';
our $ssb_passband  = '3000';
our $am_passband   = '6000';
our $fm_passband   = '12000';

# Radio tuning limits
our $tune_bottom        = '30000';
our $tune_top           = '56000000';
our $enforce_tune_limit = '0';

# Power divider.  Example, if I want 15W, I want it to set the power to .06, which is 15/255
our $powerdivider = '255';

# If your radio offsets when it switches between CW and SSB, you can set that here
# or set it to 0 if you don't want the script twiddling this on CW/SSB transitions
our $cwoffset = '700';

# If set to 1, execute auto_mode_set on manual frequency change.  cw/ssb switch
# depends on $allmodeset setting
our $fautomodeset = '1';

# If specified and the radio is set to this mode, do not force change modes if
# auto_mode_set is used.  This prevents things like WSJT-X switching to Data mode
# for JT65 and the script changing it back to USB.
our $bypassdatamode = '[PKT.SB]';

# If set to 0, do not switch between cw and ssb, but still sets lsb/usb
# 1 executes auto_mode_set and switches beween cw and ssb as well as sets lsb/usb
# and in the future perhaps data modes as well
our $allmodeset = '0';

# Average the last N signals or not
our $avgsignal = '1';

# How many samples to average
our $avgsamples = '5';

# Determine if we show tuneinfo or not.  If you have an autotuner or do not need to
# manually tune you can just set this to 0.  If you do want this information, you
# will need to modify the %tuneinfo variable in the get_bandplan function
our $showtuneinfo = '1';

# Determine if we show band info or not (ie: what band we're on)
our $showbandinfo = '1';

# Lock the mode (set it back if it's changed on the radio)
# Really only works in auto mode (?)
our $locked = '0';

# How many times can we fail opening the port before we give up?
our $rigopenmax = '25';

# Step sizes for cursor keys in auto mode
our $hzstep      = '0.1';
our $khzstep     = '1.0';
our $fivekhzstep = '5.0';
our $largestep   = '10.0';

# Step keys
our $hzupkey        = 'C';
our $hzdownkey      = 'D';
our $khzupkey       = 'A';
our $khzdownkey     = 'B';
our $fivekhzupkey   = '5';
our $fivekhzdownkey = '6';
our $largeupkey     = '[17H]';
our $largedownkey   = '[48F]';

# Scan keys
our $scanupkey   = '2';
our $scandownkey = '3';

# Step size for scan mode
our $scanstep = '.5';

# Scan delay, in seconds
our $scandelay = '.01';

# If you want to have color output, set this to 1
our $coloroutput = '1';

# If you're using a dark terminal background, set light = 0
our $lightterm = '0';

# Define 60M for our bandplan
our @sixtymfreqs = ( '5330500', '5346500', '5357000', '5371500', '5403500' );

# Define our (optional) tuner info
our %tuneinfo = (
    '1800000-1900000'   => 'A 6.0 5.5',    # 160m
    '1900000-1950000'   => 'A 5.0 5.1',    # 160m
    '1950000-2000000'   => 'A 4.1 5.1',    # 160m
    '3535000-3600000'   => 'L 2.9 5.9',    # 80m
    '3600000-3825000'   => 'ATU',          # 80m
    '3825000-3850000'   => 'L 2.0 5.0',    # 80m
    '3850000-4000000'   => 'L 1.1 5.1',    # 80m
    '5330500-5403500'   => 'K 2.0 3.0',    # 60m
    '7025000-7125000'   => 'I 4.0 4.0',    # 40m
    '7125000-7250000'   => 'I 2.9 4.0',    # 40m
    '7250000-7300000'   => 'ATU',          # 40m
    '10100000-10150000' => 'G 6.0 5.5',    # 30m
    '14025000-14250000' => 'D 2.9 4.0',    # 20m
    '14250000-14350000' => 'ATU',          # 20m
    '18068000-18168000' => 'C 2.0 0.5',    # 17m
    '21025000-21300000' => 'B 2.9 3.5',    # 15m
    '21300000-21450000' => 'ATU',          # 15m
    '24890000-24990000' => 'B 1.8 3.0',    # 12m
    '28000000-29700000' => 'ATU',          # 10m
    '50000000-54000000' => 'ATU'           # 6m
);

# Define our (optional) tuner info
# Old, something changed?
our %oldtuneinfo = (
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
    '50000000-51000000' => 'B 1.1 3.5',    # 6m
    '51000000-52000000' => 'B 6.1 3.0',    # 6m
    '52000000-53000000' => 'B 1.1 7.1',    # 6m
    '53000000-54000000' => 'F 1.2 3.6'     # 6m
);

# Define our (optional) frequency names.  If the channel does not conform to
# the standard <10Mhz LSB rule (such as data modes), add the specific mode
# use after the frequency, such as 7070000|d
our %freqnames = (
    '1838000|d'   => '160M JT65',
    '2500000|am'  => 'WWV 2MHZ',
    '5000000|am'  => 'WWV 5MHZ',
    '3576000|d'   => '80M JT65',
    '5330500'     => '60M CH1',
    '5346500'     => '60M CH2',
    '5357000'     => '60M CH3/JT65',
    '5371500'     => '60M CH4',
    '5403500'     => '60M CH5',
    '7070000|d'   => '40M PSK31',
    '7076000|d'   => '40M JT65',
    '10000000|am' => 'WWV 10MHZ',
    '10138000|d'  => '30M JT65',
    '10142150|d'  => '30M PSK31',
    '14070150|d'  => '20M PSK31',
    '14076000|d'  => '20M JT65',
    '15000000|am' => 'WWV 15MHZ',
    '18102000|d'  => '17M JT65',
    '20000000|am' => 'WWV 20MHZ',
    '21076000|d'  => '15M JT65',
    '24917000|d'  => '12M JT65',
    '25000000|am' => 'WWV 25MHZ',
    '28076000|d'  => '10M JT65',
    '14200000|d'  => 'Analog SSTV',
    '14233000|d'  => 'Digital SSTV',
    '28450000'    => '10M Call',
    '7200000'     => '40M Lids',
    '3840000'     => '80M Lids',
    '8472000'     => 'WLO Marine',
);

# Define our (optional) band names
our %bandnames = (
    '1800000-2000000'   => '160M',
    '3500000-4000000'   => '80M',
    '5330500-5403500'   => '60M',
    '7000000-7300000'   => '40M',
    '10100000-10150000' => '30M',
    '14000000-14350000' => '20M',
    '18068000-18168000' => '17M',
    '21000000-21450000' => '15M',
    '24890000-24990000' => '12M',
    '28000000-29700000' => '10M',
    '50000000-54000000' => '6M',
);

# Define our band plans
# datafreqs isn't really used right now, but define it.  Multiple flags can
# be active as there is usage overlap such a data/cw, ssb/cw etc
sub get_bandplan {
    my ( $bandcountry, $bandlicense ) = @_;
    $bandcountry = lc($bandcountry);
    $bandlicense = lc($bandlicense);

    my $privs = '0';

    # Build up priviledges from the base of novice.  This is of course based
    # on the US band plan.  Other band plans should be easily added and put
    # in their own country section

    if ( $bandcountry eq 'usa' ) {
        if ( $bandlicense eq 'novice' )     { $privs = '1'; }
        if ( $bandlicense eq 'technician' ) { $privs = '2'; }
        if ( $bandlicense eq 'general' )    { $privs = '3'; }
        if ( $bandlicense eq 'advanced' )   { $privs = '4'; }
        if ( $bandlicense eq 'extra' )      { $privs = '5'; }

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

    return ( \@cwfreqs, \@datafreqs, \@ssbfreqs );
}

1;
