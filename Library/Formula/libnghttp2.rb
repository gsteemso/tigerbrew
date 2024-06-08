class Libnghttp2 < Formula
  desc "HTTP/2 C Library"
  homepage "https://nghttp2.org/"
  url "https://github.com/nghttp2/nghttp2/releases/download/v1.62.0/nghttp2-1.62.1.tar.xz"
  mirror "http://fresh-center.net/linux/www/nghttp2-1.62.1.tar.xz"
  sha256 "2345d4dc136fda28ce243e0bb21f2e7e8ef6293d62c799abbf6f633a6887af72"
  license "MIT"

  bottle do
    sha256 "b5561ecc87f62759d6915200d7a3bd9e6cebf97842a825116e5871a2a0952b7d" => :tiger_altivec
  end

  head do
    url "https://github.com/nghttp2/nghttp2.git", branch: "master"

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build
  end

  option :universal

  depends_on "pkg-config" => :build

  # These used to live in `nghttp2`.
  link_overwrite "include/nghttp2"
  link_overwrite "lib/libnghttp2.a"
  link_overwrite "lib/libnghttp2.dylib"
  link_overwrite "lib/libnghttp2.14.dylib"
  link_overwrite "lib/libnghttp2.so"
  link_overwrite "lib/libnghttp2.so.14"
  link_overwrite "lib/pkgconfig/libnghttp2.pc"

  # Apple GCC thinks forward declarations in a different file are redefinitions
  patch :p1, :DATA

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

    bitness_stash = ENV['HOMEBREW_PREFER_64_BIT']
    archs.each do |arch|
      if build.universal?
        case arch
          when :i386, :ppc then ENV.delete 'HOMEBREW_PREFER_64_BIT'
          when :x86_64, :ppc64 then ENV['HOMEBREW_PREFER_64_BIT'] = '1'
        end
        ENV.setup_build_environment(self)
        mkdir "arch-stashes/#{arch}-bin"
      end

      system "autoreconf", "-ivf" if build.head?
      system "./configure", "--prefix=#{prefix}",
                            '--disable-dependency-tracking',
                            (ARGV.verbose? ? '--disable-silent-rules' : '--enable-silent-rules'),
                            "--enable-lib-only"
      cd 'lib' do
        system "make"
        system "make", "install"
      end

      if build.universal?
        system 'make', 'clean'
        Merge.scour_keg(prefix, "arch-stashes/#{arch}-bin")
      end # universal?
    end # archs.each

    if build.universal?
      Merge.mach_o(prefix, 'arch-stashes', archs)
      # undo architecture-specific tweak
      ENV['HOMEBREW_PREFER_64_BIT'] = bitness_stash
      ENV.setup_build_environment(self)
    end # universal?
  end # install

  test do
    (testpath/"test.c").write <<~EOS
      #include <nghttp2/nghttp2.h>
      #include <stdio.h>

      int main() {
        nghttp2_info *info = nghttp2_version(0);
        printf("%s", info->version_str);
        return 0;
      }
    EOS

    ENV.universal_binary if build.universal?
    system ENV.cc, "test.c", "-I#{include}", "-L#{lib}", "-lnghttp2", "-o", "test"
    assert_equal version.to_s, shell_output("./test")
  end # test
end # Libnghttp2

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

__END__
--- old/lib/nghttp2_submit.h	2024-06-08 16:12:54.000000000 -0700
+++ new/lib/nghttp2_submit.h	2024-06-08 16:13:47.000000000 -0700
@@ -30,8 +30,7 @@
 #endif /* HAVE_CONFIG_H */
 
 #include <nghttp2/nghttp2.h>
-
-typedef struct nghttp2_data_provider_wrap nghttp2_data_provider_wrap;
+#include "nghttp2_outbound_item.h"
 
 int nghttp2_submit_data_shared(nghttp2_session *session, uint8_t flags,
                                int32_t stream_id,
