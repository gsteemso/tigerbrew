#:Unlink, switch out, and relink your Homebrew (Tigerbrew) Cellar.
#:
#:  Usage:
#:
#:    brew switch-cellar --save-as=/stash name for current cellar/
#:                     [ --use-new=/name of existing stashed cellar/ ]
#:
#:    brew switch-cellar --refresh
#:
#:In the first form, disconnect everything from the currently active Cellar, then
#:rename it to whatever you specified with “save-as=”.  Once the thitherto‐active
#:Cellar is safely stashed away, rename whatever you specified with “use-new=” to
#:become the active Cellar.  All of the expected linkages to it are restored.  If
#:no replacement Cellar is specified, an empty one is created.
#:
#:In the second form, disconnect and then immediately reconnect everything within
#:the current Cellar.  This repairs any and all incorrect or damaged linkages.
#:

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
          begin 
            keg.unlink(mode) if keg.linked?
            keg.remove_opt_record unless ARGV.dry_run?
          rescue FormulaUnavailableError
            puts "Error unlinking #{keg.name}:  No formula."
            next
          end
        end # each |keg|
      end # each |rack|
    end # sever_cellar

    def unsever_cellar(mode)
      HOMEBREW_CELLAR.subdirs.each do |rack|
        kegs = rack.subdirs.map { |sd| Keg.new(sd) }
        kegs.each do |keg|
          begin
            keg.optlink(mode)
            keg.link(mode) unless Formulary.from_rack(rack).keg_only?
          rescue FormulaUnavailableError
            puts "Error re‐linking #{keg.name}:  No formula."
            next
          end
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
          raise "#{cellar_stash.realpath}:  File or directory already exists."
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
