# typed: true
# frozen_string_literal: true

require "spec_helper"

module Tapioca
  class CheckShimsTest < SpecWithProject
    describe "cli::check-shims" do
      after do
        @project.remove("sorbet/rbi")
      end

      describe "when Sorbet version is >= 0.5.9818" do
        before(:all) do
          @project.bundle_install
        end

        it "does nothing when there is no shims to check" do
          @project.write("sorbet/rbi/gems/foo@1.0.0.rbi", <<~RBI)
            class Foo
              attr_reader :foo
            end
          RBI

          @project.write("sorbet/rbi/dsl/foo.rbi", <<~RBI)
            class Foo
              attr_reader :bar
            end
          RBI

          result = @project.tapioca("check-shims --no-payload")

          assert_equal(<<~OUT, result.out)
            No shim RBIs to check
          OUT

          assert_success_status(result)
        end

        it "does nothing when there is no duplicates" do
          @project.write("sorbet/rbi/gems/foo@1.0.0.rbi", <<~RBI)
            class Foo
              attr_reader :foo

              class Baz; end
            end
          RBI

          @project.write("sorbet/rbi/shims/foo.rbi", <<~RBI)
            class Foo
              attr_reader :bar

              class Baz
                def baz; end
              end
            end
          RBI

          result = @project.tapioca("check-shims --no-payload")

          assert_equal(<<~OUT, result.out)
            Loading shim RBIs from sorbet/rbi/shims...  Done
            Loading gem RBIs from sorbet/rbi/gems...  Done
            Looking for duplicates...  Done

            No duplicates found in shim RBIs
          OUT

          assert_success_status(result)
        end

        it "detects duplicated definitions between shim and generated RBIs" do
          @project.write("sorbet/rbi/gems/foo@1.0.0.rbi", <<~RBI)
            class Foo
              attr_reader :foo
            end
          RBI

          @project.write("sorbet/rbi/dsl/bar.rbi", <<~RBI)
            module Bar
              def bar; end
            end
          RBI

          @project.write("sorbet/rbi/dsl/baz.rbi", <<~RBI)
            module Baz; end
          RBI

          @project.write("sorbet/rbi/shims/foo.rbi", <<~RBI)
            class Foo
              attr_reader :foo
            end
          RBI

          @project.write("sorbet/rbi/shims/bar.rbi", <<~RBI)
            module Bar
              def bar; end
            end
          RBI

          @project.write("sorbet/rbi/shims/baz.rbi", <<~RBI)
            module Baz
              def baz; end
            end
          RBI

          result = @project.tapioca("check-shims --no-payload")

          assert_includes(result.err, <<~ERR)
            Duplicated RBI for ::Bar#bar:
             * sorbet/rbi/shims/bar.rbi:2:2-2:14
             * sorbet/rbi/dsl/bar.rbi:2:2-2:14
          ERR

          assert_includes(result.err, <<~ERR)
            Duplicated RBI for ::Foo#foo:
             * sorbet/rbi/shims/foo.rbi:2:2-2:18
             * sorbet/rbi/gems/foo@1.0.0.rbi:2:2-2:18
          ERR

          assert_includes(result.err, <<~ERR)
            Please remove the duplicated definitions from sorbet/rbi/shims and sorbet/rbi/todo.rbi
          ERR

          refute_success_status(result)
        end

        it "ignores duplicates that have a signature" do
          @project.write("sorbet/rbi/gems/foo@1.0.0.rbi", <<~RBI)
            class Foo
              def foo; end
            end
          RBI

          @project.write("sorbet/rbi/shims/foo.rbi", <<~RBI)
            class Foo
              sig { void }
              def foo; end
            end
          RBI

          result = @project.tapioca("check-shims --no-payload")
          assert_success_status(result)
        end

        it "ignores duplicates that have a different signature" do
          @project.write("sorbet/rbi/gems/foo@1.0.0.rbi", <<~RBI)
            class Foo
              sig { void }
              def foo; end
            end
          RBI

          @project.write("sorbet/rbi/shims/foo.rbi", <<~RBI)
            class Foo
              sig { returns(Integer) }
              def foo; end
            end
          RBI

          result = @project.tapioca("check-shims --no-payload")
          assert_success_status(result)
        end

        it "detects duplicates that have the same signature" do
          @project.write("sorbet/rbi/gems/foo@1.0.0.rbi", <<~RBI)
            class Foo
              sig { params(x: Integer, y: String).returns(String) }
              def foo(x, y); end

              sig { params(x: Integer, y: Integer).returns(String) }
              def bar(x, y); end

              sig { params(x: Integer, y: Integer).returns(Integer) }
              def baz(x, y); end
            end
          RBI

          @project.write("sorbet/rbi/shims/foo.rbi", <<~RBI)
            class Foo
              sig { params(x: Integer, y: String).returns(String) }
              def foo(x, y); end

              sig { params(x: String, y: Integer).returns(String) }
              def bar(x, y); end

              sig { params(x: Integer, y: Integer).returns(String) }
              def baz(x, y); end
            end
          RBI

          result = @project.tapioca("check-shims --no-payload")

          assert_includes(result.err, <<~ERR)
            Duplicated RBI for ::Foo#foo:
             * sorbet/rbi/shims/foo.rbi:3:2-3:20
             * sorbet/rbi/gems/foo@1.0.0.rbi:3:2-3:20
          ERR

          assert_includes(result.err, <<~ERR)
            Please remove the duplicated definitions from sorbet/rbi/shims and sorbet/rbi/todo.rbi
          ERR

          refute_includes(result.err, "Duplicated RBI for ::Foo#bar")
          refute_includes(result.err, "Duplicated RBI for ::Foo#baz")

          refute_success_status(result)
        end

        it "detects duplicates from nodes with multiple definitions" do
          @project.write("sorbet/rbi/gems/foo@1.0.0.rbi", <<~RBI)
            class Foo
              attr_reader :foo
            end
          RBI

          @project.write("sorbet/rbi/shims/foo.rbi", <<~RBI)
            class Foo
              attr_reader :foo, :bar
            end
          RBI

          result = @project.tapioca("check-shims --no-payload")

          assert_includes(result.err, <<~ERR)
            Duplicated RBI for ::Foo#foo:
             * sorbet/rbi/shims/foo.rbi:2:2-2:24
             * sorbet/rbi/gems/foo@1.0.0.rbi:2:2-2:18
          ERR

          assert_includes(result.err, <<~ERR)
            Please remove the duplicated definitions from sorbet/rbi/shims and sorbet/rbi/todo.rbi
          ERR

          refute_success_status(result)
        end

        it "detects duplicates from same shim file" do
          @project.write("sorbet/rbi/gems/foo@1.0.0.rbi", <<~RBI)
            class Foo
              attr_reader :foo

              class Baz; end
            end

            class Bar; end
          RBI

          @project.write("sorbet/rbi/shims/foo.rbi", <<~RBI)
            class Foo
              attr_reader :foo, :bar
              def foo; end

              class Baz; end
            end

            class Bar; end
            class Bar; end
          RBI

          result = @project.tapioca("check-shims --no-payload")

          assert_includes(result.err, <<~ERR)
            Duplicated RBI for ::Foo#foo:
             * sorbet/rbi/shims/foo.rbi:2:2-2:24
             * sorbet/rbi/shims/foo.rbi:3:2-3:14
             * sorbet/rbi/gems/foo@1.0.0.rbi:2:2-2:18
          ERR

          assert_includes(result.err, <<~ERR)
            Duplicated RBI for ::Foo::Baz:
             * sorbet/rbi/shims/foo.rbi:5:2-5:16
             * sorbet/rbi/gems/foo@1.0.0.rbi:4:2-4:16
          ERR

          assert_includes(result.err, <<~ERR)
            Duplicated RBI for ::Bar:
             * sorbet/rbi/shims/foo.rbi:8:0-8:14
             * sorbet/rbi/shims/foo.rbi:9:0-9:14
             * sorbet/rbi/gems/foo@1.0.0.rbi:7:0-7:14
          ERR

          assert_includes(result.err, <<~ERR)
            Please remove the duplicated definitions from sorbet/rbi/shims and sorbet/rbi/todo.rbi
          ERR

          refute_success_status(result)
        end

        it "detects duplicates from Sorbet's payload" do
          @project.write("sorbet/rbi/shims/core/object.rbi", <<~RBI)
            class Object; end
          RBI

          @project.write("sorbet/rbi/shims/core/string.rbi", <<~RBI)
            class String
              sig { returns(String) }
              def capitalize(); end

              def some_method_that_is_not_defined_in_the_payload; end
            end
          RBI

          @project.write("sorbet/rbi/shims/stdlib/base64.rbi", <<~RBI)
            module Base64
              sig { params(str: String).returns(String) }
              def self.decode64(str); end

              def self.some_method_that_is_not_defined_in_the_payload; end
            end
          RBI

          result = @project.tapioca("check-shims")

          assert_includes(result.out, <<~OUT)
            Loading Sorbet payload...  Done
            Loading shim RBIs from sorbet/rbi/shims...  Done
            Looking for duplicates...  Done
          OUT

          assert_includes(result.err, <<~ERR)
            Duplicated RBI for ::Object:
             * https://github.com/sorbet/sorbet/tree/master/rbi/core/object.rbi#L27
             * sorbet/rbi/shims/core/object.rbi:1:0-1:17
          ERR

          assert_includes(result.err, <<~ERR)
            Duplicated RBI for ::String#capitalize:
             * https://github.com/sorbet/sorbet/tree/master/rbi/core/string.rbi#L406
             * sorbet/rbi/shims/core/string.rbi:3:2-3:23

            Duplicated RBI for ::Base64::decode64:
             * https://github.com/sorbet/sorbet/tree/master/rbi/stdlib/base64.rbi#L37
             * sorbet/rbi/shims/stdlib/base64.rbi:3:2-3:29
          ERR

          assert_includes(result.err, <<~ERR)
            Please remove the duplicated definitions from sorbet/rbi/shims and sorbet/rbi/todo.rbi
          ERR

          refute_success_status(result)
        end

        it "checks shims with custom rbi dirs" do
          @project.write("rbi/gem/foo@1.0.0.rbi", <<~RBI)
            class Foo
              def foo; end
            end
          RBI

          @project.write("rbi/dsl/foo.rbi", <<~RBI)
            class Foo
              def bar; end
            end
          RBI

          @project.write("rbi/shim/foo.rbi", <<~RBI)
            class Foo
              def foo; end
              def bar; end
            end

            module Baz
              def baz; end
            end
          RBI

          @project.write("rbi/todo.rbi", <<~RBI)
            module Baz
              def baz; end
            end
          RBI

          result = @project.tapioca(
            "check-shims --gem-rbi-dir=rbi/gem --dsl-rbi-dir=rbi/dsl --shim-rbi-dir=rbi/shim " \
              "--todo-rbi-file=rbi/todo.rbi --no-payload"
          )

          assert_includes(result.err, <<~ERR)
            Duplicated RBI for ::Foo#bar:
             * rbi/shim/foo.rbi:3:2-3:14
             * rbi/dsl/foo.rbi:2:2-2:14
          ERR

          assert_includes(result.err, <<~ERR)
            Duplicated RBI for ::Foo#foo:
             * rbi/shim/foo.rbi:2:2-2:14
             * rbi/gem/foo@1.0.0.rbi:2:2-2:14
          ERR

          assert_includes(result.err, <<~ERR)
            Duplicated RBI for ::Baz#baz:
             * rbi/todo.rbi:2:2-2:14
             * rbi/shim/foo.rbi:7:2-7:14
          ERR

          assert_includes(result.err, <<~ERR)
            Please remove the duplicated definitions from rbi/shim and rbi/todo.rbi
          ERR

          refute_success_status(result)
        end

        it "skips files with parse errors" do
          @project.write("sorbet/rbi/gems/foo@1.0.0.rbi", <<~RBI)
            class Foo
              attr_reader :foo
            end
          RBI

          @project.write("sorbet/rbi/shims/foo.rbi", <<~RBI)
            class Foo
              foo { bar }
            end
          RBI

          @project.write("sorbet/rbi/shims/bar.rbi", <<~RBI)
            module Foo
              def foo; end
            end
          RBI

          result = @project.tapioca("check-shims --no-payload")

          assert_includes(result.err, <<~ERR)
            Warning: Unsupported block node type `foo` (sorbet/rbi/shims/foo.rbi:2:2-2:13)
          ERR

          assert_includes(result.err, <<~ERR)
            Duplicated RBI for ::Foo#foo:
             * sorbet/rbi/shims/bar.rbi:2:2-2:14
             * sorbet/rbi/gems/foo@1.0.0.rbi:2:2-2:18
          ERR

          assert_includes(result.err, <<~ERR)
            Please remove the duplicated definitions from sorbet/rbi/shims and sorbet/rbi/todo.rbi
          ERR

          refute_success_status(result)
        end

        it "detects duplicated definitions between shim and annotations" do
          @project.write("sorbet/rbi/annotations/foo.rbi", <<~RBI)
            class Foo
              attr_reader :foo
            end
          RBI

          @project.write("sorbet/rbi/annotations/bar.rbi", <<~RBI)
            module Bar
              def bar; end
            end
          RBI

          @project.write("sorbet/rbi/annotations/baz.rbi", <<~RBI)
            module Baz; end
          RBI

          @project.write("sorbet/rbi/shims/foo.rbi", <<~RBI)
            class Foo
              attr_reader :foo
            end
          RBI

          @project.write("sorbet/rbi/shims/bar.rbi", <<~RBI)
            module Bar
              def bar; end
            end
          RBI

          @project.write("sorbet/rbi/shims/baz.rbi", <<~RBI)
            module Baz; end
          RBI

          result = @project.tapioca("check-shims --no-payload")

          assert_includes(result.err, <<~ERR)
            Duplicated RBI for ::Bar#bar:
             * sorbet/rbi/shims/bar.rbi:2:2-2:14
             * sorbet/rbi/annotations/bar.rbi:2:2-2:14
          ERR

          assert_includes(result.err, <<~ERR)
            Duplicated RBI for ::Foo#foo:
             * sorbet/rbi/shims/foo.rbi:2:2-2:18
             * sorbet/rbi/annotations/foo.rbi:2:2-2:18
          ERR

          assert_includes(result.err, <<~ERR)
            Duplicated RBI for ::Baz:
             * sorbet/rbi/shims/baz.rbi:1:0-1:15
             * sorbet/rbi/annotations/baz.rbi:1:0-1:15
          ERR

          assert_includes(result.err, <<~ERR)
            Please remove the duplicated definitions from sorbet/rbi/shims and sorbet/rbi/todo.rbi
          ERR

          refute_success_status(result)
        end

        it "detects duplicated definitions between the TODO file and generated RBIs" do
          @project.write("sorbet/rbi/gems/foo@1.0.0.rbi", <<~RBI)
            class Foo
              attr_reader :foo

              class Baz; end
            end
          RBI

          @project.write("sorbet/rbi/dsl/bar.rbi", <<~RBI)
            module Bar
              def bar; end
            end
          RBI

          @project.write("sorbet/rbi/todo.rbi", <<~RBI)
            class Foo
              attr_reader :foo

              class Baz; end
            end

            module Bar
              def bar; end
            end
          RBI

          result = @project.tapioca("check-shims --no-payload")

          assert_includes(result.err, <<~ERR)
            Duplicated RBI for ::Bar#bar:
             * sorbet/rbi/todo.rbi:8:2-8:14
             * sorbet/rbi/dsl/bar.rbi:2:2-2:14
          ERR

          assert_includes(result.err, <<~ERR)
            Duplicated RBI for ::Foo#foo:
             * sorbet/rbi/todo.rbi:2:2-2:18
             * sorbet/rbi/gems/foo@1.0.0.rbi:2:2-2:18
          ERR

          assert_includes(result.err, <<~ERR)
            Duplicated RBI for ::Foo::Baz:
             * sorbet/rbi/todo.rbi:4:2-4:16
             * sorbet/rbi/gems/foo@1.0.0.rbi:4:2-4:16
          ERR

          assert_includes(result.err, <<~ERR)
            Please remove the duplicated definitions from sorbet/rbi/shims and sorbet/rbi/todo.rbi
          ERR

          refute_success_status(result)
        end

        it "detects duplicated definitions between the TODO file and shims" do
          @project.write("sorbet/rbi/shims/foo.rbi", <<~RBI)
            class Foo
              attr_reader :foo
            end
          RBI

          @project.write("sorbet/rbi/shims/bar.rbi", <<~RBI)
            module Bar
              def bar; end
            end
          RBI

          @project.write("sorbet/rbi/shims/baz.rbi", <<~RBI)
            module Baz; end
          RBI

          @project.write("sorbet/rbi/todo.rbi", <<~RBI)
            class Foo
              attr_reader :foo
            end

            module Bar
              def bar; end
            end

            module Baz; end
          RBI

          result = @project.tapioca("check-shims --no-payload")

          assert_includes(result.err, <<~ERR)
            Duplicated RBI for ::Bar#bar:
             * sorbet/rbi/todo.rbi:6:2-6:14
             * sorbet/rbi/shims/bar.rbi:2:2-2:14
          ERR

          assert_includes(result.err, <<~ERR)
            Duplicated RBI for ::Foo#foo:
             * sorbet/rbi/todo.rbi:2:2-2:18
             * sorbet/rbi/shims/foo.rbi:2:2-2:18
          ERR

          assert_includes(result.err, <<~ERR)
            Duplicated RBI for ::Baz:
             * sorbet/rbi/todo.rbi:9:0-9:15
             * sorbet/rbi/shims/baz.rbi:1:0-1:15
          ERR

          assert_includes(result.err, <<~ERR)
            Please remove the duplicated definitions from sorbet/rbi/shims and sorbet/rbi/todo.rbi
          ERR

          refute_success_status(result)
        end
      end

      describe "when Sorbet version is too old" do
        before(:all) do
          @project = mock_project(sorbet_dependency: false)
          @project.require_real_gem("sorbet-static-and-runtime", "=0.5.9760")
          @project.bundle_install
        end

        it "does not check shims against payload for older Sorbet versions" do
          @project.write("sorbet/rbi/shims/core/string.rbi", <<~RBI)
            class String
              sig { returns(String) }
              def capitalize(); end

              def some_method_that_is_not_defined_in_the_payload; end
            end
          RBI

          result = @project.tapioca("check-shims")

          assert_includes(result.err, <<~ERR)
            The version of Sorbet used in your Gemfile.lock does not support `--print=payload-sources`
            Current: v0.5.9760
            Required: >= 0.5.9818
          ERR

          refute_success_status(result)
        end
      end
    end
  end
end
