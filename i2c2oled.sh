#!/bin/bash

#
# File: "media/fat/i2x2oled/i2c2oled.sh"
#
# Just for fun ;-)
#
# 2021-04-18 by venice
# License GPL v3
# 
# Using DE10-Nano's i2c Bus and Commands showing the MiSTer Logo on an connected SSD1306 OLED Display
#
# The SSD1306 is organized in eight 8-Pixel-High Pages (=Rows, 0..7) and 128 Columns (0..127).
# I you write an Data Byte you address an 8 Pixel high Column in one Page.
# Commands start with 0x00, Data with 0x40 (as far as I know)
#
# Initial Base for the Script taken from here:
# https://stackoverflow.com/questions/42980922/which-commands-do-i-have-to-use-ssd1306-over-i%C2%B2c
#
# Use Gimp to convert the original to X-PixMap (XPM) and change " " (Space) to "1" and "." (Dot) to "0" for easier handling
# See examples what to modify additionally
# The String Array has 64 Lines with 128 Chars
# Put your X-PixMap files in /media/fat/i2c2oled_pix with extension "pix"
#
# 2021-04-28
# Adding Basic Support for an 8x8 Pixel Font taken from https://github.com/greiman/SdFat under the MIT License
# Use modded ASCII functions from here https://gist.github.com/jmmitchell/c82b03e3fc2dc0dcad6c95224e42c453
# Cosmetic changes
#
# 2021-04-29/30
# Adding Font-Based Animation "pressplay" and "loading"
# The PIX's "pressplay.pix" and "loading.pix" are needed.
#
# 2021-05-01
# Adding "Warp-5" Scrolling :-)
# The PIX "ncc1701.pix" is needed.
# Using "font_width" instead of fixed value.
#
# 2021-05-15
# Adding OLED Address Detection
# If Device is not found the Script ends with Error Code 1 
# Use code from https://raspberrypi.stackexchange.com/questions/26818/check-for-i2c-device-presence
#
# 2021-05-17
# Adding an "contrast" variable so you can set your contrast value
#
#
#

# Debugging
debug="false"
debugfile="/tmp/i2c2oled"

# System Variables
oledid=3c                # OLED I2C Address without "0x"
oledaddr=0x${oledid}     # OLED I2C Address with "0x"
i2cbus=2                 # i2c-2 = Bus 2
oledfound="false"        # Pre-Set Variable with false
contrast=100             # Set Contrast Value 0..255

# Core related
newcore=""
oldcore=""
corenamefile="/tmp/CORENAME"

# Picture related
pixpath="/media/fat/i2c2oled/pix"
pixextn="pix"
startpix="${pixpath}/starting.pix"
notavailpix="${pixpath}/nopixavail.pix"
misterheaderpix="${pixpath}/misterheader.pix"
pix=""


# Animation Icon's
itape1="0x3C 0x5A 0x81 0xC3 0xC3 0x81 0x5A 0x3C"
itape2="0x3C 0x66 0xE7 0x81 0x81 0xE7 0x66 0x3C"
iload1="0x78 0x3C 0x1E 0x0F 0x87 0xC3 0xE1 0xF0"
iload2="0x00 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF 0x00"
iwarp1="0x3C 0x42 0x81 0x81 0x81 0x81 0x42 0x3C"
iwarp2="0x3C 0x7E 0xFF 0xFF 0xFF 0xFF 0x7E 0x3C"


# Font 8x8
# Font starts with ASCII "0x20/32 (Space)
font_height=8
font_width=8
font=(
"0x00" "0x00" "0x00" "0x00" "0x00" "0x00" "0x00" "0x00"  # Space
"0x00" "0x00" "0x00" "0x00" "0x5F" "0x00" "0x00" "0x00"  # !
"0x00" "0x00" "0x00" "0x03" "0x00" "0x03" "0x00" "0x00"  # "
"0x00" "0x24" "0x7E" "0x24" "0x24" "0x7E" "0x24" "0x00"  # #
"0x00" "0x2E" "0x2A" "0x7F" "0x2A" "0x3A" "0x00" "0x00"  # $
"0x00" "0x46" "0x26" "0x10" "0x08" "0x64" "0x62" "0x00"  # %
"0x00" "0x20" "0x54" "0x4A" "0x54" "0x20" "0x50" "0x00"  # &
"0x00" "0x00" "0x00" "0x04" "0x02" "0x00" "0x00" "0x00"  # '
"0x00" "0x00" "0x00" "0x3C" "0x42" "0x00" "0x00" "0x00"  # (
"0x00" "0x00" "0x00" "0x42" "0x3C" "0x00" "0x00" "0x00"  # )
"0x00" "0x10" "0x54" "0x38" "0x54" "0x10" "0x00" "0x00"  # *
"0x00" "0x10" "0x10" "0x7C" "0x10" "0x10" "0x00" "0x00"  # +
"0x00" "0x00" "0x00" "0x80" "0x60" "0x00" "0x00" "0x00"  # "
"0x00" "0x10" "0x10" "0x10" "0x10" "0x10" "0x00" "0x00"  # -
"0x00" "0x00" "0x00" "0x60" "0x60" "0x00" "0x00" "0x00"  # .
"0x00" "0x40" "0x20" "0x10" "0x08" "0x04" "0x00" "0x00"  # /
"0x3C" "0x62" "0x52" "0x4A" "0x46" "0x3C" "0x00" "0x00"  # 0
"0x44" "0x42" "0x7E" "0x40" "0x40" "0x00" "0x00" "0x00"  # 1
"0x64" "0x52" "0x52" "0x52" "0x52" "0x4C" "0x00" "0x00"  # 2
"0x24" "0x42" "0x42" "0x4A" "0x4A" "0x34" "0x00" "0x00"  # 3
"0x30" "0x28" "0x24" "0x7E" "0x20" "0x20" "0x00" "0x00"  # 4
"0x2E" "0x4A" "0x4A" "0x4A" "0x4A" "0x32" "0x00" "0x00"  # 5
"0x3C" "0x4A" "0x4A" "0x4A" "0x4A" "0x30" "0x00" "0x00"  # 6
"0x02" "0x02" "0x62" "0x12" "0x0A" "0x06" "0x00" "0x00"  # 7
"0x34" "0x4A" "0x4A" "0x4A" "0x4A" "0x34" "0x00" "0x00"  # 8
"0x0C" "0x52" "0x52" "0x52" "0x52" "0x3C" "0x00" "0x00"  # 9
"0x00" "0x00" "0x00" "0x48" "0x00" "0x00" "0x00" "0x00"  # :
"0x00" "0x00" "0x80" "0x64" "0x00" "0x00" "0x00" "0x00"  # ;
"0x00" "0x00" "0x10" "0x28" "0x44" "0x00" "0x00" "0x00"  # <
"0x00" "0x28" "0x28" "0x28" "0x28" "0x28" "0x00" "0x00"  # =
"0x00" "0x00" "0x44" "0x28" "0x10" "0x00" "0x00" "0x00"  # >
"0x00" "0x04" "0x02" "0x02" "0x52" "0x0A" "0x04" "0x00"  # ?
"0x00" "0x3C" "0x42" "0x5A" "0x56" "0x5A" "0x1C" "0x00"  # @
"0x7C" "0x12" "0x12" "0x12" "0x12" "0x7C" "0x00" "0x00"  # A
"0x7E" "0x4A" "0x4A" "0x4A" "0x4A" "0x34" "0x00" "0x00"  # B
"0x3C" "0x42" "0x42" "0x42" "0x42" "0x24" "0x00" "0x00"  # C
"0x7E" "0x42" "0x42" "0x42" "0x24" "0x18" "0x00" "0x00"  # D
"0x7E" "0x4A" "0x4A" "0x4A" "0x4A" "0x42" "0x00" "0x00"  # E
"0x7E" "0x0A" "0x0A" "0x0A" "0x0A" "0x02" "0x00" "0x00"  # F
"0x3C" "0x42" "0x42" "0x52" "0x52" "0x34" "0x00" "0x00"  # G
"0x7E" "0x08" "0x08" "0x08" "0x08" "0x7E" "0x00" "0x00"  # H
"0x00" "0x42" "0x42" "0x7E" "0x42" "0x42" "0x00" "0x00"  # I
"0x30" "0x40" "0x40" "0x40" "0x40" "0x3E" "0x00" "0x00"  # J
"0x7E" "0x08" "0x08" "0x14" "0x22" "0x40" "0x00" "0x00"  # K
"0x7E" "0x40" "0x40" "0x40" "0x40" "0x40" "0x00" "0x00"  # L
"0x7E" "0x04" "0x08" "0x08" "0x04" "0x7E" "0x00" "0x00"  # M
"0x7E" "0x04" "0x08" "0x10" "0x20" "0x7E" "0x00" "0x00"  # N
"0x3C" "0x42" "0x42" "0x42" "0x42" "0x3C" "0x00" "0x00"  # O
"0x7E" "0x12" "0x12" "0x12" "0x12" "0x0C" "0x00" "0x00"  # P
"0x3C" "0x42" "0x52" "0x62" "0x42" "0x3C" "0x00" "0x00"  # Q
"0x7E" "0x12" "0x12" "0x12" "0x32" "0x4C" "0x00" "0x00"  # R
"0x24" "0x4A" "0x4A" "0x4A" "0x4A" "0x30" "0x00" "0x00"  # S
"0x02" "0x02" "0x02" "0x7E" "0x02" "0x02" "0x02" "0x00"  # T
"0x3E" "0x40" "0x40" "0x40" "0x40" "0x3E" "0x00" "0x00"  # U
"0x1E" "0x20" "0x40" "0x40" "0x20" "0x1E" "0x00" "0x00"  # V
"0x3E" "0x40" "0x20" "0x20" "0x40" "0x3E" "0x00" "0x00"  # W
"0x42" "0x24" "0x18" "0x18" "0x24" "0x42" "0x00" "0x00"  # X
"0x02" "0x04" "0x08" "0x70" "0x08" "0x04" "0x02" "0x00"  # Y
"0x42" "0x62" "0x52" "0x4A" "0x46" "0x42" "0x00" "0x00"  # Z
"0x00" "0x00" "0x7E" "0x42" "0x42" "0x00" "0x00" "0x00"  # [
"0x00" "0x04" "0x08" "0x10" "0x20" "0x40" "0x00" "0x00"  # <backslash>
"0x00" "0x00" "0x42" "0x42" "0x7E" "0x00" "0x00" "0x00"  # ]
"0x00" "0x08" "0x04" "0x7E" "0x04" "0x08" "0x00" "0x00"  # ^
"0x80" "0x80" "0x80" "0x80" "0x80" "0x80" "0x80" "0x00"  # _
"0x3C" "0x42" "0x99" "0xA5" "0xA5" "0x81" "0x42" "0x3C"  # `
"0x00" "0x20" "0x54" "0x54" "0x54" "0x78" "0x00" "0x00"  # a
"0x00" "0x7E" "0x48" "0x48" "0x48" "0x30" "0x00" "0x00"  # b
"0x00" "0x00" "0x38" "0x44" "0x44" "0x44" "0x00" "0x00"  # c
"0x00" "0x30" "0x48" "0x48" "0x48" "0x7E" "0x00" "0x00"  # d
"0x00" "0x38" "0x54" "0x54" "0x54" "0x48" "0x00" "0x00"  # e
"0x00" "0x00" "0x00" "0x7C" "0x0A" "0x02" "0x00" "0x00"  # f
"0x00" "0x18" "0xA4" "0xA4" "0xA4" "0xA4" "0x7C" "0x00"  # g
"0x00" "0x7E" "0x08" "0x08" "0x08" "0x70" "0x00" "0x00"  # h
"0x00" "0x00" "0x00" "0x48" "0x7A" "0x40" "0x00" "0x00"  # i
"0x00" "0x00" "0x40" "0x80" "0x80" "0x7A" "0x00" "0x00"  # j
"0x00" "0x7E" "0x18" "0x24" "0x40" "0x00" "0x00" "0x00"  # k
"0x00" "0x00" "0x00" "0x3E" "0x40" "0x40" "0x00" "0x00"  # l
"0x00" "0x7C" "0x04" "0x78" "0x04" "0x78" "0x00" "0x00"  # m
"0x00" "0x7C" "0x04" "0x04" "0x04" "0x78" "0x00" "0x00"  # n
"0x00" "0x38" "0x44" "0x44" "0x44" "0x38" "0x00" "0x00"  # o
"0x00" "0xFC" "0x24" "0x24" "0x24" "0x18" "0x00" "0x00"  # p
"0x00" "0x18" "0x24" "0x24" "0x24" "0xFC" "0x80" "0x00"  # q
"0x00" "0x00" "0x78" "0x04" "0x04" "0x04" "0x00" "0x00"  # r
"0x00" "0x48" "0x54" "0x54" "0x54" "0x20" "0x00" "0x00"  # s
"0x00" "0x00" "0x04" "0x3E" "0x44" "0x40" "0x00" "0x00"  # t
"0x00" "0x3C" "0x40" "0x40" "0x40" "0x3C" "0x00" "0x00"  # u
"0x00" "0x0C" "0x30" "0x40" "0x30" "0x0C" "0x00" "0x00"  # v
"0x00" "0x3C" "0x40" "0x38" "0x40" "0x3C" "0x00" "0x00"  # w
"0x00" "0x44" "0x28" "0x10" "0x28" "0x44" "0x00" "0x00"  # x
"0x00" "0x1C" "0xA0" "0xA0" "0xA0" "0x7C" "0x00" "0x00"  # y
"0x00" "0x44" "0x64" "0x54" "0x4C" "0x44" "0x00" "0x00"  # z
"0x00" "0x08" "0x08" "0x76" "0x42" "0x42" "0x00" "0x00"  # {
"0x00" "0x00" "0x00" "0x7E" "0x00" "0x00" "0x00" "0x00"  # |
"0x00" "0x42" "0x42" "0x76" "0x08" "0x08" "0x00" "0x00"  # }
"0x00" "0x00" "0x04" "0x02" "0x04" "0x02" "0x00" "0x00"  # ~
)


# ****************** functions *********************

# Debug function
function dbug() {
  if [ "${debug}" = "true" ]; then
    if [ ! -e ${debugfile} ]; then						# log file not (!) exists (-e) create it
      echo "---------- i2c_oled Debuglog ----------" > ${debugfile}
    fi 
    echo "${1}" >> ${debugfile}							# output debug text
  fi
}

#ASCII-Functions
function chr() {
  # Get Charcater from ASCII Value (untested)
  printf \\$(printf '%03o' $1)
  #[ "$1" -lt 256 ] || return 1
  #printf "\$(printf '%03o' "$1")"
}

function ord() {
  # Get ASCII Value from Character
  local chardec=$(LC_CTYPE=C printf '%d' "'$1")
  [ "${chardec}" -eq 0 ] && chardec=32             # Manual Mod for " " (Space)
  echo ${chardec}
  #printf '%d' "'$1"
  #LC_CTYPE=C printf '%d' "'$1"
}


# Display functions
function display_off() {
  i2cset -y ${i2cbus} ${oledaddr} 0x00 0xAE  # Display OFF (sleep mode)
  #sleep 0.1
  sleep 0.01
}

function display_on() {
  i2cset -y ${i2cbus} ${oledaddr} 0x00 0xAF  # Display ON (normal mode)
  sleep 0.001
}

function init_display() {
  #i2cset -y ${i2cbus} ${oledaddr} 0xA8 0x3F 0xD3 0x00 0x40 0xA1 0xC8
  
  i2cset -y ${i2cbus} ${oledaddr} 0x00 0xA8    # Set Multiplex Ratio
  i2cset -y ${i2cbus} ${oledaddr} 0x00 0x3F    # value

  i2cset -y ${i2cbus} ${oledaddr} 0x00 0xD3    # Set Display Offset
  i2cset -y ${i2cbus} ${oledaddr} 0x00 0x00    # no vertical shift

  i2cset -y ${i2cbus} ${oledaddr} 0x00 0x40    # Set Display Start Line to 000000b
  i2cset -y ${i2cbus} ${oledaddr} 0x00 0xA1    # Set Segment Re-map, column address 127 ismapped to SEG0
  i2cset -y ${i2cbus} ${oledaddr} 0x00 0xC8    # Set COM Output Scan Direction, remapped mode. Scan from COM7 to COM0

  i2cset -y ${i2cbus} ${oledaddr} 0x00 0xDA    # Set COM Pins Hardware Configuration
  i2cset -y ${i2cbus} ${oledaddr} 0x00 0x12    # Alternative COM pin configuration, Disable COM Left/Right remap needed for 128x64

  i2cset -y ${i2cbus} ${oledaddr} 0x00 0x81    # Set Contrast Control
  i2cset -y ${i2cbus} ${oledaddr} 0x00 ${contrast}    # value, 0xFF max.
  #i2cset -y ${i2cbus} ${oledaddr} 0x00 0xCF    # value, 0x7F max.

  i2cset -y ${i2cbus} ${oledaddr} 0x00 0xA4    # display RAM content

  i2cset -y ${i2cbus} ${oledaddr} 0x00 0xA6    # non-inverting display mode - black dots on white background

  i2cset -y ${i2cbus} ${oledaddr} 0x00 0xD5    # Set Display Clock (Divide Ratio/Oscillator Frequency)
  i2cset -y ${i2cbus} ${oledaddr} 0x00 0x80    # max fequency, no divide ratio
  
  i2cset -y ${i2cbus} ${oledaddr} 0x00 0xDB    # SSD1306_COMMSELECT
  i2cset -y ${i2cbus} ${oledaddr} 0x00 0x20    # 0.77 * VCC (default)
  
  i2cset -y ${i2cbus} ${oledaddr} 0x00 0x8D    # Charge Pump Setting
  i2cset -y ${i2cbus} ${oledaddr} 0x00 0x14    # enable charge pump

  i2cset -y ${i2cbus} ${oledaddr} 0x00 0x20    # page addressing mode
  i2cset -y ${i2cbus} ${oledaddr} 0x00 0x00    # horizontal addressing mode
  #i2cset -y ${i2cbus} ${oledaddr} 0x00 0x01    # vertikal addressing mode
  #i2cset -y ${i2cbus} ${oledaddr} 0x00 0x02    # page addressing mode
  #i2cset -y ${i2cbus} ${oledaddr} 0x00 0x20    # horizontal addressing mode
  #i2cset -y ${i2cbus} ${oledaddr} 0x00 0x21    # vertikal addressing mode
  #i2cset -y ${i2cbus} ${oledaddr} 0x00 0x22    # page addressing mode

  i2cset -y ${i2cbus} ${oledaddr} 0x00 0x2E    # Deactivate Scrolling

  i2cset -y ${i2cbus} ${oledaddr} 0x00 0x26
  i2cset -y ${i2cbus} ${oledaddr} 0x00 0x00    # Dummy 00h
  i2cset -y ${i2cbus} ${oledaddr} 0x00 0x02    # Start Page 2
  i2cset -y ${i2cbus} ${oledaddr} 0x00 0x07    # Frame frequency 2 frames (fastest)
  #i2cset -y ${i2cbus} ${oledaddr} 0x00 0x00   # Frame frequency 5 frames
  #i2cset -y ${i2cbus} ${oledaddr} 0x00 0x06   # Frame frequency 25 frames (slower)
  i2cset -y ${i2cbus} ${oledaddr} 0x00 0x07    # End Page 7
  i2cset -y ${i2cbus} ${oledaddr} 0x00 0x00    # Dummy 00h
  i2cset -y ${i2cbus} ${oledaddr} 0x00 0xFF    # Dummy FFh


  reset_cursor
}

# Set Cursor to top left (0,0)
function reset_cursor() {
  i2cset -y ${i2cbus} ${oledaddr} 0x00 0x21  #   set column address
  i2cset -y ${i2cbus} ${oledaddr} 0x00 0x00  #   set start address
  i2cset -y ${i2cbus} ${oledaddr} 0x00 0x7F  #   set end address (127 max)
  i2cset -y ${i2cbus} ${oledaddr} 0x00 0x22  #   set page address
  i2cset -y ${i2cbus} ${oledaddr} 0x00 0x00  #   set start address
  i2cset -y ${i2cbus} ${oledaddr} 0x00 0x07  #   set end address (7 max)
}

# Set Cursor to x(0..127),y(0..7)
function set_cursor() {
  i2cset -y ${i2cbus} ${oledaddr} 0x00 0x21  #   set column address
  i2cset -y ${i2cbus} ${oledaddr} 0x00 $1    #   set start address (0..127 Pixel)
  i2cset -y ${i2cbus} ${oledaddr} 0x00 0x7F  #   set end address (127 max)
  i2cset -y ${i2cbus} ${oledaddr} 0x00 0x22  #   set page address
  i2cset -y ${i2cbus} ${oledaddr} 0x00 $2    #   set start address (0..7 Page)
  i2cset -y ${i2cbus} ${oledaddr} 0x00 0x07  #   set end address (7 max)
}


function clearscreen() {
# fill screen with 0x00, sent each 32 bytes
  for i in $(seq 32); do
    val=""
    for j in $(seq 32); do
      val=("${val} 0x00")
    done
    i2cset -y ${i2cbus} ${oledaddr} 0x40 ${val} i
  done
  reset_cursor  # Set Corsor to Top-Left
}

function flushscreen() {
# fill screen with 0xff, sent each 32 bytes
  for i in $(seq 32); do
    val=""
    for j in $(seq 32); do
      val=("${val} 0xff")
    done
    i2cset -y ${i2cbus} ${oledaddr} 0x40 ${val} i
  done
  reset_cursor  # Set Cursor to Top-Left
}

function sendpix() {
# Get for each 8-Bit Size Vertical Segment the Bits and send them to be drawd
  #display_off
  reset_cursor
  local val=""; local byt=0; 
  local b0=0; local b1=0; local b2=0; local b3=0; local b4=0; local b5=0; local b6=0; local b7=0
  local i=0; local j=0;
  for j in 0 8 16 24 32 40 48 56; do
    for i in $(seq 0 127); do
      b0=${logo[j+0]:${i}:1}
      b1=${logo[j+1]:${i}:1}
      b2=${logo[j+2]:${i}:1}
      b3=${logo[j+3]:${i}:1}
      b4=${logo[j+4]:${i}:1}
      b5=${logo[j+5]:${i}:1}
      b6=${logo[j+6]:${i}:1}
      b7=${logo[j+7]:${i}:1}

      #echo "${b8} ${b7} ${b6} ${b5} ${b4} ${b3} ${b2} ${b1} = ${val}"
      let byt=${b7}*128+${b6}*64+${b5}*32+${b4}*16+${b3}*8+${b2}*4+${b1}*2+${b0}*1       # Bits to Decimal
      val=("${val} ${byt}")                                       # The collected Bytes for the "i" Mode
      #echo "Byte: ${byt}"                                        # Debugging Byte
      #echo "Value: ${val}"                                       # Debugging Value
      #sleep 0.1
      if [[ ${i} -eq 31 ||  ${i} -eq 63 || ${i} -eq 95 || ${i} -eq 127 ]]; then    # Send Value every 32 Bytes
        i2cset -y ${i2cbus} ${oledaddr} 0x40 ${val} i             # Send with "i" Mode
        val=""                                                    # Cleanup
      fi # 
    done # for i
  done # for j
  #display_on
}

# i2c Show-Picture function
function showpix() {
  local corenamepos=0; local corenamelen=0;
  if [ -d "${pixpath}" ]; then					# Check for am existing Picturefolder and proceed
    pix=("${pixpath}/${1}.${pixextn}")				# Build Pix + Path + Extension
    echo "Pix: ${pix}"                                          # Show Pix-Path
    dbug "Pix: ${pix}"                                          # Debug Pix-Path 
    if [ -f "${pix}" ]; then					# Lookup for an existing PIX and proceed
      source ${pix}						# Load Picture Array
      sendpix							# ..and show it
    else							# ! No Picture available !
      if [ -f "${misterheaderpix}" ]; then			# Lookup for the Empty-Header-PIX and proceed
        source ${misterheaderpix}				# Load Picture Array for "Empty Header" if available
        sendpix	 						# ..and show it
      fi
      corenamelen=${#1}						# Get lenght of Corename
      let corenamepos=(127-corenamelen*8)/2			# Calculate X Position
      set_cursor ${corenamepos} 4				# Set Cursor Position at Page 4
      showtext ${1}						# Show the Corename
    fi								# End if Picture check
  fi
}

# function 
function showtext() {
  local a=0; local b=0; local achar=0; local charp=0; local charout="";
  local text=${1}
  local textlen=${#text}
  #echo "Textlen: ${textlen}"
  for (( a=0; a<${textlen}; a++ )); do
    achar="`ord ${text:${a}:1}`"               # get the ASCII Code
    let charp=(achar-32)*${font_width}         # calculate first byte in font array
    #let charp=(achar-32)*8                    # calculate first byte in font array
    charout=""
    for (( b=0; b<${font_width}; b++ )); do    # character loop
    #for (( b=0; b<8; b++ )); do               # character loop
      charout="${charout} ${font[charp+b]}"    # build character out of single values
    done
    # echo "${a}: ${text:${a}:1} -> ${achar} -> ${charp} -> ${charout}"
  i2cset -y ${i2cbus} ${oledaddr} 0x40 ${charout} i  # send character bytes to display
  done
}

function pressplay () {
  local t=0;
  showpix pressplay
  # Testing Font-Based-Animation
  for (( t=0; t<5; t++)); do
    set_cursor 48 4
    i2cset -y ${i2cbus} ${oledaddr} 0x40 ${itape1}  i
    set_cursor 64 4
    i2cset -y ${i2cbus} ${oledaddr} 0x40 ${itape2} i
    sleep 0.3
    set_cursor 48 4
    i2cset -y ${i2cbus} ${oledaddr} 0x40 ${itape2} i
    set_cursor 64 4
    i2cset -y ${i2cbus} ${oledaddr} 0x40 ${itape1} i
    sleep 0.3
  done
}

function loading () {
  local t=0;
  display_off
  showpix loading
  display_on
  set_cursor 24 5
  sleep 0.75
  for t in 0.5 0.45 0.4 0.35 0.3 0.25 0.2 0.15 1.0 0.1; do  # going faster each step
    i2cset -y ${i2cbus} ${oledaddr} 0x40 ${iload1} i        # Icon 1
    #i2cset -y ${i2cbus} ${oledaddr} 0x40 ${iload2} i       # Icon 2
    sleep ${t}                                              # going faster each step
  done
  sleep 0.5
}

function warp5 () {
  local t=0;
  display_off
  showpix ncc1701
  display_on
  sleep 1

  for (( t=0; t<5 ; t++ )); do
    set_cursor 56 4
    i2cset -y ${i2cbus} ${oledaddr} 0x40 ${iwarp2} i 
    sleep 0.5
    set_cursor 56 4
    i2cset -y ${i2cbus} ${oledaddr} 0x40 ${iwarp1} i
    sleep 0.5
  done

  set_cursor 40 7
  showtext "Warp 5"
  sleep 2

  set_cursor 40 7
  showtext "Energy"
  sleep 1

  set_cursor 40 7
  showtext "      "
  sleep 0.5

  # Activate Scrolling
  i2cset -y ${i2cbus} ${oledaddr} 0x00 0x2F
  sleep 5

  # Deactivate Scrolling
  i2cset -y ${i2cbus} ${oledaddr} 0x00 0x2E
  sleep 1
}


# ************************** End Functions **********************************

# ************************** Main Program **********************************

# Lookup for i2c Device

mapfile -t i2cdata < <(i2cdetect -y ${i2cbus})
for i in $(seq 1 ${#i2cdata[@]}); do
  i2cline=(${i2cdata[$i]})
  echo ${i2cline[@]:1} | grep -q ${oledid}
  if [ $? -eq 0 ]; then
    echo "OLED at 0x${oledid} found, proceed..."
    oledfound="true"
  fi
done

if [ "${oledfound}" = "false" ]; then
  echo "OLED at 0x${oledid} not found! Exit!"
  exit 1
fi


display_off     # Switch Display off
init_display    # Send INIT Commands
flushscreen     # Fill the Screen completly
display_on      # Switch Display on
sleep 0.5       # Small sleep
display_off     # Switch Display off
clearscreen     # Clear the Screen completly
display_on      # Switch Display on

#cfont=${#font[@]}        # Debugging get count font array members
#echo $cfont              # Debugging

set_cursor 16 2           # Set Cursor at Page (Row) 2 to the 16th Pixel (Column)
showtext "MiSTer FPGA"    # Some Text for the Display

sleep 1.0                 # Wait a moment

set_cursor 16 4           # Set Cursor at Page (Row) 4 to the 16th Pixel (Column)
showtext "by Sorgelig"    # Some Text for the Display

sleep 2.0                 # Wait a moment
#reset_cursor

# Run Loading Animation
loading

# Run NCC1701 Animation
#warp5

while true; do							# main loop
  if [ -r ${corenamefile} ]; then				# proceed if file exists and is readable (-r)
    newcore=$(cat ${corenamefile})				# get CORENAME
    echo "Read CORENAME: -${newcore}-"				# some output
    dbug "Read CORENAME: -${newcore}-"				# some debug output
    if [ "${newcore}" != "${oldcore}" ]; then			# proceed only if Core has changed
      dbug "Send -${newcore}- to i2c-${i2cbus}"			# some debug output
      if [ ${newcore} != "MENU" ]; then				# If Corename not "MENU"
        pressplay						# Run "pressplay" Animation
      fi       							# end if
      display_off
      showpix ${newcore}				 	# The "Magic"
      display_on
      oldcore=${newcore}					# update oldcore variable
    fi  							# end if core check
    inotifywait -e modify "${corenamefile}"			# wait here for next change of corename
  else  							# CORENAME file not found
    echo "File ${corenamefile} not found!"			# some output
    dbug "File ${corenamefile} not found!"			# some debug output
  fi  								# end if /tmp/CORENAME check
done  								# end while

# ************************** End Main Program *******************************
