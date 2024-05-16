class Openssl3 < Formula
  desc "Cryptography and SSL/TLS Toolkit"
  homepage "https://openssl.org/"
  url "https://openssl.org/source/openssl-3.2.1.tar.gz"
  sha256 "83c7329fe52c850677d75e5d0b0ca245309b97e8ecbcfdc1dfdc4ab9fac35b39"
  license "Apache-2.0"

  option :universal
  option 'without-tests', 'Skip the self-test procedure (not recommended for a first install)'

  keg_only :provided_by_osx

  depends_on "curl-ca-bundle"
  depends_on "perl"

  def arg_format(arch)
    case arch
      when :x86_64 then 'darwin64-x86_64-cc'
      when :i386   then 'darwin-i386-cc'
      when :ppc    then 'darwin-ppc-cc'
      when :ppc64  then 'darwin64-ppc-cc'
    end
  end

  def install
    # Build breaks passing -w
    ENV.enable_warnings if ENV.compiler == :gcc_4_0
    # Leopard and newer have the crypto framework
    ENV.append_to_cflags "-DOPENSSL_NO_APPLE_CRYPTO_RANDOM" if MacOS.version == :tiger
    # This could interfere with how we expect OpenSSL to build.
    ENV.delete("OPENSSL_LOCAL_CONFIG_DIR")
    # This ensures where Homebrew's Perl is needed the Cellar path isn't
    # hardcoded into OpenSSL's scripts, causing them to break every Perl update.
    # Whilst our env points to opt_bin, by default OpenSSL resolves the symlink.
    ENV["PERL"] = Formula["perl"].opt_bin/"perl" if which("perl") == Formula["perl"].opt_bin/"perl"

    if build.universal?
      ENV.permit_arch_flags
      archs = Hardware::CPU.universal_archs
      dirs = []
    else
      archs = [MacOS.preferred_arch]
    end

    openssldir.mkpath

    archs.each do |arch|
      if build.universal?
        ENV.append_to_cflags "-arch #{arch}"
        ENV['HOMEBREW_ARCHFLAGS'] = "-arch #{arch}" if superenv?
        dir = "stash-#{arch}"
        mkdir dir
        dirs << dir
      end

      configure_args = [
        "--prefix=#{prefix}",
        "--openssldir=#{openssldir}",
        arg_format(arch)
      ]
      # the assembly routines don’t work right on Tiger or on PowerPC G5
      configure_args << "no-asm" if (MacOS.version < :leopard or Hardware::CPU.family == :g5 or Hardware::CPU.family == :g5_64)
      # No {get,make,set}context support before Leopard
      configure_args << "no-async" if MacOS.version < :leopard

      system "perl", "./Configure", *configure_args
      ENV.deparallelize do
        system "make"
        system "make", "install", "MANDIR=#{man}", "MANSUFFIX=ssl"
        system "make", "test" if build.with? 'tests'
      end

      if build.universal?
        system 'make', 'clean'
        Merge.scour_keg(prefix, dir)
        # undo architecture-specific tweak before next run
        ENV.remove_from_cflags "-arch #{arch}"
      end # universal?
    end # archs.each
    Merge.mach_o(prefix, dirs) if build.universal?
  end # install

  def openssldir
    etc/"openssl@3"
  end

  def post_install
    rm_f openssldir/"cert.pem"
    openssldir.install_symlink Formula["curl-ca-bundle"].opt_share/"ca-bundle.crt" => "cert.pem"
  end

  def caveats
    <<-EOS.undent
      A CA file has been bootstrapped using certificates from the system
      keychain. To add additional certificates, place .pem files in
        #{openssldir}/certs

      and run
        #{opt_bin}/c_rehash
    EOS
  end

  test do
    # Make sure the necessary .cnf file exists, otherwise OpenSSL gets moody.
    assert_predicate openssldir/"openssl.cnf", :exist?,
            "OpenSSL requires the .cnf file for some functionality"

    # Check OpenSSL itself functions as expected.
    (testpath/"testfile.txt").write("This is a test file")
    expected_checksum = "e2d0fe1585a63ec6009c8016ff8dda8b17719a637405a4e23c0ff81339148249"
    system bin/"openssl", "dgst", "-sha256", "-out", "checksum.txt", "testfile.txt"
    open("checksum.txt") do |f|
      checksum = f.read(100).split("=").last.strip
      assert_equal checksum, expected_checksum
    end
  end # test
end # Openssl3

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
