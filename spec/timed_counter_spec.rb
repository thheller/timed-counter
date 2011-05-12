require File.dirname(__FILE__) + "/../lib/timed_counter.rb"

class User
  def initialize(id)
    @id = id
  end

  attr_reader :id
end

class DoesNotRespondToId
  def to_s
    'yo' 
  end
end

describe TimedCounter do
  context "default options" do

    before(:each) do 
      @redis = Redis.connect

      @counter = TimedCounter.new(@redis)
      @counter.reset!(:test)
    end

    it "should join array keys" do
      @counter.make_keys(:test).should == ["test"]

      # anything responding to .id will be converted to class.name#id (probably blows up under 1.8, should only use 1.9 anyways)
      @counter.make_keys([:clicks, User.new(1)]).should == ["clicks/User#1", "clicks"]
      @counter.make_keys([:views, User.new(5678)]).should == ["views/User#5678", "views"]

      @counter.make_keys([:dummy, DoesNotRespondToId.new]).should == ["dummy/yo", "dummy"]
    end

    it "should convert every timestamp to a given timezone before talking to redis" do
      ts = Time.new(2011, 1, 1, 0, 0, 0, 0) # UTC

      @counter_in_utc = TimedCounter.new(@redis, timezone: 'UTC')
      @counter_in_utc.make_ts(ts).should == '201101010000'

      @counter_in_cet = TimedCounter.new(@redis, timezone: 'CET')
      @counter_in_cet.make_ts(ts).should == '201101010100'
    end

    # could fail based on timing but im lazy
    it "should increment multiple values in a single call" do
      @counter.total(:test).should == 0

      @counter.year(:test).should == 0
      @counter.month(:test).should == 0
      @counter.day(:test).should == 0
      @counter.hour(:test).should == 0
      @counter.minute(:test).should == 0

      @counter.incr(:test, 1)
      @counter.total(:test).should == 1
      @counter.year(:test).should == 1
      @counter.month(:test).should == 1
      @counter.day(:test).should == 1
      @counter.hour(:test).should == 1
      @counter.minute(:test).should == 1

      @counter.incr(:test, 100)
      @counter.total(:test).should == 101
      @counter.year(:test).should == 101
      @counter.month(:test).should == 101
      @counter.day(:test).should == 101
      @counter.hour(:test).should == 101
      @counter.minute(:test).should == 101

      @counter.incr(:test, -50)
      @counter.total(:test).should == 51
      @counter.year(:test).should == 51
      @counter.month(:test).should == 51
      @counter.day(:test).should == 51
      @counter.hour(:test).should == 51
      @counter.minute(:test).should == 51
    end
    
    it "should be queryable by minutes" do
      now = Time.now
      five_ago = now - 300
      ten_ago = now - 600

      @counter.incr(:test, 1, five_ago)
      @counter.incr(:test, 1, ten_ago)

      # from 10 mins ago fetch the counts for 10 minutes
      minutes = @counter.minutes(:test, ten_ago, 10)
      minutes.length.should == 10
      minutes.inject(0) { |x, i| x += i }.should == 2 # sum is from rails
      minutes[0].should == 1
      minutes[5].should == 1
    end

    it "should be queryable by hours" do
      now = Time.now
      five_ago = now - (300 * 60)
      ten_ago = now - (600 * 60)

      @counter.incr(:test, 1, five_ago)
      @counter.incr(:test, 1, ten_ago)

      # from 10 hours ago fetch the counts for 10 hours
      minutes = @counter.hours(:test, ten_ago, 10)
      minutes.length.should == 10
      minutes.inject(0) { |x, i| x += i }.should == 2
      minutes[0].should == 1
      minutes[5].should == 1
    end

    it "should be queryable by days" do
      now = Time.now
      five_ago = now - ((300 * 60) * 24)
      ten_ago = now - ((600 * 60) * 24)

      @counter.incr(:test, 1, five_ago)
      @counter.incr(:test, 1, ten_ago)

      # from 10 hours ago fetch the counts for 10 hours
      minutes = @counter.days(:test, ten_ago, 10)
      minutes.length.should == 10
      minutes.inject(0) { |x, i| x += i }.should == 2
      minutes[0].should == 1
      minutes[5].should == 1
    end
  end

  context "custom options" do

    it "should not increment hours if asked to do so" do
      @redis = Redis.connect
      @counter = TimedCounter.new(@redis, minutes: false, hours: false)
      @counter.reset!(:test)

      @test_time = Time.mktime(2011,1,1,0,0,0)

      @counter.incr(:test, 1, @test_time)

      @counter.minutes(:test, @test_time, 1).should == [0]
      @counter.minute(:test, @test_time).should == 0
      
      @counter.hours(:test, @test_time, 1).should == [0]
      @counter.hour(:test, @test_time).should == 0

      @counter.days(:test, @test_time, 1).should == [1]
      @counter.day(:test, @test_time).should == 1
    end
  end

end
