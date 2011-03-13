require File.dirname(__FILE__) + "/../lib/timed_counter.rb"

describe TimedCounter do

  before(:each) do 
    @redis = Redis.connect

    @counter = TimedCounter.new(@redis)
    @counter.reset!(:test)
  end

  it "should join array keys" do
    @counter.make_key(:test).should == "test"
    @counter.make_key([:user, 1]).should == "user/1"
    @counter.make_key([:user, 1, :clicks]).should == "user/1/clicks"
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
