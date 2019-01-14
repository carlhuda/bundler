# frozen_string_literal: true

require "tempfile"

module Bundler
  class CLI::Check
    attr_reader :options

    def initialize(options)
      @options = options
    end

    def run
      Bundler.settings.set_command_option_if_given :path, options[:path]

      begin
        definition = Bundler.definition

        ui = Bundler.ui
        Bundler.ui = UI::Silent.new

        if options[:deployment]
          definition.resolve_remotely!
          final_lockfile = definition.to_lock
          current_lockfile = IO.readlines(Bundler.default_lockfile).join
          diff = Bundler::Diff.new(current_lockfile, final_lockfile)
        end

        Bundler.ui = ui

        definition.validate_runtime!
        not_installed = definition.missing_specs
      rescue GemNotFound, VersionConflict
        Bundler.ui.error "Bundler can't satisfy your Gemfile's dependencies."
        Bundler.ui.warn "Install missing gems with `bundle install`."
        exit 1
      end

      if not_installed.any?
        Bundler.ui.error "The following gems are missing"
        not_installed.each {|s| Bundler.ui.error " * #{s.name} (#{s.version})" }
        Bundler.ui.warn "Install missing gems with `bundle install`"
        exit 1
      elsif !Bundler.default_lockfile.file? && Bundler.frozen_bundle?
        Bundler.ui.error "This bundle has been frozen, but there is no #{Bundler.default_lockfile.relative_path_from(SharedHelpers.pwd)} present"
        exit 1
      else
        Bundler.load.lock(:preserve_unknown_sections => true) unless options[:"dry-run"] || options[:deployment]

        if options[:deployment]
          puts diff
        else
          Bundler.ui.info "The Gemfile's dependencies are satisfied"
        end
      end
    end
  end
end
