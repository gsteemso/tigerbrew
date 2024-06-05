class Isl < Formula
  desc "Integer Set Library for the polyhedral model"
  homepage "https://libisl.sourceforge.io"
  # Note: Always use tarball instead of git tag for stable version.
  #
  # Currently isl detects its version using source code directory name
  # and update isl_version() function accordingly.  All other names will
  # result in isl_version() function returning "UNKNOWN" and hence break
  # package detection.
  url "https://libisl.sourceforge.io/isl-0.18.tar.bz2"
  mirror "https://gcc.gnu.org/pub/gcc/infrastructure/isl-0.18.tar.bz2"
  sha256 "6b8b0fd7f81d0a957beb3679c81bbb34ccc7568d5682844d8924424a0dadcb1b"

  bottle do
    cellar :any
    sha256 "8561e09544a30e9d7bfef5483e9c54dff72c4ecd06ed2e7d3e4f9a3ef08f5dd0" => :tiger_g4e
    sha256 "478c188866c0ae28e7446f0a63fc13d5a3938766accc7a2c1bfaa040a2d378ad" => :leopard_g4e
  end

  option :universal

  head do
    url "https://repo.or.cz/r/isl.git"

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build
  end

  depends_on "gmp"

  def install
    if build.universal?
      ENV.permit_arch_flags if superenv?
      ENV.un_m64 if Hardware::CPU.family == :g5_64
      archs = Hardware::CPU.universal_archs
      mkdir 'arch-stashes'
      dirs = []
    else
      archs = [MacOS.preferred_arch]
    end

    archs.each do |arch|
      if build.universal?
        case arch
          when :i386, :ppc then ENV.m32
          when :x86_64, :ppc64 then ENV.m64
        end
        mkdir "arch-stashes/#{arch}-bin"
      end

      system "./autogen.sh" if build.head?
      system "./configure", "--disable-dependency-tracking",
                            (ARGV.verbose? ? '--disable-silent-rules' : '--enable-silent-rules'),
                            "--prefix=#{prefix}",
                            "--with-gmp=system",
                            "--with-gmp-prefix=#{Formula["gmp"].opt_prefix}"
      system "make", "check"
      system "make", "install"

      if build.universal?
        system 'make', 'clean'
        Merge.scour_keg(prefix, "arch-stashes/#{arch}-bin")
        # undo architecture-specific tweaks before next run
        case arch
          when :i386, :ppc then ENV.un_m32
          when :x86_64, :ppc64 then ENV.un_m64
        end # case arch
      end # universal?
    end # archs.each

    Merge.mach_o(prefix, 'arch-stashes', archs) if build.universal?

    (share/"gdb/auto-load").install Dir["#{lib}/*-gdb.py"]
  end

  test do
    (testpath/"test.c").write <<-EOS.undent
      #include <isl/ctx.h>

      int main()
      {
        isl_ctx* ctx = isl_ctx_alloc();
        isl_ctx_free(ctx);
        return 0;
      }
    EOS
    ENV.universal_binary if build.universal?
    system ENV.cc, "test.c", "-L#{lib}", "-lisl", "-o", "test"
    system "./test"
  end
end

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

    # install_prefix expects a Pathname object, not just a string
    def mach_o(install_prefix, stash_root, archs, sub_path = '')
      # don’t suffer a double slash when sub_path is null:
      s_p = (sub_path == '' ? '' : sub_path + '/')
      # generate a full list of files, even if some are not present on all architectures; bear in
      # mind that the current _directory_ may not even exist on all archs
      basename_list = []
      arch_dirs = archs.map {|a| "#{a}-bin"}
      arch_dir_list = arch_dirs.join(',')
      Dir["#{stash_root}/{#{arch_dir_list}}/#{s_p}*"].map { |f|
        File.basename(f)
      }.each { |b|
        basename_list << b unless basename_list.count(b) > 0
      }
      basename_list.each do |b|
        spb = s_p + b
        the_arch_dir = arch_dirs.detect { |ad| File.exist?("#{stash_root}/#{ad}/#{spb}") }
        pn = Pathname("#{stash_root}/#{the_arch_dir}/#{spb}")
        if pn.directory?
          mach_o(install_prefix, stash_root, archs, spb)
        else
          arch_files = Dir["#{stash_root}/{#{arch_dir_list}}/#{spb}"]
          if arch_files.length > 1
            system 'lipo', '-create', *arch_files, '-output', install_prefix/spb
          else
            # presumably there's a reason this only exists for one architecture, so no error;
            # the same rationale would apply if it only existed in, say, two out of three
            cp arch_files.first, install_prefix/spb
          end # if > 1 file?
        end # if directory?
      end # each basename |b|
    end # mach_o
  end # << self
end # Merge
