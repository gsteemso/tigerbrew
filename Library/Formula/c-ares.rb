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

  def install
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
      if build.universal?
        ENV.append_to_cflags "-arch #{arch}"
        case arch
          when :i386, :ppc then ENV.m32
          when :x86_64, :ppc64 then ENV.m64
        end
        dir = "stash-#{arch}"
        mkdir dir
        dirs << dir
      end

      system "./configure", "--prefix=#{prefix}",
                            "--disable-dependency-tracking",
                            "--disable-debug",
                            '--enable-symbol-hiding',
                            '--enable-nonblocking'
      system "make"
      ENV.deparallelize do
        system "make", "install"
      end

      if build.universal?
        system 'make', 'clean'
        Merge.scour_keg(prefix, dir, '')
        # ares_build.h is architecture-dependent; when installing :universal, this copy will be
        # used in merging them all together
        mkdir "arch-headers/#{arch}"
        cp include/'ares_build.h', "arch-headers/#{arch}/ares_build.h"

        # undo architecture-specific tweaks before next run
        ENV.remove_from_cflags "-arch #{arch}"
        case arch
          when :i386, :ppc
            ENV.remove 'HOMEBREW_ARCHFLAGS', '-m32'
            # this really is exactly what stdenv adds for .m32 – no cross‐compiling for you!
            ENV.remove 'LDFLAGS', "-arch #{Hardware::CPU.arch_32_bit}" unless superenv?
          when :x86_64, :ppc64
            ENV.remove 'HOMEBREW_ARCHFLAGS', '-m64'
            # this really is exactly what stdenv adds for .m64 – no cross‐compiling for you!
            ENV.remove 'LDFLAGS', "-arch #{Hardware::CPU.arch_64_bit}" unless superenv?
        end # case arch
      end # universal?
    end # archs.each

    if build.universal?
      Merge.mach_o(prefix, dirs, '')
      Merge.cpp_headers(include, 'arch-headers', archs)
    end # if build.universal?
  end # install

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
  end # test
end # CAres

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
