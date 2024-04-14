class Openssl3 < Formula
  desc "Cryptography and SSL/TLS Toolkit"
  homepage "https://openssl.org/"
  url "https://openssl.org/source/openssl-3.2.1.tar.gz"
  sha256 "83c7329fe52c850677d75e5d0b0ca245309b97e8ecbcfdc1dfdc4ab9fac35b39"
  license "Apache-2.0"

  option :universal

  keg_only :provided_by_osx

  depends_on "curl-ca-bundle"
  depends_on "perl"

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

  def arg_format(arch)
    case arch
      when :x86_64 then 'darwin64-x86_64-cc'
      when :i386   then 'darwin-i386-cc'
      when :ppc    then 'darwin-ppc-cc'
      when :ppc64  then 'darwin64-ppc-cc'
    end
  end

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
    elsif MacOS.prefer_64_bit?
      archs = [Hardware::CPU.arch_64_bit]
    else
      archs = [Hardware::CPU.arch_32_bit]
    end

    openssldir.mkpath

    dirs = []

    archs.each do |arch|
      if build.universal?
        ENV.append_to_cflags "-arch #{arch}"
        dir = "build-#{arch}"
        dirs << dir
        mkdir dir
      end

      args = [
        "--prefix=#{prefix}",
        "--openssldir=#{openssldir}",
        arg_format(arch)
      ]
      # the assembly routines don’t work right on Tiger or on 32-bit PPC
      args << "no-asm" if (MacOS.version < :leopard or arch == :ppc)
      # No {get,make,set}context support before Leopard
      args << "no-async" if MacOS.version < :leopard

      system "perl", "./Configure", *args
      ENV.deparallelize do 
        system "make"
        system "make", "install", "MANDIR=#{man}", "MANSUFFIX=ssl"
        system "make", "test"
      end

      if build.universal?
        # undo architecture-specific tweak before next run
        ENV.remove_from_cflags "-arch #{arch}"
        scour_keg(dir, '')
        system 'make', 'clean'
      end
    end
    merge_mach_o_stashes(dirs, '') if build.universal?
  end

  def openssldir
    etc/"openssl@3"
  end

  def post_install
    rm_f openssldir/"cert.pem"
    openssldir.install_symlink Formula["curl-ca-bundle"].opt_share/"ca-bundle.crt" => "cert.pem"
  end

  def caveats
    <<~EOS
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
  end
end
