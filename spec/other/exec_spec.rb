require "spec_helper"

describe "bundle exec" do
  before :each do
    system_gems "rack-1.0.0", "rack-0.9.1"
  end

  it "activates the correct gem" do
    gemfile <<-G
      gem "rack", "0.9.1"
    G

    bundle "exec rackup"
    expect(out).to eq("0.9.1")
  end

  it "works when the bins are in ~/.bundle" do
    install_gemfile <<-G
      gem "rack"
    G

    bundle "exec rackup"
    expect(out).to eq("1.0.0")
  end

  it "works when running from a random directory" do
    install_gemfile <<-G
      gem "rack"
    G

    bundle "exec 'cd #{tmp('gems')} && rackup'"

    expect(out).to eq("1.0.0")
  end

  it "works when exec'ing something else" do
    install_gemfile 'gem "rack"'
    bundle "exec echo exec"
    expect(out).to eq("exec")
  end

  it "accepts --verbose" do
    install_gemfile 'gem "rack"'
    bundle "exec --verbose echo foobar"
    expect(out).to eq("foobar")
  end

  it "passes --verbose to command if it is given after the command" do
    install_gemfile 'gem "rack"'
    bundle "exec echo --verbose"
    expect(out).to eq("--verbose")
  end

  it "can run a command named --verbose" do
    install_gemfile 'gem "rack"'
    File.open("--verbose", 'w') do |f|
      f.puts "#!/bin/sh"
      f.puts "echo foobar"
    end
    File.chmod(0744, "--verbose")
    ENV['PATH'] = "."
    bundle "exec -- --verbose"
    expect(out).to eq("foobar")
  end

  it "handles different versions in different bundles" do
    build_repo2 do
      build_gem "rack_two", "1.0.0" do |s|
        s.executables = "rackup"
      end
    end

    install_gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack", "0.9.1"
    G

    Dir.chdir bundled_app2 do
      install_gemfile bundled_app2('Gemfile'), <<-G
        source "file://#{gem_repo2}"
        gem "rack_two", "1.0.0"
      G
    end

    bundle "exec rackup"

    expect(out).to eq("0.9.1")
    expect(err).to match("deprecated")

    Dir.chdir bundled_app2 do
      bundle "exec rackup"
      expect(out).to eq("1.0.0")
    end
  end

  it "handles gems installed with --without" do
    install_gemfile <<-G, :without => :middleware
      source "file://#{gem_repo1}"
      gem "rack" # rack 0.9.1 and 1.0 exist

      group :middleware do
        gem "rack_middleware" # rack_middleware depends on rack 0.9.1
      end
    G

    bundle "exec rackup"

    expect(out).to eq("0.9.1")
    should_not_be_installed "rack_middleware 1.0"
  end

  it "should not duplicate already exec'ed RUBYOPT or PATH" do
    install_gemfile <<-G
      gem "rack"
    G

    rubyopt = ENV['RUBYOPT']
    rubyopt = "-I#{bundler_path} -rbundler/setup #{rubyopt}"

    bundle "exec 'echo $RUBYOPT'"
    expect(out).to have_rubyopts(rubyopt)

    bundle "exec 'echo $RUBYOPT'", :env => {"RUBYOPT" => rubyopt}
    expect(out).to have_rubyopts(rubyopt)
  end

  it "errors nicely when the argument doesn't exist" do
    install_gemfile <<-G
      gem "rack"
    G

    bundle "exec foobarbaz", :exitstatus => true
    expect(exitstatus).to eq(127)
    expect(out).to include("bundler: command not found: foobarbaz")
    expect(out).to include("Install missing gem executables with `bundle install`")
  end

  it "errors nicely when the argument is not executable" do
    install_gemfile <<-G
      gem "rack"
    G

    bundle "exec touch foo"
    bundle "exec ./foo", :exitstatus => true
    expect(exitstatus).to eq(126)
    expect(out).to include("bundler: not executable: ./foo")
  end

  it "errors nicely when no arguments are passed" do
    install_gemfile <<-G
      gem "rack"
    G

    bundle "exec", :exitstatus => true
    expect(exitstatus).to eq(128)
    expect(out).to include("bundler: exec needs a command to run")
  end

  describe "with gem executables" do
    describe "run from a random directory" do
      before(:each) do
        install_gemfile <<-G
          gem "rack"
        G
      end

      it "works when unlocked" do
        bundle "exec 'cd #{tmp('gems')} && rackup'"
        expect(out).to eq("1.0.0")
      end

      it "works when locked" do
        should_be_locked
        bundle "exec 'cd #{tmp('gems')} && rackup'"
        expect(out).to eq("1.0.0")
      end
    end

    describe "from gems bundled via :path" do
      before(:each) do
        build_lib "fizz", :path => home("fizz") do |s|
          s.executables = "fizz"
        end

        install_gemfile <<-G
          gem "fizz", :path => "#{File.expand_path(home("fizz"))}"
        G
      end

      it "works when unlocked" do
        bundle "exec fizz"
        expect(out).to eq("1.0")
      end

      it "works when locked" do
        should_be_locked

        bundle "exec fizz"
        expect(out).to eq("1.0")
      end
    end

    describe "from gems bundled via :git" do
      before(:each) do
        build_git "fizz_git" do |s|
          s.executables = "fizz_git"
        end

        install_gemfile <<-G
          gem "fizz_git", :git => "#{lib_path('fizz_git-1.0')}"
        G
      end

      it "works when unlocked" do
        bundle "exec fizz_git"
        expect(out).to eq("1.0")
      end

      it "works when locked" do
        should_be_locked
        bundle "exec fizz_git"
        expect(out).to eq("1.0")
      end
    end

    describe "from gems bundled via :git with no gemspec" do
      before(:each) do
        build_git "fizz_no_gemspec", :gemspec => false do |s|
          s.executables = "fizz_no_gemspec"
        end

        install_gemfile <<-G
          gem "fizz_no_gemspec", "1.0", :git => "#{lib_path('fizz_no_gemspec-1.0')}"
        G
      end

      it "works when unlocked" do
        bundle "exec fizz_no_gemspec"
        expect(out).to eq("1.0")
      end

      it "works when locked" do
        should_be_locked
        bundle "exec fizz_no_gemspec"
        expect(out).to eq("1.0")
      end
    end
  end
end
