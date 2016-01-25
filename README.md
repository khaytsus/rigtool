rigtool
================

Control an amateur radio that is compatable with hamlib.

This script allows me to automate a good deal of things on my radio, particularly the ability to quickly go to a frequency that I'm interested in, such as DX Spot or a calling frequency I use, or to scan the bands.  Often I just use it in automatic mode and let it tell me what my manual tuner settings are for the given frequency, as well as make sure I'm within my band priviledges.

This has been tested on Linux using hamlib 3.0.1 and a Yaesu FT-450AT.  As far as I know everything in this script should apply to nearly any radio with hamlib support.  The only exceptions I can think of is if your radio does not have a B vfo or does not adjust the frequency based on the mode.  This script tries to automate as much as possible without interfering with usage but it might still have quirks or behave differently than you expect.  Suggestions, bug reports, or pull requests are welcome!

This script has the US Band Plan preconfigured as of 12/2015, but I do not have plans to input any other country band plans into the script.  I will be happy to take patches or pull requests to add this information, so if you're interested in adding the band plan for your country please let me know if you have any questions.

### High Level functionality
  * Prompt that shows frequency, signal strength, mode, vfo, lock status
  * Switch frequency and/or modes by typing to tool command prompt
  * Automatically select CW, USB or LSB based on frequency
  * Warn if out of band for set US Amateur License (US-only at this time)
  * Perform a soft-lock on frequency/mode
  * Scan a range of frequencies in Manual mode
  * Does a scan of the current band limits in Automatic mode
  * Automatic mode which shows prompt and adjusts lsb/usb in real time
  * Frequency adjustment and scan control via keyboard while Automatic mode
  * Tuner settings guide

Other stuff like return, store vfo a/b, remember last frequency, etc to mention?

### Prompt

The prompt is based on the mode (manual or automatic) and has some dynamic text associated for if out of band, in scan mode, etc, but it always shows the following:

Freq/Signal/Mode/Lockstatus

### Manual mode commands

 * auto
  * Switch to Automatic mode
 * f
  * Switch to frequency in kHz
 * u
  * Switch to Upper Side Band
 * l
  * Switch to Lower Side Band
 * c
  * Switch to CW
 * am
  * Switch to AM
 * a
  * Switch to VFO A
 * b
  * Switch to VFO B
 * r
  * Revert to last freq/mode
 * q
  * Exit automatuc mode or exit
 * lock
  * Lock to current freq/mode
 * unlock
  * Unlock
 * sBOTTOM-TOP
  * Scan from frequency BOTTOM to TOP
 * ?
  * Help
 * ??
  * Auto mode help

*** Automatic mode commands

 * l
  * Lock frequency/mode
 * u
  * Unlock
 * Cursor up/down
  * Change frequency +/- 10hz
 * Cursor right/left
  * Change frequency +/- 1khz
 * Page up/down
  * Change frequency +/- 10khz
 * Home up/down
  * Scan up/down
 * q
  * Exit auto mode

### Frequency changes

When changing frequencies in manual mode, the script will automatically pick if lsb or usb is to be used.  This happens without any interaction when in Automatic mode, such adjusting the VFO on the radio or changing frequency via the keyboard.

In manual mode, you may combine multiple commands into one, such as:

 * f7188ub
  * Move to 7188kHz USB on VFO B
  * Note that by default, 7188 would be LSB, but since specified, it will use USB
  * Not specifying the mode will automatically pick lsb or usb

### Automatic mode

When in automatic mode, the prompt refreshes constantly to show the current frequency, signal strength, mode, vfo used, and lock status.  As you change bands, it will automatically switch the mode to lsb or usb based on the frequency, as well as warn you if you are out of band and will show you your tuner settings for the given frequency range.

Automatic mode also has a number of key commands that will let you change the frequency or initiate scan mode so you can control your radio entirely from the keyboard.

You can control if the script automatically switches between CW and Phone modes or if it only control LSB/USB switches.

### Scan mode

When initiated from Manual mode, the scan mode simply scans from the bottom frequency given to the top frequency given and when it reaches the boundary, it reverses and scans down the band.  Example:  s7100-7300 will scan from 7100kHz to 7300kHz, starting at 7100kHz.

When initiated from Automatic mode, the scan will scan from the current frequency until it reaches the band edge for your priviledges, at which time the scan direction will reverse.  If the scan is initiated outside of your allowed band allocation, the scan will continue until stopped.

Both modes can be interrupted by pressing any key which provides input to the script (not shift, alt, etc).

### VFO A/B and Revert

By using VFO A and B as well as the Revert command, you can flip between different frequencies fast.

The revert command will let you flip between the current and previous frequency, such as in this example.

You're on 28450kHz and you see a DX spot on 28400, you can type f28400 (or just 28400) and listen.  If you want to return to your previous frequency, you can just type 'r' to revert back.  You may flip back and forth this way as much as you like.

### Band priviledges

The script uses the band priviledes configuration to determine when to switch to cw or phone modes, as well as when to show warnings when out of band priviledges.

The script is configured for the US Amateur Band Allocations as of 12/2015 and you may configure your license in the script.

The variables were designed so that the base priviledges (ie:  Novice) are configured first, then any modifications to those priviledges are added all the way up to the Extra class, to reduce duplication of every band and allocation.  The script has conditionals around the country in use so that additional priviledges may be easily added.  If you would like to add the band plan of your country please send me a pull request or patch.

### Tuner guide

The script can show you suggested settings for your tuner if you use a manual tuner.  You may add as many sections to the %tuneinfo variable as you like, depending upon your specific tuner and antenna configuration.  If you do not need this information at all you can disable it.

### In-Script configuration variables

The variables which control the script defaults and initiliation are at the top of the script and are self-documented and will not be repeated here.  Please modify the script to match your license and other tweaks you might want to change.  If you do a lot of CW mode, you might want to enable the automodeset variable to switch to CW mode automatically.

### Command Line Arguments

You may specify "auto" as the first command line argument to go directly into Automatic mode.

### Todo

 * Scan mode signal detection
 * Disable tx out of privs/band, etc (if possible in hamlib)
 * Real radio lock mode, not software emulated mode (if possible in hamlib)
 * Do something with data frequency allocation info
  * Possibly ability to switch to cw or data mode, but they generally overlap
 * Identify specific frequencies by name
  * Identify calling frequencies, known nets, etc
 * Change to named frequency
 * Macros, like it would be nice if I could set PMS Lower 1 and PMS Upper 1 and start scanning PMS 1

### Known Bugs/Limitations

 * Still going +/- 700hz sometimes when manually spinning vfo across voice/cw modes
  * Need to identify why, I've seen this a few times when $allmodeset is enabled
 * Changing vfo a/b/memory in manual input mode sometimes don't know last mode since it hasn't read the radio since the last time enter was pressed.
  * Manual mode doesn't read the radio info until enter is hit, so it can "miss" things, not sure what I can do here
 * Need to figure out how to send more hamlib commands
  * Arbitrary cat control which isn't directly in hamlib, mayb other things

### Troubleshooting

  * Perl Issues
   * Check your dependencies
   * Your distribution most likely packages the requirements, look for them there before going to CPAN or other repositories
  * Command Not Found type errors when running the scripts
   * Run script directly with perl, or set the script as executable.
   * Note that the script might not be in your executable path, so even if set executable you may have to run it with the full or relative path

### Dependencies

  * Radio which supports CAT control and is supported by hamlib

  * rigctld
   * rigctld must be running and configured to talk to your radio.  If the host or port is different than default you may set this at the top of the script

  * hamlib
   * Specific version requirements unknown; I am using 3.0.1

  * Perl modules
   * Term::ReadKey

  * Optional Perl modules
   * Term::ANSIColor
