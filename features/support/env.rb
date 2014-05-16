require 'aruba/cucumber'

Before do
  @processes = []
  @aruba_timeout_seconds = 30
end
