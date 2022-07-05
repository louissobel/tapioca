# typed: true
# frozen_string_literal: true

module Tapioca
  class Cli < Thor
    include CliHelper
    include ConfigHelper
    include EnvHelper

    FILE_HEADER_OPTION_DESC = "Add a \"This file is generated\" header on top of each generated RBI file"

    class_option :config,
      aliases: ["-c"],
      banner: "<config file path>",
      type: :string,
      desc: "Path to the Tapioca configuration file",
      default: TAPIOCA_CONFIG_FILE
    class_option :verbose,
      aliases: ["-V"],
      type: :boolean,
      desc: "Verbose output for debugging purposes",
      default: false

    desc "init", "initializes folder structure"
    option :postrequire, type: :string, default: DEFAULT_POSTREQUIRE_FILE
    def init
      command = Commands::Init.new(
        sorbet_config: SORBET_CONFIG_FILE,
        tapioca_config: options[:config],
        default_postrequire: options[:postrequire]
      )
      command.execute
    end

    desc "require", "generate the list of files to be required by tapioca"
    option :postrequire, type: :string, default: DEFAULT_POSTREQUIRE_FILE
    def require
      command = Commands::Require.new(
        requires_path: options[:postrequire],
        sorbet_config_path: SORBET_CONFIG_FILE
      )
      Tapioca.silence_warnings do
        command.execute
      end
    end

    desc "todo", "generate the list of unresolved constants"
    option :todo_file,
      type: :string,
      desc: "Path to the generated todo RBI file",
      default: DEFAULT_TODO_FILE
    option :file_header,
      type: :boolean,
      desc: FILE_HEADER_OPTION_DESC,
      default: true
    def todo
      command = Commands::Todo.new(
        todo_file: options[:todo_file],
        file_header: options[:file_header]
      )
      Tapioca.silence_warnings do
        command.execute
      end
    end

    desc "dsl [constant...]", "generate RBIs for dynamic methods"
    option :outdir,
      aliases: ["--out", "-o"],
      banner: "directory",
      desc: "The output directory for generated DSL RBI files",
      default: DEFAULT_DSL_DIR
    option :file_header,
      type: :boolean,
      desc: FILE_HEADER_OPTION_DESC,
      default: true
    option :only,
      type: :array,
      banner: "compiler [compiler ...]",
      desc: "Only run supplied DSL compiler(s)",
      default: []
    option :exclude,
      type: :array,
      banner: "compiler [compiler ...]",
      desc: "Exclude supplied DSL compiler(s)",
      default: []
    option :verify,
      type: :boolean,
      default: false,
      desc: "Verifies RBIs are up-to-date"
    option :quiet,
      aliases: ["-q"],
      type: :boolean,
      desc: "Suppresses file creation output",
      default: false
    option :workers,
      aliases: ["-w"],
      type: :numeric,
      desc: "EXPERIMENTAL: Number of parallel workers to use when generating RBIs",
      default: 1
    option :rbi_max_line_length,
      type: :numeric,
      desc: "Set the max line length of generated RBIs. Signatures longer than the max line length will be wrapped",
      default: 120
    option :environment,
      aliases: ["-e"],
      type: :string,
      desc: "The Rack/Rails environment to use when generating RBIs",
      default: "development"
    def dsl(*constants)
      set_environment

      command = Commands::Dsl.new(
        requested_constants: constants,
        outpath: Pathname.new(options[:outdir]),
        only: options[:only],
        exclude: options[:exclude],
        file_header: options[:file_header],
        compiler_path: Tapioca::Dsl::Compilers::DIRECTORY,
        tapioca_path: TAPIOCA_DIR,
        should_verify: options[:verify],
        quiet: options[:quiet],
        verbose: options[:verbose],
        number_of_workers: options[:workers],
        rbi_formatter: rbi_formatter(options)
      )

      if options[:workers] != 1
        say(
          "Using more than one worker is experimental and might produce results that are not deterministic",
          :red
        )
      end

      Tapioca.silence_warnings do
        command.execute
      end
    end

    desc "gem [gem...]", "generate RBIs from gems"
    option :outdir,
      aliases: ["--out", "-o"],
      banner: "directory",
      desc: "The output directory for generated gem RBI files",
      default: DEFAULT_GEM_DIR
    option :file_header,
      type: :boolean,
      desc: FILE_HEADER_OPTION_DESC,
      default: true
    option :all,
      type: :boolean,
      desc: "Regenerate RBI files for all gems",
      default: false
    option :prerequire,
      aliases: ["--pre", "-b"],
      banner: "file",
      desc: "A file to be required before Bundler.require is called",
      default: nil
    option :postrequire,
      aliases: ["--post", "-a"],
      banner: "file",
      desc: "A file to be required after Bundler.require is called",
      default: DEFAULT_POSTREQUIRE_FILE
    option :exclude,
      aliases: ["-x"],
      type: :array,
      banner: "gem [gem ...]",
      desc: "Exclude the given gem(s) from RBI generation",
      default: []
    option :typed_overrides,
      aliases: ["--typed", "-t"],
      type: :hash,
      banner: "gem:level [gem:level ...]",
      desc: "Override for typed sigils for generated gem RBIs",
      default: DEFAULT_OVERRIDES
    option :verify,
      type: :boolean,
      desc: "Verify RBIs are up-to-date",
      default: false
    option :doc,
      type: :boolean,
      desc: "Include YARD documentation from sources when generating RBIs. Warning: this might be slow",
      default: true
    option :exported_gem_rbis,
      type: :boolean,
      desc: "Include RBIs found in the `rbi/` directory of the gem",
      default: true
    option :workers,
      aliases: ["-w"],
      type: :numeric,
      desc: "EXPERIMENTAL: Number of parallel workers to use when generating RBIs",
      default: 1
    option :auto_strictness,
      type: :boolean,
      desc: "Autocorrect strictness in gem RBIs in case of conflict with the DSL RBIs",
      default: true
    option :dsl_dir,
      aliases: ["--dsl-dir"],
      banner: "directory",
      desc: "The DSL directory used to correct gems strictnesses",
      default: DEFAULT_DSL_DIR
    option :rbi_max_line_length,
      type: :numeric,
      desc: "Set the max line length of generated RBIs. Signatures longer than the max line length will be wrapped",
      default: 120
    option :environment,
      aliases: ["-e"],
      type: :string,
      desc: "The Rack/Rails environment to use when generating RBIs",
      default: "development"
    def gem(*gems)
      Tapioca.silence_warnings do
        set_environment

        all = options[:all]
        verify = options[:verify]

        command = Commands::Gem.new(
          gem_names: all ? [] : gems,
          exclude: options[:exclude],
          prerequire: options[:prerequire],
          postrequire: options[:postrequire],
          typed_overrides: options[:typed_overrides],
          outpath: Pathname.new(options[:outdir]),
          file_header: options[:file_header],
          include_doc: options[:doc],
          include_exported_rbis: options[:exported_gem_rbis],
          number_of_workers: options[:workers],
          auto_strictness: options[:auto_strictness],
          dsl_dir: options[:dsl_dir],
          rbi_formatter: rbi_formatter(options)
        )

        unless gems.empty?
          raise MalformattedArgumentError, "Option '--all' must be provided without any other arguments" if all
          raise MalformattedArgumentError, "Option '--verify' must be provided without any other arguments" if verify
        end

        if options[:workers] != 1
          say(
            "Using more than one worker is experimental and might produce results that are not deterministic",
            :red
          )
        end

        if gems.empty? && !all
          command.sync(should_verify: verify)
        else
          command.execute(should_verify: verify)
        end
      end
    end
    map "gems" => :gem

    desc "check-shims", "check duplicated definitions in shim RBIs"
    option :gem_rbi_dir, type: :string, desc: "Path to gem RBIs", default: DEFAULT_GEM_DIR
    option :dsl_rbi_dir, type: :string, desc: "Path to DSL RBIs", default: DEFAULT_DSL_DIR
    option :shim_rbi_dir, type: :string, desc: "Path to shim RBIs", default: DEFAULT_SHIM_DIR
    option :annotations_rbi_dir, type: :string, desc: "Path to annotations RBIs", default: DEFAULT_ANNOTATIONS_DIR
    option :todo_rbi_file, type: :string, desc: "Path to the generated todo RBI file", default: DEFAULT_TODO_FILE
    option :payload, type: :boolean, desc: "Check shims against Sorbet's payload", default: true
    def check_shims
      command = Commands::CheckShims.new(
        gem_rbi_dir: options[:gem_rbi_dir],
        dsl_rbi_dir: options[:dsl_rbi_dir],
        shim_rbi_dir: options[:shim_rbi_dir],
        annotations_rbi_dir: options[:annotations_rbi_dir],
        todo_rbi_file: options[:todo_rbi_file],
        payload: options[:payload]
      )
      command.execute
    end

    desc "annotations", "Pull gem RBI annotations from remote sources"
    option :sources, type: :array, default: [CENTRAL_REPO_ROOT_URI],
      desc: "URIs of the sources to pull gem RBI annotations from"
    option :netrc, type: :boolean, default: true, desc: "Use .netrc to authenticate to private sources"
    option :netrc_file, type: :string, desc: "Path to .netrc file"
    option :auth, type: :string, default: nil, desc: "HTTP authorization header for private sources"
    option :typed_overrides,
      aliases: ["--typed", "-t"],
      type: :hash,
      banner: "gem:level [gem:level ...]",
      desc: "Override for typed sigils for pulled annotations",
      default: {}
    def annotations
      if !options[:netrc] && options[:netrc_file]
        say_error("Options `--no-netrc` and `--netrc-file` can't be used together", :bold, :red)
        exit(1)
      end

      command = Commands::Annotations.new(
        central_repo_root_uris: options[:sources],
        auth: options[:auth],
        netrc_file: netrc_file(options),
        typed_overrides: options[:typed_overrides]
      )
      command.execute
    end

    map ["--version", "-v"] => :__print_version

    desc "--version, -v", "show version"
    def __print_version
      puts "Tapioca v#{Tapioca::VERSION}"
    end

    no_commands do
      def self.exit_on_failure?
        true
      end
    end
  end
end
