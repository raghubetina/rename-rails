require "test_helper"

module RailsStarterApp
  class Application
  end
end

class RenameIntoGeneratorTest < Minitest::Test
  def setup
    @workspace = Dir.mktmpdir("rename-rails-")
    @old_path = File.join(@workspace, "rails-starter-app")

    FileUtils.mkdir_p(File.join(@old_path, "config"))
    FileUtils.mkdir_p(File.join(@old_path, "app/views/layouts"))
    FileUtils.mkdir_p(File.join(@old_path, "app/views/pwa"))

    File.write(File.join(@old_path, "README.md"), "# Rails Starter App\n")
    File.write(File.join(@old_path, ".env.example"), "DATABASE_URL=postgresql://localhost/rails_starter_app_development\n")
    File.write(File.join(@old_path, "package.json"), <<~JSON)
      {
        "name": "rails-starter-app",
        "private": true
      }
    JSON
    File.write(File.join(@old_path, "yarn.lock"), <<~LOCK)
      "rails-starter-app@workspace:.":
        resolution: "rails-starter-app@workspace:."
    LOCK
    File.write(File.join(@old_path, "config/application.rb"), <<~RUBY)
      module RailsStarterApp
        class Application < Rails::Application
        end
      end
    RUBY
    File.write(File.join(@old_path, "config/database.yml"), <<~YAML)
      development:
        database: rails_starter_app_development

      test:
        database: rails_starter_app_test

      production:
        database: rails_starter_app_production
        username: rails_starter_app
        password: <%= ENV["RAILS_STARTER_APP_DATABASE_PASSWORD"] %>
    YAML
    File.write(File.join(@old_path, "app/views/layouts/application.html.erb"), <<~ERB)
      <!DOCTYPE html>
      <title>Rails Starter App</title>
      <meta name="application-name" content="Rails Starter App">
    ERB
    File.write(File.join(@old_path, "app/views/pwa/manifest.json.erb"), <<~ERB)
      {
        "name": "RailsStarterApp",
        "description": "RailsStarterApp app"
      }
    ERB
  end

  def teardown
    FileUtils.rm_rf(@workspace)
  end

  def test_renames_hidden_env_files_humanized_names_and_package_workspace_entries
    generator = Rename::Generators::IntoGenerator.new(["screen-slate"], {}, destination_root: @old_path)

    Dir.chdir(@old_path) do
      with_fake_rails_context(root: Pathname.new(@old_path), application: RailsStarterApp::Application.new) do
          generator.into
      end
    end

    new_path = File.join(@workspace, "screen-slate")

    assert Dir.exist?(new_path), "expected renamed app directory to exist"
    assert_includes File.read(File.join(new_path, "config/application.rb")), "module ScreenSlate"
    assert_includes File.read(File.join(new_path, ".env.example")), "screen_slate_development"
    assert_includes File.read(File.join(new_path, "README.md")), "# Screen Slate"
    assert_includes File.read(File.join(new_path, "app/views/layouts/application.html.erb")), "Screen Slate"
    assert_includes File.read(File.join(new_path, "package.json")), %("name":"screen-slate")
    assert_includes File.read(File.join(new_path, "yarn.lock")), "screen-slate@workspace:."
    assert_includes File.read(File.join(new_path, "config/database.yml")), 'ENV["SCREEN_SLATE_DATABASE_PASSWORD"]'
    refute_includes File.read(File.join(new_path, "config/database.yml")), 'screen_slate_DATABASE_PASSWORD'
  end

  private

  def with_fake_rails_context(root:, application:)
    rails_singleton = class << Rails
      self
    end

    original_root = Rails.method(:root)
    original_application = Rails.method(:application)

    rails_singleton.send(:define_method, :root) { root }
    rails_singleton.send(:define_method, :application) { application }

    yield
  ensure
    rails_singleton.send(:define_method, :root) { original_root.call }
    rails_singleton.send(:define_method, :application) { original_application.call }
  end
end
