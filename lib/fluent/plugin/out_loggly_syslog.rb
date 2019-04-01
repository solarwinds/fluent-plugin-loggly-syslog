require 'yajl'

module Fluent
  class LogglySyslog < Fluent::BufferedOutput
    class SocketFailureError < StandardError; end
    attr_accessor :sockets

    #config_param :output_include_time, :bool, default: true # Recommended
    #config_param :time_precision_digits, :integer, default: 0

    # if loggly_token left empty in fluent config, it will throw Fluent::ConfigError
    config_param :loggly_token, :string
    config_param :loggly_tag, :string, default: nil
    config_param :loggly_hostname, :string, default: nil
    config_param :loggly_host, :string, default: 'logs-01.loggly.com'
    config_param :loggly_port, :integer, default: 6514
    config_param :discard_unannotated_pod_logs, :bool, default: false
    config_param :parse_json, :bool, default: false
    # overriding default flush_interval (60 sec) from Fluent::BufferedOutput
    config_param :flush_interval, :time, default: 1

    # register as 'loggly_syslog' fluent plugin
    Fluent::Plugin.register_output('loggly_syslog', self)

    # declare const string for nullifying token if we decide to discard records
    DISCARD_STRING = 'DISCARD'

    def configure(conf)
      super
      # parses fluent config
    end

    def start
      super
      # create initial socket based on config param
      @socket = create_socket(@loggly_host, @loggly_port)
    end

    def shutdown
      super
      @socket.close
    end

    def format(tag, time, record)
      [tag, time, record].to_msgpack
    end

    def write(chunk)
      chunk.msgpack_each { |(tag, time, record)|
        token = pick_token(record)
        unless token.eql? DISCARD_STRING
          packet = create_packet(tag, time, record, token)
          send_to_loggly(packet)
        end
      }
    end

    def create_socket(host, port)
      log.info "initializing tcp socket for #{host}:#{port}"
      begin
        socket = TCPSocket.new(host, port)
        log.debug "enabling ssl for socket #{host}:#{port}"
        ssl = OpenSSL::SSL::SSLSocket.new(socket)
        # close tcp and ssl socket when either fails
        ssl.sync_close = true
        # initiate SSL/TLS handshake with server
        ssl.connect
      rescue => e
        log.warn "failed to create tcp socket #{host}:#{port}: #{e}"
        ssl = nil
      end
      ssl
    end

    def pick_token(record)
      # if kubernetes pod has loggly url as annotation, use it
      if record.dig('kubernetes', 'annotations', 'solarwinds_io/loggly_token')
        token = record['kubernetes']['annotations']['solarwinds_io/loggly_token']
        # else if kubernetes namespace has papertrail destination as annotation, use it
      elsif record.dig('kubernetes', 'namespace_annotations', 'solarwinds_io/loggly_token')
        token = record['kubernetes']['namespace_annotations']['solarwinds_io/loggly_token']
        # else if it is a kubernetes log and we're discarding unannotated logs
      elsif record.dig('kubernetes') && @discard_unannotated_pod_logs
        token = DISCARD_STRING
        # else use pre-configured destination
      else
        token = @loggly_token
      end
      token
    end

    def create_packet(tag, time, record, token)
      # construct Syslog RFC 5424 compliant packet from fluent record, see:
      #   https://tools.ietf.org/html/rfc5424
      # example:
      #   '<134>1 2018-05-10T21:11:58-05:00 mysite.com myapp procid msgid \
      #     [xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx@41058 tag="syslog"] \
      #     message'

      if @parse_json && record.dig('message')
        begin
          parser = Yajl::Parser.new
          parsed_message = parser.parse(record['message'])
          record['log'] = parsed_message
          record.delete('message')
        rescue Yajl::ParseError
        end
      end

      pri             = 134                                          # 134 is hardcoded facility local0 and severity info
      version         = 1                                            # Syslog Protocol v1
      record_time     = time ? Time.at(time) : Time.now
      timestamp       = record_time.to_datetime.rfc3339
      hostname        = @loggly_hostname || '-'
      app_name        = tag || '-'
      procid          = '-'                                          # set procid and msgid to NILVALUE
      msgid           = '-'
      pen             = 41058                                        # Loggly's Private Enterprise Number is 41058
      tag             = @loggly_tag ? " tag=\"#{@loggly_tag}\"" : '' # write tag only if passed in through config
      structured_data = "[#{token}@#{pen}#{tag}]"
      msg             = Yajl.dump(record)

      "<#{pri}>#{version} #{timestamp} #{hostname} #{app_name} #{procid} #{msgid} #{structured_data} #{msg}\n"
    end

    def send_to_loggly(packet)
      # recreate the socket if it's nil
      @socket ||= create_socket(@loggly_host, @loggly_port)
      if @socket.nil?
        err_msg = "Unable to create socket with #{@loggly_host}:#{@loggly_port}"
        raise SocketFailureError, err_msg
      else
        begin
          # send it
          @socket.write packet
        rescue => e
          # socket failed, reset to nil to recreate for the next write
          @socket = nil
          err_msg = "Closing socket. #{e.class} writing to '#{@loggly_host}:#{@loggly_port}': #{e}"
          raise SocketFailureError, err_msg, e.backtrace
        end
      end
    end
  end
end