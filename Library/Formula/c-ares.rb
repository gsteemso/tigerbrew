class CAres < Formula
  desc "Asynchronous DNS library"
  homepage "http://c-ares.haxx.se/"
  url "http://c-ares.haxx.se/download/c-ares-1.10.0.tar.gz"
  mirror "https://github.com/bagder/c-ares/archive/cares-1_10_0.tar.gz"
  sha256 "3d701674615d1158e56a59aaede7891f2dde3da0f46a6d3c684e0ae70f52d3db"
  head "https://github.com/bagder/c-ares.git"

  bottle do
    cellar :any
    sha256 "68d6374d5665448f947c8cfb2090171c0c865e239a786139f108979138d03a68" => :el_capitan
    sha1 "aa711a345bac4780f2e7737c212c1fb5f7862de8" => :yosemite
    sha1 "c6851c662552524fa92e341869a23ea72dbc4375" => :mavericks
    sha1 "27494a19ac612daedeb55356e911328771f94b19" => :mountain_lion
  end

  option :universal

  # `class_exec` doesn't exist in Tiger/Leopard stock Ruby.  Ideally, find a workaround
  Pathname.class_exec {
    # binread does not exist in Leopard stock Ruby 1.8.6, and Tigerbrew's
    # cobbled-in version doesn't work, so use this instead
    def b_read(offset = 0, length = self.size)
      self.open('rb') do |f|
        f.pos = offset
        f.read(length)
      end
    end

    def is_bare_mach_o?
      # MH_MAGIC    = 'feedface'
      # MH_MAGIC_64 = 'feedfacf' -- same value with lowest-order bit inverted
      [self.b_read(0,4).unpack('N').first & 0xfffffffe].pack('N').unpack('H8').first == 'feedface'
    end
  }

  def install
    def scour_keg(stash, sub_path)
      s_p = (sub_path == '' ? '' : sub_path + '/')
      Dir["#{prefix}/#{s_p}*"].each do |f|
        pn = Pathname(f)
        spb = s_p + pn.basename
        if pn.directory?
          mkdir "#{stash}/#{spb}"
          scour_keg(stash, spb)
        elsif ((not pn.symlink?) and pn.file? and pn.is_bare_mach_o?)
          cp pn, "#{stash}/#{spb}"
        end
      end
    end

    def merge_mach_o_stashes(arch_dirs, sub_path)
      s_p = (sub_path == '' ? '' : sub_path + '/')
      Dir["#{arch_dirs.first}/#{s_p}*"].each do |f|
        pn = Pathname(f)
        spb = s_p + pn.basename
        if pn.directory?
          merge_mach_o_stashes(arch_dirs, spb)
        else
          system 'lipo', '-create', *Dir["{#{arch_dirs.join(',')}}/#{spb}"],
                         '-output', prefix/spb
        end
      end
    end

    if build.universal?
      ENV.permit_arch_flags
      archs = Hardware::CPU.universal_archs
    elsif MacOS.prefer_64_bit?
      archs = [Hardware::CPU.arch_64_bit]
    else
      archs = [Hardware::CPU.arch_32_bit]
    end

    dirs = []

    archs.each do |arch|
      if build.universal?
        ENV.append_to_cflags "-arch #{arch}"
        case arch
          when :i386, :ppc then ENV.m32
          when :x86_64, :ppc64 then ENV.m64
        end
        dir = "build-#{arch}"
        dirs << dir
        mkdir dir
      end

      system "./configure", "--prefix=#{prefix}",
                            "--disable-dependency-tracking",
                            "--disable-debug",
                            "--enable-symbol-hiding"
      system "make", "install"

      if build.universal?
        # undo architecture-specific tweaks before next run
        ENV.remove_from_cflags "-arch #{arch}"
        case arch
          when :i386, :ppc
            ENV.remove 'HOMEBREW_ARCHFLAGS', '-m32'
            unless superenv?
              ENV.remove 'LDFLAGS', "-arch #{Hardware::CPU.arch_32_bit}"
            end
          when :x86_64, :ppc64
            ENV.remove "HOMEBREW_ARCHFLAGS", "-m64"
            unless superenv?
              ENV.remove 'LDFLAGS', "-arch #{Hardware::CPU.arch_64_bit}"
            end
        end
        scour_keg(dir, '')
        system 'make', 'clean'
      end
    end
    merge_mach_o_stashes(dirs, '') if build.universal?
  end

  test do
    (testpath/"test.c").write <<-EOS.undent
      #include <stdio.h>
      #include <ares.h>

      int main()
      {
        ares_library_init(ARES_LIB_INIT_ALL);
        ares_library_cleanup();
        return 0;
      }
    EOS
    ENV.universal_binary if build.universal?
    system ENV.cc, "test.c", "-L#{lib}", "-lcares", "-o", "test"
    system "./test"
  end
end
