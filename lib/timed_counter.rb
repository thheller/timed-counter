require 'rubygems'
require 'redis'
require 'nest'

class TimedCounter
  def initialize(key, redis)
    @redis = redis
    @key = key
    @root = Nest.new(key, redis)

    @redis.sadd("timed_counters", @key)
  end

  # redis key to total will be "c:#{key}:total"
  def incr(amount = 1, time = nil)
    ts = (time || Time.now).strftime("%Y%m%d%H%M")

    hour_key = ts[0, 10]
    min = ts[10, 2]

    day_key = ts[0, 8]
    hour = ts[8,2]

    month_key = ts[0, 6]
    day = ts[6,2]

    year_key = ts[0, 4]
    month = ts[4, 2]

    # store values in hashes
    #
    # total: 1
    # years: { 2011: 1, 2010: 0 }
    # 2011: { 01: 0, 02: 0, 03: 1, ... } months
    # 2011-03: { 01: 0, 02: 0, ...} days
    # 2011-03-11: { 00: 0, 01: 0, 02: 0, ...} hours
    # 2011-03-11 11: { 00, 01, 02, ...} minutes

    result = @redis.multi do
      @root[:total].incrby(amount)
      @root[:years].hincrby(year_key, amount)
      @root[year_key].hincrby(month, amount)
      @root[month_key].hincrby(day, amount)
      @root[day_key].hincrby(hour, amount)
      @root[hour_key].hincrby(min, amount)
    end

    # for now just keep everything, time will tell how much data we are talking about
    # set_expires(result, amount)

    true
  end

  # only set expires when the the counter state == amount aka. we created it.
  def set_expires(result, amount)
    if result[0] == amount
      # total was new
    end

    if result[1] == amount
      # years/year was new
    end

    if result[2] == amount
      # year/month was new
    end

    if result[3] == amount
      # month/day was new
    end

    # keep hour precision data for 180 days?
    if result[4] == amount
      # day/hour was new
      @root[hour_key].expire(86400 * 180) # expire in 180 days?
    end

    # keep minute precision data for 30 days?
    if result[5] == amount
      # hour/min was new
      @root[hour_key].expire(86400 * 30) # expire in 180 days?
    end

    true
  end


  # start timestamp
  # count number of steps
  # step_size number of seconds to increment steps
  # ts_index index in 201103111200
  def query_hash_range(start, count, step_size, ts_index, ts_size = 2)
    hash = Hash.new { |h, k| h[k] = [] }
    count.times do |it|
      ts = (start + (it * step_size)).strftime("%Y%m%d%H%M")
      hash[ts[0, ts_index]] << ts[ts_index, ts_size]
    end
    
    keys = hash.to_a.sort_by { |it| it[0] }
    mres = @redis.multi do
      keys.each do |key, values|
        @root[key].hmget(*values)
      end
    end

    mres.flatten.collect(&:to_i)
  end

  def total
    @root[:total].get.to_i
  end

  def year(time = nil)
    @root[:years].hget((time || Time.now).strftime('%Y')).to_i
  end

  def month(time = nil)
    ts = (time || Time.now).strftime("%Y%m")
    @root[ts[0, 4]].hget(ts[4, 2]).to_i
  end

  def day(time = nil)
    ts = (time || Time.now).strftime("%Y%m%d")
    @root[ts[0, 6]].hget(ts[6, 2]).to_i
  end

  def days(start, count)
    query_hash_range(start, count, 60*60*24, 6, 2)
  end

  def hour(time = nil)
    ts = (time || Time.now).strftime("%Y%m%d%H")
    @root[ts[0, 8]].hget(ts[8, 2]).to_i
  end

  def hours(start, count)
    query_hash_range(start, count, 60*60, 8, 2)
  end

  def minute(time = nil)
    ts = (time || Time.now).strftime("%Y%m%d%H%M")
    @root[ts[0, 10]].hget(ts[10, 2]).to_i
  end

  def minutes(start, count)
    query_hash_range(start, count, 60, 10, 2)
  end
end
