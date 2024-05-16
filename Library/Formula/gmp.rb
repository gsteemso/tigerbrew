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
    else
      archs = [MacOS.preferred_arch]
    end

    archs.each do |arch|
      ENV.append_to_cflags "-arch #{arch}"
      if (arch == :ppc64 or Hardware::CPU.ppc? and Hardware::CPU.is_64_bit?)
        ENV.append_to_cflags '-force_cpusubtype_ALL'
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
      args << (ARGV.verbose? ? '--disable-silent-rules' : '--enable-silent-rules')
      args << '--disable-assembly' if Hardware.is_32_bit?

      host_sym = (build.bottle? ? (ARGV.bottle_arch or Hardware.oldest_cpu) : build_cpu)
      if cpu_lookup(host_sym) != cpu_lookup(build_cpu)
        args << "--build=#{cpu_lookup(build_cpu)}-#{tuple_trailer}"
        args << "--host=#{cpu_lookup(host_sym)}-#{tuple_trailer}"
      end

      system './configure', *args
      system 'make'
      system 'make', 'check'
      ENV.deparallelize
      system 'make', 'install'

      if build.universal?
        system 'make', 'clean'
        Merge.scour_keg(prefix, dir)
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
      Merge.mach_o(prefix, dirs)
      Merge.cpp_headers(include, 'arch-headers', archs)
    end # universal?
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

    def cpp_headers(include_dir, stash_dir, archs, sub_path = '', extensions = ['h'])
      # Architecture-specific <header>.<extension> files need to be surgically combined and were
      # stashed for this purpose.  The differences are relatively minor and can be “#if defined ()”
      # together.  We make the simplifying assumption that the architecture-dependent headers in
      # question are present on all architectures.
      #
      # Don’t suffer a double slash when sub_path is null:
      s_p = (sub_path == '' ? '' : sub_path + '/')
      Dir["#{stash_dir}/#{archs[0]}/#{s_p}*.{#{extensions.join(',')}}"].each do |basis_file|
        spb = s_p + File.basename(basis_file)
        if File.directory?(basis_file)
          cpp_headers(include_dir, stash_dir, archs, spb, extensions)
        else
          diffpoints = {}  # Keyed by line number in the basis file.  Each value is an array of
                           # three‐element hashes; containing the arch, the hunk’s displacement
                           # (number of basis‐file lines it replaces), and an array of its lines.
          archs[1..-1].each do |a|
            raw_diffs = `diff --minimal --unified=0 #{basis_file} #{stash_dir}/#{a}/#{spb}`
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
              # we want the lines that are either unchanged between files or only found in the non‐
              # basis file; and to shave off the leading ‘+’ or ‘ ’
              d.lines { |line| line_group << line[1..-1] if line =~ /^[+ ]/ }
              diffpoints[base_linenumber_string] << {
                :arch => a,
                :displacement => length_match,
                :hunk_lines => line_group
              }
            end # diff_hunks.each
          end # archs.each
          # Ideally, the logic would account for overlapping and/or different-displacement hunks
          # at this point; but since most packages don't appear to generate that in the first place,
          # it can wait.  That said, packages exist (e.g. Python and Python 3) which can and do
          # generate quad fat binaries, so it can’t be ignored forever.
          basis_lines = []
          File.open(basis_file, 'r') { |text| basis_lines = text.read.lines[0..-1] }
          # bear in mind that the line-array indices are one less than the line numbers
          #
          # start with the last diff point so the insertions don’t screw up our line numbering
          diffpoints.keys.sort.reverse.each do |index_string|
            diff_start = index_string.to_i - 1
            diff_end = index_string.to_i + diffpoints[index_string][0][:displacement] - 2
            adjusted_lines = [
              "\#if defined (__#{archs[0]}__)\n",
              basis_lines[diff_start..diff_end],
              *(diffpoints[index_string].map { |dp|
                  [ "\#elif defined (__#{dp[:arch]}__)\n", *(dp[:hunk_lines]) ]
                }),
              "\#endif\n"
            ]
            basis_lines[diff_start..diff_end] = adjusted_lines
          end # keys.each do
          File.new("#{include_dir}/#{spb}", 'w').syswrite(basis_lines.join(''))
        end # if not a directory
      end # Dir[basis files].each
    end # cpp_headers

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
