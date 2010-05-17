
require 'uwchat'

class QuitCommand < UWChat::ServerCommand

  command :quit

  description "Disconnect from chat"

  when_run do | server, client |
    client.sock.puts "Server: Later dude."
    server.do_log( "[command quit] #{client.username} on #{client.port} quit.")
    client.sock.close
  end

end

class UsersCommand < UWChat::ServerCommand

  command :users

  description "List active users"

  when_run do | server, client |
    server.clients.map{|c|c.username}.each do |user|
      client.sock.puts user
    end
    server.do_log( "[command users] Listed users for #{client.username}.")
  end

end

class HelpCommand < UWChat::ServerCommand

  command :help

  description "List available commands"

  when_run do | server, client |
    client.sock.puts
    client.sock.puts "Available Commands"
    client.sock.puts "  prepend command name with slash to run, e.g. /users"
    client.sock.puts "  anything typed without a command will be sent to all other users."
    client.sock.puts
    server.commands.each do |command|
      client.sock.puts command[0].to_s
      client.sock.puts " - #{command[1][:desc]}"
      client.sock.puts " - Parameters: #{command[1][:block].arity - 2}"
      client.sock.puts
    end
    server.do_log( "[command help] Listed available commands for #{client.username}")
  end

end
