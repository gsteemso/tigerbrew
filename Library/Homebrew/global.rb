require "rbconfig"          #⎟ Ruby libraries
require "set"               #⎠
require "extend/fileutils"  # all these others are Homebrew libraries
require "extend/pathname"
require "extend/ARGV"
require "extend/string"
require "os"
require "utils"
require "exceptions"
require "extend/tiger" if RUBY_VERSION == "1.8.2"
require "extend/leopard" if RUBY_VERSION <= "1.8.6"

ARGV.extend(HomebrewArgvExtension)

HOMEBREW_VERSION = ENV["HOMEBREW_VERSION"]
HOMEBREW_WWW = "https://github.com/mistydemeo/tigerbrew"

require "config"  # a Homebrew library

RbConfig = Config if RUBY_VERSION < "1.8.6" # different module name on Tiger

if RbConfig.respond_to?(:ruby)
  RUBY_PATH = Pathname.new(RbConfig.ruby)
else
  RUBY_PATH = Pathname.new(RbConfig::CONFIG["bindir"]).join(
    RbConfig::CONFIG["ruby_install_name"] + RbConfig::CONFIG["EXEEXT"]
  )
end
RUBY_BIN = RUBY_PATH.dirname  # the directory our binary lives in

if RUBY_PLATFORM =~ /darwin/
  MACOS_FULL_VERSION = `/usr/bin/sw_vers -productVersion`.chomp
  MACOS_VERSION = MACOS_FULL_VERSION[/10\.\d+/]
  OS_VERSION = "OS X #{MACOS_FULL_VERSION}"
else
  MACOS_FULL_VERSION = MACOS_VERSION = "0"
  OS_VERSION = RUBY_PLATFORM
end

HOMEBREW_GITHUB_API_TOKEN = ENV["HOMEBREW_GITHUB_API_TOKEN"]

HOMEBREW_USER_AGENT_CURL = ENV["HOMEBREW_USER_AGENT_CURL"]
ruby_version = "#{RUBY_VERSION}#{"-p#{RUBY_PATCHLEVEL}" if defined? RUBY_PATCHLEVEL}"
HOMEBREW_USER_AGENT_RUBY = "#{ENV["HOMEBREW_USER_AGENT"]} ruby/#{ruby_version}"

HOMEBREW_CURL_ARGS = "-f#LA"

require "tap_constants"

module Homebrew
  include FileUtils
  extend self

  attr_accessor :failed
  alias_method :failed?, :failed
end

HOMEBREW_PULL_OR_COMMIT_URL_REGEX = %r[https://github\.com/([\w-]+)/tigerbrew(-[\w-]+)?/(?:pull/(\d+)|commit/[0-9a-fA-F]{4,40})]

require "compat" unless ARGV.include?("--no-compat") || ENV["HOMEBREW_NO_COMPAT"]

ORIGINAL_PATHS = ENV["PATH"].split(File::PATH_SEPARATOR).map { |p| Pathname.new(p).expand_path rescue nil }.compact.freeze

HOMEBREW_INTERNAL_COMMAND_ALIASES = {
  "ls" => "list",
  "homepage" => "home",
  "-S" => "search",
  "up" => "update",
  "ln" => "link",
  "instal" => "install", # gem does the same
  "rm" => "uninstall",
  "remove" => "uninstall",
  "configure" => "diy",
  "abv" => "info",
  "dr" => "doctor",
  "--repo" => "--repository",
  "environment" => "--env",
  "--config" => "config"
}
