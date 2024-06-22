# at this point we expect Ruby’s `pathname` and Homebrew’s `extend/pathname` to be in effect

if ENV['HOMEBREW_BREW_FILE']
  # Path to `bin/brew` main executable in {HOMEBREW_PREFIX}
  HOMEBREW_BREW_FILE = Pathname.new(ENV['HOMEBREW_BREW_FILE'])
else
  odie '$HOMEBREW_BREW_FILE was not exported! Please call bin/brew directly!'
end

HOMEBREW_CACHE           = Pathname.new(ENV['HOMEBREW_CACHE'])
                           # Where downloads (bottles, source tarballs, etc.) are cached
  HOMEBREW_CACHE_FORMULA =   HOMEBREW_CACHE/'Formula'
                             # Where brews installed via URL are cached
HOMEBREW_CELLAR          = Pathname.new(ENV['HOMEBREW_CELLAR'])
HOMEBREW_LIBRARY         = Pathname.new(ENV['HOMEBREW_LIBRARY'])
  HOMEBREW_CONTRIB       =   HOMEBREW_LIBRARY/'Contributions'
  HOMEBREW_LIBRARY_PATH  =   HOMEBREW_LIBRARY/'Homebrew'            # Homebrew’s Ruby libraries
  HOMEBREW_LOAD_PATH     =   HOMEBREW_LIBRARY_PATH
                             # The path to our libraries _when invoking Ruby_.  Is sometimes set to
                             # a custom value during unit testing of Homebrew itself.
HOMEBREW_PREFIX          = Pathname.new(ENV['HOMEBREW_PREFIX'])     # Where we link under
HOMEBREW_REPOSITORY      = Pathname.new(ENV['HOMEBREW_REPOSITORY']) # Where .git is found
HOMEBREW_VERSION         = Pathname.new(ENV['HOMEBREW_VERSION'])    # Permanently fixed at 0.9.5

# These may optionally be user‐defined:
HOMEBREW_LOGS = Pathname.new(ENV["HOMEBREW_LOGS"] || "~/Library/Logs/Homebrew/").expand_path
                # Where build, postinstall, and test logs of formulæ are written to
HOMEBREW_TEMP = Pathname.new(ENV['HOMEBREW_TEMP'] || "/tmp")
                # Where temporary folders for building and testing formulæ are created
