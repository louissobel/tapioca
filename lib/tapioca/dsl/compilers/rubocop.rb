# typed: strict
# frozen_string_literal: true

begin
  require "rubocop"
rescue LoadError
  return
end

module Tapioca
  module Dsl
    module Compilers
      # TODO: documentation
      class Rubocop < Compiler
        def self.gather_constants
          all_modules.select do |c|
            name_of(c) && c < ::Rubocop::Cop::Base
          end
        end
      end
    end
  end
end
