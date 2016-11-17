package rigtool;

# URL for Hamlib
our $hamliburl = "localhost:4532";

# Your call priviledges (sorry, US-only for now, blank this out for elsewhere)
our $country = 'USA';
our $license = 'Advanced';

# Pass band widths
our $cw_passband   = '1000';
our $data_passband = '3000';
our $ssb_passband  = '3000';
our $am_passband   = '6000';

# Radio tuning limits
our $tune_bottom        = '30000';
our $tune_top           = '56000000';
our $enforce_tune_limit = '0';

# If your radio offsets when it switches between CW and SSB, you can set that here
# or set it to 0 if you don't want the script twiddling this on CW/SSB transitions
our $cwoffset = '700';

# If set to 1, execute auto_mode_set on manual frequency change.  cw/ssb switch
# depends on $allmodeset setting
our $fautomodeset = '1';

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

# How many times can we fail opening the port before we give up?
our $rigopenmax = '25';

# Step sizes for cursor keys in auto mode
our $hzstep    = '0.1';
our $khzstep   = '1.0';
our $largestep = '10';

# Step size for scan mode
our $scanstep = '2.0';

# Scan delay, in seconds
our $scandelay = '.1';

# Define our (optional) tuner info
our %tuneinfo = (
    '1800000-1900000'   => 'A 6.0 5.5',     # 160m
    '1900000-1950000'   => 'A 5.0 5.1',     # 160m
    '1950000-2000000'   => 'A 4.1 5.1',     # 160m
    '3535000-3600000'   => 'L 2.9 5.9',     # 80m
    '3700000-3750000'   => 'ATU',           # 80m
    '3800000-3850000'   => 'L 2.0 5.0',     # 80m
    '3850000-4000000'   => 'L 1.1 5.1',     # 80m
    '5330500-5403500'   => 'L 1.5 3.0',     # 60m
    '7025000-7125000'   => 'I 4.0 4.0',     # 40m
    '7125000-7300000'   => 'I 2.9 4.0',     # 40m
    '10100000-10150000' => 'G 6.0 5.5',     # 30m
    '14025000-14250000' => 'D 2.9 4.0',     # 20m
    '14250000-14350000' => 'ATU',           # 20m
    '18068000-18168000' => 'C 2.0 0.5',     # 17m
    '21025000-21300000' => 'B 2.9 3.5',     # 15m
    '21300000-21450000' => 'ATU',           # 15m
    '24890000-24990000' => 'B 1.8 3.0',     # 12m
    '28000000-29700000' => 'Direct',        # 10m
    '50000000-50100000' => 'C 3.1 3.1',     # 6m
    '50100000-51000000' => 'C 6.0 3.4',     # 6m
    '51000000-52000000' => 'D 3.0 -2.0',    # 6m
    '52000000-53000000' => 'D 1.0 4.2',     # 6m
    '53000000-53500000' => 'F 5.6 1.5',     # 6m
    '53500000-54000000' => 'G 0.0 3.1'      # 6m
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

# Define our (optional) frequency names
our %freqnames = (
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
    '28450000' => '10M Call',
    '7200000'  => '40M Lids',
    '3840000'  => '80M Lids',
    '8472000'  => 'WLO Marine',
);

# Define our (optional) band names
our %bandnames = (
    '1800000-2000000'  => '160M',
    '3500000-4000000'  => '80M',
    '5330500-5403500'  => '60M',
    '7000000-7300000'  => '40M',
    '10100000-10150000'  => '30M',
    '14000000-14350000'  => '20M',
    '18068000-18168000'  => '17M',
    '21000000-21450000'  => '15M',
    '24890000-24990000'  => '12M',
    '28000000-29700000'  => '10M',
    '50000000-54000000'  => '6M',
);

1;
