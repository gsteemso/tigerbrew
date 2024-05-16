class Libarchive < Formula
  desc "Multi-format archive and compression library"
  homepage "http://www.libarchive.org"
  url "https://www.libarchive.org/downloads/libarchive-3.7.4.tar.xz"
  sha256 "f887755c434a736a609cbd28d87ddbfbe9d6a3bb5b703c22c02f6af80a802735"

  option :universal

  keg_only :provided_by_osx

  def install
    if build.universal?
      ENV.permit_arch_flags
      archs = Hardware::CPU.universal_archs
      dirs = []
    else
      archs = [MacOS.preferred_arch]
    end

    archs.each do |arch|
      if build.universal?
        ENV.append_to_cflags "-arch #{arch}"
#       case arch
#         when :i386, :ppc then ENV.m32
#         when :x86_64, :ppc64 then ENV.m64
#       end
        dir = "stash-#{arch}"
        mkdir dir
        dirs << dir
      end

      args = %W[
        --prefix=#{prefix}
        --disable-dependency-tracking
        --disable-acl
        --without-lzo2
        --without-nettle
        --without-xml2
        --without-expat
      ]
      args << (ARGV.verbose? ? '--disable-silent-rules' : '--enable-silent-rules')
      system "./configure", *args
      system 'make'
      system "make", "install"

      if build.universal?
        system 'make', 'clean'
        Merge.scour_keg(prefix, dir)
        # undo architecture-specific tweak(s) before next run
        ENV.remove_from_cflags "-arch #{arch}"
#       case arch
#         when :i386, :ppc then ENV.un_m32
#         when :x86_64, :ppc64 then ENV.un_m64
#       end # case arch
      end # universal?
    end # archs.each
    Merge.mach_o(prefix, dirs) if build.universal?
  end # install

  test do
    (testpath/"test").write("test")
    system bin/"bsdtar", "-czvf", "test.tar.gz", "test"
    assert_match /test/, shell_output("#{bin}/bsdtar -xOzf test.tar.gz")
  end
end # Libarchive

class Merge
  module Pathname_extension
    def is_bare_mach_o?
      # header word 0, magic signature:
      #   MH_MAGIC    = 'feedface' – value with lowest‐order bit clear
      #   MH_MAGIC_64 = 'feedfacf' – same value with lowest‐order bit set
      # low‐order 24 bits of header word 1, CPU type:  7 is x86, 12 is ARM, 18 is PPC
      # header word 3, file type:  no types higher than 10 are defined
      # header word 5, net size of load commands, is far smaller than the filesize
      if (self.file? and self.size >= 28 and mach_header = self.binread(24).unpack('N6'))
        raise('Fat binary found where bare Mach-O file expected') if mach_header[0] == 0xcafebabe
        ((mach_header[0] & 0xfffffffe) == 0xfeedface and
          [7, 12, 18].detect { |item| (mach_header[1] & 0x00ffffff) == item } and
          mach_header[3] < 11 and
          mach_header[5] < self.size)
      else
        false
      end
    end unless method_defined?(:is_bare_mach_o?)
  end # Pathname_extension

  class << self
    include FileUtils

    def scour_keg(keg_prefix, stash, sub_path = '')
      # don’t suffer a double slash when sub_path is null:
      s_p = (sub_path == '' ? '' : sub_path + '/')
      Dir["#{keg_prefix}/#{s_p}*"].each do |f|
        pn = Pathname(f).extend(Pathname_extension)
        spb = s_p + pn.basename
        if pn.directory?
          Dir.mkdir "#{stash}/#{spb}"
          scour_keg(keg_prefix, stash, spb)
        # the number of things that look like Mach-O files but aren’t is horrifying, so test
        elsif ((not pn.symlink?) and pn.is_bare_mach_o?)
          cp pn, "#{stash}/#{spb}"
        end
      end
    end # scour_keg

    def mach_o(install_prefix, arch_dirs, sub_path = '')
      # don’t suffer a double slash when sub_path is null:
      s_p = (sub_path == '' ? '' : sub_path + '/')
      # generate a full list of files, even if some are not present on all architectures; bear in
      # mind that the current _directory_ may not even exist on all archs
      basename_list = []
      arch_dir_list = arch_dirs.join(',')
      Dir["{#{arch_dir_list}}/#{s_p}*"].map { |f|
        File.basename(f)
      }.each do |b|
        basename_list << b unless basename_list.count(b) > 0
      end
      basename_list.each do |b|
        spb = s_p + b
        the_arch_dir = arch_dirs.detect { |ad| File.exist?("#{ad}/#{spb}") }
        pn = Pathname("#{the_arch_dir}/#{spb}")
        if pn.directory?
          mach_o(install_prefix, arch_dirs, spb)
        else
          arch_files = Dir["{#{arch_dir_list}}/#{spb}"]
          if arch_files.length > 1
            system 'lipo', '-create', *arch_files, '-output', install_prefix/spb
          else
            # presumably there's a reason this only exists for one architecture, so no error;
            # the same rationale would apply if it only existed in, say, two out of three
            cp arch_files.first, install_prefix/spb
          end # if > 1 file?
        end # if directory?
      end # basename_list.each
    end # mach_o
  end # << self
end # Merge
