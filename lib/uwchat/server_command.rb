require 'uwchat'

module UWChat

  class ServerCommand
    @@commands = Array.new

    def initialize

    end

    def self::inherited( klass )
      @@commands << klass
    end

    def self::execute( *args )
      raise RuntimeError, "Unable to execute base class: ServerCommand" if self == ServerCommand
      self.run_block.call(args)
    end

    def self::commands
      @@commands
    end

    def self::command( name )
      @command = name
    end

    def self::cmd
      @command
    end

    def self::description( str )
      @description = str
    end

    def self::desc
      @description
    end

    def self::when_run( *args, &block )
      @run_block =  block
      @parameters = *args
    end

    def self::run_block
      @run_block
    end

  end

end
