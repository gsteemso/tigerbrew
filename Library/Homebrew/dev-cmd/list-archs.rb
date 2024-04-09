module Larks
  KNOWN_SIGNATURES = {
    'cafebabe' => :FAT_MAGIC,
    'bebafeca' => :FAT_CIGAM,
    'feedface' => :MH_MAGIC,
    'cefaedfe' => :MH_CIGAM,
    'feedfacf' => :MH_MAGIC_64,
    'cffaedfe' => :MH_CIGAM_64,
    '7f454c46' => :MH_ELF,
    '464c457f' => :MH_FLE,
  }.freeze

  KNOWN_CPU_TYPES = {
    '00000001' => :VAX,
    '00000006' => :m68k,
    '00000007' => :i386,
    '00000008' => :MIPS,
    '00000010' => :m98k,
    '00000011' => :PA,
    '00000012' => :ARM,
    '00000013' => :m88k,
    '00000014' => :SPARC,
    '00000015' => :i860,
    '00000018' => :PPC,
    '01000006' => :a68080,
    '01000007' => :x86_64,
    '01000008' => :MIPS64,
    '01000011' => :PA64,
    '01000012' => :ARM64,
    '01000014' => :SPARC64,
    '01000016' => :ALPHA,
    '01000018' => :PPC64
  }.freeze

  KNOWN_PPC_SUBTYPES = {
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

  Fat_Arch = Struct.new(
    :cputype,
    :cpusubtype,
    :offset,
    :size,
    :align,
  )

  Mach_Header = Struct.new(
    :magic,
    :cputype,
    :cpusubtype,
    :filetype,
    :ncmds,
    :sizeofcmds,
    :flags,
  )

  CPU_pair = Struct.new(
    :type,
    :subtype,
  )

  def cpu_valid(type, subtype)
    case type
    when :i386, :x86_64
      type
    when :PPC
      KNOWN_PPC_SUBTYPES[subtype]
    when :PPC64
      :ppc64
    else
      nil
    end
  end # cpu_valid
end # Larks

class Pathname
  include Larks

  # binread does not exist in Leopard stock Ruby 1.8.6, and Tigerbrew's
  # cobbled-in version isn't very good at all, so use this instead
  def b_read(length = self.size, offset = 0)
    self.open('rb') do |f|
      f.pos = offset
      f.read(length)
    end
  end

  def mach_o_signature?
    KNOWN_SIGNATURES[self.b_read(4).unpack('H8')]
  end
end # Pathname

module Homebrew
  include Larks

  def list_archs
    requested = ARGV.kegs
    if requested.empty?
      opoo 'Only installed formulae have anything to check the architecture of.'
      return 0
    end
    oh1 "Checking which architectures #{keg.name} was built for..." if requested.size > 1
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
          opoo "Something's not right.  #{mo_file} is a Mach-O file, but it's in ELF format."
          next
        when :FAT_MAGIC
          count = mo_file.b_read(4,4).unpack('N')
          if count == 0
            opoo "Something's not right.  #{mo_file} is a fat binary but there appear to be no binaries in it."
          elsif count == 1
            opoo "Something's not right.  #{mo_file} is a fat-binary container with only one binary inside."
          else
            parts = []
            0.upto(count - 1) do |i|
              parts << CPU_pair.new(mo_file.b_read(8, 8 + 20*i).unpack('N2'))
              parts[i][:type] = parts[i][:type].unpack('H8')
              parts[i][:subtype] = parts[i][:subtype].unpack('H8')
            end
            report = ''
            parts.each { |part|
              if arch = cpu_valid(part[:type], part[:subtype])
                report += "  #{arch}\n"
              else
                ct = (KNOWN_TYPES[part[:type]] or part[:type])
                report += "  [Something foreign!  Its CPU type and subtype are #{ct} and #{part[:subtype]}.]\n"
              end # if-else
            }
            ohai "#{keg.name} is built for the following #{count} architectures:", report            
          end # if-elsif-else
        else
          cpu = CPU_pair.new(mo_file.b_read(4, 4).unpack('H8'), mo_file.b_read(4, 8).unpack('H8'))
          if arch = cpu_valid(cpu[:type], cpu[:subtype])
            oh1 "#{keg.name} is built for #{arch}."
          else
            ct = (KNOWN_TYPES[cpu[:type]] or cpu[:type])
            oh1 "#{keg.name} is built for something foreign!  Its CPU type and subtype are #{ct} and #{cpu[:subtype]}."
          end # if-else
        end # case
      else
        ohai 'No valid Mach-O architectures found', <<-_.undent
          #{keg.name} doesn't seem to contain any useable Mach-O files.  This can happen if, for
          example, its formula installs only header or documentation files.

          Since #{keg.name} is thus more or less platform-agnostic, you could technically call it
          "universal" if you really want to.
        _
      end #if-else
    end # do
  end # list_archs
end # Homebrew
