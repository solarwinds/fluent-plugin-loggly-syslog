require 'test_helper'

class Fluent::LogglyTest < Test::Unit::TestCase

  class TestSocket
    attr_reader :packets

    def initialize
      @packets = []
    end

    def puts(message)
      @packets << message
    end
  end

  def setup
    Fluent::Test.setup
    @driver = Fluent::Test::BufferedOutputTestDriver.new(Fluent::LogglySyslog, 'test')
    @mock_token = 'c56a4180-65aa-42ec-a945-5fd21dec0538'
    @driver.configure("
      loggly_token #{@mock_token}
      ")
    #@driver.instance.socket = TestSocket.new
    @default_record = {
      'hostname' => 'some_hostname',
      'facility' => 'local0',
      'severity' => 'warn',
      'program' => 'some_program',
      'message' => 'some_message'
    }
  end

  def test_configure_empty_configuration
    begin
      @driver.configure('')
    rescue => e
      assert e.is_a? Fluent::ConfigError
    end
  end

  def test_configure_uses_loggly_config
    assert @driver.instance.loggly_token.eql? @mock_token
  end

  def test_pick_token
    namespace_token = 'namespace_token'
    namespace_annotation_record = {
      'hostname' => 'some_hostname',
      'facility' => 'local0',
      'severity' => 'warn',
      'program' => 'some_program',
      'message' => 'some_message',
      'kubernetes' => {
        'namespace_annotations' => {
          'solarwinds_io/loggly_token' => namespace_token,
        }
      }
    }
    token = @driver.instance.pick_token(namespace_annotation_record)
    assert token.eql? namespace_token

    pod_token = 'pod_token'
    pod_annotation_record = {
      'hostname' => 'some_hostname',
      'facility' => 'local0',
      'severity' => 'warn',
      'program' => 'some_program',
      'message' => 'some_message',
      'kubernetes' => {
        'annotations' => {
          'solarwinds_io/loggly_token' => pod_token,
        }
      }
    }
    token = @driver.instance.pick_token(pod_annotation_record)
    assert token.eql? pod_token
  end
end
