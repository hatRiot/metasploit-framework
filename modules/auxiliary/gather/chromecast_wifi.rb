##
# This module requires Metasploit: http//metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

require 'msf/core'

class Metasploit4 < Msf::Auxiliary

  include Msf::Exploit::Remote::HttpClient

  def initialize(info = {})
    super(update_info(info,
      'Name' => 'Chromecast Wifi Enumeration',
      'Description' => %q{
        This module enumerates wireless access points through Chromecast.
      },
      'Author' => ['wvu'],
      'References' => [
        ['URL', 'https://en.wikipedia.org/wiki/Chromecast']
      ],
      'License' => MSF_LICENSE
    ))

    register_options([
      Opt::RPORT(8008)
    ], self.class)
  end

  def run
    res = scan

    if res && res.code == 200
      waps = Rex::Ui::Text::Table.new(
        'Header' => 'Wireless Access Points',
        'Columns' => [
          'BSSID',
          'PWR',
          'ENC',
          'CIPHER',
          'ESSID'
        ],
        'SortIndex' => -1
      )

      JSON.parse(res.body).each do |wap|
        waps << [
          wap['bssid'],
          wap['signal_level'],
          case wap['wpa_auth']
          when 1
            'OPN'
          when 5
            'WPA'
          when 7
            'WPA2'
          else
            wap['wpa_auth']
          end,
          case wap['wpa_cipher']
          when 1
            ''
          when 3
            'TKIP'
          when 4
            'CCMP'
          else
            wap['wpa_cipher']
          end,
          wap['ssid'] + (wap['wpa_id'] ? ' (*)' : '')
        ]
      end

      print_line(waps.to_s)

      report_note(
        :host => rhost,
        :port => rport,
        :proto => 'tcp',
        :type => 'chromecast.wifi',
        :data => waps.to_csv
      )
    end
  end

  def scan
    begin
      send_request_raw(
        'method' => 'POST',
        'uri' => '/setup/scan_wifi',
        'agent' => Rex::Text.rand_text_english(rand(42) + 1)
      )
      send_request_raw(
        'method' => 'GET',
        'uri' => '/setup/scan_results',
        'agent' => Rex::Text.rand_text_english(rand(42) + 1)
      )
    rescue Rex::ConnectionRefused, Rex::ConnectionTimeout,
           Rex::HostUnreachable => e
      fail_with(Failure::Unreachable, e)
    ensure
      disconnect
    end
  end

end
