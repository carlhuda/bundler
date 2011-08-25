$:.unshift File.expand_path('../vendor', __FILE__)
require 'thor'
require 'bundler'

module Bundler
  class GemHelper

    def self.version_tasks(opts = {})
      dir = opts[:dir] || Dir.pwd
      self.new(dir, opts[:name]).version_tasks
    end

    VERSION_ASSIGNMENT_REGEXP = /\A\s*?VERSION\s*?=\s*?['"](.*?)['"]/mx

    def version_tasks
      desc "Handle gem version"
      namespace 'version' do
        desc "Bump major version number"
        task "bump:major" do
          bump :major
        end
        desc "Bump minor version number"
        task "bump:minor" do
          bump :minor
        end
        desc "Bump patch version number"
        task "bump:patch" do
          bump :patch
        end
        desc "write out a specified version (rake version:write[\"x.y.z\"])"
        task "write", :version do |task, args|
          change_version_to(args.version)
        end
      end
    end

    def bump bit_to_increment
      method = "bump_#{bit_to_increment.to_s}".to_sym
      change_version_to send(method)
    end

    def bump_major
      hash = {}
      hash[:major], hash[:minor], hash[:patch] = version.to_s.split('.')
      hash[:major] = hash[:major].to_i + 1
      "#{hash[:major]}.0.0"
    end

    def bump_minor
      hash = {}
      hash[:major], hash[:minor], hash[:patch] = version.to_s.split('.')
      hash[:minor] = hash[:minor].to_i + 1
      "#{hash[:major]}.#{hash[:minor]}.0"
    end

    def bump_patch
      hash = {}
      hash[:major], hash[:minor], hash[:patch] = version.to_s.split('.')
      hash[:patch] = hash[:patch].to_i + 1
      "#{hash[:major]}.#{hash[:minor]}.#{hash[:patch]}"
    end

    def change_version_to(new_version)
      new_file = new_version_file(new_version)
      File.open(version_file, 'w') { |f| f << new_file }
      Bundler.ui.confirm "New version is now #{new_version}"
    end

    protected

    def new_version_file new_version
      version_gsub = '\1' + new_version + '\1'
      lines_of_version_file.map do |line|
        is_line_with_version_assignment?(line) ? line.gsub(/(["']).*?["']/, version_gsub) : line
      end.join
    end

    def lines_of_version_file
      File.readlines(version_file)
    end

    def version_file
      return @version_file if defined? @version_file
      file_array = Dir[File.join(base, 'lib', name, 'version.rb')]
      raise_no_file_found if file_array.empty?
      @version_file = file_array.first
    end

    def is_line_with_version_assignment? line
      !!(line[VERSION_ASSIGNMENT_REGEXP])
    end

    def raise_no_file_found
      raise ArgumentError, "No file named 'version.rb' was found. Please use bundler to initialize the gem version."
    end

  end
end
