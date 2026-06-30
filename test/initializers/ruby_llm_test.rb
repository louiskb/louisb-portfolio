require "test_helper"

class RubyLlmInitializerTest < ActiveSupport::TestCase
  test "the initializer opts into the new acts_as API" do
    # Proves config/initializers/ruby_llm.rb ran at boot and set the flag,
    # silencing the legacy-acts_as 2.0 deprecation warning.
    assert RubyLLM.config.use_new_acts_as
  end

  test "configuring with a nil Anthropic key does not raise" do
    # Graceful degradation: a missing ANTHROPIC_API_KEY must never crash boot.
    original = RubyLLM.config.anthropic_api_key
    assert_nothing_raised do
      RubyLLM.configure { |config| config.anthropic_api_key = nil }
    end
  ensure
    RubyLLM.configure { |config| config.anthropic_api_key = original }
  end
end
