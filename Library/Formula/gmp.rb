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

    # a utility routine to map Tigerbrew’s CPU symbols to those used in configuring a GMP build
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

    # a utility routine for processing diffs (used when splicing together the architecture-
    # dependent header files of a :universal build)
    def extract_new_lines(hunk)
      hunk.lines.select { |l| l =~ /^\+/ }.map { |l| l[1, -1] }
    end

    b_cpu = Hardware::CPU.family
    tuple_trailer = "apple-darwin#{`uname -r`}"

    if build.universal?
      archs = Hardware::CPU.universal_archs
      mkdir per_arch_gmp_h
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

      # this header is architecture-dependent; in the case of installing :universal, this copy will
      # be used when merging them all together
      system 'cp', 'include/gmp.h', "../per_arch_gmp_h/#{arch}"

      # undo architecture-specific tweaks before next run
      ENV.remove_from_cflags "-arch #{arch}"
      ENV.remove 'HOMEBREW_ARCHFLAGS', '-m32' if (arch == :i386 or arch == :ppc)
      ENV.remove_from_cflags '-force_cpusubtype_ALL' if arch == :ppc64

      cd '..'
    end # archs.each

    lib.mkdir

    if build.universal?
      # build the fat libraries directly into place
      system 'lipo', '-create', *Dir["{#{dirs.join(',')}}/lib/libgmp.??.dylib"],
                     '-output', lib/'libgmp.10.dylib'
      system 'lipo', '-create', *Dir["{#{dirs.join(',')}}/lib/libgmp.a"],
                     '-output', lib/'libgmp.a'
      system 'lipo', '-create', *Dir["{#{dirs.join(',')}}/lib/libgmpxx.?.dylib"],
                     '-output', lib/'libgmpxx.4.dylib'
      system 'lipo', '-create', *Dir["{#{dirs.join(',')}}/lib/libgmpxx.a"],
                     '-output', lib/'libgmpxx.a'
      # grab the symlinks too
      lib.install Dir["#{dirs.first}/lib/lib*"].select { |s| Pathname.new(s).symlink? }
      # and the C++ header, which is architecture-independent
      include.install "#{dirs.first}/include/gmpxx.h"

      # The system-specific gmp.h files need to be surgically combined.  They were stashed in
      # ./per_arch_gmp_h/ for this purpose.  The differences are minor and can be #ifdef’d together.
      basis_file = "per_arch_gmp_h/#{archs.first}"
      diffpoints = {}  # Keyed by line number in the basis file.  Contains arrays of two-element
                       # hashes, where one item is the arch and the other is the applicable hunk.
      archs[1..-1].each do |a|
        raw_diffs = `diff -u 0 #{basis_file} per_arch_gmp_h/#{a}`
        diff_hunks = raw_diffs.lines[2..-1].join('').split(/(?=^\@\@)/)
        diff_hunks.each do |d|
          basis_line = d.match(/\A@@ -(\d+)/)[0]
          unless diffpoints.has_key?(basis_line)
            diffpoints[basis_line] = []
          end
          diffpoints[basis_line] << { :arch => a,
                                      :displacement => d.match(/\A@@ -\d+,(\d+)/)[0],
                                      :hunk_lines => extract_new_lines(d)
                                    }
        end
      end
      # Ideally the algorithm would account for overlapping and/or different-length hunks at this
      # point; but since that doesn't appear to be a thing that GMP generates in the first place,
      # and would in any case only become relevant if "REALLY universal" triple-or-more fat
      # binaries are implemented, it can wait.

      basis_lines = basis_file.lines  # the array indices are one less than the line numbers
      # start with the last diff point so that the insertions don't screw up our line numbering
      diffpoints.keys.sort.reverse.each do |index|
        diff_start = index - 1
        diff_end = index + diffpoints[index][0][:displacement] - 2
        basis_lines[diff_start..diff_end] = [
          "\#if defined (__#{archs.first}__)\n",
          basis_lines[diff_start..diff_end],
          *diffpoints[index].each { |d|
            [ "\#elif defined (__#{d[:arch]}__)\n", *d[:hunk_lines] ]
          },
          "\#endif\n"
        ]
      end
      File.new(include/'gmp.h'.to_path, 'w', 0644).write basis_lines.join('')
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
