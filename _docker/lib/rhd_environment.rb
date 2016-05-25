require 'erb'
require 'fileutils'

#
# Models an environment supported by the developers.redhat.com start-up scripts.
#
# This implementation expects an environment to contain a docker-compose.yml file in the root of the directory
#
# @author rblake@redhat.com
#
class RhdEnvironment

  attr_accessor :environment_name, :environment_directory

  def initialize(environment_directory, testing_directory, drupal_directory)
    @environment_directory = environment_directory
    @testing_directory = testing_directory
    @environment_name = environment_directory.split('/').last
    @drupal_directory = drupal_directory
  end

  #
  # Get the path to the docker-compose.yml file for this environment
  #
  def get_docker_compose_file
    "#{@environment_directory}/docker-compose.yml"
  end

  def get_testing_docker_compose_file
    "#{@testing_directory}/docker-compose.yml"
  end

  #
  # Is this an environment in which we run Drupal?
  #
  def is_drupal_environment?
    @environment_name.include?('drupal')
  end

  #
  # Performs cursory checks to determine if this looks like a valid environment directory
  #
  def is_valid_environment?
    has_docker_compose = File.exist?(get_docker_compose_file)

    if !has_docker_compose
      puts "Environment '#{environment_name}' defined in directory '#{@environment_directory}' is not valid as it does not contain a docker-compose.yml"
    end

    has_docker_compose
  end

  def create_file(file_name)
    absolute_file_path = get_absolute_file_name(file_name)

    FileUtils.rm(absolute_file_path, :force => true)
    FileUtils.touch(absolute_file_path)
    get_file(file_name)
  end

  def get_absolute_file_name(file_name)
    File.join @environment_directory, file_name
  end

  def get_file(file_name)
    file = File.new(get_absolute_file_name(file_name))
    File.exist?(file) ? file : nil
  end

  #
  # Templates any resources required by the environment. In reality the only environment
  # that needs this is the Drupal pull-request environment
  #
  def template_resources
    # TODO verify permissions
    File.chmod(0775, @drupal_directory)
    output_file = File.join(@drupal_directory, 'rhd.settings.yml')
    File.write(output_file, ERB.new(File.read(get_file('rhd.settings.yml.erb'))).result)

    output_file = File.join(@drupal_directory, 'rhd.settings.php')
    File.write(output_file, File.read(get_file('rhd.settings.php')))
  end

  #
  # Returns the likely docker-compose project name for this environment. If the environment
  # variable ENV['COMPOSE_PROJECT_NAME'] is set, then this is used in preference.
  #
  def get_compose_project_name
    if ENV['COMPOSE_PROJECT_NAME'].to_s == ''
      @environment_name.gsub('-','')
    else
      ENV['COMPOSE_PROJECT_NAME']
    end
  end

  #
  # Provides the list of supporting services that should be started in each environment before
  # running Awestruct
  #
  def get_supporting_services

    supporting_services = []

    case @environment_name
      when 'awestruct-dev', 'awestruct-pull-request'
         supporting_services += %w(mysql searchisko)
      when 'drupal-dev', 'drupal-pull-request'
         supporting_services+= %w(mysql searchisko drupalmysql drupal)
      when 'drupal-staging', 'drupal-production'
        supporting_services += %w(drupal)
    end
    supporting_services

  end

  private :get_absolute_file_name

end
