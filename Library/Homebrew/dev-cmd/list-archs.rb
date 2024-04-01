module larks
  VALID_SIGNATURES = {
    0xcafebabe => 'FAT_MAGIC',
    0xbebafeca => 'FAT_CIGAM',
    0xfeedface => 'MH_MAGIC',
    0xcefaedfe => 'MH_CIGAM',
    0xfeedfacf => 'MH_MAGIC_64',
    0xcffaedfe => 'MH_CIGAM_64',
  }.freeze
  KNOWN_SIGNATURES = VALID_SIGNATURES + { 0x7f454c46 => 'MH_ELF' }
  KNOWN_SIGNATURES.freeze
  Fat_Arch = Struct.new{:cputype, :cpusubtype, :offset, :size, :align}
  Mach_Header = Struct.new{:magic, :cputype, :cpusubtype, :filetype, :ncmds, :sizeofcmds, :flags}
  Subsonic = Struct.new{:pathname, :signature, :cputype, :cpusubtype}
end

class Pathname
  # binread does not exist in Leopard stock Ruby 1.8.6, and Tigerbrew’s
  # cobbled‐in version isn’t very good at all, so use this instead
  def b_read(length = self.size, offset = 0)
    self.open('rb') do |f|
      f.pos = offset
      f.read(length)
    end
  end

  def mach_o_signature?
    larks::VALID_SIGNATURES[self.b_read(4).unpack('N')]
  end

  def fat_mach_parts
    parts = []
    count = self.b_read(4,4).unpack('N')
    for index in [0.upto count - 1]
      fat_record = Fat_arch.new(self.b_read(20, 8 + 20*index).unpack('N5'))
      mach_o_header = self.b_read(28, fat_record[:offset])
      parts << larks::Subsonic.new(self, )
    end
  end
end

module Homebrew
  def list_archs
    def parse_mach_o(subject)
      
    end

    ARGV.kegs.each do |keg|
      oh1 "Checking which architectures #{keg.name} was built for..." if ARGV.kegs.size > 1
      possibles = Dir["#{keg.bin}/*"].select { |f| File.executable?(f) } + Dir["#{keg.lib}/*"]
      sig = nil
      mo_file = possibles.reject { |f|
          (File.symlink?(f) or File.directory?(f))
        }.map { |m|
          Pathname.new(m)
        }.detect { |pn|
          sig = pn.mach_o_signature?
        }
      case sig
      when 'FAT_MAGIC'
        feast = mo_file.fat_mach_parts.map { |cutlet|  }
      when 'MH_MAGIC', 'MH_MAGIC_64'
        
      when 'FAT_CIGAM', 'MH_CIGAM', 'MH_CIGAM_64'
        opoo 'Your install of Ruby is horked!  It decoded a big‐endian value as little‐endian.'
      else
        ohai 'No Mach-O architectures found', <<-_.undent
          #{keg.name} doesn’t seem to contain any Mach-O files.  This can happen if, for example,
          its formula installs only header or documentation files.

          Since #{keg.name} is thus more or less platform-agnostic, you could technically call it
          “universal” if you really want to.
        _ 
      end
    end
  end
end
