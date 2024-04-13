SIGNATURES = {
  'cafebabe' => :FAT_MAGIC,
  'feedface' => :MH_MAGIC,
  'feedfacf' => :MH_MAGIC_64,
  '7f454c46' => :MH_ELF,
  'bebafeca' => :FAT_CIGAM,
  'cefaedfe' => :MH_CIGAM,
  'cffaedfe' => :MH_CIGAM_64,
  '464c457f' => :MH_FLE,
}.freeze

CPU_TYPES = {
  '00000001' => :VAX,
  '00000006' => :m68k,
  '00000007' => :i386,
  '00000008' => :MIPS,
  '0000000a' => :m98k,
  '0000000b' => :PA,
  '0000000c' => :ARM,
  '0000000d' => :m88k,
  '0000000e' => :SPARC,
  '0000000f' => :i860,
  '00000012' => :PPC,
  '01000006' => :a68080,
  '01000007' => :x86_64,
  '01000008' => :MIPS64,
  '0100000b' => :PA64,
  '0100000c' => :ARM64,
  '0100000e' => :SPARC64,
  '01000010' => :ALPHA,
  '01000012' => :PPC64
}.freeze

PPC_SUBTYPES = {
  '00000000' => :ppc_all,
  '00000001' => :ppc601,
  '00000002' => :ppc602,
  '00000003' => :ppc603,
  '00000004' => :ppc603e,
  '00000005' => :ppc603ev,
  '00000006' => :ppc604,
  '00000007' => :ppc604e,
  '00000008' => :ppc620,
  '00000009' => :ppc750,
  '0000000a' => :ppc7400,
  '0000000b' => :ppc7450,
  '00000064' => :ppc970
}.freeze

def cpu_valid(type, subtype)
  case CPU_TYPES[type]
  when :i386, :x86_64
    type
  when :PPC
    PPC_SUBTYPES[subtype]
  when :PPC64
    :ppc64
  else
    nil
  end
end # cpu_valid

# Assume the TTY understands standard control sequences:
# - In the 7-bit environment imposed by UTF-8, the Control Sequence Introducer (CSI) consists of
#   "ESC `[`".
# - Control sequences containing multiple parameters separate them by `;`.
# - The Select Graphic Rendition (SGR) sequence is "CSI <P> ... `m`".  SGR is affected by the
#   Graphic Rendition Combination Mode (GRCM).  The default (off) GRCM state, REPLACING, causes any
#   SGR sequence to reset all parameters it doesn't explicitly mention; enabling the CUMULATIVE
#   state allows effects to persist until cancelled.  Luckily, OS X's Terminal app seems to ignore
#   the standard and default this to the more sensible CUMULATIVE state, at least under Leopard.
# - If GRCM is in the REPLACING state and needs to be set CUMULATIVE, the Set Mode (SM) sequence is
#   "CSI <P> ... `h`" and the parameter value for GRCM is 21.  Should it for some reason need to be
#   changed back to REPLACING, the Reset Mode (RM) sequence is "CSI <P> ... `l`".
# - The SGR parameters are:
#   `0`:  Restores the default rendition, regardless of the GRCM state.
#   `1`:  Bold or increased intensity.  (The few hardware terminals implementing these had a seven-
#   `2`:  Faint or reduced intensity.    step intensity scale, ranging from "totally dark, no
#                                        output" to "too bright".)
#   `3`:  Italicized.
#   `4`:  Underlined (cancels `21`).
#   `5`:  Blinking, at less than 150 per minute (2.5 Hz).
#   `6`:  Blinking, at 150 per minute (2.5 Hz) or more.
#   `7`:  Negative image (inverse video).
#   `8`:  Concealed characters.
#   `9`:  Strikethrough (characters legible but marked for deletion).
#   `10`:  Primary (default) font.
#   `11`-`19`:  Alternate fonts 1-9.
#   `20`:  Fraktur (Gothic).
#   `21`:  Doubly underlined (cancels `4`).
#   `22`:  Normal intensity (cancels `1` and `2`).
#   `23`:  Cancels Italics and Fraktur (`3` and `20`).
#   `24`:  Cancels single and double underlining (`4` and `21`).
#   `25`:  Cancels blinking (`5` and `6`).
#   `26`:  Reserved for proportional-width characters.  (Probably never implemented in hardware.)
#   `27`:  Positive image (cancels inverse video, `7`).
#   `28`:  Visible characters (cancels concealment, `8`).
#   `29`:  Cancels strikethrough (`9`).
#   `30`:  Black display.
#   `31`:  Red display (dark).
#   `32`:  Green display (dark).
#   `33`:  Yellow display (dark).
#   `34`:  Blue display (dark).
#   `35`:  Magenta display (purple).
#   `36`:  Cyan display (teal).
#   `37`:  White display (light grey).
#   `38`:  Reserved for setting display colour.
#   `39`:  Default display (implementation-defined).
#   `40`:  Black display.
#   `41`:  Red background (dark).
#   `42`:  Green background (dark).
#   `43`:  Yellow background (dark).
#   `44`:  Blue background (dark).
#   `45`:  Magenta background (purple).
#   `46`:  Cyan background (teal).
#   `47`:  White background (light grey).
#   `48`:  Reserved for setting background colour.
#   `49`:  Default background (implementation-defined).
#   `50`:  Reserved for cancelling the effects of `26`.
#   `51`:  Framed.
#   `52`:  Encircled.
#   `53`:  Overlined.
#   `54`:  Neither framed nor encircled (cancels `51` and `52`).
#   `55`:  Cancels overlining (`53`).
#   `56`-`59`:  Unused.
#   `60`:  Ideogram underline/right-side line.
#   `61`:  Ideogram double underline/right-side line.
#   `62`:  Ideogram overline/left-side line.
#   `63`:  Ideogram double overline/left-side line.
#   `64`:  Ideogram stress marking.
#   `65`:  Cancels `60`-`64`.
# Extensions to the above include:
#   `38` (and `48`):  Multiple implementations.  Mac OS X's Terminal app doesn't support any of
#                     them, at least under Leopard.
#                     - 88-value colour is implemented by some terminal emulators in a manner
#                       similar to the encoding of 256-value colour, but the details of the scheme
#                       are neither standardized nor well-publicized.  It is known to involve a
#                       four-step colour cube similar to the six-step cube used in 256-value colour,
#                       as well as the regular and bright sets of eight colours, and eight steps of
#                       greyscale.
#                     - 256-value (8-bit) colour is implemented as "CSI `38;5;` COLOUR `m`", where
#                       COLOUR is a value from `0`-`255`, interpreted as follows:
#                       `0`-`7`:  Standard colours, as above.
#                       `8`-`15`:  Bright versions of the standard colours, as below.
#                       `16`-`231`:  RGB colours, in a six-step (0..5) cubic space -- the encoded
#                                    value = 16 + (36 x RED + 6 x GREEN + BLUE).  It appears that
#                                    these may actually represent levels 1-6 from a range of 0-7,
#                                    with some of the resulting coverage gaps occupied by the other
#                                    40 encoded colours.
#                       `232`-`255`:  24 shades of grey from dark to light, intermediate to the
#                                     above.  In total, this could yield 32 greys plus black and
#                                     white, but whether any consensus ordering of the nominally
#                                     redundant encodings exists is unclear.
#                     - 24-bit colour (eight bits per RGB component) is implemented as
#                       "CSI `38;2;` RED `;` GREEN `;` BLUE `m`", where RED, GREEN and BLUE are
#                       each values in the range `0` through `255`.
#                     - Some standards incorrectly specify both 8-bit and 24-bit colour using `:`
#                       instead of `;`.  Such would be valid, if incompatible, if colons were only
#                       specified to separate the three components of a 24-bit colour string; but
#                       that isn't what was done.
#   `90`:  Bright black (dark grey) display, equivalent to `38;5;8`.
#   `91`:  Bright red display, equivalent to `38;5;9`.
#   `92`:  Bright green display, equivalent to `38;5;10`.
#   `93`:  Bright yellow display, equivalent to `38;5;11`.
#   `94`:  Bright blue display, equivalent to `38;5;12`.
#   `95`:  Bright magenta display, equivalent to `38;5;13`.
#   `96`:  Bright cyan display, equivalent to `38;5;14`.
#   `97`:  Bright white display, equivalent to `38;5;15`.
#   `100`:  Bright black (dark grey) background, equivalent to `48;5;8`.
#   `101`:  Bright red background, equivalent to `48;5;9`.
#   `102`:  Bright green background, equivalent to `48;5;10`.
#   `103`:  Bright yellow background, equivalent to `48;5;11`.
#   `104`:  Bright blue background, equivalent to `48;5;12`.
#   `105`:  Bright magenta background, equivalent to `48;5;13`.
#   `106`:  Bright cyan background, equivalent to `48;5;14`.
#   `107`:  Bright white background, equivalent to `48;5;15`.

def sgr(*list)  # "Select Graphic Rendition"
  "\033[#{list.join(';')}m"
end

def oho(msg)
  puts "#{sgr 1, 36, 40}==>#{sgr 39} #{msg}#{sgr 0}"
end

def ohey(title, *msg)
  oho title
  puts msg
end

class Pathname
  # binread does not exist in Leopard stock Ruby 1.8.6, and Tigerbrew's
  # cobbled-in version isn't very good at all, so use this instead
  def b_read(offset = 0, length = self.size)
    self.open('rb') do |f|
      f.pos = offset
      f.read(length)
    end
  end

  def mach_o_signature?
    SIGNATURES[self.b_read(0, 4).unpack('H8')[0]]
  end
end # Pathname

module Homebrew
  def list_archs
    requested = ARGV.kegs
    if requested.empty?
      onoe 'Only installed formulae have anything to check the architecture of.'
      return 0
    end
    no_archs = false
    requested.each do |keg|
      sig = nil
      possibles = Dir["#{keg}/lib/*"] + Dir["#{keg}/bin/*"].select { |f| File.executable?(f) }
      mo_file = possibles.reject { |f|
          (File.symlink?(f) or File.directory?(f))
        }.map { |m|
          Pathname.new(m)
        }.detect { |pn|
          sig = pn.mach_o_signature?
        }
      if sig
        case sig
        when :FAT_CIGAM, :MH_CIGAM, :MH_CIGAM_64, :MH_FLE
          odie 'Your install of Ruby is horked!  It decoded a big-endian value as little-endian.'
        when :MH_ELF
          opoo "Something's not right.  #{sgr 37}#{mo_file}#{sgr 39} is a Mach-O file, but it's in ELF format."
          next
        when :FAT_MAGIC
          count = mo_file.b_read(4,4).unpack('N')[0]
          if count == 0
            opoo "#{sgr 97}#{keg.name}#{sgr 39}:  Something's not right.  #{sgr 37}#{mo_file}#{sgr 39} is a fat binary but there appear to be no binaries in it."
          elsif count == 1
            opoo "#{sgr 97}#{keg.name}#{sgr 39}:  Something's not right.  #{sgr 37}#{mo_file}#{sgr 39} is a fat-binary container with only one binary inside."
          else
            parts = []
            0.upto(count - 1) do |i|
              parts << {
                :type => mo_file.b_read(8 + 20*i, 4).unpack('H8')[0],
                :subtype => mo_file.b_read(12 + 20*i, 4).unpack('H8')[0]
              }
            end # do
            report = []
            foreign_parts = []
            parts.each { |part|
              if arch = cpu_valid(part[:type], part[:subtype])
                report << "#{sgr 97}#{arch}#{sgr 39}"
              else
                ct = (CPU_TYPES[part[:type]] or part[:type])
                foreign_parts << "[Something foreign, with CPU type #{sgr 37}#{ct}#{sgr 39} and subtype #{sgr 37}#{part[:subtype]}#{sgr 39}.]"
              end # if-else arch
            }
            report = "#{sgr 97}#{keg.name}#{sgr 39} is built for #{count} architectures:  #{report.join(', ')}."
            if foreign_parts == []
              oho report
            else
              ohey report, sgr(1), foreign_parts.join("\n"), sgr(0)
            end # if-else foreign_parts
          end # if-elsif-else count
        else # case sig
          cpu = {
            :type => mo_file.b_read(4, 4).unpack('H8')[0],
            :subtype => mo_file.b_read(8, 4).unpack('H8')[0]
          }
          if arch = cpu_valid(cpu[:type], cpu[:subtype])
            oho "#{sgr 97}#{keg.name}#{sgr 39} is built for one architecture:  #{sgr 97}#{arch}#{sgr 39}."
          else
            ct = (CPU_TYPES[cpu[:type]] or cpu[:type])
            oho "#{sgr 97}#{keg.name}#{sgr 39} is built for something foreign, with CPU type #{sgr 37}#{ct}#{sgr 39} and subtype #{sgr 37}#{cpu[:subtype]}#{sgr 39}."
          end # if-else arch
        end # case sig
      else # if sig
        oho "#{sgr 97}#{keg.name}#{sgr 39}:  #{sgr 33}No valid Mach-O architectures found."
        no_archs = true
      end # if sig
    end # do |keg|
    if no_archs
      puts <<-_.undent
        Sometimes a successful brew produces no Mach-O files.  This can happen if, for
        example, the formula responsible installs only header or documentation files.
      _
    end
  end # list_archs
end # Homebrew
