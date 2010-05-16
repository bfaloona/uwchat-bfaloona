require 'uwchat'

describe UWChat::ServerCommand do

  describe "Class Structure" do

    it "should have required elements" do
      # Arrange
      num_cmds = UWChat::ServerCommand.commands.size

      # Act
      class TestCommand < UWChat::ServerCommand; end

      # Assert
      UWChat::ServerCommand.commands.size.should == num_cmds + 1
    end

  end

  describe "Methods" do

    before(:all) do
      @server = UWChat::Server.new(File.join( File.dirname(__FILE__), 'passwd' ))
      @server.start

      # Act
      class Test2Command < UWChat::ServerCommand
        command :cmd2
        description 'my second test command'
        when_run do
          "I'm a block!"
        end
      end
    end

    after(:all) do
      @server.shutdown
    end

    it "should return command values" do
      # Assert
      Test2Command.cmd.should == :cmd2
      Test2Command.desc.should == 'my second test command'
      Test2Command.run_block.should be_kind_of(Proc)
    end

    it "should accept parameters to gain access client and server objects" do
      # Act
      class SanityCommand < UWChat::ServerCommand
        command :sanity
        description 'sanity test of client and server objects'
        when_run do | server, client |
          [client.username, server.port]
        end
      end

      # Assert
      UWChat::ServerCommand.commands.map{|c|c.cmd}.should include(:sanity).should be_true
      client = mock( 'connection' )
      client.should_receive( :username ).and_return( 'user' )
      ret_array = SanityCommand.run_block.call( @server, client )

      ret_array.should be_kind_of(Array)
      ret_array[0].should == 'user'
      ret_array[1].should == 36963
    end

    it "should include execute()" do
      # Arrange
      client = mock( 'connection' )
      client.should_receive( :username ).and_return( 'user' )

      # Act
      ret_array = SanityCommand.execute( @server, client )

      # Assert
      ret_array.should == ['user', 36963]
    end

    it "should accept parameters which are yeilded to the block" do
      # Arrange
      client = mock( 'client' )

      class DoubleCommand < UWChat::ServerCommand
        command :double
        when_run do | server, client, obj |
          obj * 2
        end
      end

      # Act
      DoubleCommand.execute(@server, client, 'double me! ').should == 'double me! double me! '

    end
  end

end