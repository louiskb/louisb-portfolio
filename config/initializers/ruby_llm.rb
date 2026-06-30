RubyLLM.configure do |config|
  # Anthropic Claude is the only provider this app uses. A missing key never
  # raises here — the AI blog features simply stay disabled (see ai_configured?)
  # until ANTHROPIC_API_KEY is set, so the rest of the app boots and runs fine.
  config.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY", nil)

  # Opt into the modern association-based acts_as API (valid setter in
  # ruby_llm 1.16). Silences the legacy-acts_as deprecation warning.
  config.use_new_acts_as = true
end
