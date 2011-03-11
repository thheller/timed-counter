require File.dirname(__FILE__) + "/../lib/timed_counter.rb"

describe TimedCounter do

  before(:each) do 
    @redis = Redis.connect
    @redis.flushdb

    @counter = TimedCounter.new("test", @redis)
  end

  # could fail based on timing but im lazy
  it "should increment multiple values in a single call" do
    @counter.total.should == 0

    @counter.year.should == 0
    @counter.month.should == 0
    @counter.day.should == 0
    @counter.hour.should == 0
    @counter.minute.should == 0

    @counter.incr(1)
    @counter.total.should == 1 

    @counter.year.should == 1
    @counter.month.should == 1
    @counter.day.should == 1
    @counter.hour.should == 1
    @counter.minute.should == 1

    @counter.incr(100)
    @counter.total.should == 101 

    @counter.year.should == 101
    @counter.month.should == 101
    @counter.day.should == 101
    @counter.hour.should == 101
    @counter.minute.should == 101

    @counter.incr(-50)
    @counter.total.should == 51 

    @counter.year.should == 51
    @counter.month.should == 51
    @counter.day.should == 51
    @counter.hour.should == 51
    @counter.minute.should == 51
  end
  
  it "should be queryable by minutes" do
    now = Time.now
    five_ago = now - 300
    ten_ago = now - 600

    @counter.incr(1, five_ago)
    @counter.incr(1, ten_ago)

    # from 10 mins ago fetch the counts for 10 minutes
    minutes = @counter.minutes(ten_ago, 10)
    minutes.length.should == 10
    minutes.inject(0) { |x, i| x += i }.should == 2 # sum is from rails
    minutes[0].should == 1
    minutes[5].should == 1
  end

  it "should be queryable by hours" do
    now = Time.now
    five_ago = now - (300 * 60)
    ten_ago = now - (600 * 60)

    @counter.incr(1, five_ago)
    @counter.incr(1, ten_ago)

    # from 10 hours ago fetch the counts for 10 hours
    minutes = @counter.hours(ten_ago, 10)
    minutes.length.should == 10
    minutes.inject(0) { |x, i| x += i }.should == 2
    minutes[0].should == 1
    minutes[5].should == 1
  end

  it "should be queryable by days" do
    now = Time.now
    five_ago = now - ((300 * 60) * 24)
    ten_ago = now - ((600 * 60) * 24)

    @counter.incr(1, five_ago)
    @counter.incr(1, ten_ago)

    # from 10 hours ago fetch the counts for 10 hours
    minutes = @counter.days(ten_ago, 10)
    minutes.length.should == 10
    minutes.inject(0) { |x, i| x += i }.should == 2
    minutes[0].should == 1
    minutes[5].should == 1
  end
end
