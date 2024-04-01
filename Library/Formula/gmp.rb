class Gmp < Formula
  desc "GNU multiple precision arithmetic library"
  homepage "https://gmplib.org/"
  url "https://gmplib.org/download/gmp/gmp-6.3.0.tar.lz"  # the .lz is smaller than the .xz
  mirror "https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.lz"
  sha256 "be5c908a7a836c3a9bd9d62aa58563c5e9e7fef94c43a7f42dbc35bb6d02733c"

#  bottle do
#    sha256 "fe8558bf7580c9c8a3775016eccf61249b8d637b1b2970942dba22444c48da7d" => :tiger_altivec
#  end

  option :cxx11
  option :universal

  def install
    ENV.cxx11 if build.cxx11?
    ENV.permit_arch_flags if build.universal?

    def cpu_lookup(cpu_sym)
      case cpu_sym
        when :g3
          'powerpc750'
        when :g4
          'powerpc7400'
        when :g4e
          'powerpc7450'
        when :g5, :g5_64
          'powerpc970'
        when :core
          'pentiumm'
        when :penryn
          'core2'
        when :arrandale
          'westmere'
        when :dunno
          'unknown'
        else
          cpu_sym.to_s
      end
    end

    b_cpu = Hardware::CPU.family
    tuple_trailer = "apple-darwin#{`uname -r`}"

    if build.universal?
      archs = Hardware::CPU.universal_archs
    elsif MacOS.prefer_64_bit?
      archs = [Hardware::CPU.arch_64_bit]
    else
      archs = [Hardware::CPU.arch_32_bit]
    end

    dirs = []

    archs.each do |arch|
      ENV.append_to_cflags "-arch #{arch}"

      h_sym = (build.bottle? ? (ARGV.bottle_arch or Hardware.oldest_cpu) : b_cpu)

      args = %W[
        --prefix=#{prefix}
        --enable-cxx
        --build=#{cpu_lookup(b_cpu)}-#{tuple_trailer}
        --host=#{cpu_lookup(h_sym)}-#{tuple_trailer}
      ]
      args << '--disable-silent-rules' if ARGV.verbose?

      case arch
        when :i386, :ppc
          mode = '32'
          ENV.m32
          args << '--disable-assembly'
        when :ppc64
          mode='mode64'
          ENV.append_to_cflags '-force_cpusubtype_ALL'
        when :x86_64
          mode = '64'
      end
      args << "ABI=#{mode}"

      dir = "build-#{arch}"
      dirs << dir
      mkdir dir
      cd dir

      ENV.deparallelize
      system '../configure', "--exec-prefix=#{Dir.pwd}", *args
      system 'make'
      system 'make', 'check'
      system 'make', 'install'

      # undo architecture-specific tweaks before next run
      ENV.remove_from_cflags "-arch #{arch}"
      ENV.remove 'HOMEBREW_ARCHFLAGS', '-m32' if (arch == :i386 or arch == :ppc)
      ENV.remove_from_cflags '-force_cpusubtype_ALL' if arch == :ppc64

      cd '..'
    end # archs.each

    lib.mkdir

    if build.universal?
      system 'lipo', '-create', *Dir["{#{dirs.join(',')}}/lib/libgmp.??.dylib"],
                     '-output', lib/'libgmp.10.dylib'
      system 'lipo', '-create', *Dir["{#{dirs.join(',')}}/lib/libgmp.a"],
                     '-output', lib/'libgmp.a'
      system 'lipo', '-create', *Dir["{#{dirs.join(',')}}/lib/libgmpxx.?.dylib"],
                     '-output', lib/'libgmpxx.4.dylib'
      system 'lipo', '-create', *Dir["{#{dirs.join(',')}}/lib/libgmpxx.a"],
                     '-output', lib/'libgmpxx.a'
      lib.install Dir["#{dirs.first}/lib/lib*"].select { |s| Pathname.new(s).symlink? }

      # TODO:  the system-specific header files need to be surgically combined.  For now just stash
      # them someplace that won’t be erased when we finish.  On ppc/ppc64, only 2 lines differ.  It
      # should be feasible to “#if defined” each pair into a unit.
      dirs.each { |d|
        dpath = include/d
        dpath.mkdir
        dpath.install Dir["#{d}/include/*"]
      }
    else
      lib.install Dir["#{dirs.first}/lib/lib*"]
      include.install Dir["#{dirs.first}/include/*"]
    end

    # install & fix up the pkgconfig files, which still expect the libraries in the build directory
    # after they have been moved:
    lib.install "#{dirs.first}/lib/pkgconfig"
    Dir["#{lib}/pkgconfig/*"].each do |f|
      system 'sed', '-e', '/^exec_prefix=/d', '-e', 's/exec_prefix/prefix/g', f
    end
  end

  test do
    (testpath/"test.c").write <<-EOS.undent
      #include <gmp.h>
      #include <stdlib.h>

      int main() {
        mpz_t i, j, k;
        mpz_init_set_str (i, "1a", 16);
        mpz_init (j);
        mpz_init (k);
        mpz_sqrtrem (j, k, i);
        if (mpz_get_si (j) != 5 || mpz_get_si (k) != 1) abort();
        return 0;
      }
    EOS
    system ENV.cc, "test.c", "-L#{lib}", "-lgmp", "-o", "test"
    system "./test"
  end
end
