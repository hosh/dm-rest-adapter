module SpecHelpers
  module Macros
    module DebugExamples
      def debug_lvars(*lvars)
        _lvars = lvars.flatten
        it "DEBUG" do
          h = _lvars.inject(Hash.new) { |m,k| m[k.to_sym] = send(k); m }
          ap h
        end
      end
    end
  end
end
RSpec::Core::ExampleGroup.send(:extend, SpecHelpers::Macros::DebugExamples)
