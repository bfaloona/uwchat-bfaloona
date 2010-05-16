
require 'uwchat'

class QuitCommand < UWChat::ServerCommand

#  puts 'this is the QuitCommand class block'

  command :quit

  description "Disconnect from chat"

  when_run do | server, client |
    client.sock.puts "Server: Later."
    client.sock.close
    server.log( "#{client.username} on #{client.port} quit.")
    server.remove_client( client.port )
  end

end
