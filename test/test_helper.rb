rootdir = File.dirname(File.dirname(__FILE__))
$LOAD_PATH.unshift rootdir + '/test'
$LOAD_PATH.unshift rootdir + '/lib'

require 'test/unit'
require 'resque'

begin
    require 'turn' # nicer test output.
rescue LoadError
end

require 'resque-exponential-backoff'