module Firetail
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("../install/templates", __FILE__)

      desc "create firetail configuration template to config/firetail.yml and add middleware"
      def add_configuration_template
        template "firetail.yml", File.join("config", "firetail.yml")
        application "config.middleware.use Firetail::Run"
      end

      def show_readme
        readme "README" if behavior == :invoke
      end
    end
  end
end
