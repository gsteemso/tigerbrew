class Perl < Formula
  desc "Highly capable, feature-rich programming language"
  homepage "https://www.perl.org/"
  url "https://www.cpan.org/src/5.0/perl-5.38.2.tar.xz"
  sha256 "d91115e90b896520e83d4de6b52f8254ef2b70a8d545ffab33200ea9f1cf29e8"

  head "https://perl5.git.perl.org/perl.git", :branch => "blead"

  keg_only :provided_by_osx,
    "OS X ships Perl and overriding that can cause unintended issues"

  bottle do
    sha256 "22a0e98c6e0c1356823dffdd096fb150a938992672aceb9dc916cf7834577833" => :tiger_altivec
  end

  option :universal
  option "with-dtrace", "Build with DTrace probes" if MacOS.version >= :leopard
  option "with-tests", "Run the build-test suite (expect 1 test file to partly fail on 64-bit PowerPC)"

  def install
    ENV.permit_arch_flags if superenv?
    ENV.un_m64 if Hardware::CPU.family == :g5_64
    if build.universal?
      archs = Hardware::CPU.universal_archs
      dirs = []
    else
      archs = [MacOS.preferred_arch]
    end # universal?
    archs.each do |arch|
      ENV.append_to_cflags "-arch #{arch}"
      bitness = Hardware::CPU.bits
      if build.universal?
        dir = "stash-#{arch}"
        mkdir dir
        dirs << dir
      end # universal?
      args = %W[
        -des
        -Dprefix=#{prefix}
        -Uvendorprefix=
        -Dprivlib=#{lib}
        -Darchlib=#{lib}
        -Dman1dir=#{man1}
        -Dman3dir=#{man3}
        -Dman3ext=3pl
        -Dhtml1dir=#{doc}/html
        -Dhtml3dir=#{doc}/modules/html
        -Dsitelib=#{lib}/site_perl
        -Dsitearch=#{lib}/site_perl
        -Dsiteman1dir=#{man1}
        -Dsiteman3dir=#{man3}
        -Dsitehtml1dir=#{doc}/html
        -Dsitehtml3dir=#{doc}/modules/html
        -Dperladmin=none
        -Dstartperl=\#!#{opt_bin}/perl
        -Duseshrplib
        -Duselargefiles
        -Dusenm
        -Dusethreads
        -Acppflags=#{ENV.cppflags}
        -Accflags=#{ENV.cflags}
        -Alddlflags=#{ENV.ldflags}
        -Aldflags=#{ENV.ldflags}
      ]
      args << '-Duse64bitall' if bitness == 64
      args << "-Dusedtrace" if build.with? "dtrace"
      args << "-Dusedevel" if build.head?
      system "./Configure", *args
      system "make"
      system "make", "test" if build.with?("tests") || build.bottle?
      system "make", "install"
      if build.universal?
        system 'make', 'distclean'
        Merge.scour_keg(prefix, dir)
        # undo architecture-specific tweak before next run
        ENV.remove_from_cflags "-arch #{arch}"
      end # universal?
    end # each |arch|
    Merge.mach_o(prefix, dirs) if build.universal?
  end

  def caveats; <<-EOS.undent
    By default Perl installs modules in your HOME dir. If this is an issue run:
      `#{bin}/cpan o conf init`
    and tell it to put them in, for example, #{opt_lib}/site_perl instead.
    EOS
  end

  test do
    (testpath/"test.pl").write "print 'Perl is not an acronym, but JAPH is a Perl acronym!';"
    system "#{bin}/perl", "test.pl"
  end

  # Unbreak Perl build on legacy Darwin systems
  # https://github.com/Perl/perl5/pull/21023
  # lib/ExtUtils/MM_Darwin.pm: Unbreak Perl build
  # https://github.com/Perl-Toolchain-Gang/ExtUtils-MakeMaker/pull/444/files
  # t/04-xs-rpath-darwin.t: Need Darwin 9 minimum
  # https://github.com/Perl-Toolchain-Gang/ExtUtils-MakeMaker/pull/446
  # undocumented, same file: Dummy library build needs to match Perl build, especially on 64-bit
  # -rpath wont work when targeting 10.3 on 10.5
  # https://github.com/Perl/perl5/pull/21367
  patch :p0, :DATA
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

__END__
--- cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_Darwin.pm.orig	2023-03-02 11:53:45.000000000 +0000
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_Darwin.pm	2023-05-21 05:13:48.000000000 +0100
@@ -46,29 +46,4 @@
     $self->SUPER::init_dist(@_);
 }
 
-=head3 cflags
-
-Over-ride Apple's automatic setting of -Werror
-
-=cut
-
-sub cflags {
-    my($self,$libperl)=@_;
-    return $self->{CFLAGS} if $self->{CFLAGS};
-    return '' unless $self->needs_linking();
-
-    my $base = $self->SUPER::cflags($libperl);
-
-    foreach (split /\n/, $base) {
-        /^(\S*)\s*=\s*(\S*)$/ and $self->{$1} = $2;
-    };
-    $self->{CCFLAGS} .= " -Wno-error=implicit-function-declaration";
-
-    return $self->{CFLAGS} = qq{
-CCFLAGS = $self->{CCFLAGS}
-OPTIMIZE = $self->{OPTIMIZE}
-PERLTYPE = $self->{PERLTYPE}
-};
-}
-
 1;
--- dist/ExtUtils-CBuilder/lib/ExtUtils/CBuilder/Platform/darwin.pm.orig	2023-03-02 11:53:46.000000000 +0000
+++ dist/ExtUtils-CBuilder/lib/ExtUtils/CBuilder/Platform/darwin.pm	2023-05-21 05:18:00.000000000 +0100
@@ -16,9 +16,6 @@
   local $cf->{ccflags} = $cf->{ccflags};
   $cf->{ccflags} =~ s/-flat_namespace//;
 
-  # XCode 12 makes this fatal, breaking tons of XS modules
-  $cf->{ccflags} .= ($cf->{ccflags} ? ' ' : '').'-Wno-error=implicit-function-declaration';
-
   $self->SUPER::compile(@_);
 }
 
--- cpan/ExtUtils-MakeMaker/t/04-xs-rpath-darwin.t
+++ cpan/ExtUtils-MakeMaker/t/04-xs-rpath-darwin.t
@@ -14,9 +14,13 @@ BEGIN {
     chdir 't' or die "chdir(t): $!\n";
     unshift @INC, 'lib/';
     use Test::More;
+    my ($osmajmin) = $Config{osvers} =~ /^(\d+\.\d+)/;
     if( $^O ne "darwin" ) {
         plan skip_all => 'Not darwin platform';
     }
+    elsif ($^O eq 'darwin' && $osmajmin < 9) {
+	plan skip_all => 'For OS X Leopard and newer'
+    }
     else {
         plan skip_all => 'Dynaloading not enabled'
             if !$Config{usedl} or $Config{usedl} ne 'define';
@@ -195,7 +199,7 @@
     my $libext = $Config{so};
 
     my $libname = 'lib' . $self->{mylib_lib_name} . '.' . $libext;
-    my @cmd = ($cc, '-I.', '-dynamiclib', '-install_name',
+    my @cmd = ($cc, split(' ', $ENV{'CFLAGS'}), '-I.', '-dynamiclib', '-install_name',
              '@rpath/' . $libname,
              'mylib.c', '-o', $libname);
     _run_system_cmd(\@cmd);
--- hints/darwin.sh.orig	2023-08-12 09:55:03.000000000 +0100
+++ hints/darwin.sh	2023-08-12 09:55:59.000000000 +0100
@@ -287,14 +287,14 @@
    ldflags="${ldflags} -flat_namespace"
    lddlflags="${ldflags} -bundle -undefined suppress"
    ;;
-[7-9].*)   # OS X 10.3.x - 10.5.x
+[7-8].*)   # OS X 10.3.x - 10.4.x
    lddlflags="${ldflags} -bundle -undefined dynamic_lookup"
    case "$ld" in
        *MACOSX_DEPLOYMENT_TARGET*) ;;
        *) ld="env MACOSX_DEPLOYMENT_TARGET=10.3 ${ld}" ;;
    esac
    ;;
-*)        # OS X 10.6.x - current
+*)        # OS X 10.5.x - current
    # The MACOSX_DEPLOYMENT_TARGET is not needed,
    # but the -mmacosx-version-min option is always used.
 
