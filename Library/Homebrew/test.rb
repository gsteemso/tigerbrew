old_trap = trap("INT") { exit! 130 }

require "global"
require "extend/ENV"
require "timeout"
require "debrew"
require "formula_assertions"
require "fcntl"
require "socket"

TEST_TIMEOUT_SECONDS = 5*60

begin
  error_pipe = UNIXSocket.open(ENV["HOMEBREW_ERROR_PIPE"], &:recv_io)
  error_pipe.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)

  trap("INT", old_trap)

  formula = ARGV.formulae.first
  formula.build = BuildOptions.new(Tab.for_formula(formula).used_options, formula.options)
  formula.extend(Homebrew::Assertions)

  ENV.activate_extensions!
  ENV.setup_build_environment(formula)
  # enable argument refurbishment
  # (this lets the optimization flags be noticed; otherwise, 64‐bit and universal builds fail)
  ENV.append 'HOMEBREW_CCCFG', 'O'

  if ARGV.debug?
    formula.extend(Debrew::Formula)
    raise "test returned false" if formula.run_test == false
  else
    # tests can also return false to indicate failure
    Timeout.timeout TEST_TIMEOUT_SECONDS do
      raise "test returned false" if formula.run_test == false
    end # timeout?
  end # debug?
  oh1 'Test passed'
rescue Exception => e
  Marshal.dump(e, error_pipe)
  error_pipe.close
  exit! 1
end
