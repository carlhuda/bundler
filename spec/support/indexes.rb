module Spec
  module Indexes
    def dep(name, reqs = nil)
      @deps ||= []
      @deps << Bundler::Dependency.new(name, :version => reqs)
    end

    def platform(*args)
      @platforms ||= []
      @platforms.concat args.map { |p| Gem::Platform.new(p) }
    end

    alias platforms platform

    def make_deps
      @platforms ||= ['ruby']
      deps = []
      @deps.each do |d|
        @platforms.each do |p|
          deps << Bundler::DepProxy.new(d, p)
        end
      end
      deps
    end

    def resolve(resolver = nil)
      Bundler::Resolver.resolve(make_deps, @index)
    end

    def should_resolve_as(specs)
      got = resolve
      got = got.map { |s| s.full_name }.sort
      got.should == specs.sort
    end

    def should_conflict_on(names)
      begin
        got = resolve
        flunk "The resolve succeeded with: #{got.map { |s| s.full_name }.sort.inspect}"
      rescue Bundler::VersionConflict => e
        Array(names).sort.should == e.conflicts.sort
      end
    end

    def gem(*args, &blk)
      build_spec(*args, &blk).first
    end

    # Create an index that triggers a worst-case scenario in the
    # current (1.1.rc.7) resolver.
    #
    # The trick here is that there are many versions (+n+) of many
    # gems (+m+) on which 'root' declares a non-specific dependency.
    # It also declares a non-specific dependency on 'more' where
    # 'more' has both more available versions that the other
    # dependecies and declares specific dependencies on older
    # versions.
    #
    # Thus during resolution, newest versions are favored until 'more'
    # is activated, after which each intermediate dependency's
    # activated version is decremented recursively during the
    # backtracking.
    #
    # @param [Integer] m number of unique gems (plus one called 'root'
    # that depends on each, and one called 'more' that depends on
    # version 1.0.0 of each)
    #
    # @apram [Integer] n number of versions of each gem, except 'root'
    # which only has version 1.0 and 'more' which has n+1 versions
    def a_worst_case_index(m, n)
      build_index do
        gem 'root', '1.0' do
          m.times { |i| dep "gem#{i}", '>= 1.0' }
          dep 'more', '>= 1.0'
        end

        n.times do |patch|
          m.times { |i| gem "gem#{i}", "1.0.#{patch}" }
        end
        (n+1).times do |patch|
          gem 'more', "1.0.#{patch}" do
            m.times { |i| dep "gem#{i}", '= 1.0.0' }
          end
        end
      end
    end

    def an_awesome_index
      build_index do
        gem "rack", %w(0.8 0.9 0.9.1 0.9.2 1.0 1.1)
        gem "rack-mount", %w(0.4 0.5 0.5.1 0.5.2 0.6)

        # --- Rails
        versions "1.2.3 2.2.3 2.3.5 3.0.0.beta 3.0.0.beta1" do |version|
          gem "activesupport", version
          gem "actionpack", version do
            dep "activesupport", version
            if version >= v('3.0.0.beta')
              dep "rack", '~> 1.1'
              dep "rack-mount", ">= 0.5"
            elsif version > v('2.3')   then dep "rack", '~> 1.0.0'
            elsif version > v('2.0.0') then dep "rack", '~> 0.9.0'
            end
          end
          gem "activerecord", version do
            dep "activesupport", version
            dep "arel", ">= 0.2" if version >= v('3.0.0.beta')
          end
          gem "actionmailer", version do
            dep "activesupport", version
            dep "actionmailer",  version
          end
          if version < v('3.0.0.beta')
            gem "railties", version do
              dep "activerecord",  version
              dep "actionpack",    version
              dep "actionmailer",  version
              dep "activesupport", version
            end
          else
            gem "railties", version
            gem "rails", version do
              dep "activerecord",  version
              dep "actionpack",    version
              dep "actionmailer",  version
              dep "activesupport", version
              dep "railties",      version
            end
          end
        end

        versions '1.0 1.2 1.2.1 1.2.2 1.3 1.3.0.1 1.3.5 1.4.0 1.4.2 1.4.2.1' do |version|
          platforms "ruby java mswin32 mingw32" do |platform|
            next if version == v('1.4.2.1') && platform != pl('x86-mswin32')
            next if version == v('1.4.2') && platform == pl('x86-mswin32')
            gem "nokogiri", version, platform do
              dep "weakling", ">= 0.0.3" if platform =~ pl('java')
            end
          end
        end

        versions '0.0.1 0.0.2 0.0.3' do |version|
          gem "weakling", version
        end

        # --- Rails related
        versions '1.2.3 2.2.3 2.3.5' do |version|
          gem "activemerchant", version do
            dep "activesupport", ">= #{version}"
          end
        end
      end
    end
  end
end
