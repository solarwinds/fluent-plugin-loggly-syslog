# Fluent::Plugin::LogglySyslog

[![Gem Version](https://badge.fury.io/rb/fluent-plugin-loggly-syslog.svg)](https://badge.fury.io/rb/fluent-plugin-loggly-syslog) [![CircleCI](https://circleci.com/gh/solarwinds/fluent-plugin-loggly-syslog/tree/master.svg?style=shield)](https://circleci.com/gh/solarwinds/fluent-plugin-loggly-syslog/tree/master)

## Description

This repository contains the Fluentd Loggly Syslog Output Plugin.

## Installation

Install this gem when setting up fluentd:
```ruby
gem install fluent-plugin-loggly-syslog
```

## Usage

### Setup

This is a buffered output plugin for Fluentd that's configured to send logs to Loggly using the [syslog endpoint](https://www.loggly.com/docs/streaming-syslog-without-using-files/).

Each log line will arrive in Loggly with 2 payloads: the json representation of the fluent record and the data from the syslog wrapper.

Data from the syslog wrapper includes:
```
appName - this defaults to the fluent tag
hostname - this can be optionally configured as loggly_hostname (see below)
timestamp - this defaults to the timestamp associated with the record and falls back to the current time at the time it reaches the plugin
```

You're also able to (optionally) tag loggly records with any string you want, see `loggly_tag` below. 

To configure this in fluentd:
```xml
<match whatever.*>
  @type loggly_syslog
  loggly_token <your_loggly_token>
  loggly_tag <your_loggly_tag>
  loggly_hostname "#{ENV['HOST']}"
</match>
```


### Advanced Configuration
This plugin inherits a few useful config parameters from Fluent's `BufferedOutput` class.

Parameters for flushing the buffer, based on size and time, are `buffer_chunk_limit` and `flush_interval`, respectively. This plugin overrides the inherited default `flush_interval` to `1`, causing the fluent buffer to flush to Loggly every second. 

If the plugin fails to write to Loggly for any reason, the log message will be put back in Fluent's buffer and retried. Retrying can be tuned and inherits a default configuration where `retry_wait` is set to `1` second and `retry_limit` is set to `17` attempts.

If you want to change any of these parameters simply add them to the match stanza. For example, to flush the buffer every 60 seconds and stop retrying after 2 attempts, set something like:
```xml
<match whatever.*>
  @type loggly_syslog
  loggly_token <your_loggly_token>
  flush_interval 60
  retry_limit 2
</match>
```

BufferedOutput also allows you to keep the buffer stored on disk, where it can persist through process restarts. This is great for avoiding dropping logs during outages, see:

```xml
<match whatever.*>
  @type loggly_syslog
  loggly_token <your_loggly_token>
  buffer_type file
  buffer_path /var/log/fluentd-buffer
</match>
```

### Annotations

If you're running on Kubernetes you can use annotations to redirect logs to alternate Loggly accounts.

Simply enable the fluent-plugin-kubernetes_metadata_filter gem in your Fluentd setup and configure it to match annotations:

```
<filter kubernetes.**>
  type kubernetes_metadata
  annotation_match ["solarwinds.io/*"]
</filter>
```

Then add the following annotation to each namespace or pod that you'd like to redirect logs for:

```
solarwinds.io/loggly_token: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
```

If both a pod and the namespace it's in have this annotation, the pod's annotation takes precedence.

## Development

This plugin is targeting Ruby 2.4 and Fluentd v1.0, although it should work with older versions of both.

We have a [Makefile](Makefile) to wrap common functions and make life easier.

### Install Dependencies
`make bundle`

### Test
`make test`

### Release in [RubyGems](https://rubygems.org/gems/fluent-plugin-loggly-syslog)
To release a new version, update the version number in the [GemSpec](fluent-plugin-loggly-syslog.gemspec) and then, run:

`make release`

## Contributing

Bug reports and pull requests are welcome on GitHub at: https://github.com/solarwinds/fluent-plugin-loggly-syslog

## License

The gem is available as open source under the terms of the [Apache License](LICENSE).

# Questions/Comments?

Please [open an issue](https://github.com/solarwinds/fluent-plugin-loggly-syslog/issues/new), we'd love to hear from you. As a SolarWinds Innovation Project, this adapter is supported in a best-effort fashion.
