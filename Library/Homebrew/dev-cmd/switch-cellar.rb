require 'keg'
require 'formulary'
require 'tab'
require 'formula'
require 'ostruct'

module Homebrew
  def switch_cellar
    def sever_cellar(mode)
      HOMEBREW_CELLAR.subdirs.each do |rack|
        kegs = rack.subdirs.map { |sd| Keg.new(sd) }
        kegs.each do |keg|
          keg.unlink(mode) if keg.linked?
          begin 
            keg.remove_opt_record unless ARGV.dry_run?
          rescue
          end
        end # each |keg|
      end # each |rack|
    end # sever_cellar

    def unsever_cellar(mode)
      HOMEBREW_CELLAR.subdirs.each do |rack|
        kegs = rack.subdirs.map { |sd| Keg.new(sd) }
        kegs.each do |keg|
          keg.link(mode) unless Formulary.from_rack(rack).keg_only?
          keg.optlink(mode)
        end # each |keg|
      end # each |rack|
    end # unsever_cellar

    def annulnil(arg)
      if arg == nil
        arg = ''
      else
        arg
      end
    end # annulnil

    unless HOMEBREW_CELLAR.directory?
      puts 'You have no Cellar to switch.'
      return
    end
    HOMEBREW_CELLAR.parent.cd do
      mode = OpenStruct.new
      mode.dry_run = ARGV.dry_run?
      if ARGV.include? '--refresh'  # regenerating links in place
        sever_cellar(mode)
        unsever_cellar(mode)
      else  # swapping Cellars wholesale
        # a pathname – either absolute, or relative to the current (Cellar’s parent) directory:
        cellar_stash = Pathname(annulnil ARGV.value('save-as'))
        if cellar_stash == ''
          raise UsageError
        elsif cellar_stash.exist?
          raise "#{cellar_stash.realpath}:  Cannot overwrite existing file or directory."
        end
        sever_cellar(mode)
        begin
          HOMEBREW_CELLAR.rename cellar_stash
        rescue
          unsever_cellar(mode)
          raise RuntimeError
        end
        # a pathname – either absolute, or relative to the current (Cellar’s parent) directory:
        new_cellar = Pathname(annulnil ARGV.value('use-new'))
        if (new_cellar != '' and new_cellar.exist?)
          begin
            new_cellar.rename HOMEBREW_CELLAR
          rescue
            HOMEBREW_CELLAR.mkdir
            raise RuntimeError
          end
          unsever_cellar(mode)
        else
          HOMEBREW_CELLAR.mkdir
        end # new cellar
      end # swapping Cellars, not regenerating links in place
    end # cd into HOMEBREW_CELLAR.parent
  end # switch_cellar
end # module Homebrew

# the help text:

#:
#:  brew switch-cellar --save-as=/name to archive current cellar as/
#:                   [ --use-new=/name of existing stashed cellar/ ]
#:
#:  brew switch-cellar --refresh
#:
#:In the first form, this command safely disconnects everything in the currently
#:active Cellar, and then renames it to whatever you specified under “save-as=”.
#:Once the thitherto‐active Cellar has been safely stashed away, the previously‐
#:saved Cellar specified with “use-new=” is renamed, becoming the active Cellar.
#:All the expected linkages to it are restored.
#:
#:(If no replacement Cellar was identified, a new, empty Cellar will be created;
#:obviously, nothing will be linked into it).
#:
#:In the second form, this command safely disconnects and immediately reconnects
#:everything within the current Cellar.  As a side effect, any and all incorrect
#:and/or damaged linkages are repaired.
#:
