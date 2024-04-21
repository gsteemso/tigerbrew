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
    # utility routine:  map Tigerbrew’s CPU symbols to those for configuring a GMP build
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
    end # cpu_lookup

    build_cpu = Hardware::CPU.family
    tuple_trailer = "apple-darwin#{`uname -r`.to_i}"

    ENV.cxx11 if build.cxx11?

    if build.universal?
      ENV.permit_arch_flags
      archs = Hardware::CPU.universal_archs
      mkdir 'arch-headers'
      dirs = []
    elsif MacOS.prefer_64_bit?
      archs = [Hardware::CPU.arch_64_bit]
    else
      archs = [Hardware::CPU.arch_32_bit]
    end

    archs.each do |arch|
      ENV.append_to_cflags "-arch #{arch}"
      if arch == :ppc64
        ENV.append_to_cflags '-force_cpusubtype_ALL'
      else
        ENV.remove_from_cflags '-arch ppc64'
      end

      if build.universal?
        dir = "stash-#{arch}"
        mkdir dir
        dirs << dir
      end

      args = %W[
        --prefix=#{prefix}
        --enable-cxx
      ]

      host_sym = (build.bottle? ? (ARGV.bottle_arch or Hardware.oldest_cpu) : build_cpu)
      args << "--build=#{cpu_lookup(build_cpu)}-#{tuple_trailer}" if host_sym != build_cpu

      args << (ARGV.verbose? ? '--disable-silent-rules' : '--enable-silent-rules')

      args << '--disable-assembly' if Hardware.is_32_bit?

      system './configure', *args
      system 'make'
      system 'make', 'check'
      ENV.deparallelize
      system 'make', 'install'

      if build.universal?
        system 'make', 'clean'
        Merge.scour_keg(prefix, dir, '')
        # gmp.h is architecture-dependent; when installing :universal, this copy will be used in
        # merging them all together
        mkdir "arch-headers/#{arch}"
        cp include/'gmp.h', "arch-headers/#{arch}/gmp.h"
        # undo architecture-specific tweaks before next run
        ENV.remove_from_cflags "-arch #{arch}"
        ENV.remove_from_cflags '-force_cpusubtype_ALL' if arch == :ppc64
      end # universal?
    end # archs.each

    if build.universal?
      Merge.mach_o(prefix, dirs, '')
      Merge.cpp_headers(include, 'arch-headers', archs)
    end
  end # install

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
    ENV.universal_binary if build.universal?
    system ENV.cc, "test.c", "-L#{lib}", "-lgmp", "-o", "test"
    system "./test"
  end # test
end #Gmp

class Merge
  # `class_exec` doesn't exist in Tiger/Leopard stock Ruby.  Ideally, find a workaround.
  Pathname.class_exec {
    # binread does not exist in Leopard stock Ruby 1.8.6, and Tigerbrew's
    # cobbled-in version doesn't work, so use this instead
    def b_read(offset = 0, length = self.size)
      self.open('rb') do |f|
        f.pos = offset
        f.read(length)
      end
    end unless method_defined?(:b_read)

    def is_bare_mach_o?
      # MH_MAGIC    = 'feedface'
      # MH_MAGIC_64 = 'feedfacf' -- same value with lowest-order bit inverted
      self.file? and
      self.size >= 4 and
      [self.b_read(0,4).unpack('N').first & 0xfffffffe].pack('N').unpack('H8').first == 'feedface'
    end unless method_defined?(:is_bare_mach_o?)
  }

  class << self
    include FileUtils

    def scour_keg(keg_prefix, stash, sub_path)
      s_p = (sub_path == '' ? '' : sub_path + '/')
      Dir["#{keg_prefix}/#{s_p}*"].each do |f|
        pn = Pathname(f)
        spb = s_p + pn.basename
        if pn.directory?
          Dir.mkdir "#{stash}/#{spb}"
          scour_keg(keg_prefix, stash, spb)
        elsif ((not pn.symlink?) and pn.is_bare_mach_o?)
          cp pn, "#{stash}/#{spb}"
        end
      end
    end # scour_keg

    def cpp_headers(include_dir, stash_dir, archs, extensions = ['h'])
      # System-specific <header>.<extension> files need to be surgically combined.  They were stashed
      # for this purpose.  The differences are usually minor and can be “#if defined ()” together.
      Dir["#{stash_dir}/#{archs.first}/*.{#{extensions.join(',')}}"].each do |basis_file|
        header_name = File.basename(basis_file)
        diffpoints = {}  # Keyed by line number in the basis file.  Each value is an array of three‐
                         # element hashes; containing the arch, the hunk’s displacement (the number
                         # of basis‐file lines it replaces), and an array of its lines.
        archs[1..-1].each do |a|
          raw_diffs = `diff --minimal --unified=0 #{basis_file} #{stash_dir}/#{a}/#{header_name}`
          next unless raw_diffs
          # The unified diff output begins with two lines identifying the source files, which are
          # followed by a series of hunk records, each describing one difference that was found.
          # Each hunk record begins with a line that looks like:
          # @@ -line_number,length_in_lines +line_number,length_in_lines @@
          diff_hunks = raw_diffs.lines[2..-1].join('').split(/(?=^@@)/)
          diff_hunks.each do |d|
            # lexical sorting of numbers requires that they all be the same length
            base_linenumber_string = ('00000' + d.match(/\A@@ -(\d+)/)[1])[-6..-1]
            unless diffpoints.has_key?(base_linenumber_string)
              diffpoints[base_linenumber_string] = []
            end
            length_match = d.match(/\A@@ -\d+,(\d+)/)
            # if the hunk length is 1, the comma and second number are not present
            length_match = (length_match == nil ? 1 : length_match[1].to_i)
            line_group = []
            # we want the lines that are either unchanged between files or only present in the non‐
            # basis file; and to shave off the leading ‘+’ or ‘ ’
            d.lines { |line| line_group << line[1..-1] if line =~ /^[+ ]/ }
            diffpoints[base_linenumber_string] << {
              :arch => a,
              :displacement => length_match,
              :hunk_lines => line_group
            }
          end # diff_hunks.each
        end # archs.each

        # Ideally, the algorithm would account for overlapping and/or different-displacement hunks
        # at this point; but since that doesn’t appear to be a thing most packages generate in the
        # first place, and will in any case only become relevant if “REALLY universal” multi‐
        # platform fat binaries are implemented, it can wait.

        basis_lines = []
        File.open(basis_file, 'r') { |text| basis_lines = text.read.lines[0..-1] }
        # bear in mind that the line-array indices are one less than the line numbers

        # start with the last diff point so the insertions don’t screw up our line numbering
        diffpoints.keys.sort.reverse.each do |index_string|
          diff_start = index_string.to_i - 1
          diff_end = index_string.to_i + diffpoints[index_string][0][:displacement] - 2
          adjusted_lines = [
            "\#if defined (__#{archs.first}__)\n",
            basis_lines[diff_start..diff_end],
            *(diffpoints[index_string].map { |d|
                [ "\#elif defined (__#{d[:arch]}__)\n", *(d[:hunk_lines]) ]
              }),
            "\#endif\n"
          ]
          basis_lines[diff_start..diff_end] = adjusted_lines
        end # keys.each do

        File.new("#{include_dir}/#{header_name}", 'w').syswrite(basis_lines.join(''))
      end # Dir[basis files].each
    end # cpp_headers

    def mach_o(install_prefix, arch_dirs, sub_path)
      s_p = (sub_path == '' ? '' : sub_path + '/')
      Dir["#{arch_dirs.first}/#{s_p}*"].each do |f|
        pn = Pathname(f)
        spb = s_p + pn.basename
        if pn.directory?
          mach_o(install_prefix, arch_dirs, spb)
        else
          arch_files = Dir["{#{arch_dirs.join(',')}}/#{spb}"]
          if arch_files.length > 1
            system 'lipo', '-create', *arch_files, '-output', install_prefix/spb
          else
            # presumably there's a reason this only exists for one architecture, so no error;
            # the same rationale would apply if it only existed in, say, two out of three
            cp arch_files.first, "#{install_prefix}/#{spb}"
          end # if > 1 file?
        end # if directory?
      end # Dir[stashed files].each
    end # mach_o

  end # Merge << self
end # Merge
